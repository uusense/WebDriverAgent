/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "FBMjpegServer.h"


#import <mach/mach_time.h>
@import UniformTypeIdentifiers;

#import "GCDAsyncSocket.h"
#import "FBConfiguration.h"
#import "FBLogger.h"
#import "FBScreenshot.h"
#import "FBImageProcessor.h"
#import "FBImageUtils.h"
#import "XCUIScreen.h"

static const NSUInteger MAX_FPS = 60;
static const NSTimeInterval FRAME_TIMEOUT = 1.;

static NSString *const SERVER_NAME = @"WDA MJPEG Server";
static const char *QUEUE_NAME = "JPEG Screenshots Provider Queue";


@interface FBMjpegServer()


//@property (nonatomic) NSTimer *mainTimer;
//@property (nonatomic) dispatch_queue_t backgroundQueue;
//@property (nonatomic) NSMutableArray<GCDAsyncSocket *> *activeClients;
//@property (nonatomic) NSUInteger currentFramerate;
//@property (nonatomic) XCUIScreen *mainScreen;
//@property (nonatomic) CGRect screenRect;
//@property (nonatomic) CGRect screenActualRect;

@property (nonatomic, readonly) dispatch_queue_t backgroundQueue;
@property (nonatomic, readonly) NSMutableArray<GCDAsyncSocket *> *listeningClients;
@property (nonatomic, readonly) FBImageProcessor *imageProcessor;
@property (nonatomic, readonly) long long mainScreenID;

@end


@implementation FBMjpegServer

