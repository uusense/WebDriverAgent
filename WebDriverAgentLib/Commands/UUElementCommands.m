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
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <sys/sysctl.h>
#import <mach/mach.h>
#import <ReplayKit/ReplayKit.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "UUElementCommands.h"
#import "FBExceptions.h"
#import "XCUIApplication.h"

#import "FBKeyboard.h"
#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBRunLoopSpinner.h"
#import "FBElementCache.h"
#import "FBErrorBuilder.h"
#import "FBSession.h"
#import "FBMacros.h"
#import "FBMathUtils.h"
#import "NSPredicate+FBFormat.h"
#import "XCUICoordinate.h"
#import "XCUIDevice.h"
#import "XCTRunnerDaemonSession.h"
#import "XCUIElement+FBIsVisible.h"
#import "XCUIElement+FBPickerWheel.h"
#import "XCUIElement+FBScrolling.h"
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

#import "XCTestDriver.h"
#import "XCTRunnerDaemonSession.h"

#import "FBAlert.h"

#import "UUMonkey.h"
#import "UUMonkeyXCTestPrivate.h"
#import "UUMonkeySingleton.h"

#import "STDPingServices.h"
#import "BatteryInfoManager.h"

#import "Reachability.h"

#import "FBScreenshot.h"
#import "XCUIScreen.h"
#import "FBConfiguration.h"
#import "FBImageProcessor.h"
#import "FBLogger.h"
#import "FBResponsePayload.h"

#import "FBXMLGenerationOptions.h"

@import UniformTypeIdentifiers;

static const NSTimeInterval UUHomeButtonCoolOffTime = 0.0;
static const NSTimeInterval SCREENSHOT_TIMEOUT = 0.5;
static NSString *const SOURCE_FORMAT_XML = @"xml";
static NSString *const SOURCE_FORMAT_JSON = @"json";
static NSString *const SOURCE_FORMAT_DESCRIPTION = @"description";

@interface UUElementCommands ()

@end

@implementation UUElementCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes {
  return
  @[
    [[FBRoute POST:@"/uusense/tap"].withoutSession respondWithTarget:self action:@selector(uuHandleTapCoordinate:)],
    [[FBRoute POST:@"/uusense/monkey/tap"].withoutSession respondWithTarget:self action:@selector(uuHandleTap:)],
    [[FBRoute POST:@"/uusense/forcetouch"].withoutSession respondWithTarget:self action:@selector(uuHandleForceTouch:)],
    [[FBRoute POST:@"/uusense/touchAndHold"].withoutSession respondWithTarget:self action:@selector(uuHandleTouchAndHoldCoordinate:)],
    [[FBRoute POST:@"/uusense/monkey/touchAndHold"].withoutSession respondWithTarget:self action:@selector(uuHandleTouchAndHold:)],
    [[FBRoute POST:@"/uusense/doubleTap"] respondWithTarget:self action:@selector(uuHandleDoubleTapCoordinate:)],
    [[FBRoute POST:@"/uusense/dragfromtoforduration"].withoutSession respondWithTarget:self action:@selector(uuHandleDragCoordinate:)],
    [[FBRoute POST:@"/uusense/monkey/dragfromtoforduration"].withoutSession respondWithTarget:self action:@selector(uuHandleDrag:)],
//    [[FBRoute POST:@"/uusense/dragfromtofordurationtest"].withoutSession respondWithTarget:self action:@selector(uuHandleDragCoordinate:)],
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
    [[FBRoute POST:@"/uusense/move"].withoutSession respondWithTarget:self action:@selector(uu_handleMove:)],
    
    [[FBRoute GET:@"/uusense/lockButton"].withoutSession respondWithTarget:self action:@selector(uu_lockButton:)],
    [[FBRoute POST:@"/uusense/unlockWithOutCheck"].withoutSession respondWithTarget:self action:@selector(handleUnlock:)],
    
    [[FBRoute POST:@"/uusense/ping"].withoutSession respondWithTarget:self action:@selector(handlePingCommand:)],
    
    [[FBRoute GET:@"/wda/netType"].withoutSession respondWithTarget:self action:@selector(handleGetNetType:)],
    [[FBRoute GET:@"/wda/netBrand"].withoutSession respondWithTarget:self action:@selector(handleGetNetBrand:)],
    [[FBRoute POST:@"/wda/uuGet"].withoutSession respondWithTarget:self action:@selector(handleUuGet:)],
    [[FBRoute POST:@"/wda/uuPost"].withoutSession respondWithTarget:self action:@selector(handleUuPost:)],
    
    [[FBRoute GET:@"/uusense/screenshot"].withoutSession respondWithTarget:self action:@selector(uu_handleGetScreenshot:)],
    [[FBRoute GET:@"/uusense/screenshot"] respondWithTarget:self action:@selector(uu_handleGetScreenshot:)],
    [[FBRoute GET:@"/uusense/scalingcreenshot"].withoutSession respondWithTarget:self action:@selector(uu_handleScalingScreenshot:)],
    [[FBRoute POST:@"/uusense/screenshot"].withoutSession respondWithTarget:self action:@selector(uu_handleASScreenshot:)],
    
    [[FBRoute POST:@"/url"].withoutSession respondWithTarget:self action:@selector(uu_handleOpenURL:)],
    
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
    
    [UUElementCommands uuSynthesizeEvent:event andHandle:handlerBlock];
  }];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)uu_handleMove:(FBRouteRequest *)request {
  
  NSArray *pointsArray    = request.arguments[@"points"];
  NSTimeInterval duration = [request.arguments[@"duration"] doubleValue];
  //  CGFloat velocity        = [request.arguments[@"velocity"] floatValue];
  double dragTime         = 0.2;
  
  if ((nil == pointsArray) || ([pointsArray count] <= 0)) {
    return FBResponseWithUnknownErrorFormat(@"Points are null");
  }
  
  __block BOOL didSucceed;
  [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)(void)){
    XCEventGeneratorHandler handlerBlock = ^(XCSynthesizedEventRecord *record, NSError *commandError) {
      didSucceed = (commandError == nil);
      completion();
    };
    
    NSDictionary *startPoint = pointsArray.firstObject;
    CGPoint hitPoint = CGPointMake([startPoint[@"x"] intValue], [startPoint[@"y"] intValue]);
    XCPointerEventPath *eventPath = [[XCPointerEventPath alloc] initForTouchAtPoint:hitPoint offset:duration];
    
    for (NSUInteger i = 1; i < [pointsArray count]; i++) {
      //      NSDictionary * sPoint = pointsArray[i - 1];
      NSDictionary * ePoint = pointsArray[i];
      //      CGFloat deltaX        = [ePoint[@"x"] intValue] - [sPoint[@"x"] intValue];
      //      CGFloat deltaY        = [ePoint[@"y"] intValue] - [sPoint[@"y"] intValue];
      //      double distance       = sqrt(deltaX*deltaX + deltaY*deltaY);
      //      double dragTime       = distance / velocity;
      
      CGPoint endPoint = CGPointMake([ePoint[@"x"] intValue], [ePoint[@"y"] intValue]);
      [eventPath moveToPoint:endPoint atOffset:duration + (dragTime * i)];
    }
    [eventPath liftUpAtOffset:duration + (dragTime * [pointsArray count])];
    XCSynthesizedEventRecord *event = [[XCSynthesizedEventRecord alloc] initWithName:@"move" interfaceOrientation:UIInterfaceOrientationPortrait];
    [event addPointerEventPath:eventPath];
    [UUElementCommands uuSynthesizeEvent:event andHandle:handlerBlock];
  }];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)uuGetSysInfo:(FBRouteRequest *)request
{
  [[BatteryInfoManager sharedManager] startBatteryMonitoring];
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
  
  [dic setObject:@([BatteryInfoManager sharedManager].capacity) forKey:@"BatteryCapacity"];
  [dic setObject:@([BatteryInfoManager sharedManager].voltage) forKey:@"BatteryVoltage"];
  [dic setObject:@([BatteryInfoManager sharedManager].levelPercent) forKey:@"BatteryLevelPercent"];
  [dic setObject:@([BatteryInfoManager sharedManager].levelMAH) forKey:@"BatteryLevelMAH"];
  [dic setObject:[BatteryInfoManager sharedManager].status forKey:@"BatteryStatus"];
  
  [[BatteryInfoManager sharedManager] stopBatteryMonitoring];
  return FBResponseWithObject(dic);
}

