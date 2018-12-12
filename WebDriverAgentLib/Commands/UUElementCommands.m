//
//  UUElementCommands.m
//  WebDriverAgent
//
//  Created by 刘 晓东 on 2017/6/27.
//  Copyright © 2017年 Facebook. All rights reserved.
//

#import <sys/utsname.h>
#import <objc/runtime.h>
#import <SystemConfiguration/CaptiveNetwork.h>

#import "UUElementCommands.h"

#import "FBApplication.h"
#import "FBKeyboard.h"
#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBRunLoopSpinner.h"
#import "FBElementCache.h"
#import "FBErrorBuilder.h"
#import "FBSession.h"
#import "FBApplication.h"
#import "FBMacros.h"
#import "FBMathUtils.h"
#import "NSPredicate+FBFormat.h"
#import "XCUICoordinate.h"
#import "XCUIDevice.h"
#import "XCTRunnerDaemonSession.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBPickerWheel.h"
#import "XCUIElement+FBScrolling.h"
#import "XCUIElement+FBTap.h"
#import "XCUIElement+FBTyping.h"
#import "XCUIElement+FBUtilities.h"
#import "XCUIElement+FBWebDriverAttributes.h"
#import "FBElementTypeTransformer.h"
#import "XCUIElement.h"
#import "XCUIElementQuery.h"

#import "XCPointerEventPath.h"
#import "XCSynthesizedEventRecord.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCTestManager_ManagerInterface-Protocol.h"
#import "XCUIDevice+FBHelpers.h"
#import "XCEventGenerator.h"

#import "FBXPath.h"
#import "XCUIApplication+FBHelpers.h"
#import "DeviceInfoManager.h"

#import "FBAlert.h"

#import "UUMonkey.h"
#import "UUMonkeyXCTestPrivate.h"
#import "UUMonkeySingleton.h"

#import<sys/sysctl.h>
#import<mach/mach.h>

#import <ReplayKit/ReplayKit.h>

static const NSTimeInterval UUHomeButtonCoolOffTime = 0.0;

@interface UUElementCommands ()

@end

@implementation UUElementCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes {
  return
  @[
    [[FBRoute POST:@"/uusense/tap"].withoutSession respondWithTarget:self action:@selector(uuHandleTap:)],
    [[FBRoute POST:@"/uusense/forcetouch"].withoutSession respondWithTarget:self action:@selector(uuHandleForceTouch:)],
    [[FBRoute POST:@"/uusense/touchAndHold"].withoutSession respondWithTarget:self action:@selector(uuHandleTouchAndHoldCoordinate:)],
    [[FBRoute POST:@"/uusense/doubleTap"] respondWithTarget:self action:@selector(uuHandleDoubleTapCoordinate:)],
    [[FBRoute POST:@"/uusense/dragfromtoforduration"].withoutSession respondWithTarget:self action:@selector(uuHandleDragCoordinate:)],
    [[FBRoute POST:@"/uusense/back"] respondWithTarget:self action:@selector(uuBack:)],
    
    [[FBRoute GET:@"/uusense/ssid"].withoutSession respondWithTarget:self action:@selector(uuGetSSID:)],
    [[FBRoute GET:@"/uusense/source"].withoutSession respondWithTarget:self action:@selector(uuSource:)],
    
    [[FBRoute GET:@"/uusense/sysinfo"].withoutSession respondWithTarget:self action:@selector(uuGetSysInfo:)],
    [[FBRoute GET:@"/uusense/alert"].withoutSession respondWithTarget:self action:@selector(uuDealAlert:)],
    [[FBRoute POST:@"/uusense/dealAlert"].withoutSession respondWithTarget:self action:@selector(uuDealAlertWithParam:)],
    
    [[FBRoute POST:@"/uusense/homescreen"].withoutSession respondWithTarget:self action:@selector(handleHomescreenCommand:)],
    [[FBRoute POST:@"/uusense/monkey"] respondWithTarget:self action:@selector(handleMonkeyCommand:)],
    [[FBRoute POST:@"/uusense/activeTestingApp"].withoutSession respondWithTarget:self action:@selector(handleActiveTestingAppCommand:)],
    [[FBRoute POST:@"/uusense/whetherCrashed"].withoutSession respondWithTarget:self action:@selector(handleWhetherCrashedCommand:)],
    [[FBRoute POST:@"/uusense/globalInput"].withoutSession respondWithTarget:self action:@selector(uu_handleGlobalInput:)],
    
    [[FBRoute POST:@"/uusense/doubleMove"].withoutSession respondWithTarget:self action:@selector(uu_handleDoubleMove:)],
    
    [[FBRoute GET:@"/uusense/lockButton"].withoutSession respondWithTarget:self action:@selector(uu_lockButton:)],
    [[FBRoute POST:@"/uusense/unlockWithOutCheck"].withoutSession respondWithTarget:self action:@selector(handleUnlock:)],
  ];
}