//- (instancetype)init
//{
//    if ((self = [super init])) {
//        _activeClients = [NSMutableArray array];
//        _backgroundQueue = dispatch_queue_create(QUEUE_NAME, DISPATCH_QUEUE_SERIAL);
//        Class xcScreenClass = objc_lookUpClass("XCUIScreen");
//        self.mainScreen = (XCUIScreen *)[xcScreenClass mainScreen];
//        XCUIApplication *app = FBApplication.fb_activeApplication;
//        CGSize screenSize = FBAdjustDimensionsForApplication(app.frame.size, app.interfaceOrientation);
//        self.screenActualRect = CGRectMake(0, 0, screenSize.width * [[DeviceInfoManager sharedManager] getScaleFactor], screenSize.height * [[DeviceInfoManager sharedManager] getScaleFactor]);
//        self.screenRect = CGRectMake(0, 0, screenSize.width, screenSize.height);
//        if (![self.class canStreamScreenshots]) {
//            if (![self.class canScheduleTimerBlock]) {
//                [self resetTimer2:FBConfiguration.mjpegServerFramerate];
//                return self;
//            }
//            [FBLogger log:@"MJPEG server cannot start because the current iOS version is not supported"];
//            [self resetTimer3:FBConfiguration.mjpegServerFramerate];
//            return self;
//        }
//
//        [self resetTimer:FBConfiguration.mjpegServerFramerate];
//    }
//    return self;
//}
//
//- (void)resetTimer:(NSUInteger)framerate
//{
//    if (self.mainTimer && self.mainTimer.valid) {
//        [self.mainTimer invalidate];
//    }
//    self.currentFramerate = framerate;
//    NSTimeInterval timerInterval = 1.0 / ((0 == framerate || framerate > MAX_FPS) ? MAX_FPS : framerate);
//    self.mainTimer = [NSTimer scheduledTimerWithTimeInterval:timerInterval
//                                                     repeats:YES
//                                                       block:^(NSTimer * _Nonnull timer) {
//                                                           if (self.currentFramerate == FBConfiguration.mjpegServerFramerate) {
//                                                               [self streamScreenshot];
//                                                           } else {
//                                                               [self resetTimer:FBConfiguration.mjpegServerFramerate];
//                                                           }
//                                                       }];
//}
//
//- (void)resetTimer2:(NSUInteger)framerate
//{
//    if (self.mainTimer && self.mainTimer.valid) {
//        [self.mainTimer invalidate];
//    }
//    self.currentFramerate = framerate;
//    NSTimeInterval timerInterval = 1.0 / ((0 == framerate || framerate > MAX_FPS) ? MAX_FPS : framerate);
//    __weak typeof(self)weak_self = self;
//    self.mainTimer = [NSTimer scheduledTimerWithTimeInterval:timerInterval target:weak_self selector:@selector(streamScreenshot2) userInfo:nil repeats:YES];
//}
//
//- (void)resetTimer3:(NSUInteger)framerate
//{
//    if (self.mainTimer && self.mainTimer.valid) {
//        [self.mainTimer invalidate];
//    }
//    self.currentFramerate = framerate;
//    NSTimeInterval timerInterval = 1.0 / ((0 == framerate || framerate > MAX_FPS) ? MAX_FPS : framerate);
//    self.mainTimer = [NSTimer scheduledTimerWithTimeInterval:timerInterval
//                                                     repeats:YES
//                                                       block:^(NSTimer * _Nonnull timer) {
//                                                           if (self.currentFramerate == FBConfiguration.mjpegServerFramerate) {
//                                                               [self streamScreenshot2];
//                                                           } else {
//                                                               [self resetTimer3:FBConfiguration.mjpegServerFramerate];
//                                                           }
//                                                       }];
//}
//
//- (void)streamScreenshot
//{
//    @synchronized (self.activeClients) {
//        if (0 == self.activeClients.count) {
//            return;
//        }
//    }
//
//    __block NSData *screenshotData = nil;
//    CGFloat compressionQuality = FBConfiguration.mjpegServerScreenshotQuality / 100.0f;
//    id<XCTestManager_ManagerInterface> proxy = [FBXCTestDaemonsProxy testRunnerProxy];
//    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
//    [proxy _XCT_requestScreenshotOfScreenWithID:[[XCUIScreen mainScreen] displayID]
//                                       withRect:CGRectNull
//                                            uti:(__bridge id)kUTTypeJPEG
//                             compressionQuality:screenshotCompressionQuality
//                                      withReply:^(NSData *data, NSError *error) {
//                                          screenshotData = data;
//                                          dispatch_semaphore_signal(sem);
//                                      }];
//    dispatch_semaphore_wait(sem, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(SCREENSHOT_TIMEOUT * NSEC_PER_SEC)));
//    if (nil == screenshotData) {
//        return;
//    }
//
//    dispatch_async(self.backgroundQueue, ^{
//        NSString *chunkHeader = [NSString stringWithFormat:@"--BoundaryString\r\nContent-type: image/jpg\r\nContent-Length: %@\r\n\r\n", @(screenshotData.length)];
//        NSMutableData *chunk = [[chunkHeader dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
//        [chunk appendData:screenshotData];
//        [chunk appendData:(id)[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
//        @synchronized (self.activeClients) {
//            for (GCDAsyncSocket *client in self.activeClients) {
//                [client writeData:chunk withTimeout:-1 tag:0];
//            }
//        }
//    });
//}
//
//- (void)streamScreenshot2
//{
//    @synchronized (self.activeClients) {
//        if (0 == self.activeClients.count) {
//            return;
//        }
//    }
//    __block NSData *screenshotData = nil;
//    NSError *error;
//    XCUIApplication *app = FBApplication.fb_activeApplication;
//    CGSize screenSize = FBAdjustDimensionsForApplication(app.frame.size, app.interfaceOrientation);
//    CGRect tmpScreenActualRect = CGRectMake(0, 0, screenSize.width * [[DeviceInfoManager sharedManager] getScaleFactor], screenSize.height * [[DeviceInfoManager sharedManager] getScaleFactor]);
//    screenshotData = [self.mainScreen screenshotDataForQuality:2 rect:tmpScreenActualRect error:&error];
//
//    if (nil == screenshotData || error != nil) {
//        return;
//    }
//
//    dispatch_async(self.backgroundQueue, ^{
//        NSString *chunkHeader = [NSString stringWithFormat:@"--BoundaryString\r\nContent-type: image/jpg\r\nContent-Length: %@\r\n\r\n", @(screenshotData.length)];
//        NSMutableData *chunk = [[chunkHeader dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
//        [chunk appendData:screenshotData];
//        [chunk appendData:(id)[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
//        @synchronized (self.activeClients) {
//            for (GCDAsyncSocket *client in self.activeClients) {
//                [client writeData:chunk withTimeout:-1 tag:0];
//            }
//        }
//    });
//}
//
//+ (BOOL)canStreamScreenshots
//{
//    static dispatch_once_t onceCanStream;
//    static BOOL result;
//    dispatch_once(&onceCanStream, ^{
//        result = [(NSObject *)[FBXCTestDaemonsProxy testRunnerProxy] respondsToSelector:@selector(_XCT_requestScreenshotOfScreenWithID:withRect:uti:compressionQuality:withReply:)];
//    });
//    return result;
//}
//
//+ (BOOL)canScheduleTimerBlock
//{
//    static dispatch_once_t canSTB;
//    static BOOL result;
//    dispatch_once(&canSTB, ^{
//        result = [NSTimer respondsToSelector:@selector(scheduledTimerWithTimeInterval:repeats:block:)];
//    });
//    return result;
//}
//
//- (void)didClientConnect:(GCDAsyncSocket *)newClient
//{
//  [FBLogger logFmt:@"Got screenshots broadcast client connection at %@:%d", newClient.connectedHost, newClient.connectedPort];
//  // Start broadcast only after there is any data from the client
//  [newClient readDataWithTimeout:-1 tag:0];
//}
//
//- (void)didClientSendData:(GCDAsyncSocket *)client
//{
//    dispatch_async(self.backgroundQueue, ^{
//        NSString *streamHeader = [NSString stringWithFormat:@"HTTP/1.0 200 OK\r\nServer: %@\r\nConnection: close\r\nMax-Age: 0\r\nExpires: 0\r\nCache-Control: no-cache, private\r\nPragma: no-cache\r\nContent-Type: multipart/x-mixed-replace; boundary=--BoundaryString\r\n\r\n", SERVER_NAME];
//        [newClient writeData:(id)[streamHeader dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
//    });
//
//    @synchronized (self.activeClients) {
//        [self.activeClients removeAllObjects];
//        [self.activeClients addObjectsFromArray:activeClients];
//    }
//}
//
//- (void)didClientDisconnect:(GCDAsyncSocket *)client
//{
//    @synchronized (self.activeClients) {
//        [self.activeClients removeAllObjects];
//        [self.activeClients addObjectsFromArray:activeClients];
//    }
//}


