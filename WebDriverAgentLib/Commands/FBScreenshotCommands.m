/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBScreenshotCommands.h"

#import <objc/runtime.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "XCUIDevice+FBHelpers.h"
#import "FBRoute.h"
#import "FBRouteRequest.h"
#import "FBApplication.h"
#import "FBMathUtils.h"
#import "XCUIScreen.h"
#import "DeviceInfoManager.h"
#import "XCTestManager_ManagerInterface-Protocol.h"
#import "FBXCTestDaemonsProxy.h"
#import "FBLogger.h"

static const NSTimeInterval SCREENSHOT_TIMEOUT = 0.5;

@implementation FBScreenshotCommands

#pragma mark - <FBCommandHandler>

+ (NSArray *)routes
{
  return
  @[
    [[FBRoute GET:@"/screenshot"].withoutSession respondWithTarget:self action:@selector(handleGetScreenshot:)],
    [[FBRoute GET:@"/screenshot"] respondWithTarget:self action:@selector(handleGetScreenshot:)],
    [[FBRoute GET:@"/uusense/screenshot"].withoutSession respondWithTarget:self action:@selector(uu_handleGetScreenshot:)],
    [[FBRoute GET:@"/uusense/screenshot"] respondWithTarget:self action:@selector(uu_handleGetScreenshot:)],
    [[FBRoute POST:@"/uusense/screenshot"].withoutSession respondWithTarget:self action:@selector(uu_handleASScreenshot:)],
    [[FBRoute POST:@"/uusense/screenshot2"].withoutSession respondWithTarget:self action:@selector(uu_handlePostScreenshot:)],
  ];
}


#pragma mark - Commands

+ (id<FBResponsePayload>)handleGetScreenshot:(FBRouteRequest *)request
{
  NSError *error;
  //NSData *screenshotData = [[XCUIDevice sharedDevice] fb_screenshotWithError:&error];
  NSData *screenshotData = [[XCUIDevice sharedDevice] uu_screenshotWithError:&error];
  if (nil == screenshotData) {
    return FBResponseWithStatus([FBCommandStatus unableToCaptureScreenErrorWithMessage:error.description traceback:nil]);
  }
  NSString *screenshot = [screenshotData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
  return FBResponseWithObject(screenshot);
}

+ (id<FBResponsePayload>)uu_handleGetScreenshot:(FBRouteRequest *)request
{
  NSError *error;
  NSData *screenshotData = [[XCUIDevice sharedDevice] uu_screenshotWithError:&error];
  if (nil == screenshotData) {
    return FBResponseWithStatus([FBCommandStatus unableToCaptureScreenErrorWithMessage:error.description traceback:nil]);
  }
  if ( [[UIDevice currentDevice].systemVersion doubleValue] <= 11 ) {
    return UUResponseWithPNG(screenshotData);
  } else {
    return UUResponseWithJPG(screenshotData);
  }
}

+ (id<FBResponsePayload>)uu_handlePostScreenshot:(FBRouteRequest *)request
{
  NSError *error;
  CGRect rect = CGRectMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue], (CGFloat)[request.arguments[@"width"] doubleValue], (CGFloat)[request.arguments[@"height"] doubleValue]);
  
  NSUInteger quality = (NSUInteger)[request.arguments[@"quality"] unsignedIntegerValue];
  NSData *screenshotData = [[XCUIDevice sharedDevice] uu_screenshotWithSize:rect andQuality:quality andError:&error];
  if (nil == screenshotData) {
    return FBResponseWithStatus([FBCommandStatus unableToCaptureScreenErrorWithMessage:error.description traceback:nil]);
  }
  NSString *screenshot = [screenshotData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
  return FBResponseWithObject(screenshot);
}