#pragma mark - Commands
+ (id<FBResponsePayload>)uu_lockButton:(FBRouteRequest *)request {
  [[XCUIDevice sharedDevice] pressLockButton];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)uu_handleDoubleMove:(FBRouteRequest *)request {

  NSInteger aX1 = [request.arguments[@"aX1"] integerValue];
  NSInteger aY1 = [request.arguments[@"aY1"] integerValue];
  NSInteger aX2 = [request.arguments[@"aX2"] integerValue];
  NSInteger aY2 = [request.arguments[@"aY2"] integerValue];
  
  NSInteger bX1 = [request.arguments[@"bX1"] integerValue];
  NSInteger bY1 = [request.arguments[@"bY1"] integerValue];
  NSInteger bX2 = [request.arguments[@"bX2"] integerValue];
  NSInteger bY2 = [request.arguments[@"bY2"] integerValue];
  
  float duration = [request.arguments[@"duration"] floatValue];
  
  __block BOOL didSucceed;
  [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)(void)){
    XCEventGeneratorHandler handlerBlock = ^(XCSynthesizedEventRecord *record, NSError *commandError) {
      didSucceed = (commandError == nil);
      completion();
    };
    
    CGPoint hitPoint = CGPointMake(aX1, aY1);
    CGPoint targetPoint = CGPointMake(aX2, aY2);
    XCPointerEventPath *eventPath = [[XCPointerEventPath alloc] initForTouchAtPoint:hitPoint offset:0.0];
    [eventPath moveToPoint:targetPoint atOffset:duration];
    [eventPath liftUpAtOffset:duration];
    
    CGPoint hitPoint2 = CGPointMake(bX1, bY1);
    CGPoint targetPoint2 = CGPointMake(bX2, bY2);
    XCPointerEventPath *eventPath2 = [[XCPointerEventPath alloc] initForTouchAtPoint:hitPoint2 offset:0.0];
    [eventPath2 moveToPoint:targetPoint2 atOffset:duration];
    [eventPath2 liftUpAtOffset:duration];
    
    XCSynthesizedEventRecord *event =
    [[XCSynthesizedEventRecord alloc]
     initWithName:@"doubleMove"
     interfaceOrientation:UIInterfaceOrientationPortrait];
    
    [event addPointerEventPath:eventPath];
    [event addPointerEventPath:eventPath2];

    [[XCTRunnerDaemonSession sharedSession] synthesizeEvent:event completion:^(NSError *invokeError){
      handlerBlock(event, invokeError);
    }];
  }];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)uuDealAlert:(FBRouteRequest *)request {
  FBApplication *application = request.session.activeApplication ?: [FBApplication fb_activeApplication];
  FBAlert *alert = [FBAlert alertWithApplication:application];
  NSError *error;
  NSInteger counts = 0;
  while (alert.isPresent && counts < 10) {
    [alert uuAcceptWithError:&error];
    alert = [FBAlert alertWithApplication:application];
    counts += 1;
  }
  if (error) {
    return FBResponseWithError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)uuDealAlertWithParam:(FBRouteRequest *)request {
  FBApplication *application = request.session.activeApplication ?: [FBApplication fb_activeApplication];
  BOOL accept = [request.arguments[@"accept"] boolValue];
  FBAlert *alert = [FBAlert alertWithApplication:application];
  if (nil == alert) {
    return FBResponseWithOK();
  }
  NSError *error;
  NSInteger counts = 0;
  while (alert.isPresent && counts < 10) {
    if (accept) {
      [alert uuAcceptWithError:&error];
    } else {
      [alert uuDismissWithError:&error];
    }
    alert = [FBAlert alertWithApplication:application];
    counts += 1;
  }
  if (error) {
    return FBResponseWithError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)uuGetSysInfo:(FBRouteRequest *)request
{
  
  vm_statistics_data_t vmStats;
  mach_msg_type_number_t infoCount = HOST_VM_INFO_COUNT;
  kern_return_t kernReturn = host_statistics(mach_host_self(),
                                             HOST_VM_INFO,
                                             (host_info_t)&vmStats,
                                             &infoCount);
  
  if (kernReturn != KERN_SUCCESS) {
    
  }
  
  float cpuUsage           = [[DeviceInfoManager sharedManager] getCPUUsage];
  int64_t totalMem         = [[DeviceInfoManager sharedManager] getTotalMemory];
  double freeMem           = vm_page_size *vmStats.free_count;
  int64_t freeDisk         = [[DeviceInfoManager sharedManager] getFreeDiskSpace];
  NSString *networkTypeStr = [[DeviceInfoManager sharedManager] getNettype];

  NSString *totalMemStr = [NSString stringWithFormat:@"%.2f", totalMem/1024.0/1024.0];
  NSString *freeMemStr  = [NSString stringWithFormat:@"%.2f", freeMem/1024.0/1024.0];
  NSString *freeDiskStr = [NSString stringWithFormat:@"%.2f", freeDisk/1024.0/1024.0];
  
  
  NSMutableDictionary *dic = [NSMutableDictionary dictionary];
  [dic setObject:@(cpuUsage) forKey:@"cpuUsage"];
  [dic setObject:networkTypeStr forKey:@"networkType"];
  [dic setObject:totalMemStr forKey:@"totalMem"];
  [dic setObject:freeDiskStr forKey:@"freeDisk"];
  [dic setObject:freeMemStr forKey:@"freeMem"];
  [dic setObject:@"MB" forKey:@"memeryUnit"];
  
  return FBResponseWithObject(dic);
}

+ (id<FBResponsePayload>)uuHandleDoubleTapCoordinate:(FBRouteRequest *)request {
  XCUIApplication *application        = request.session.uu_application;
  CGPoint doubleTapPoint              = CGPointMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue]);
  XCUICoordinate *doubleTapCoordinate = [self.class uuGestureCoordinateWithCoordinate:doubleTapPoint application:application shouldApplyOrientationWorkaround:YES];
  [doubleTapCoordinate doubleTap];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)uuHandleTouchAndHoldCoordinate:(FBRouteRequest *)request {
  CGPoint touchPoint        = CGPointMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue]);
  double duration           = [request.arguments[@"duration"] doubleValue];
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  [[XCEventGenerator sharedGenerator] pressAtPoint:touchPoint forDuration:[request.arguments[@"duration"] doubleValue] orientation:UIInterfaceOrientationPortrait handler:^(XCSynthesizedEventRecord *record, NSError *error) {
    dispatch_semaphore_signal(sema);
  }];
  dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(duration * NSEC_PER_SEC)));
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)uuHandleDragCoordinate:(FBRouteRequest *)request {
  CGPoint startPoint      = CGPointMake((CGFloat)[request.arguments[@"fromX"] doubleValue], (CGFloat)[request.arguments[@"fromY"] doubleValue]);
  CGPoint endPoint        = CGPointMake((CGFloat)[request.arguments[@"toX"] doubleValue], (CGFloat)[request.arguments[@"toY"] doubleValue]);
  NSTimeInterval duration = [request.arguments[@"duration"] doubleValue];
  CGFloat velocity        = [request.arguments[@"velocity"] floatValue];
  if (velocity <= 0) {
    return FBResponseWithErrorFormat(@"Duration velocity is invalid. passing velocity is %f", velocity);
  }
  CGFloat deltaX            = endPoint.x - startPoint.x;
  CGFloat deltaY            = endPoint.y - startPoint.y;
  double distance           = sqrt(deltaX*deltaX + deltaY*deltaY);
  double dragTime           = distance / velocity;
  dispatch_semaphore_t sema = dispatch_semaphore_create(0);
  [[XCEventGenerator sharedGenerator] pressAtPoint:startPoint forDuration:duration liftAtPoint:endPoint velocity:velocity orientation:UIInterfaceOrientationPortrait name:@"uuHandleDrag" handler:^(XCSynthesizedEventRecord *record, NSError *error) {
    dispatch_semaphore_signal(sema);
  }];
  dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)((duration + dragTime + 0.1) * NSEC_PER_SEC)));
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)uuHandleTap:(FBRouteRequest *)request {
  CGPoint tapPoint = CGPointMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue]);
  [[XCEventGenerator sharedGenerator] pressAtPoint:tapPoint forDuration:0 orientation:UIInterfaceOrientationPortrait handler:^(XCSynthesizedEventRecord *record, NSError *error) {
  }];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)uuHandleForceTouch:(FBRouteRequest *)request {
  CGPoint touchPoint    = CGPointMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue]);
  double pressure = 1;
  double duration = 1;
  __block BOOL didSucceed;
  [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)(void)){
    XCEventGeneratorHandler handlerBlock = ^(XCSynthesizedEventRecord *record, NSError *commandError) {
      didSucceed = (commandError == nil);
      completion();
    };
    XCPointerEventPath *eventPath = [[XCPointerEventPath alloc] initForTouchAtPoint:touchPoint offset:0.0];
    [eventPath pressDownWithPressure:pressure atOffset:0.0];

    [eventPath liftUpAtOffset:duration];
    XCSynthesizedEventRecord *event =
    [[XCSynthesizedEventRecord alloc]
     initWithName:[NSString stringWithFormat:@"Force touch on %@", NSStringFromCGPoint(touchPoint)]
     interfaceOrientation:UIInterfaceOrientationPortrait];
    [event addPointerEventPath:eventPath];
    [[XCTRunnerDaemonSession sharedSession] synthesizeEvent:event completion:^(NSError *invokeError){
      handlerBlock(event, invokeError);
    }];
  }];
  if (didSucceed) {
    return FBResponseWithOK();
  } else {
    return FBResponseWithErrorFormat(@"Failed to force touch");
  }
}