- (instancetype)init
{
  if ((self = [super init])) {
    _listeningClients = [NSMutableArray array];
    dispatch_queue_attr_t queueAttributes = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_UTILITY, 0);
    _backgroundQueue = dispatch_queue_create(QUEUE_NAME, queueAttributes);
    dispatch_async(_backgroundQueue, ^{
      [self streamScreenshot];
    });
    _imageProcessor = [[FBImageProcessor alloc] init];
    _mainScreenID = [XCUIScreen.mainScreen displayID];
  }
  return self;
}

- (void)scheduleNextScreenshotWithInterval:(uint64_t)timerInterval timeStarted:(uint64_t)timeStarted
{
  uint64_t timeElapsed = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW) - timeStarted;
  int64_t nextTickDelta = timerInterval - timeElapsed;
  if (nextTickDelta > 0) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, nextTickDelta), self.backgroundQueue, ^{
      [self streamScreenshot];
    });
  } else {
    // Try to do our best to keep the FPS at a decent level
    dispatch_async(self.backgroundQueue, ^{
      [self streamScreenshot];
    });
  }
}

- (void)streamScreenshot
{
  NSUInteger framerate = FBConfiguration.mjpegServerFramerate;
  uint64_t timerInterval = (uint64_t)(1.0 / ((0 == framerate || framerate > MAX_FPS) ? MAX_FPS : framerate) * NSEC_PER_SEC);
  uint64_t timeStarted = clock_gettime_nsec_np(CLOCK_MONOTONIC_RAW);
  @synchronized (self.listeningClients) {
    if (0 == self.listeningClients.count) {
      [self scheduleNextScreenshotWithInterval:timerInterval timeStarted:timeStarted];
      return;
    }
  }

  NSError *error;
  CGFloat compressionQuality = MAX(FBMinCompressionQuality,
                                   MIN(FBMaxCompressionQuality, FBConfiguration.mjpegServerScreenshotQuality / 100.0));
  NSData *screenshotData = [FBScreenshot takeInOriginalResolutionWithScreenID:self.mainScreenID
                                                           compressionQuality:compressionQuality
                                                                          uti:UTTypeJPEG
                                                                      timeout:FRAME_TIMEOUT
                                                                        error:&error];
  if (nil == screenshotData) {
    [FBLogger logFmt:@"%@", error.description];
    [self scheduleNextScreenshotWithInterval:timerInterval timeStarted:timeStarted];
    return;
  }

  CGFloat scalingFactor = FBConfiguration.mjpegScalingFactor / 100.0;
  [self.imageProcessor submitImageData:screenshotData
                         scalingFactor:scalingFactor
                     completionHandler:^(NSData * _Nonnull scaled) {
    [self sendScreenshot:scaled];
  }];

  [self scheduleNextScreenshotWithInterval:timerInterval timeStarted:timeStarted];
}

