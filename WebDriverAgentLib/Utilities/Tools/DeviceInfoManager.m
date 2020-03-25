//
//  DeviceInfoManager.m
//  ClientTest
//
//  Created by Leon on 2017/5/18.
//  Copyright © 2017年 王鹏飞. All rights reserved.
//

#define KIsiPhoneX ([UIScreen instancesRespondToSelector:@selector(currentMode)] ? CGSizeEqualToSize(CGSizeMake(1125, 2436), [[UIScreen mainScreen] currentMode].size) : NO)

#import <AdSupport/AdSupport.h>
#import <UIKit/UIKit.h>

#import <CoreTelephony/CTCarrier.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>

// 下面是获取mac地址需要导入的头文件
#include <sys/socket.h> // Per msqr
#include <sys/sysctl.h>
#include <net/if.h>
#include <net/if_dl.h>


#import <sys/sockio.h>
#import <sys/ioctl.h>
#import <arpa/inet.h>

// 下面是获取ip需要的头文件
#include <ifaddrs.h>

//获取网络类型标识的头文件
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <SystemConfiguration/CaptiveNetwork.h>
#import <SystemConfiguration/SystemConfiguration.h>


#include <mach/mach.h> // 获取CPU信息所需要引入的头文件
//#include <arpa/inet.h>
//#include <ifaddrs.h>
#import "DeviceInfoManager.h"
#import "sys/utsname.h"
#import "Reachability.h"
#import "DeviceDataLibrery.h"

@implementation DeviceInfoManager

+ (instancetype)sharedManager {
  static DeviceInfoManager *_manager;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    _manager = [[DeviceInfoManager alloc] init];
  });
  return _manager;
}

/**
 *  获取mac地址
 *
 *  @return mac地址  为了保护用户隐私，每次都不一样，苹果官方哄小孩玩的
 */
- (NSString *)getMacAddress {
  int                    mib[6];
  size_t                len;
  char                *buf;
  unsigned char        *ptr;
  struct if_msghdr    *ifm;
  struct sockaddr_dl    *sdl;
  
  mib[0] = CTL_NET;
  mib[1] = AF_ROUTE;
  mib[2] = 0;
  mib[3] = AF_LINK;
  mib[4] = NET_RT_IFLIST;
  
  if ((mib[5] = if_nametoindex("en0")) == 0) {
    printf("Error: if_nametoindex error/n");
    return NULL;
  }
  
  if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0) {
    printf("Error: sysctl, take 1/n");
    return NULL;
  }
  
  if ((buf = malloc(len)) == NULL) {
    printf("Could not allocate memory. error!/n");
    return NULL;
  }
  
  if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
    printf("Error: sysctl, take 2");
    return NULL;
  }
  
  ifm = (struct if_msghdr *)buf;
  sdl = (struct sockaddr_dl *)(ifm + 1);
  ptr = (unsigned char *)LLADDR(sdl);
  
  NSString *outstring = [NSString stringWithFormat:@"%02x%02x%02x%02x%02x%02x", *ptr, *(ptr+1), *(ptr+2), *(ptr+3), *(ptr+4), *(ptr+5)];
  free(buf);
  
  return [outstring uppercaseString];
}


// 获取设备型号
- (const NSString *)getDeviceName {
  return [[DeviceDataLibrery sharedLibrery] getDiviceName];
}

- (const NSString *)getInitialFirmware {
  return [[DeviceDataLibrery sharedLibrery] getInitialVersion];
}

- (const NSString *)getLatestFirmware {
  return [[DeviceDataLibrery sharedLibrery] getLatestVersion];
}

// 私有API，上线会被拒
- (NSString *)getDeviceColor {
  return [self _getDeviceColorWithKey:@"DeviceColor"];
}

// 私有API，上线会被拒
- (NSString *)getDeviceEnclosureColor {
  return [self _getDeviceColorWithKey:@"DeviceEnclosureColor"];
}

