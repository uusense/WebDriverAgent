//
//  UUResponsePic.h
//  WebDriverAgentLib
//
//  Created by 刘 晓东 on 2018/4/19.
//  Copyright © 2018年 Facebook. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <WebDriverAgentLib/FBResponsePayload.h>
#import <WebDriverAgentLib/FBHTTPStatusCodes.h>

NS_ASSUME_NONNULL_BEGIN

@interface UUResponsePicPayload : NSObject <FBResponsePayload>

- (instancetype)initWithData:(NSData *)data andType:(NSString *)type;

@end

NS_ASSUME_NONNULL_END
