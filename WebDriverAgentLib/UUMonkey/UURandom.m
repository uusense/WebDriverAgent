//
//  UURandom.m
//  monkeyios
//
//  Created by 刘 晓东 on 2018/3/2.
//  Copyright © 2018年 刘 晓东. All rights reserved.
//

#import "UURandom.h"

@implementation UURandom

+ (instancetype)aUURandom {
    return [UURandom aUURandomWithSeed:0];
}

+ (instancetype)aUURandomWithSeed:(UInt32)seed {
    return [UURandom aUURandomWithSeed:seed andSequence:0];
}

+ (instancetype)aUURandomWithSeed:(UInt32)seed andSequence:(UInt32)sequence {
    return [[UURandom alloc] initWithSeed:seed andSequence:sequence];
}

- (instancetype)initWithSeed:(UInt32)seed andSequence:(UInt32)sequence {
    self = [super init];
    if (self) {
        _state = 0;
        _increment = ( (UInt64)sequence << 1 ) | 1;
        _state = _state &+ (UInt64)seed;
    }
    return self;
}

- (UInt32)randomUInt32 {
  return arc4random();
}

- (NSInteger)randomIntLessThan:(NSInteger)lessThan {
    return (NSInteger)([self randomUInt32] % (UInt32)lessThan);
}

- (NSUInteger)randomUIntLessThan:(NSUInteger)lessThan {
    return (NSUInteger)([self randomUInt32] % (UInt32)lessThan);
}

- (float)randomFloat {
    return (float)([self randomUInt32] / 4294967296.0);
}

- (float)randomFloatLessThan:(float)lessThan {
    return [self randomFloat] * lessThan;
}

- (double)randomDouble {
    return (double)[self randomUInt32] / 4294967296.0;
}

- (double)randomDoubleLessThan:(double)lessThan {
    return [self randomDouble] * lessThan;
}

@end