// 广告位标识符：在同一个设备上的所有App都会取到相同的值，是苹果专门给各广告提供商用来追踪用户而设的，用户可以在 设置|隐私|广告追踪里重置此id的值，或限制此id的使用，故此id有可能会取不到值，但好在Apple默认是允许追踪的，而且一般用户都不知道有这么个设置，所以基本上用来监测推广效果，是戳戳有余了
- (NSString *)getIDFA {
  return [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
}

- (NSString *)getDeviceModel {
  struct utsname systemInfo;
  uname(&systemInfo);
  NSString *deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
  return deviceModel;
}

#ifdef __IPHONE_OS_VERSION_MIN_REQUIRED
- (BOOL)canMakePhoneCall {
  __block BOOL can = NO;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSURL *iURL = [NSURL URLWithString:@"tel://"];
    if (iURL) {
      can = [[UIApplication sharedApplication] canOpenURL:iURL];
    }
  });
  return can;
}
#endif

- (NSDate *)getSystemUptime {
  NSTimeInterval time = [[NSProcessInfo processInfo] systemUptime];
  return [[NSDate alloc] initWithTimeIntervalSinceNow:(0 - time)];
}

- (NSUInteger)getCPUFrequency {
  return [self _getSystemInfo:HW_CPU_FREQ];
}

- (NSUInteger)getBusFrequency {
  return [self _getSystemInfo:HW_BUS_FREQ];
}

- (NSUInteger)getRamSize {
  return [self _getSystemInfo:HW_MEMSIZE];
}

- (NSString *)getCPUProcessor {
  return [[DeviceDataLibrery sharedLibrery] getCPUProcessor] ? : @"unKnown";
}

#pragma mark - CPU
- (NSUInteger)getCPUCount {
  return [NSProcessInfo processInfo].activeProcessorCount;
}

- (float)getCPUUsage {
  float cpu = 0;
  NSArray *cpus = [self getPerCPUUsage];
  if (cpus.count == 0) return -1;
  for (NSNumber *n in cpus) {
    cpu += n.floatValue;
  }
  return cpu;
}



- (NSString *)getNettype {

   NSString *netconnType = @"";
    Reachability *reach = [Reachability reachabilityWithHostName:@"www.apple.com"];
    
  #pragma clang diagnostic push
  #pragma clang diagnostic ignored "-Wcovered-switch-default"
    switch ([reach currentReachabilityStatus]) {
      case NotReachable: {
        netconnType = @"no network";
      }
        break;
      case ReachableViaWiFi: {
        netconnType = @"Wifi";
      }
        break;
      case ReachableViaWWAN: {
        CTTelephonyNetworkInfo *info = [[CTTelephonyNetworkInfo alloc] init];
        NSString *currentStatus = info.currentRadioAccessTechnology;
        if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyGPRS"]) {
          netconnType = @"GPRS";
        }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyEdge"]) {
          netconnType = @"2.75G EDGE";
        }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyWCDMA"]){
          netconnType = @"3G";
        }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyHSDPA"]){
          netconnType = @"3.5G HSDPA";
        }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyHSUPA"]){
          netconnType = @"3.5G HSUPA";
        }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyCDMA1x"]){
          netconnType = @"2G";
        }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyCDMAEVDORev0"]){
          netconnType = @"3G";
        }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyCDMAEVDORevA"]){
          netconnType = @"3G";
        }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyCDMAEVDORevB"]){
          netconnType = @"3G";
        }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyeHRPD"]){
          netconnType = @"HRPD";
        }else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyLTE"]){
          netconnType = @"4G";
        }
      }
        break;
      default:
        break;
    }
    NSLog(@"netconnType is %@", netconnType);
  #pragma clang diagnostic pop
   
  return netconnType;
}





