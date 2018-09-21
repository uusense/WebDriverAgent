//
//  UUMonkeyXCTestPrivate.h
//  monkeyios
//
//  Created by 刘 晓东 on 2018/3/2.
//  Copyright © 2018年 刘 晓东. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import "UUMonkey.h"

static const UIInterfaceOrientation orientationValue = UIInterfaceOrientationPortrait;


@interface UUMonkey (MonkeyXCTestPrivate)

- (void)addDefaultXCTestPrivateActions;
- (void)addXCTestTapAction:(double)weight multipleTapProbability:(double)multipleTapProbability   multipleTouchProbability:(double)multipleTouchProbability;

- (void)addXCTestTapAction:(double)weight;
- (void)addXCTestLongPressAction:(double) weight;
- (void)addXCTestDragAction:(double) weight;
- (void)addXCTestPinchCloseAction:(double) weight;
- (void)addXCTestPinchOpenAction:(double) weight;
- (void)addXCTestRotateAction:(double) weight;
- (void)addXCTestOrientationAction:(double) weight;

@end