+ (id<FBResponsePayload>)uuHandleDoubleTapCoordinate:(FBRouteRequest *)request {
  XCUIApplication *application        = request.session.activeApplication;
  CGPoint doubleTapPoint              = CGPointMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue]);
  XCUICoordinate *doubleTapCoordinate = [self.class uuGestureCoordinateWithCoordinate:doubleTapPoint application:application shouldApplyOrientationWorkaround:YES];
  [doubleTapCoordinate doubleTap];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)uuHandleTouchAndHoldCoordinate:(FBRouteRequest *)request {
  
  NSError *error;
  NSNumber *x = request.arguments[@"x"];
  NSNumber *y = request.arguments[@"y"];

  if ((nil == x && nil != y) || (nil != x && nil == y)) {
    [[[FBErrorBuilder alloc]
      withDescription:@"Both x and y coordinates must be provided"]
     buildError:&error];
    return FBResponseWithUnknownError(error);
  }
  
  XCUIApplication *application = request.session.activeApplication ?: XCUIApplication.fb_activeApplication;
  
  id target = [self.class uuGestureCoordinateWithOffset:CGVectorMake(x.doubleValue, y.doubleValue)
                                        element:application];
  if (nil == target) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:error.localizedDescription
                                                                       traceback:nil]);
  }
  [target pressForDuration:[request.arguments[@"duration"] doubleValue]];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)uuHandleTouchAndHold:(FBRouteRequest *)request {
  CGPoint touchPoint        = CGPointMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue]);
  double duration           = [request.arguments[@"duration"] doubleValue];
  
  __block BOOL didSucceed;
  [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)(void)){
    XCEventGeneratorHandler handlerBlock = ^(XCSynthesizedEventRecord *record, NSError *commandError) {
      didSucceed = (commandError == nil);
      completion();
    };
    XCPointerEventPath *eventPath = [[XCPointerEventPath alloc] initForTouchAtPoint:touchPoint offset:0.0];
    [eventPath liftUpAtOffset:duration];
    XCSynthesizedEventRecord *event = [[XCSynthesizedEventRecord alloc] initWithName:@"touchAndHold" interfaceOrientation:UIInterfaceOrientationPortrait];
    [event addPointerEventPath:eventPath];
    [UUElementCommands uuSynthesizeEvent:event andHandle:handlerBlock];
  }];
  
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)uuHandleDrag:(FBRouteRequest *)request {
  CGPoint startPoint      = CGPointMake((CGFloat)[request.arguments[@"fromX"] doubleValue], (CGFloat)[request.arguments[@"fromY"] doubleValue]);
  CGPoint endPoint        = CGPointMake((CGFloat)[request.arguments[@"toX"] doubleValue], (CGFloat)[request.arguments[@"toY"] doubleValue]);
  NSTimeInterval duration = [request.arguments[@"duration"] doubleValue];
  CGFloat velocity        = [request.arguments[@"velocity"] floatValue];
  if (velocity <= 0) {
    return FBResponseWithUnknownErrorFormat(@"Duration velocity is invalid. passing velocity is %f", velocity);
  }
  CGFloat deltaX            = endPoint.x - startPoint.x;
  CGFloat deltaY            = endPoint.y - startPoint.y;
  double distance           = sqrt(deltaX*deltaX + deltaY*deltaY);
  double dragTime           = distance / velocity;
  
  __block BOOL didSucceed;
  [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)(void)){
    XCEventGeneratorHandler handlerBlock = ^(XCSynthesizedEventRecord *record, NSError *commandError) {
      didSucceed = (commandError == nil);
      completion();
    };
    XCPointerEventPath *eventPath = [[XCPointerEventPath alloc] initForTouchAtPoint:startPoint offset:duration];
    [eventPath moveToPoint:endPoint atOffset:duration + dragTime];
    [eventPath liftUpAtOffset:duration + dragTime];
    XCSynthesizedEventRecord *event = [[XCSynthesizedEventRecord alloc] initWithName:@"drag" interfaceOrientation:UIInterfaceOrientationPortrait];
    
    [event addPointerEventPath:eventPath];
    [UUElementCommands uuSynthesizeEvent:event andHandle:handlerBlock];
  }];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)uuHandleDragCoordinate:(FBRouteRequest *)request {
  XCUIApplication *application = request.session.activeApplication ?: XCUIApplication.fb_activeApplication;
  CGVector startOffset = CGVectorMake([request.arguments[@"fromX"] doubleValue],
                                      [request.arguments[@"fromY"] doubleValue]);
  XCUICoordinate *startCoordinate = [self.class uuGestureCoordinateWithOffset:startOffset element:application];
  CGVector endOffset = CGVectorMake([request.arguments[@"toX"] doubleValue],
                                    [request.arguments[@"toY"] doubleValue]);
  XCUICoordinate *endCoordinate = [self.class uuGestureCoordinateWithOffset:endOffset element:application];
  NSTimeInterval duration = [request.arguments[@"duration"] doubleValue];
  [startCoordinate pressForDuration:duration thenDragToCoordinate:endCoordinate];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)uuHandleTapCoordinate:(FBRouteRequest *)request {
  XCUIApplication *application = request.session.activeApplication ?: XCUIApplication.fb_activeApplication;
  CGPoint tapPoint = CGPointMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue]);
  XCUICoordinate *doubleTapCoordinate = [self.class uuGestureCoordinateWithCoordinate:tapPoint application:application shouldApplyOrientationWorkaround:YES];
  [doubleTapCoordinate tap];
  
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)uuHandleTap:(FBRouteRequest *)request {
  
  CGPoint tapPoint = CGPointMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue]);
  
  __block BOOL didSucceed;
  [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)(void)){
    XCEventGeneratorHandler handlerBlock = ^(XCSynthesizedEventRecord *record, NSError *commandError) {
      didSucceed = (commandError == nil);
      completion();
    };
    XCPointerEventPath *eventPath = [[XCPointerEventPath alloc] initForTouchAtPoint:tapPoint offset:0.0];
    [eventPath liftUpAtOffset: 0.01f];
    XCSynthesizedEventRecord *event =
    [[XCSynthesizedEventRecord alloc]
     initWithName:[NSString stringWithFormat:@"Tap on %@", NSStringFromCGPoint(tapPoint)]
     interfaceOrientation:UIInterfaceOrientationPortrait];
    [event addPointerEventPath:eventPath];
    [UUElementCommands uuSynthesizeEvent:event andHandle:handlerBlock];
  }];

  return FBResponseWithOK();
}