- (NSArray *)getPerCPUUsage {
  processor_info_array_t _cpuInfo, _prevCPUInfo = nil;
  mach_msg_type_number_t _numCPUInfo, _numPrevCPUInfo = 0;
  unsigned _numCPUs;
  NSLock *_cpuUsageLock;
  
  int _mib[2U] = { CTL_HW, HW_NCPU };
  size_t _sizeOfNumCPUs = sizeof(_numCPUs);
  int _status = sysctl(_mib, 2U, &_numCPUs, &_sizeOfNumCPUs, NULL, 0U);
  if (_status)
    _numCPUs = 1;
  
  _cpuUsageLock = [[NSLock alloc] init];
  
  natural_t _numCPUsU = 0U;
  kern_return_t err = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &_numCPUsU, &_cpuInfo, &_numCPUInfo);
  if (err == KERN_SUCCESS) {
    [_cpuUsageLock lock];
    
    NSMutableArray *cpus = [NSMutableArray new];
    for (unsigned i = 0U; i < _numCPUs; ++i) {
      Float32 _inUse, _total;
      if (_prevCPUInfo) {
        _inUse = (
                  (_cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER]   - _prevCPUInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER])
                  + (_cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM] - _prevCPUInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM])
                  + (_cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE]   - _prevCPUInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE])
                  );
        _total = _inUse + (_cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE] - _prevCPUInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE]);
      } else {
        _inUse = _cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_USER] + _cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_SYSTEM] + _cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_NICE];
        _total = _inUse + _cpuInfo[(CPU_STATE_MAX * i) + CPU_STATE_IDLE];
      }
      [cpus addObject:@(_inUse / _total)];
    }
    
    [_cpuUsageLock unlock];
    if (_prevCPUInfo) {
      size_t prevCpuInfoSize = sizeof(integer_t) * _numPrevCPUInfo;
      vm_deallocate(mach_task_self(), (vm_address_t)_prevCPUInfo, prevCpuInfoSize);
    }
    return cpus;
  } else {
    return nil;
  }
}

#pragma mark - Disk
- (NSString *)getApplicationSize {
  unsigned long long documentSize   =  [self _getSizeOfFolder:[self _getDocumentPath]];
  unsigned long long librarySize   =  [self _getSizeOfFolder:[self _getLibraryPath]];
  unsigned long long cacheSize =  [self _getSizeOfFolder:[self _getCachePath]];
  
  unsigned long long total = documentSize + librarySize + cacheSize;
  
  NSString *applicationSize = [NSByteCountFormatter stringFromByteCount:total countStyle:NSByteCountFormatterCountStyleFile];
  return applicationSize;
}

- (int64_t)getTotalDiskSpace {
  NSError *error = nil;
  NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:&error];
  if (error) return -1;
  int64_t space =  [[attrs objectForKey:NSFileSystemSize] longLongValue];
  if (space < 0) space = -1;
  return space;
}

- (int64_t)getFreeDiskSpace {
  
  //    if (@available(iOS 11.0, *)) {
  //        NSError *error = nil;
  //        NSURL *testURL = [NSURL URLWithString:NSHomeDirectory()];
  //
  //        NSDictionary *dict = [testURL resourceValuesForKeys:@[NSURLVolumeAvailableCapacityForImportantUsageKey] error:&error];
  //
  //        return (int64_t)dict[NSURLVolumeAvailableCapacityForImportantUsageKey];
  //
  //
  //    } else {
  NSError *error = nil;
  NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:&error];
  if (error) return -1;
  int64_t space =  [[attrs objectForKey:NSFileSystemFreeSize] longLongValue];
  if (space < 0) space = -1;
  return space;
  //    }
  
}

- (int64_t)getUsedDiskSpace {
  int64_t totalDisk = [self getTotalDiskSpace];
  int64_t freeDisk = [self getFreeDiskSpace];
  if (totalDisk < 0 || freeDisk < 0) return -1;
  int64_t usedDisk = totalDisk - freeDisk;
  if (usedDisk < 0) usedDisk = -1;
  return usedDisk;
}

#pragma mark - Memory
- (int64_t)getTotalMemory {
  int64_t totalMemory = [[NSProcessInfo processInfo] physicalMemory];
  if (totalMemory < -1) totalMemory = -1;
  return totalMemory;
}

- (int64_t)getActiveMemory {
  mach_port_t host_port = mach_host_self();
  mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
  vm_size_t page_size;
  vm_statistics_data_t vm_stat;
  kern_return_t kern;
  
  kern = host_page_size(host_port, &page_size);
  if (kern != KERN_SUCCESS) return -1;
  kern = host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size);
  if (kern != KERN_SUCCESS) return -1;
  return vm_stat.active_count * page_size;
}

