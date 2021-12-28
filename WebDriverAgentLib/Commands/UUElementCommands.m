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
#import "FBExceptions.h"

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

#import "XCTestDriver.h"
#import "XCTRunnerDaemonSession.h"

#import "FBAlert.h"

#import "UUMonkey.h"
#import "UUMonkeyXCTestPrivate.h"
#import "UUMonkeySingleton.h"

#import "STDPingServices.h"
#import "BatteryInfoManager.h"

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
    [[FBRoute POST:@"/uusense/move"].withoutSession respondWithTarget:self action:@selector(uu_handleMove:)],
    
    [[FBRoute GET:@"/uusense/lockButton"].withoutSession respondWithTarget:self action:@selector(uu_lockButton:)],
    [[FBRoute POST:@"/uusense/unlockWithOutCheck"].withoutSession respondWithTarget:self action:@selector(handleUnlock:)],
    
    [[FBRoute POST:@"/uusense/ping"].withoutSession respondWithTarget:self action:@selector(handlePingCommand:)],
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
    return FBResponseWithUnknownError(error);
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
    return FBResponseWithUnknownError(error);
  }
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

+ (id<FBResponsePayload>)uuHandleDragCoordinate:(FBRouteRequest *)request {
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
    if ([[XCTestDriver sharedTestDriver] respondsToSelector:@selector(managerProxy)]) {
      proxy = [XCTestDriver sharedTestDriver].managerProxy;
    } else {
      proxy = ((XCTRunnerDaemonSession *)[objc_lookUpClass("XCTRunnerDaemonSession") sharedSession]).daemonProxy;
    }
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
    return FBResponseWithStatus([FBCommandStatus unsupportedOperationErrorWithMessage:[NSString stringWithFormat:@"Unknown source type '%@'. Only 'xml' and 'json' source types are supported.", sourceType] traceback:nil]);
  }
  if (nil == result) {
    return FBResponseWithUnknownErrorFormat(@"Cannot get '%@' source of the current application", sourceType);
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
  return FBResponseWithUnknownErrorFormat(@"Cannot back of the current page");
  
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
    if (nil == application) {
      [UUMonkeySingleton sharedInstance].application = request.session.activeApplication ?: [FBApplication fb_activeApplication];
      application = [UUMonkeySingleton sharedInstance].application;
    }
    NSInteger monkeyIterations = [request.arguments[@"monkeyIterations"] integerValue];
    if ([UUMonkeySingleton sharedInstance].application == nil) {
      return FBResponseWithUnknownErrorFormat(@"Cannot get the current application");
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
  if (![FBKeyboard typeText:text frequency:frequency error:&error]) {
    return FBResponseWithUnknownErrorFormat(@"Failed to input");
  }
    return FBResponseWithOK();
}

+ (id<FBResponsePayload>)handleUnlock:(FBRouteRequest *)request {
  NSError *error;
  if (![[XCUIDevice sharedDevice] uu_unlockScreen:&error]) {
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

