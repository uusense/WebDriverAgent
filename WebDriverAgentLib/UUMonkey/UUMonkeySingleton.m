//
//  UUMonkeySingleton.m
//  WebDriverAgentLib
//
//  Created by 刘 晓东 on 2018/3/11.
//  Copyright © 2018年 Facebook. All rights reserved.
//

#import "UUMonkeySingleton.h"

@implementation UUMonkeySingleton

+ (instancetype)sharedInstance {
  static UUMonkeySingleton *instance = nil;
  static dispatch_once_t once;
  
  dispatch_once(&once, ^{
    instance = [[self alloc] init];
  });
  
  return instance;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    self.monkey      = nil;
    self.application = nil;
  }
  return self;
}

@end
