//
//  UURandom.h
//  monkeyios
//
//  Created by 刘 晓东 on 2018/3/2.
//  Copyright © 2018年 刘 晓东. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface UURandom : NSObject


@property (nonatomic, assign) UInt64 state;
@property (nonatomic, assign) UInt64 increment;

+ (instancetype)aUURandom;

+ (instancetype)aUURandomWithSeed:(UInt32)seed;

+ (instancetype)aUURandomWithSeed:(UInt32)seed andSequence:(UInt32)sequence;

- (instancetype)initWithSeed:(UInt32)seed andSequence:(UInt32)sequence;

- (UInt32)randomUInt32;

- (NSInteger)randomIntLessThan:(NSInteger)lessThan;

- (NSUInteger)randomUIntLessThan:(NSUInteger)lessThan;

- (float)randomFloat;

- (float)randomFloatLessThan:(float)lessThan;

- (double)randomDouble;

- (double)randomDoubleLessThan:(double)lessThan;

@end
