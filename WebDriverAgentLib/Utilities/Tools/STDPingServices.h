//
//  STDPingServices.h
//  STKitDemo
//
//  Created by SunJiangting on 15-3-9.
//  Copyright (c) 2015年 SunJiangting. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "SimplePing.h"


typedef NS_ENUM(NSInteger, STDPingStatus) {
    STDPingStatusDidStart,
    STDPingStatusDidReceivePacket,
    STDPingStatusDidTimeout,
    STDPingStatusFinished,
    STDPingStatusError,
};


@interface STDPingItem : NSObject

@property(nonatomic) NSString *originalAddress;
@property(nonatomic, copy) NSString *IPAddress;

@property(nonatomic) NSUInteger dateBytesLength;
@property(nonatomic) double     timeMilliseconds;
@property(nonatomic) NSInteger  timeToLive;
@property(nonatomic) NSInteger  ICMPSequence;

@property(nonatomic) STDPingStatus status;

+ (NSString *)statisticsWithPingItems:(NSArray *)pingItems;

@end


@interface STDPingServices : NSObject

@property(nonatomic) BOOL isTest;
@property(nonatomic) double timeoutMilliseconds;
@property(nonatomic) NSInteger  maximumPingTimes;

+ (STDPingServices *)startPingAddress:(NSString *)address
                      callbackHandler:(void(^)(STDPingItem *pingItem, NSArray *pingItems))handler;

+ (STDPingServices *)startPingAddress:(NSString *)address
                              andSize:(NSInteger)size
                      callbackHandler:(void(^)(STDPingItem *item, NSArray *pingItems))handler;

+ (STDPingServices *)startPingAddress:(NSString *)address
                              andSize:(NSInteger)size
                           andTimeout:(double)timeout
                      callbackHandler:(void(^)(STDPingItem *item, NSArray *pingItems))handler;

- (void)cancel;

@end
