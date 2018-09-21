//
//  UUResponsePic.m
//  WebDriverAgentLib
//
//  Created by 刘 晓东 on 2018/4/19.
//  Copyright © 2018年 Facebook. All rights reserved.
//

#import "UUResponsePicPayload.h"

#import <RoutingHTTPServer/RouteResponse.h>

@interface UUResponsePicPayload ()

@property (nonatomic, copy, readonly) NSData *data;
@property (nonatomic, copy, readonly) NSString *type;

@end

@implementation UUResponsePicPayload

- (instancetype)initWithData:(NSData *)data andType:(NSString *)type {
  NSParameterAssert(data);
  if (!data) {
    return nil;
  }
  NSParameterAssert(type);
  if (!type) {
    return nil;
  }
  
  self = [super init];
  if (self) {
    _data = data;
    _type = type;
  }
  return self;
}

- (void)dispatchWithResponse:(RouteResponse *)response {
  if ([@"png" isEqualToString:self.type]) {
    [response setHeader:@"Content-Type" value:@"image/png"];
  } else if ([@"jpg" isEqualToString:self.type]) {
    [response setHeader:@"Content-Type" value:@"image/jpeg"];
  }
  [response respondWithData:self.data];
}

@end