- (void)sendScreenshot:(NSData *)screenshotData {
  NSString *chunkHeader = [NSString stringWithFormat:@"--BoundaryString\r\nContent-type: image/jpeg\r\nContent-Length: %@\r\n\r\n", @(screenshotData.length)];
  NSMutableData *chunk = [[chunkHeader dataUsingEncoding:NSUTF8StringEncoding] mutableCopy];
//  NSString *screenshot = [screenshotData base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
//  screenshotData = [screenshot dataUsingEncoding:kCFStringEncodingUTF8];
  [chunk appendData:screenshotData];
  [chunk appendData:(id)[@"\r\n\r\n" dataUsingEncoding:NSUTF8StringEncoding]];
  @synchronized (self.listeningClients) {
    for (GCDAsyncSocket *client in self.listeningClients) {
      [client writeData:chunk withTimeout:-1 tag:0];
    }
  }
}

- (void)didClientConnect:(GCDAsyncSocket *)newClient
{
  [FBLogger logFmt:@"Got screenshots broadcast client connection at %@:%d", newClient.connectedHost, newClient.connectedPort];
  // Start broadcast only after there is any data from the client
  [newClient readDataWithTimeout:-1 tag:0];
}

- (void)didClientSendData:(GCDAsyncSocket *)client
{
  @synchronized (self.listeningClients) {
    if ([self.listeningClients containsObject:client]) {
      return;
    }
  }

  [FBLogger logFmt:@"Starting screenshots broadcast for the client at %@:%d", client.connectedHost, client.connectedPort];
  NSString *streamHeader = [NSString stringWithFormat:@"HTTP/1.0 200 OK\r\nServer: %@\r\nConnection: close\r\nMax-Age: 0\r\nExpires: 0\r\nCache-Control: no-cache, private\r\nPragma: no-cache\r\nContent-Type: multipart/x-mixed-replace; boundary=--BoundaryString\r\n\r\n", SERVER_NAME];
  [client writeData:(id)[streamHeader dataUsingEncoding:NSUTF8StringEncoding] withTimeout:-1 tag:0];
  @synchronized (self.listeningClients) {
    [self.listeningClients addObject:client];
  }
}

- (void)didClientDisconnect:(GCDAsyncSocket *)client
{
  @synchronized (self.listeningClients) {
    [self.listeningClients removeObject:client];
  }
  [FBLogger log:@"Disconnected a client from screenshots broadcast"];
}


@end