+ (id<FBResponsePayload>)handleGetWindowSize:(FBRouteRequest *)request {
  CGRect frame = request.session.activeApplication.wdFrame;
  CGSize screenSize = FBAdjustDimensionsForApplication(frame.size, request.session.activeApplication.interfaceOrientation);
  return FBResponseWithStatus(FBCommandStatusNoError, @{
                                                        @"width": @(screenSize.width),
                                                        @"height": @(screenSize.height),
                                                        });
}

+ (id<FBResponsePayload>)uuGetSSID:(FBRouteRequest *)request {
  NSString *ssid = nil;
  ssid = [UUElementCommands CurrentSSIDInfo];
  
  return FBResponseWithStatus(FBCommandStatusNoError, @{
                                                        @"ssid": ssid?:@"",
                                                        });
}

+ (id<FBResponsePayload>)uuSource:(FBRouteRequest *)request {
  CFAbsoluteTime start = CFAbsoluteTimeGetCurrent();
  FBApplication *application = request.session.activeApplication ?: [FBApplication fb_activeApplication];
  NSString *sourceType = request.parameters[@"format"];
  id result;
  if (!sourceType || [sourceType caseInsensitiveCompare:@"xml"] == NSOrderedSame) {
    result = [FBXPath uuXmlStringWithSnapshot:application.lastSnapshot];
  } else if ([sourceType caseInsensitiveCompare:@"json"] == NSOrderedSame) {
    result = application.fb_tree;
  } else {
    return FBResponseWithStatus(
                                FBCommandStatusUnsupported,
                                [NSString stringWithFormat:@"Unknown source type '%@'. Only 'xml' and 'json' source types are supported.", sourceType]
                                );
  }
  if (nil == result) {
    return FBResponseWithErrorFormat(@"Cannot get '%@' source of the current application", sourceType);
  }
  
  CFAbsoluteTime end = CFAbsoluteTimeGetCurrent();
  NSLog(@"time cost: %0.3f", end - start);
  return FBResponseWithObject(result);
}