+ (void)uuSynthesizeEvent:(XCSynthesizedEventRecord *)event andHandle:(XCEventGeneratorHandler)handler {
  Class FBXCTRunnerDaemonSessionClass = nil;
  FBXCTRunnerDaemonSessionClass = objc_lookUpClass("XCTRunnerDaemonSession");
  void (^errorHandler)(NSError *) = ^(NSError *invokeError) {
    handler(event, invokeError);
  };
  if (nil == FBXCTRunnerDaemonSessionClass) {
    id<XCTestManager_ManagerInterface> proxy = nil;
    proxy = ((XCTRunnerDaemonSession *)[objc_lookUpClass("XCTRunnerDaemonSession") sharedSession]).daemonProxy;
    [proxy _XCT_synthesizeEvent:event completion:errorHandler];
  } else {
    if ([XCUIDevice.sharedDevice respondsToSelector:@selector(eventSynthesizer)]) {
      [[XCUIDevice.sharedDevice eventSynthesizer] synthesizeEvent:event completion:(id)^(BOOL result, NSError *invokeError) {
        handler(event, invokeError);
      }];
    } else {
      [[FBXCTRunnerDaemonSessionClass sharedSession] synthesizeEvent:event completion:^(NSError *invokeError){
        handler(event, invokeError);
      }];
    }
  }
  handler(event, nil);
}

