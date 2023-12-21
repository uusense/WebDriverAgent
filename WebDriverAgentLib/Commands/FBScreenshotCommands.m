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
#import "FBScreenshot.h"
#import "FBMacros.h"
#import "FBConfiguration.h"
#import "FBErrorBuilder.h"
#import "FBImageProcessor.h"

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
    [[FBRoute GET:@"/uusense/scalingcreenshot"].withoutSession respondWithTarget:self action:@selector(uu_handleScalingScreenshot:)],
    [[FBRoute POST:@"/uusense/screenshot"].withoutSession respondWithTarget:self action:@selector(uu_handleASScreenshot:)],
    //[[FBRoute POST:@"/uusense/screenshot2"].withoutSession respondWithTarget:self action:@selector(uu_handlePostScreenshot:)],
  ];
}


#pragma mark - Commands

+ (id<FBResponsePayload>)handleGetScreenshot:(FBRouteRequest *)request
{
  NSError *error;
  NSData *screenshotData = [[XCUIDevice sharedDevice] fb_screenshotWithError:&error];
  if (nil == screenshotData) {
    return FBResponseWithStatus([FBCommandStatus unableToCaptureScreenErrorWithMessage:error.description traceback:nil]);
  }
  NSString *screenshot = [screenshotData base64EncodedStringWithOptions:0];
  return FBResponseWithObject(screenshot);
}