+ (id<FBResponsePayload>)uuBack:(FBRouteRequest *)request {
  FBApplication *application = request.session.activeApplication ?: [FBApplication fb_activeApplication];
  if (application.navigationBars.buttons.count > 0) {
    [[application.navigationBars.buttons elementBoundByIndex:0] tap];
    return FBResponseWithOK();
  }
  return FBResponseWithErrorFormat(@"Cannot back of the current page");
  
}

+ (id<FBResponsePayload>)handleHomescreenCommand:(FBRouteRequest *)request {
  [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:UUHomeButtonCoolOffTime]];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleMonkeyCommand:(FBRouteRequest *)request {
  @autoreleasepool {
    FBApplication *app = request.session.activeApplication ?: [FBApplication fb_activeApplication];
    if (nil != app) { }
    XCUIApplication *application = [UUMonkeySingleton sharedInstance].application;
    NSInteger monkeyIterations = [request.arguments[@"monkeyIterations"] integerValue];
    if (application == nil) {
      return FBResponseWithErrorFormat(@"Cannot get the current application");
    }
    if (nil == [UUMonkeySingleton sharedInstance].monkey) {
      UUMonkey *monkey = [[UUMonkey alloc] initWithFrame:application.frame];
      [monkey addDefaultXCTestPrivateActions];
      [UUMonkeySingleton sharedInstance].monkey = monkey;
    }
    [UUMonkeySingleton sharedInstance].monkey.application = (XCUIApplication *)application;
    [[UUMonkeySingleton sharedInstance].monkey monkeyAroundWithIterations:monkeyIterations];
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleActiveTestingAppCommand:(FBRouteRequest *)request {
  XCUIApplication *application = [UUMonkeySingleton sharedInstance].application;
  if (application == nil) {
    return FBResponseWithErrorFormat(@"Cannot get the current application");
  }
  if (application.state != XCUIApplicationStateRunningForeground && application.state != XCUIApplicationStateNotRunning) {
    [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:UUHomeButtonCoolOffTime]];
    [application activate];
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleWhetherCrashedCommand:(FBRouteRequest *)request {
  XCUIApplication *application = [UUMonkeySingleton sharedInstance].application;
  if (application == nil) {
    return FBResponseWithErrorFormat(@"Cannot get the current application");
  }
  if (application && !application.running) {
    [[NSException exceptionWithName:FBApplicationCrashedException reason:@"Application is not running, possibly crashed" userInfo:nil] raise];
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)uu_handleGlobalInput:(FBRouteRequest *)request {
  NSString *text = request.arguments[@"text"];
  if (!text) {
    return FBResponseWithStatus(
                                FBCommandStatusInvalidArgument,
                                [NSString stringWithFormat:@"%@ is not a valid TEXT", text]
                                );
  }
  NSUInteger frequency = 60;
  NSError *error = nil;
  if (![FBKeyboard typeText:text frequency:frequency error:&error]) {
    return FBResponseWithErrorFormat(@"Failed to input");
  }
    return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleUnlock:(FBRouteRequest *)request
{
  NSError *error;
  if (![[XCUIDevice sharedDevice] uu_unlockScreen:&error]) {
    return FBResponseWithError(error);
  }
  return FBResponseWithOK();
}


#pragma mark - Helpers

/**
 Returns gesture coordinate for the application based on absolute coordinate
 
 @param coordinate absolute screen coordinates
 @param application the instance of current application under test
 @shouldApplyOrientationWorkaround whether to apply orientation workaround. This is to
 handle XCTest bug where it does not translate screen coordinates for elements if
 screen orientation is different from the default one (which is portrait).
 Different iOS version have different behavior, for example iOS 9.3 returns correct
 coordinates for elements in landscape, but iOS 10.0+ returns inverted coordinates as if
 the current screen orientation would be portrait.
 @return translated gesture coordinates ready to be passed to XCUICoordinate methods
 */
+ (XCUICoordinate *)uuGestureCoordinateWithCoordinate:(CGPoint)coordinate application:(XCUIApplication *)application shouldApplyOrientationWorkaround:(BOOL)shouldApplyOrientationWorkaround {
  
  CGPoint point = coordinate;
  if (shouldApplyOrientationWorkaround) {
    point = FBInvertPointForApplication(coordinate, application.frame.size, application.interfaceOrientation);
  }
  XCUICoordinate *appCoordinate = [[XCUICoordinate alloc] initWithElement:application normalizedOffset:CGVectorMake(0, 0)];
  return [[XCUICoordinate alloc] initWithCoordinate:appCoordinate pointsOffset:CGVectorMake(point.x, point.y)];
}

+ (NSString *)buildTimestamp {
  return [NSString stringWithFormat:@"%@ %@",
          [NSString stringWithUTF8String:__DATE__],
          [NSString stringWithUTF8String:__TIME__]
          ];
}

+ (NSString *)CurrentSSIDInfo {
  NSArray *ifs = (__bridge_transfer id)CNCopySupportedInterfaces();
  NSLog(@"Supported interfaces: %@", ifs);
  id info = nil;
  for (NSString *ifnam in ifs) {
    info = (__bridge_transfer id)CNCopyCurrentNetworkInfo((__bridge CFStringRef)ifnam);
    NSLog(@"%@ => %@", ifnam, info);
    if (info && [info count]) { break; }
  }
  return [[(NSDictionary*)info objectForKey:@"SSID"] lowercaseString];
}


@end