+ (id<FBResponsePayload>)uuHandleForceTouch:(FBRouteRequest *)request {
  CGPoint touchPoint = CGPointMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue]);
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
    [UUElementCommands uuSynthesizeEvent:event andHandle:handlerBlock];
  }];
  if (didSucceed) {
    return FBResponseWithOK();
  } else {
    return FBResponseWithUnknownErrorFormat(@"Failed to force touch");
  }
}

+ (id<FBResponsePayload>)handleGetWindowSize:(FBRouteRequest *)request {
  CGRect frame = request.session.activeApplication.wdFrame;
  CGSize screenSize = FBAdjustDimensionsForApplication(frame.size, request.session.activeApplication.interfaceOrientation);
  return FBResponseWithObject(@{
                                @"width": @(screenSize.width),
                                @"height": @(screenSize.height),
                                });
}

+ (id<FBResponsePayload>)uuGetSSID:(FBRouteRequest *)request {
  NSString *ssid = nil;
  ssid = [UUElementCommands CurrentSSIDInfo];
  
  return FBResponseWithObject(@{
                                @"ssid": ssid?:@"",
                                });
}

+ (id<FBResponsePayload>)uuBack:(FBRouteRequest *)request {
  XCUIApplication *application = request.session.activeApplication ?: XCUIApplication.fb_activeApplication;
  if (application.navigationBars.buttons.count > 0) {
    [[application.navigationBars.buttons elementBoundByIndex:0] tap];
    return FBResponseWithOK();
  }
  return FBResponseWithUnknownErrorFormat(@"Cannot back of the current page");
  
}

+ (id<FBResponsePayload>)handleHomescreenCommand:(FBRouteRequest *)request {
  [[XCUIDevice sharedDevice] pressButton:XCUIDeviceButtonHome];
  [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:UUHomeButtonCoolOffTime]];
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleMonkeyCommand:(FBRouteRequest *)request {
//  @autoreleasepool {
//    FBApplication *app = request.session.activeApplication ?: [FBApplication fb_activeApplication];
//    if (nil != app) { }
//    XCUIApplication *application = [UUMonkeySingleton sharedInstance].application;
//    if (nil == application) {
//      [UUMonkeySingleton sharedInstance].application = request.session.activeApplication ?: [FBApplication fb_activeApplication];
//      application = [UUMonkeySingleton sharedInstance].application;
//    }
//    NSInteger monkeyIterations = [request.arguments[@"monkeyIterations"] integerValue];
//    if ([UUMonkeySingleton sharedInstance].application == nil) {
//      return FBResponseWithUnknownErrorFormat(@"Cannot get the current application");
//    }
//    if (nil == [UUMonkeySingleton sharedInstance].monkey) {
//      UUMonkey *monkey = [[UUMonkey alloc] initWithFrame:application.frame];
//      [monkey addDefaultXCTestPrivateActions];
//      [UUMonkeySingleton sharedInstance].monkey = monkey;
//    }
//    [UUMonkeySingleton sharedInstance].monkey.application = (XCUIApplication *)application;
//    [[UUMonkeySingleton sharedInstance].monkey monkeyAroundWithIterations:monkeyIterations];
//  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleActiveTestingAppCommand:(FBRouteRequest *)request {
  XCUIApplication *application = [UUMonkeySingleton sharedInstance].application;
  if (application == nil) {
    return FBResponseWithUnknownErrorFormat(@"Cannot get the current application");
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
    return FBResponseWithUnknownErrorFormat(@"Cannot get the current application");
  }
  if (application && !application.running) {
    [[NSException exceptionWithName:FBApplicationCrashedException reason:@"Application is not running, possibly crashed" userInfo:nil] raise];
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)uu_handleGlobalInput:(FBRouteRequest *)request {
  NSString *text = request.arguments[@"text"];
  if (!text) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:[NSString stringWithFormat:@"%@ is not a valid TEXT", text] traceback:nil]);
  }
  NSUInteger frequency = 60;
  NSError *error = nil;
  
  FBTypeText(text,frequency,&error);

  if (error != nil) {
    return FBResponseWithUnknownErrorFormat(@"Failed to input");
  }
    return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleUnlock:(FBRouteRequest *)request {
  NSError *error;
  if (![[XCUIDevice sharedDevice] fb_unlockScreen:&error]) {
    return FBResponseWithUnknownError(error);
  }
  return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handlePingCommand:(FBRouteRequest *)request {
  NSString *address = request.arguments[@"address"];
  __block NSInteger count = (NSInteger)[(NSNumber *)request.arguments[@"count"] integerValue];
  __block NSMutableArray *results = [NSMutableArray array];
  NSInteger size = (NSInteger)[(NSNumber *)request.arguments[@"size"] integerValue];
  NSInteger timeout = (NSInteger)[(NSNumber *)request.arguments[@"timeout"] integerValue];
  
  if (count <= 0) {
    return FBResponseWithUnknownErrorFormat(@"count is less than 1");
  }
  
  size = size > 8 ? size : 64;
  timeout = timeout < 3600 ? timeout : 500;
  
  [STDPingServices startPingAddress:address
                            andSize:size
                         andTimeout:timeout
                    callbackHandler:^(STDPingItem *pingItem, NSArray *pingItems) {
      NSLog(@"%@ %ld %f", pingItem.IPAddress, (long)pingItem.timeToLive, pingItem.timeMilliseconds);
      NSString *info = @"";
      if (pingItem.status == STDPingStatusFinished || pingItem.status == STDPingStatusError) {
        count = 0;
      } else {
        if (pingItem.status == STDPingStatusDidTimeout) {
          info = [NSString stringWithFormat:@"%ld,%d,%ld", (long)pingItem.ICMPSequence, -1, (long)pingItem.timeToLive];
        } else {
           info = [NSString stringWithFormat:@"%ld,%f,%ld", (long)pingItem.ICMPSequence, pingItem.timeMilliseconds, (long)pingItem.timeToLive];
        }
        [results addObject:info];
        count = count - 1;
      }
    }
   ];
  
  do {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]];
  } while (count > 0);

  return FBResponseWithObject(results);
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

