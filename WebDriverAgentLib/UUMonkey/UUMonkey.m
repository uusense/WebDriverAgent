//
//  UUMonkey.m
//  monkeyios
//
//  Created by 刘 晓东 on 2018/3/2.
//  Copyright © 2018年 刘 晓东. All rights reserved.
//

#import "UUMonkey.h"


@implementation UURandomAction


@end


@implementation UURegularAction


@end


@implementation UUMonkey

- (instancetype)initWithFrame:(CGRect)frame {
    NSTimeInterval time = [NSDate timeIntervalSinceReferenceDate];
    UInt32 seed = (UInt32)((UInt64)(time * 1000) & 0xffffffff);
    return [self initWithSeed:seed andFrame:frame];
}

- (instancetype)initWithSeed:(UInt32)seed andFrame:(CGRect)frame {
    self = [super init];
    if (self) {
      self.r              = [UURandom aUURandomWithSeed:seed];
      self.frame          = frame;
      self.randomActions  = [NSMutableArray array];
      self.totalWeight    = 0;
      self.regularActions = [NSMutableArray array];
      self.application    = nil;
    }
    return self;
}

- (void)monkeyAroundWithIterations:(NSInteger)iterations {
    for (NSInteger i = 0; i < iterations; i++) {
        [self actRandomly];
        [self actRegularly];
    }
}

- (void)monkeyAroundForDuration:(NSTimeInterval)duration {
    NSTimeInterval monkeyTestingTime = [NSDate date].timeIntervalSince1970;
    
    do {
        [self actRandomly];
        [self actRegularly];
    } while (([NSDate date].timeIntervalSince1970 - monkeyTestingTime) < duration);
}

- (void)addActionWithWeight:(double)weight andAction:(ActionClosure)action {
    self.totalWeight          += weight;
    UURandomAction *iAction   = [[UURandomAction alloc] init];
    iAction.accumulatedWeight = self.totalWeight;
    iAction.action            = [self actInForeground:action];
    [self.randomActions addObject:iAction];
}

- (void)addActionWithInterval:(double)interval andAction:(ActionClosure)action {
    UURegularAction *iAction = [[UURegularAction alloc] init];
    iAction.interval         = interval;
    iAction.action           = [self actInForeground:action];
    [self.regularActions addObject:iAction];
}

- (void)actRandomly {
    double x = [self.r randomDouble] * self.totalWeight;
    for (UURandomAction *action in self.randomActions) {
        if (x < action.accumulatedWeight) {
            action.action();
            return;
        }
    }
}

- (void)actRegularly {
    self.actionCounter += 1;
    
    for (UURegularAction *action in self.regularActions) {
        if (((NSInteger)self.actionCounter % (NSInteger)action.interval) == 0) {
            action.action();
        }
    }
}

- (NSInteger)randomIntLessThan:(NSInteger)lessThan {
    return [self.r randomIntLessThan:lessThan];
}

- (NSUInteger)randomUIntLessThan:(NSUInteger)lessThan {
    return [self.r randomUIntLessThan:lessThan];
}

- (CGFloat)randomCGFloatLessThan:(CGFloat)lessThan {
    return [self.r randomFloatLessThan:(float)lessThan];
}

- (CGPoint)randomPoint {
    return [self randomPointInRect:self.frame];
}

- (CGPoint)randomPointAvoidingPanelAreas {
    CGFloat topHeight               = 20;
    CGFloat bottomHeight            = 20;
    CGRect frameWithoutTopAndBottom = CGRectMake(0, topHeight, self.frame.size.width, self.frame.size.height - topHeight - bottomHeight);
    return [self randomPointInRect:frameWithoutTopAndBottom];
}

- (CGPoint)randomPointInRect:(CGRect)rect {
    return CGPointMake(rect.origin.x + [self randomCGFloatLessThan:rect.size.width], rect.origin.y + [self randomCGFloatLessThan:rect.size.height]);
}

- (NSArray<NSValue *> *)randomClusteredPointsWithCount:(NSInteger)count {

    CGPoint centre     = [self randomPoint];
    CGRect clusterRect = [self rectAround:centre andSizeFraction:3 inRect:self.frame];
  
    NSMutableArray *points = [NSMutableArray array];
    [points addObject:[NSValue valueWithCGPoint:centre]];
    
    for (NSInteger i = 0; i < count; i++) {
        [points addObject:[NSValue valueWithCGPoint:[self randomPointInRect:clusterRect]]];
    }
    
    return [points copy];
}

- (CGRect)randomRect {
    return [self rectAround:[self randomPoint] andSizeFraction:3 inRect:self.frame];
}

- (CGRect)randomRectWithSizeFraction:(CGFloat)sizeFraction {
     return [self rectAround:[self randomPoint] andSizeFraction:sizeFraction inRect:self.frame];
}

- (ActionClosure)actInForeground:(ActionClosure)action {
    return  ^{
        NSString *version = [UIDevice currentDevice].systemVersion;
        if (version.doubleValue <= 9.0) {
            action();
            return ;
        } else {
          __weak typeof(self) weakSelf = self;
            ActionClosure closure = ^{
              __strong typeof(self) strongSelf = weakSelf;
                if (strongSelf.application.state != XCUIApplicationStateRunningForeground && strongSelf.application.state != XCUIApplicationStateNotRunning) {
                    [strongSelf.application activate];
                }
                action();
            };
            if ([NSThread isMainThread]) {
                closure();
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    closure();
                });
            }
        }
    };
}

- (CGRect)rectAround:(CGPoint)point andSizeFraction:(CGFloat)sizeFraction inRect:(CGRect)rect {
    CGFloat size = MIN(self.frame.size.width, self.frame.size.height) / sizeFraction;
    CGFloat x0   = (point.x - self.frame.origin.x) * (self.frame.size.width - size) / self.frame.size.width + self.frame.origin.x;
    CGFloat y0   = (point.y - self.frame.origin.y) * (self.frame.size.height - size) / self.frame.size.width + self.frame.origin.y;
    return CGRectMake(x0, y0, size, size);
}

- (void)sleepSeconds:(double)seconds {
    if (seconds > 0) {
        usleep((unsigned int)(seconds * 1000000.0));
    }
}

@end
