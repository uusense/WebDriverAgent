//
//  UUMonkeyXCTestPrivate.m
//  monkeyios
//
//  Created by 刘 晓东 on 2018/3/2.
//  Copyright © 2018年 刘 晓东. All rights reserved.
//

#import <objc/runtime.h>

#import "UUMonkeyXCTestPrivate.h"
#import "XCEventGenerator.h"

#import "FBRunLoopSpinner.h"
#import "XCPointerEventPath.h"
#import "XCSynthesizedEventRecord.h"
#import "FBXCTestDaemonsProxy.h"
#import "XCTestDriver.h"
#import "XCUIDevice.h"
#import "XCTRunnerDaemonSession.h"

@implementation UUMonkey (MonkeyXCTestPrivate)

- (void)addDefaultXCTestPrivateActions {
  [self addXCTestTapAction:80];
  [self addXCTestLongPressAction:10];
  [self addXCTestDragAction:10];
}

- (void)addXCTestTapAction:(double)weight multipleTapProbability:(double)multipleTapProbability   multipleTouchProbability:(double)multipleTouchProbability {
    __weak __typeof(self) weakself = self;
    [self addActionWithWeight:weight andAction:^{
        __strong __typeof(self) strongSelf = weakself;
        CGRect rect               = [strongSelf randomRect];
        CGPoint tapPoint          = [strongSelf randomPointInRect:rect];
      
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
        
         Class FBXCTRunnerDaemonSessionClass = nil;
         FBXCTRunnerDaemonSessionClass = objc_lookUpClass("XCTRunnerDaemonSession");
         void (^errorHandler)(NSError *) = ^(NSError *invokeError) {
           handlerBlock(event, invokeError);
         };
         if (nil == FBXCTRunnerDaemonSessionClass) {
           id<XCTestManager_ManagerInterface> proxy = nil;
            proxy = ((XCTRunnerDaemonSession *)[objc_lookUpClass("XCTRunnerDaemonSession") sharedSession]).daemonProxy;
           [proxy _XCT_synthesizeEvent:event completion:errorHandler];
         } else {
           if ([XCUIDevice.sharedDevice respondsToSelector:@selector(eventSynthesizer)]) {
             [[XCUIDevice.sharedDevice eventSynthesizer] synthesizeEvent:event completion:(id)^(BOOL result, NSError *invokeError) {
               handlerBlock(event, invokeError);
             }];
           } else {
             [[FBXCTRunnerDaemonSessionClass sharedSession] synthesizeEvent:event completion:^(NSError *invokeError){
               handlerBlock(event, invokeError);
             }];
           }
         }
      }];
    }];
}

- (void)addXCTestTapAction:(double)weight {
    [self addXCTestTapAction:weight multipleTapProbability:0.05 multipleTouchProbability:0.05];
}

- (void)addXCTestLongPressAction:(double) weight {
  __weak __typeof(self) weakself = self;
  [self addActionWithWeight:weight andAction:^{
    __strong __typeof(self) strongSelf = weakself;
    CGPoint point = [strongSelf randomPoint];
    
    __block BOOL didSucceed;
    [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)(void)){
      XCEventGeneratorHandler handlerBlock = ^(XCSynthesizedEventRecord *record, NSError *commandError) {
        didSucceed = (commandError == nil);
        completion();
      };
      XCPointerEventPath *eventPath = [[XCPointerEventPath alloc] initForTouchAtPoint:point offset:0.0];
      [eventPath liftUpAtOffset: 0.5f];
      XCSynthesizedEventRecord *event =
      [[XCSynthesizedEventRecord alloc]
       initWithName:[NSString stringWithFormat:@"Tap on %@", NSStringFromCGPoint(point)]
       interfaceOrientation:UIInterfaceOrientationPortrait];
      [event addPointerEventPath:eventPath];
      
      Class FBXCTRunnerDaemonSessionClass = nil;
      FBXCTRunnerDaemonSessionClass = objc_lookUpClass("XCTRunnerDaemonSession");
      void (^errorHandler)(NSError *) = ^(NSError *invokeError) {
        handlerBlock(event, invokeError);
      };
      if (nil == FBXCTRunnerDaemonSessionClass) {
        id<XCTestManager_ManagerInterface> proxy = nil;
        proxy = ((XCTRunnerDaemonSession *)[objc_lookUpClass("XCTRunnerDaemonSession") sharedSession]).daemonProxy;
        [proxy _XCT_synthesizeEvent:event completion:errorHandler];
      } else {
        if ([XCUIDevice.sharedDevice respondsToSelector:@selector(eventSynthesizer)]) {
          [[XCUIDevice.sharedDevice eventSynthesizer] synthesizeEvent:event completion:(id)^(BOOL result, NSError *invokeError) {
            handlerBlock(event, invokeError);
          }];
        } else {
          [[FBXCTRunnerDaemonSessionClass sharedSession] synthesizeEvent:event completion:^(NSError *invokeError){
            handlerBlock(event, invokeError);
          }];
        }
      }
    }];
  }];
}

- (void)addXCTestDragAction:(double) weight {
  __weak __typeof(self) weakself = self;
  [self addActionWithWeight:weight andAction:^{
    __strong __typeof(self) strongSelf = weakself;
    CGPoint start = [strongSelf randomPointAvoidingPanelAreas];
    CGPoint end = [strongSelf randomPoint];
    __block BOOL didSucceed;
    [FBRunLoopSpinner spinUntilCompletion:^(void(^completion)(void)){
      XCEventGeneratorHandler handlerBlock = ^(XCSynthesizedEventRecord *record, NSError *commandError) {
        didSucceed = (commandError == nil);
        completion();
      };

      XCPointerEventPath *eventPath = [[XCPointerEventPath alloc] initForTouchAtPoint:start offset:0.0];
      [eventPath moveToPoint:end atOffset:0.2];
      [eventPath liftUpAtOffset:0.2];
      XCSynthesizedEventRecord *event =
      [[XCSynthesizedEventRecord alloc] initWithName:@"move" interfaceOrientation:UIInterfaceOrientationPortrait];
      [event addPointerEventPath:eventPath];
      
      Class FBXCTRunnerDaemonSessionClass = nil;
      FBXCTRunnerDaemonSessionClass = objc_lookUpClass("XCTRunnerDaemonSession");
      void (^errorHandler)(NSError *) = ^(NSError *invokeError) {
        handlerBlock(event, invokeError);
      };
      if (nil == FBXCTRunnerDaemonSessionClass) {
        id<XCTestManager_ManagerInterface> proxy = nil;
        proxy = ((XCTRunnerDaemonSession *)[objc_lookUpClass("XCTRunnerDaemonSession") sharedSession]).daemonProxy;
        [proxy _XCT_synthesizeEvent:event completion:errorHandler];
      } else {
        if ([XCUIDevice.sharedDevice respondsToSelector:@selector(eventSynthesizer)]) {
          [[XCUIDevice.sharedDevice eventSynthesizer] synthesizeEvent:event completion:(id)^(BOOL result, NSError *invokeError) {
            handlerBlock(event, invokeError);
          }];
        } else {
          [[FBXCTRunnerDaemonSessionClass sharedSession] synthesizeEvent:event completion:^(NSError *invokeError){
            handlerBlock(event, invokeError);
          }];
        }
      }
    }];
    
  }];
}

- (void)addXCTestPinchCloseAction:(double) weight {
    
}

- (void)addXCTestPinchOpenAction:(double) weight {
    
}

- (void)addXCTestRotateAction:(double) weight {
    
}

- (void)addXCTestOrientationAction:(double) weight {
    
}


@end