+ (id<FBResponsePayload>)handleGetNetType:(FBRouteRequest *)request
{
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
      }else if (@available(iOS 14.0, *)) {
          if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyNRNSA"]){
              netconnType = @"5G NSA";
          } else if ([currentStatus isEqualToString:@"CTRadioAccessTechnologyNR"]){
              netconnType = @"5G";
          }
        }
      }
      break;
    default:
      break;
  }
  NSLog(@"netconnType is %@", netconnType);
#pragma clang diagnostic pop
  return FBResponseWithObject(netconnType);
}

+ (id<FBResponsePayload>)handleGetNetBrand:(FBRouteRequest *)request
{
  CTTelephonyNetworkInfo *info = [[CTTelephonyNetworkInfo alloc] init];
  CTCarrier *carinfo = info.subscriberCellularProvider;
  return FBResponseWithObject(@{
            @"Name": carinfo.carrierName?:@"",
            @"MNC": carinfo.mobileNetworkCode?:@"",
            @"ISOCountryCode": carinfo.isoCountryCode?:@"",
            @"MCC": carinfo.mobileCountryCode?:@"",});
}

+ (id<FBResponsePayload>)handleUuGet:(FBRouteRequest *)request
{
  NSString *urlStr     = request.arguments[@"url"];
  NSTimeInterval timeOut = [request.arguments[@"timeout"] doubleValue];
  timeOut = (timeOut <= 0 ) ? 1 : timeOut;
  NSURL *url = [NSURL URLWithString:urlStr];
  NSURLRequest *req = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:timeOut];
  NSURLSession *session = [NSURLSession sharedSession];
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  __block NSError *errorInfo = nil;
  __block NSString *ret = nil;
  NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    if (error) {
      errorInfo = error;
    }
    @try {
      if (data) {
        NSData *dataTmp = data;
        ret = [[NSString alloc] initWithData:dataTmp encoding:NSUTF8StringEncoding];
      }
    } @catch (NSException *exception) {
      NSLog(@"%@", [exception description]);
    }
    dispatch_semaphore_signal(semaphore);
  }];
  [dataTask resume];
  dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeOut * NSEC_PER_SEC)));
  if (errorInfo) {
    return FBResponseWithUnknownError(errorInfo);
  } else {
    return FBResponseWithObject(@{@"response": ret ?: @""});
  }
}

+ (id<FBResponsePayload>)handleUuPost:(FBRouteRequest *)request
{
  NSString *urlStr     = request.arguments[@"url"];
  NSTimeInterval timeOut = [request.arguments[@"timeout"] doubleValue];
  timeOut = (timeOut <= 0 ) ? 1 : timeOut;
  NSDictionary *params = request.arguments[@"params"];
  NSURL *url = [NSURL URLWithString:urlStr];
  NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:timeOut];
  req.HTTPMethod = @"POST";
  [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
  NSError *paramError = nil;
  if (params) {
    NSData *bodyData = [NSJSONSerialization dataWithJSONObject:params options:NSJSONWritingPrettyPrinted error:&paramError];
    if(nil == paramError && nil != bodyData)
      [req setHTTPBody:bodyData];
  }
  NSURLSession *session = [NSURLSession sharedSession];
  dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
  __block NSError *errorInfo = nil;
  __block NSString *ret = nil;
  NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
    if (error) {
      errorInfo = error;
    }
    @try {
      if (data) {
        NSData *dataTmp = data;
        ret = [[NSString alloc] initWithData:dataTmp encoding:NSUTF8StringEncoding];
      }
    } @catch (NSException *exception) {
      NSLog(@"%@", [exception description]);
    }
    dispatch_semaphore_signal(semaphore);
  }];
  [dataTask resume];
  dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeOut * NSEC_PER_SEC)));
  if (errorInfo) {
    return FBResponseWithUnknownError(errorInfo);
  } else {
    return FBResponseWithObject(@{@"response": ret ?: @""});
  }
}


+ (id<FBResponsePayload>)uu_handleGetScreenshot:(FBRouteRequest *)request
{
  NSError *error;
  NSData *screenshotData = [[XCUIDevice sharedDevice] fb_screenshotWithError:&error];
  if (nil == screenshotData) {
    return FBResponseWithStatus([FBCommandStatus unableToCaptureScreenErrorWithMessage:error.description traceback:nil]);
  }
  if ( [[UIDevice currentDevice].systemVersion doubleValue] <= 11 ) {
    return UUResponseWithPNG(screenshotData);
  } else {
    return UUResponseWithJPG(screenshotData);
  }
}

