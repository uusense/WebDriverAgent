//
//  UUMonkeyXCTestPrivate.m
//  monkeyios
//
//  Created by 刘 晓东 on 2018/3/2.
//  Copyright © 2018年 刘 晓东. All rights reserved.
//

#import "UUMonkeyXCTestPrivate.h"
#import "XCEventGenerator.h"

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
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
//        [[XCEventGenerator sharedGenerator] pressAtPoint:tapPoint forDuration:0 orientation:orientationValue handler:^(XCSynthesizedEventRecord *record, NSError *error) {
      [[NSClassFromString(@"XCEventGenerator") sharedGenerator] pressAtPoint:tapPoint forDuration:0 orientation:orientationValue handler:^(XCSynthesizedEventRecord *record, NSError *error) {
          dispatch_semaphore_signal(sema);
        }];
        dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)));
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
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [[NSClassFromString(@"XCEventGenerator") sharedGenerator] pressAtPoint:point forDuration:0.5 orientation:orientationValue handler:^(XCSynthesizedEventRecord *record, NSError *error) {
      dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)));
  }];
}

- (void)addXCTestDragAction:(double) weight {
  __weak __typeof(self) weakself = self;
  [self addActionWithWeight:weight andAction:^{
    __strong __typeof(self) strongSelf = weakself;
    CGPoint start = [strongSelf randomPointAvoidingPanelAreas];
    CGPoint end = [strongSelf randomPoint];
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [[NSClassFromString(@"XCEventGenerator") sharedGenerator] pressAtPoint:start forDuration:0 liftAtPoint:end velocity:1000 orientation:orientationValue name:@"Monkey drag" handler:^(XCSynthesizedEventRecord *record, NSError *error) {
      dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)));
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