+ (id<FBResponsePayload>)uu_handleGetScreenshot:(FBRouteRequest *)request
{
  NSError *error;
  NSData *screenshotData = [[XCUIDevice sharedDevice] fb_screenshotWithError:&error];
  if (nil == screenshotData) {
    return FBResponseWithStatus([FBCommandStatus unableToCaptureScreenErrorWithMessage:error.description traceback:nil]);
  }
  if ( [[UIDevice currentDevice].systemVersion doubleValue] <= 11 ) {
    return UUResponseWithPNG(screenshotData);
  } else {
    return UUResponseWithJPG(screenshotData);
  }
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
  Class xcScreenClass = objc_lookUpClass("XCUIScreen");
  XCUIScreen *mainScreen = (XCUIScreen *)[xcScreenClass mainScreen];
  
  rect = CGRectMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue], (CGFloat)[request.arguments[@"width"] doubleValue], (CGFloat)[request.arguments[@"height"] doubleValue]);

  if (rect.origin.x < 0 || rect.origin.y < 0 || (0.0 == rect.size.height && 0.0 == rect.size.width) || fullScreen) {
    rect = CGRectNull;
  }
  
  if ([FBScreenshotCommands isNewScreenshotAPISupported]) {
    id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
    __block NSError *innerError = nil;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    if (SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(@"15.0")) {
      id screnshotRequest = [FBScreenshot screenshotRequestWithScreenID:[XCUIScreen.mainScreen displayID]
                                                                 rect:rect
                                                                  uti:(__bridge id)kUTTypeJPEG
                                                   compressionQuality:FBMaxCompressionQuality
                                                                error:&error];
      if (nil == screnshotRequest) {
        return nil;
      }
      [proxy _XCT_requestScreenshot:screnshotRequest
                          withReply:^(id image, NSError *err) {
        if (nil != err) {
          innerError = err;
        } else {
          screenshotData = [image data];
        }
        dispatch_semaphore_signal(sem);
      }];
      dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SCREENSHOT_TIMEOUT * NSEC_PER_SEC)));
      if (nil == screenshotData) {
        return FBResponseWithStatus([FBCommandStatus unableToCaptureScreenErrorWithMessage:@"Screen shot failed" traceback:nil]);
      } else {
        return UUResponseWithJPG(screenshotData);
      }
    }
    
    if (version.doubleValue >= 14.1) {
        rect = CGRectMake((CGFloat)[request.arguments[@"x"] doubleValue], (CGFloat)[request.arguments[@"y"] doubleValue], (CGFloat)[request.arguments[@"width"] doubleValue], (CGFloat)[request.arguments[@"height"] doubleValue]);
        if (rect.origin.x < 0 || rect.origin.y < 0 || (0.0 == rect.size.height && 0.0 == rect.size.width) || fullScreen) {
          rect = CGRectNull;
        }
        [proxy _XCT_requestScreenshotOfScreenWithID:[[XCUIScreen mainScreen] displayID]
                                             withRect:rect
                                                  uti:(__bridge id)kUTTypeJPEG
                                   compressionQuality:FBMaxCompressionQuality
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
  }
  
  if (![mainScreen respondsToSelector: @selector(screenshotDataForQuality:rect:error:)]) {
      CGFloat screenshotCompressionQuality = 1.0;
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
  //Class xcScreenClass = objc_lookUpClass("XCUIScreen");
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
  //XCUIScreen *mainScreen = (XCUIScreen *)[xcScreenClass mainScreen];
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

+ (id<FBResponsePayload>)uu_handleScalingScreenshot:(FBRouteRequest *)request
{
  CGFloat scalingFactor = [FBConfiguration mjpegScalingFactor] / 100.0f;
  BOOL usesScaling = fabs(FBMaxScalingFactor - scalingFactor) > DBL_EPSILON;
  CGFloat compressionQuality = FBConfiguration.mjpegServerScreenshotQuality / 100.0f;
  // If scaling is applied we perform another JPEG compression after scaling
  // To get the desired compressionQuality we need to do a lossless compression here
  CGFloat screenshotCompressionQuality = usesScaling ? FBMaxCompressionQuality : compressionQuality;
  NSError *error;
  NSData *screenshotData = [FBScreenshot takeInOriginalResolutionWithScreenID:[XCUIScreen.mainScreen displayID]
                                                           compressionQuality:screenshotCompressionQuality
                                                                          uti:(__bridge id)kUTTypeJPEG
                                                                      timeout:1.
                                                                        error:&error];
  if (nil == screenshotData) {
    [FBLogger logFmt:@"%@", error.description];
    FBResponseWithUnknownErrorFormat(@"screenshot error: %@",[error description]);
  }

  if (usesScaling) {
    screenshotData = [self.class scaledJpegImageWithImage:screenshotData scalingFactor:scalingFactor compressionQuality:compressionQuality error:&error];
  }
  NSString *screenshot = [screenshotData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
  return FBResponseWithObject(screenshot);
}

+  (nullable NSData *)scaledJpegImageWithImage:(NSData *)image
                                scalingFactor:(CGFloat)scalingFactor
                           compressionQuality:(CGFloat)compressionQuality
                                        error:(NSError **)error
{
  CGImageSourceRef imageData = CGImageSourceCreateWithData((CFDataRef)image, nil);
  CGSize size = [self.class imageSizeWithImage:imageData];
  CGFloat scaledMaxPixelSize = MAX(size.width, size.height) * scalingFactor;
  CFDictionaryRef params = (__bridge CFDictionaryRef)@{
    (const NSString *)kCGImageSourceCreateThumbnailWithTransform: @(YES),
    (const NSString *)kCGImageSourceCreateThumbnailFromImageIfAbsent: @(YES),
    (const NSString *)kCGImageSourceThumbnailMaxPixelSize: @(scaledMaxPixelSize)
  };
  CGImageRef scaled = CGImageSourceCreateThumbnailAtIndex(imageData, 0, params);
  CFRelease(imageData);
  if (nil == scaled) {
    [[[FBErrorBuilder builder]
      withDescriptionFormat:@"Failed to scale the image"]
     buildError:error];
    return nil;
  }
  NSData *resData = [self.class jpegDataWithImage:scaled
                         compressionQuality:compressionQuality];
  if (nil == resData) {
    [[[FBErrorBuilder builder]
      withDescriptionFormat:@"Failed to compress the image to JPEG format"]
     buildError:error];
  }
  CGImageRelease(scaled);
  return resData;
}

+ (CGSize)imageSizeWithImage:(CGImageSourceRef)imageSource
{
  NSDictionary *options = @{
    (const NSString *)kCGImageSourceShouldCache: @(NO)
  };
  CFDictionaryRef properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, (CFDictionaryRef)options);
  NSNumber *width = [(__bridge NSDictionary *)properties objectForKey:(const NSString *)kCGImagePropertyPixelWidth];
  NSNumber *height = [(__bridge NSDictionary *)properties objectForKey:(const NSString *)kCGImagePropertyPixelHeight];
  CGSize size = CGSizeMake([width floatValue], [height floatValue]);
  CFRelease(properties);
  return size;
}

+ (nullable NSData *)jpegDataWithImage:(CGImageRef)imageRef
                    compressionQuality:(CGFloat)compressionQuality
{
  NSMutableData *newImageData = [NSMutableData data];
  CGImageDestinationRef imageDestination = CGImageDestinationCreateWithData((CFMutableDataRef)newImageData, kUTTypeJPEG, 1, NULL);
  CFDictionaryRef compressionOptions = (__bridge CFDictionaryRef)@{
    (const NSString *)kCGImageDestinationLossyCompressionQuality: @(compressionQuality)
  };
  CGImageDestinationAddImage(imageDestination, imageRef, compressionOptions);
  if(!CGImageDestinationFinalize(imageDestination)) {
    [FBLogger log:@"Failed to write the image"];
    newImageData = nil;
  }
  CFRelease(imageDestination);
  return newImageData;
}

+ (BOOL)isNewScreenshotAPISupported
{
  static dispatch_once_t newScreenshotAPISupported;
  static BOOL result;
  dispatch_once(&newScreenshotAPISupported, ^{
    result = [(NSObject *)[FBXCTestDaemonsProxy testRunnerProxy] respondsToSelector:@selector(_XCT_requestScreenshotOfScreenWithID:withRect:uti:compressionQuality:withReply:)];
  });
  return result;
}


@end