+ (id<FBResponsePayload>)uu_handleASScreenshot:(FBRouteRequest *)request
{
  NSError *error;
  CGRect rect = CGRectZero;
  NSString *version = [UIDevice currentDevice].systemVersion;
  __block NSData *screenshotData = nil;
  BOOL fullScreen = [request.arguments[@"full"] integerValue] == 1 ? YES : NO;
  NSUInteger q = (NSUInteger)[request.arguments[@"quality"] unsignedIntegerValue];
  NSString *type = request.arguments[@"type"];
  Class xcScreenClass = objc_lookUpClass("XCUIScreen");
  XCUIScreen *mainScreen = (XCUIScreen *)[xcScreenClass mainScreen];
  
  rect = CGRectMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue], (CGFloat)[request.arguments[@"width"] doubleValue], (CGFloat)[request.arguments[@"height"] doubleValue]);

  if (rect.origin.x < 0 || rect.origin.y < 0 || (0.0 == rect.size.height && 0.0 == rect.size.width) || fullScreen) {
    rect = CGRectNull;
  }
  
  if ( [type isEqualToString:@"SMALLJPG"] ) {
    CGFloat compressionQuality = MAX(FBMinCompressionQuality,
                                     MIN(FBMaxCompressionQuality, FBConfiguration.mjpegServerScreenshotQuality / 100.0));
    XCUIScreen *mainScreen = XCUIScreen.mainScreen;
    NSData *screenshotData = [FBScreenshot takeInOriginalResolutionWithScreenID:mainScreen.displayID
                                                           compressionQuality:compressionQuality
                                                                          uti:UTTypeJPEG
                                                                      timeout:SCREENSHOT_TIMEOUT
                                                                        error:&error];
    if (nil == screenshotData) {
      return nil;
    }
    CGFloat scalingFactor = FBConfiguration.mjpegScalingFactor / 100.0;
    screenshotData = [[[FBImageProcessor alloc] init] scaledImageWithData:screenshotData
                                                            uti:UTTypeJPEG
                                                  scalingFactor:scalingFactor
                                             compressionQuality:FBMaxCompressionQuality
                                                          error:&error];
    
    if (nil != screenshotData) {
      return UUResponseWithJPG(screenshotData);
    }
  }
  
  
  if ([UUElementCommands isNewScreenshotAPISupported]) {
    id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
    __block NSError *innerError = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"15.0")) {
      id screnshotRequest = [FBScreenshot screenshotRequestWithScreenID:[XCUIScreen.mainScreen displayID]
                                                                 rect:rect
                                                                  uti:UTTypeJPEG
                                                   compressionQuality:FBMaxCompressionQuality/2
                                                                error:&error];
      if (nil == screnshotRequest) {
        return nil;
      }
      [proxy _XCT_requestScreenshot:screnshotRequest
                          withReply:^(id image, NSError *err) {
        if (nil != err) {
          innerError = err;
        } else {
          screenshotData = [image data];
        }
        dispatch_semaphore_signal(sem);
      }];
      dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SCREENSHOT_TIMEOUT * NSEC_PER_SEC)));
      if (nil == screenshotData) {
        return FBResponseWithStatus([FBCommandStatus unableToCaptureScreenErrorWithMessage:@"Screen shot failed" traceback:nil]);
      } else {
        return UUResponseWithJPG(screenshotData);
      }
    }
    
    if (version.doubleValue >= 14.1) {
        rect = CGRectMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue], (CGFloat)[request.arguments[@"width"] doubleValue], (CGFloat)[request.arguments[@"height"] doubleValue]);
        if (rect.origin.x < 0 || rect.origin.y < 0 || (0.0 == rect.size.height && 0.0 == rect.size.width) || fullScreen) {
          rect = CGRectNull;
        }
        [proxy _XCT_requestScreenshotOfScreenWithID:[[XCUIScreen mainScreen] displayID]
                                             withRect:rect
                                                  uti:(__bridge id)kUTTypeJPEG
                                   compressionQuality:FBMaxCompressionQuality
                                            withReply:^(NSData *data, NSError *err) {
            if (err != nil) {
                [FBLogger logFmt:@"Error taking screenshot: %@", [error description]];
            }
            screenshotData = data;
            dispatch_semaphore_signal(sem);
        }];
        dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SCREENSHOT_TIMEOUT * NSEC_PER_SEC)));
        if (nil != screenshotData) {
          return UUResponseWithJPG(screenshotData);
        }
    }
  }
  
  if (![mainScreen respondsToSelector: @selector(screenshotDataForQuality:rect:error:)]) {
      CGFloat screenshotCompressionQuality = 1.0;
      id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
      dispatch_semaphore_t sem = dispatch_semaphore_create(0);
      [proxy _XCT_requestScreenshotOfScreenWithID:[[XCUIScreen mainScreen] displayID]
                                           withRect:rect
                                                uti:(__bridge id)kUTTypeJPEG
                                 compressionQuality:screenshotCompressionQuality
                                          withReply:^(NSData *data, NSError *err) {
          if (err != nil) {
              [FBLogger logFmt:@"Error taking screenshot: %@", [error description]];
          }
          screenshotData = data;
          dispatch_semaphore_signal(sem);
      }];
      dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SCREENSHOT_TIMEOUT * NSEC_PER_SEC)));
      if (nil != screenshotData) {
        return UUResponseWithJPG(screenshotData);
      }
  }
  
  double scaled = [[DeviceInfoManager sharedManager] getScaleFactor];
  
  if (!fullScreen) {
    if (version.doubleValue >= 11.0) {
        rect = CGRectMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue], (CGFloat)[request.arguments[@"width"] doubleValue], (CGFloat)[request.arguments[@"height"] doubleValue]);
    } else {
        rect = CGRectMake((CGFloat)[request.arguments[@"x"] doubleValue] * scaled, (CGFloat)[request.arguments[@"y"] doubleValue] * scaled, (CGFloat)[request.arguments[@"width"] doubleValue] * scaled, (CGFloat)[request.arguments[@"height"] doubleValue] * scaled);
    }
  }

  screenshotData = nil;
  //Class xcScreenClass = objc_lookUpClass("XCUIScreen");
  if (xcScreenClass == nil) {
    return FBResponseWithStatus([FBCommandStatus unableToCaptureScreenErrorWithMessage:@"Screen shot failed, XCUIScreen is nil" traceback:nil]);
  }

  NSUInteger quality = 2;
  CGRect screenRect = CGRectZero;
  
  if (rect.origin.x < 0 || rect.origin.y < 0 || (0.0 == rect.size.height && 0.0 == rect.size.width) || fullScreen) {
    XCUIApplication *app = XCUIApplication.fb_systemApplication;
    CGSize screenSize = FBAdjustDimensionsForApplication(app.frame.size, app.interfaceOrientation);
    if (version.doubleValue >= 11.0) {
      screenRect = CGRectMake(0, 0, screenSize.width, screenSize.height);
    } else {
      screenRect = CGRectMake(0, 0, screenSize.width * scaled, screenSize.height * scaled);
    }
  } else {
    screenRect = rect;
  }
  if (0 < q && q < 3) {
    quality = q;
  }
  //XCUIScreen *mainScreen = (XCUIScreen *)[xcScreenClass mainScreen];
  if ([type isEqualToString:@"PNG"]) {
    screenshotData = [[mainScreen screenshot] PNGRepresentation];
  } else {
    screenshotData = [mainScreen screenshotDataForQuality:quality rect:screenRect error:&error];
  }
  if (nil == screenshotData || error) {
    return FBResponseWithStatus([FBCommandStatus unableToCaptureScreenErrorWithMessage:@"Screen shot failed, XCUIScreen is nil" traceback:nil]);
  }
  
  if ([type isEqualToString:@"PNG"]) {
    return UUResponseWithPNG(screenshotData);
  } else {
    return UUResponseWithJPG(screenshotData);
  }
}