- (int64_t)getInActiveMemory {
  mach_port_t host_port = mach_host_self();
  mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
  vm_size_t page_size;
  vm_statistics_data_t vm_stat;
  kern_return_t kern;
  
  kern = host_page_size(host_port, &page_size);
  if (kern != KERN_SUCCESS) return -1;
  kern = host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size);
  if (kern != KERN_SUCCESS) return -1;
  return vm_stat.inactive_count * page_size;
}

- (int64_t)getFreeMemory {
  mach_port_t host_port = mach_host_self();
  mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
  vm_size_t page_size;
  vm_statistics_data_t vm_stat;
  kern_return_t kern;
  
  kern = host_page_size(host_port, &page_size);
  if (kern != KERN_SUCCESS) return -1;
  kern = host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size);
  if (kern != KERN_SUCCESS) return -1;
  return vm_stat.free_count * page_size;
}

- (int64_t)getUsedMemory {
  mach_port_t host_port = mach_host_self();
  mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
  vm_size_t page_size;
  vm_statistics_data_t vm_stat;
  kern_return_t kern;
  
  kern = host_page_size(host_port, &page_size);
  if (kern != KERN_SUCCESS) return -1;
  kern = host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size);
  if (kern != KERN_SUCCESS) return -1;
  return page_size * (vm_stat.active_count + vm_stat.inactive_count + vm_stat.wire_count);
}

- (int64_t)getWiredMemory {
  mach_port_t host_port = mach_host_self();
  mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
  vm_size_t page_size;
  vm_statistics_data_t vm_stat;
  kern_return_t kern;
  
  kern = host_page_size(host_port, &page_size);
  if (kern != KERN_SUCCESS) return -1;
  kern = host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size);
  if (kern != KERN_SUCCESS) return -1;
  return vm_stat.wire_count * page_size;
}

- (int64_t)getPurgableMemory {
  mach_port_t host_port = mach_host_self();
  mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
  vm_size_t page_size;
  vm_statistics_data_t vm_stat;
  kern_return_t kern;
  
  kern = host_page_size(host_port, &page_size);
  if (kern != KERN_SUCCESS) return -1;
  kern = host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size);
  if (kern != KERN_SUCCESS) return -1;
  return vm_stat.purgeable_count * page_size;
}

#pragma mark - Private Method
- (NSString *)_getDeviceColorWithKey:(NSString *)key {
  UIDevice *device = [UIDevice currentDevice];
  SEL selector = NSSelectorFromString(@"deviceInfoForKey:");
  if (![device respondsToSelector:selector]) {
    selector = NSSelectorFromString(@"_deviceInfoForKey:");
  }
  if ([device respondsToSelector:selector]) {
    // 消除警告“performSelector may cause a leak because its selector is unknown”
    IMP imp = [device methodForSelector:selector];
    NSString * (*func)(id, SEL, NSString *) = (NSString *(*)(__strong id, SEL, NSString *__strong))imp;
    
    return func(device, selector, key);
  }
  return @"unKnown";
}

- (NSUInteger)_getSystemInfo:(uint)typeSpecifier {
  size_t size = sizeof(int);
  int result;
  int mib[2] = {CTL_HW, typeSpecifier};
  sysctl(mib, 2, &result, &size, NULL, 0);
  return (NSUInteger)result;
}

- (NSString *)_getDocumentPath {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *basePath = [paths firstObject];
  return basePath;
}

- (NSString *)_getLibraryPath {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
  NSString *basePath = [paths firstObject];
  return basePath;
}

- (NSString *)_getCachePath {
  NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
  NSString *basePath = [paths firstObject];
  return basePath;
}

-(unsigned long long)_getSizeOfFolder:(NSString *)folderPath {
  NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:folderPath error:nil];
  NSEnumerator *contentsEnumurator = [contents objectEnumerator];
  
  NSString *file;
  unsigned long long folderSize = 0;
  
  while ((file = [contentsEnumurator nextObject])) {
    NSDictionary *fileAttributes = [[NSFileManager defaultManager] attributesOfItemAtPath:[folderPath stringByAppendingPathComponent:file] error:nil];
    folderSize += [[fileAttributes objectForKey:NSFileSize] intValue];
  }
  return folderSize;
}

