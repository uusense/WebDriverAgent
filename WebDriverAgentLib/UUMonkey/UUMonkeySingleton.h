//
//  UUMonkeySingleton.h
//  WebDriverAgentLib
//
//  Created by 刘 晓东 on 2018/3/11.
//  Copyright © 2018年 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <XCTest/XCTest.h>

#import "UUMonkey.h"


@interface UUMonkeySingleton : NSObject

@property (nonatomic, strong) XCUIApplication *application;
@property (nonatomic, strong) UUMonkey *monkey;

+ (instancetype)sharedInstance;

@end
