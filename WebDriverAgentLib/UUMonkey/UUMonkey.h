//
//  UUMonkey.h
//  monkeyios
//
//  Created by 刘 晓东 on 2018/3/2.
//  Copyright © 2018年 刘 晓东. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>

#import "UURandom.h"

#pragma mark - https API
typedef void (^ActionClosure)(void); // 访问成功block

@interface UURandomAction : NSObject

@property (nonatomic, assign) double accumulatedWeight;
@property (nonatomic, copy) ActionClosure action;

@end

@interface UURegularAction : NSObject

@property (nonatomic, assign) double interval;
@property (nonatomic, copy) ActionClosure action;

@end



@interface UUMonkey : NSObject

@property (nonatomic, strong) UURandom *r;
@property (nonatomic, assign) CGRect frame;

@property (nonatomic, strong) NSMutableArray<UURandomAction *> *randomActions;
@property (nonatomic, assign) double totalWeight;

@property (nonatomic, strong) NSMutableArray<UURegularAction *> *regularActions;
@property (nonatomic, assign) NSInteger actionCounter;

@property (nonatomic, strong) XCUIApplication *application;

- (instancetype)initWithFrame:(CGRect)frame;
- (instancetype)initWithSeed:(UInt32)seed andFrame:(CGRect)frame;

- (void)monkeyAroundWithIterations:(NSInteger)iterations;
- (void)monkeyAroundForDuration:(NSTimeInterval)duration;

- (void)addActionWithWeight:(double)weight andAction:(ActionClosure)action;
- (void)addActionWithInterval:(double)interval andAction:(ActionClosure)action;

- (NSInteger)randomIntLessThan:(NSInteger)lessThan;
- (NSUInteger)randomUIntLessThan:(NSUInteger)lessThan;
- (CGFloat)randomCGFloatLessThan:(CGFloat)lessThan;

- (CGPoint)randomPoint;
- (CGPoint)randomPointAvoidingPanelAreas;
- (CGPoint)randomPointInRect:(CGRect)rect;
- (NSArray<NSValue *> *)randomClusteredPointsWithCount:(NSInteger)count;

- (CGRect)randomRect;
- (CGRect)randomRectWithSizeFraction:(CGFloat)sizeFraction;

@end