- (double)getScaleFactor {
  if ([[self uu_showName] isEqualToString:@"iPhone 1G"] || [[self uu_showName] isEqualToString:@"iPhone 3G"] || [[self uu_showName] isEqualToString:@"iPhone 3GS"] || [[self uu_showName] isEqualToString:@"iPod Touch 1G"] || [[self uu_showName] isEqualToString:@"iPod Touch 2G"] || [[self uu_showName] isEqualToString:@"iPod Touch 3G"]) {
    return 1.0;
  }else if ([[self uu_showName] isEqualToString:@"iPhone 4"] || [[self uu_showName]isEqualToString:@"Verizon iPhone 4"] || [[self uu_showName]isEqualToString:@"iPhone 4s"] || [[self uu_showName] isEqualToString:@"iPod Touch 4G"]||[[self uu_showName] isEqualToString:@"iPhone 5"] || [[self uu_showName] isEqualToString:@"iPhone 5c"] || [[self uu_showName] isEqualToString:@"iPhone 5s"] || [[self uu_showName] isEqualToString:@"iPhone SE"] || [[self uu_showName] isEqualToString:@"iPod Touch 5G"]||[[self uu_showName] isEqualToString:@"iPhone 6"] || [[self uu_showName]isEqualToString:@"iPhone 6s"] || [[self uu_showName] isEqualToString:@"iPhone 7"] || [[self uu_showName] isEqualToString:@"iPhone 8"] || [[self uu_showName] isEqualToString:@"iPhone XR"]){
    return 2.0;
  }else if ([[self uu_showName] isEqualToString:@"iPhone 6 Plus"] || [[self uu_showName] isEqualToString:@"iPhone 6s Plus"] || [[self uu_showName] isEqualToString:@"iPhone 7 Plus"] || [[self uu_showName] isEqualToString:@"iPhone 8 Plus"]||[[self uu_showName] isEqualToString:@"iPhone X"] || [[self uu_showName] isEqualToString:@"iPhone XS"] || [[self uu_showName] isEqualToString:@"iPhone XS Max"]){
    return 3.0;
  }else{
    return 1.0;
  }
}