+ (id<FBResponsePayload>)uu_handleScalingScreenshot:(FBRouteRequest *)request
{
  CGFloat scalingFactor = [FBConfiguration mjpegScalingFactor] / 100.0f;
  BOOL usesScaling = fabs(FBMaxScalingFactor - scalingFactor) > DBL_EPSILON;
  CGFloat compressionQuality = FBConfiguration.mjpegServerScreenshotQuality / 100.0f;
  // If scaling is applied we perform another JPEG compression after scaling
  // To get the desired compressionQuality we need to do a lossless compression here
  CGFloat screenshotCompressionQuality = usesScaling ? FBMaxCompressionQuality : compressionQuality;
  NSError *error;
  NSData *screenshotData = [FBScreenshot takeInOriginalResolutionWithScreenID:[XCUIScreen.mainScreen displayID]
                                                           compressionQuality:screenshotCompressionQuality
                                                                          uti:UTTypeJPEG
                                                                      timeout:1.
                                                                        error:&error];
  if (nil == screenshotData) {
    [FBLogger logFmt:@"%@", error.description];
    FBResponseWithUnknownErrorFormat(@"screenshot error: %@",[error description]);
  }

  if (usesScaling) {
    screenshotData = [self.class scaledJpegImageWithImage:screenshotData scalingFactor:scalingFactor compressionQuality:compressionQuality error:&error];
  }
  NSString *screenshot = [screenshotData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
  return FBResponseWithObject(screenshot);
}

+  (nullable NSData *)scaledJpegImageWithImage:(NSData *)image
                                scalingFactor:(CGFloat)scalingFactor
                           compressionQuality:(CGFloat)compressionQuality
                                        error:(NSError **)error
{
  CGImageSourceRef imageData = CGImageSourceCreateWithData((CFDataRef)image, nil);
  CGSize size = [self.class imageSizeWithImage:imageData];
  CGFloat scaledMaxPixelSize = MAX(size.width, size.height) * scalingFactor;
  CFDictionaryRef params = (__bridge CFDictionaryRef)@{
    (const NSString *)kCGImageSourceCreateThumbnailWithTransform: @(YES),
    (const NSString *)kCGImageSourceCreateThumbnailFromImageIfAbsent: @(YES),
    (const NSString *)kCGImageSourceThumbnailMaxPixelSize: @(scaledMaxPixelSize)
  };
  CGImageRef scaled = CGImageSourceCreateThumbnailAtIndex(imageData, 0, params);
  CFRelease(imageData);
  if (nil == scaled) {
    [[[FBErrorBuilder builder]
      withDescriptionFormat:@"Failed to scale the image"]
     buildError:error];
    return nil;
  }
  NSData *resData = [self.class jpegDataWithImage:scaled
                         compressionQuality:compressionQuality];
  if (nil == resData) {
    [[[FBErrorBuilder builder]
      withDescriptionFormat:@"Failed to compress the image to JPEG format"]
     buildError:error];
  }
  CGImageRelease(scaled);
  return resData;
}

+ (CGSize)imageSizeWithImage:(CGImageSourceRef)imageSource
{
  NSDictionary *options = @{
    (const NSString *)kCGImageSourceShouldCache: @(NO)
  };
  CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, (CFDictionaryRef)options);
  NSNumber *width = [(__bridge NSDictionary *)properties objectForKey:(const NSString *)kCGImagePropertyPixelWidth];
  NSNumber *height = [(__bridge NSDictionary *)properties objectForKey:(const NSString *)kCGImagePropertyPixelHeight];
  CGSize size = CGSizeMake([width floatValue], [height floatValue]);
  CFRelease(properties);
  return size;
}