+ (id<FBResponsePayload>)uu_handleASScreenshot:(FBRouteRequest *)request
{
  NSError *error;
  CGRect rect = CGRectZero;
  NSString *version = [UIDevice currentDevice].systemVersion;
  __block NSData *screenshotData = nil;
  BOOL fullScreen = [request.arguments[@"full"] integerValue] == 1 ? YES : NO;
  NSUInteger q = (NSUInteger)[request.arguments[@"quality"] unsignedIntegerValue];
  NSString *type = request.arguments[@"type"];
  
  if (version.doubleValue >= 14.1) {
    
      rect = CGRectMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue], (CGFloat)[request.arguments[@"width"] doubleValue], (CGFloat)[request.arguments[@"height"] doubleValue]);
    
      if (rect.origin.x < 0 || rect.origin.y < 0 || (0.0 == rect.size.height && 0.0 == rect.size.width) || fullScreen) {
        rect = CGRectNull;
      }
      
      CGFloat screenshotCompressionQuality = 0.6;
    
      id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
      dispatch_semaphore_t sem = dispatch_semaphore_create(0);
      [proxy _XCT_requestScreenshotOfScreenWithID:[[XCUIScreen mainScreen] displayID]
                                           withRect:rect
                                                uti:(__bridge id)kUTTypeJPEG
                                 compressionQuality:screenshotCompressionQuality
                                          withReply:^(NSData *data, NSError *err) {
          if (err != nil) {
              [FBLogger logFmt:@"Error taking screenshot: %@", [error description]];
          }
          screenshotData = data;
          dispatch_semaphore_signal(sem);
      }];
      dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SCREENSHOT_TIMEOUT * NSEC_PER_SEC)));
      if (nil != screenshotData) {
        return UUResponseWithJPG(screenshotData);
      }
  }
  
  double scaled = [[DeviceInfoManager sharedManager] getScaleFactor];
  
  if (!fullScreen) {
    if (version.doubleValue >= 11.0) {
        rect = CGRectMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue], (CGFloat)[request.arguments[@"width"] doubleValue], (CGFloat)[request.arguments[@"height"] doubleValue]);
    } else {
        rect = CGRectMake((CGFloat)[request.arguments[@"x"] doubleValue] * scaled, (CGFloat)[request.arguments[@"y"] doubleValue] * scaled, (CGFloat)[request.arguments[@"width"] doubleValue] * scaled, (CGFloat)[request.arguments[@"height"] doubleValue] * scaled);
    }
  }

  screenshotData = nil;
  Class xcScreenClass = objc_lookUpClass("XCUIScreen");
  if (xcScreenClass == nil) {
    return FBResponseWithStatus([FBCommandStatus unableToCaptureScreenErrorWithMessage:@"Screen shot failed, XCUIScreen is nil" traceback:nil]);
  }

  NSUInteger quality = 2;
  CGRect screenRect = CGRectZero;
  
  if (rect.origin.x < 0 || rect.origin.y < 0 || (0.0 == rect.size.height && 0.0 == rect.size.width) || fullScreen) {
    XCUIApplication *app = FBApplication.fb_activeApplication;
    CGSize screenSize = FBAdjustDimensionsForApplication(app.frame.size, app.interfaceOrientation);
    if (version.doubleValue >= 11.0) {
      screenRect = CGRectMake(0, 0, screenSize.width, screenSize.height);
    } else {
      screenRect = CGRectMake(0, 0, screenSize.width * scaled, screenSize.height * scaled);
    }
  } else {
    screenRect = rect;
  }
  if (0 < q && q < 3) {
    quality = q;
  }
  XCUIScreen *mainScreen = (XCUIScreen *)[xcScreenClass mainScreen];
  if ([type isEqualToString:@"PNG"]) {
    screenshotData = [[mainScreen screenshot] PNGRepresentation];
  } else {
    screenshotData = [mainScreen screenshotDataForQuality:quality rect:screenRect error:&error];
  }
  if (nil == screenshotData || error) {
    return FBResponseWithStatus([FBCommandStatus unableToCaptureScreenErrorWithMessage:@"Screen shot failed, XCUIScreen is nil" traceback:nil]);
  }
  
  if ([type isEqualToString:@"PNG"]) {
    return UUResponseWithPNG(screenshotData);
  } else {
    return UUResponseWithJPG(screenshotData);
  }
}


@end