- (NSString *)uu_showName {
  struct utsname systemInfo;
  uname(&systemInfo);
  NSString *deviceModel = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];
  if ([deviceModel isEqualToString:@"iPhone1,1"]) return @"iPhone 1G";
  if ([deviceModel isEqualToString:@"iPhone1,2"]) return @"iPhone 3G";
  if ([deviceModel isEqualToString:@"iPhone2,1"]) return @"iPhone 3GS";
  if ([deviceModel isEqualToString:@"iPhone3,1"]) return @"iPhone 4";
  if ([deviceModel isEqualToString:@"iPhone3,2"]) return @"Verizon iPhone 4";
  if ([deviceModel isEqualToString:@"iPhone4,1"]) return @"iPhone 4s";
  if ([deviceModel isEqualToString:@"iPhone5,1"]) return @"iPhone 5";
  if ([deviceModel isEqualToString:@"iPhone5,2"]) return @"iPhone 5";
  if ([deviceModel isEqualToString:@"iPhone5,3"]) return @"iPhone 5c";
  if ([deviceModel isEqualToString:@"iPhone5,4"]) return @"iPhone 5c";
  if ([deviceModel isEqualToString:@"iPhone6,1"]) return @"iPhone 5s";
  if ([deviceModel isEqualToString:@"iPhone6,2"]) return @"iPhone 5s";
  if ([deviceModel isEqualToString:@"iPhone8,4"]) return @"iPhone SE";
  if ([deviceModel isEqualToString:@"iPhone7,1"]) return @"iPhone 6 Plus";
  if ([deviceModel isEqualToString:@"iPhone7,2"]) return @"iPhone 6";
  if ([deviceModel isEqualToString:@"iPhone8,1"]) return @"iPhone 6s";
  if ([deviceModel isEqualToString:@"iPhone8,2"]) return @"iPhone 6s Plus";
  if ([deviceModel isEqualToString:@"iPhone9,1"]) return @"iPhone 7";
  if ([deviceModel isEqualToString:@"iPhone9,2"]) return @"iPhone 7 Plus";
  if ([deviceModel isEqualToString:@"iPhone10,1"]) return @"iPhone 8";
  if ([deviceModel isEqualToString:@"iPhone10,2"]) return @"iPhone 8 Plus";
  if ([deviceModel isEqualToString:@"iPhone10,3"]) return @"iPhone X";
  if ([deviceModel isEqualToString:@"iPhone10,4"]) return @"iPhone 8";
  if ([deviceModel isEqualToString:@"iPhone10,5"]) return @"iPhone 8 Plus";
  if ([deviceModel isEqualToString:@"iPhone10,6"]) return @"iPhone X";
  if ([deviceModel isEqualToString:@"iPhone11,8"]) return @"iPhone XR";
  if ([deviceModel isEqualToString:@"iPhone11,6"]) return @"iPhone XS Max";
  if ([deviceModel isEqualToString:@"iPhone11,2"]) return @"iPhone XS";
  
  //iPod 系列
  if ([deviceModel isEqualToString:@"iPod1,1"]) return @"iPod Touch 1G";
  if ([deviceModel isEqualToString:@"iPod2,1"]) return @"iPod Touch 2G";
  if ([deviceModel isEqualToString:@"iPod3,1"]) return @"iPod Touch 3G";
  if ([deviceModel isEqualToString:@"iPod4,1"]) return @"iPod Touch 4G";
  if ([deviceModel isEqualToString:@"iPod5,1"]) return @"iPod Touch 5G";
  
  //iPad 系列
  if ([deviceModel isEqualToString:@"iPad1,1"]) return @"iPad";
  if ([deviceModel isEqualToString:@"iPad2,1"]) return @"iPad 2 (WiFi)";
  if ([deviceModel isEqualToString:@"iPad2,2"]) return @"iPad 2 (GSM)";
  if ([deviceModel isEqualToString:@"iPad2,3"]) return @"iPad 2 (CDMA)";
  if ([deviceModel isEqualToString:@"iPad2,4"]) return @"iPad 2 (32nm)";
  if ([deviceModel isEqualToString:@"iPad2,5"]) return @"iPad mini (WiFi)";
  if ([deviceModel isEqualToString:@"iPad2,6"]) return @"iPad mini (GSM)";
  if ([deviceModel isEqualToString:@"iPad2,7"]) return @"iPad mini (CDMA)";
  
  if ([deviceModel isEqualToString:@"iPad3,1"]) return @"iPad 3(WiFi)";
  if ([deviceModel isEqualToString:@"iPad3,2"]) return @"iPad 3(CDMA)";
  if ([deviceModel isEqualToString:@"iPad3,3"]) return @"iPad 3(4G)";
  if ([deviceModel isEqualToString:@"iPad3,4"]) return @"iPad 4 (WiFi)";
  if ([deviceModel isEqualToString:@"iPad3,5"]) return @"iPad 4 (4G)";
  if ([deviceModel isEqualToString:@"iPad3,6"]) return @"iPad 4 (CDMA)";
  
  if ([deviceModel isEqualToString:@"iPad4,1"]) return @"iPad Air";
  if ([deviceModel isEqualToString:@"iPad4,2"]) return @"iPad Air";
  if ([deviceModel isEqualToString:@"iPad4,3"]) return @"iPad Air";
  if ([deviceModel isEqualToString:@"iPad5,3"]) return @"iPad Air 2";
  if ([deviceModel isEqualToString:@"iPad5,4"]) return @"iPad Air 2";
  if ([deviceModel isEqualToString:@"i386"]) return @"Simulator";
  if ([deviceModel isEqualToString:@"x86_64"]) return @"Simulator";
  
  if ([deviceModel isEqualToString:@"iPad4,4"]
      ||[deviceModel isEqualToString:@"iPad4,5"]
      ||[deviceModel isEqualToString:@"iPad4,6"]) return @"iPad mini 2";
  
  if ([deviceModel isEqualToString:@"iPad4,7"]
      ||[deviceModel isEqualToString:@"iPad4,8"]
      ||[deviceModel isEqualToString:@"iPad4,9"]) return @"iPad mini 3";
  
  return deviceModel;
}

@end