+ (nullable NSData *)jpegDataWithImage:(CGImageRef)imageRef
                    compressionQuality:(CGFloat)compressionQuality
{
  NSMutableData *newImageData = [NSMutableData data];
  CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((CFMutableDataRef)newImageData, kUTTypeJPEG, 1, NULL);
  CFDictionaryRef compressionOptions = (__bridge CFDictionaryRef)@{
    (const NSString *)kCGImageDestinationLossyCompressionQuality: @(compressionQuality)
  };
  CGImageDestinationAddImage(imageDestination, imageRef, compressionOptions);
  if(!CGImageDestinationFinalize(imageDestination)) {
    [FBLogger log:@"Failed to write the image"];
    newImageData = nil;
  }
  CFRelease(imageDestination);
  return newImageData;
}

+ (BOOL)isNewScreenshotAPISupported
{
  static dispatch_once_t newScreenshotAPISupported;
  static BOOL result;
  dispatch_once(&newScreenshotAPISupported, ^{
    result = [(NSObject *)[FBXCTestDaemonsProxy testRunnerProxy] respondsToSelector:@selector(_XCT_requestScreenshotOfScreenWithID:withRect:uti:compressionQuality:withReply:)];
  });
  return result;
}

+ (id<FBResponsePayload>)uu_handleOpenURL:(FBRouteRequest *)request
{
  NSString *urlString = request.arguments[@"url"];
  if (!urlString) {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:@"URL is required" traceback:nil]);
  }
  NSString* bundleId = request.arguments[@"bundleId"];
  NSNumber* idleTimeoutMs = request.arguments[@"idleTimeoutMs"];
  NSError *error;
  if (nil == bundleId) {
    if (![XCUIDevice.sharedDevice fb_openUrl:urlString error:&error]) {
      return FBResponseWithUnknownError(error);
    }
  } else {
    if (![XCUIDevice.sharedDevice fb_openUrl:urlString withApplication:bundleId error:&error]) {
      return FBResponseWithUnknownError(error);
    }
    if (idleTimeoutMs.doubleValue > 0) {
      XCUIApplication *app = [[XCUIApplication alloc] initWithBundleIdentifier:bundleId];
      [app fb_waitUntilStableWithTimeout:FBMillisToSeconds(idleTimeoutMs.doubleValue)];
    }
  }
  return FBResponseWithOK();
}


+ (XCUICoordinate *)uuGestureCoordinateWithOffset:(CGVector)offset
                                        element:(XCUIElement *)element
{
  return [[element coordinateWithNormalizedOffset:CGVectorMake(0, 0)] coordinateWithOffset:offset];
}


+ (UIDeviceOrientation)uuOrientation

{
//  UIDeviceOrientationLandscapeLeft,
//  UIDeviceOrientationLandscapeRight,
  UIDeviceOrientation orientation = [XCUIDevice sharedDevice].orientation;
  return orientation;
}

+ (id<FBResponsePayload>)uuSource:(FBRouteRequest *)request
{
  // This method might be called without session
//  XCUIApplication *application = request.session.activeApplication ?: XCUIApplication.fb_activeApplication;
  
  NSString *sourceType = request.parameters[@"format"] ?: SOURCE_FORMAT_XML;
  NSString *sourceScope = request.parameters[@"scope"];
  NSString *bundleIdentifier = request.parameters[@"bundleID"];
  XCUIApplication *application = [[XCUIApplication alloc] initWithBundleIdentifier:bundleIdentifier];
  id result;
  if ([sourceType caseInsensitiveCompare:SOURCE_FORMAT_XML] == NSOrderedSame) {
    NSArray<NSString *> *excludedAttributes = nil == request.parameters[@"excluded_attributes"]
      ? nil
      : [request.parameters[@"excluded_attributes"] componentsSeparatedByString:@","];
    result = [application fb_xmlRepresentationWithOptions:
        [[[FBXMLGenerationOptions new]
          withExcludedAttributes:excludedAttributes]
         withScope:sourceScope]];
  } else if ([sourceType caseInsensitiveCompare:SOURCE_FORMAT_JSON] == NSOrderedSame) {
    NSString *excludedAttributesString = request.parameters[@"excluded_attributes"];
    NSSet<NSString *> *excludedAttributes = (excludedAttributesString == nil)
          ? nil
          : [NSSet setWithArray:[excludedAttributesString componentsSeparatedByString:@","]];

    result = [application fb_tree:excludedAttributes];
  } else if ([sourceType caseInsensitiveCompare:SOURCE_FORMAT_DESCRIPTION] == NSOrderedSame) {
    result = application.fb_descriptionRepresentation;
  } else {
    return FBResponseWithStatus([FBCommandStatus invalidArgumentErrorWithMessage:[NSString stringWithFormat:@"Unknown source format '%@'. Only %@ source formats are supported.",
                                                                                  sourceType, @[SOURCE_FORMAT_XML, SOURCE_FORMAT_JSON, SOURCE_FORMAT_DESCRIPTION]] traceback:nil]);
  }
  if (nil == result) {
    return FBResponseWithUnknownErrorFormat(@"Cannot get '%@' source of the current application", sourceType);
  }
  return FBResponseWithObject(result);
}




@end

