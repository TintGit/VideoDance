//
//  TTCameraCapture.m
//  TuCamera
//
//  Created by 言有理 on 2021/10/21.
//

@import AVFoundation;
#import "TTCameraCapture.h"
#import "TTCameraCapture+Tools.h"
static void*  SessionRunningContext = &SessionRunningContext;

@interface TTCameraCapture ()<AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureAudioDataOutputSampleBufferDelegate>
@property(nonatomic) dispatch_queue_t sessionQueue;
@property(nonatomic) AVCaptureSession* session;
@property(nonatomic) AVCaptureDeviceInput* videoDeviceInput;
@property(nonatomic) AVCaptureVideoDataOutput *videoDataOutput;

@property(nonatomic) TTCamSetupResult setupResult;
@property(nonatomic, getter=isSessionRunning) BOOL sessionRunning;
@property(nonatomic)NSInteger captureFps;
@end

@implementation TTCameraCapture

- (instancetype)init {
    self = [super init];
    if (self) {
        _session = [[AVCaptureSession alloc] init];
        _sessionQueue = dispatch_queue_create("session queue", DISPATCH_QUEUE_SERIAL);
        _setupResult = TTCamSetupResultSuccess;
        
        switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
            case AVAuthorizationStatusAuthorized: {
                // The user has previously granted access to the camera.
                break;
            }
            case AVAuthorizationStatusNotDetermined: {
                dispatch_suspend(self.sessionQueue);
                [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                    if (!granted) {
                        self.setupResult = TTCamSetupResultCameraNotAuthorized;
                    }
                    dispatch_resume(self.sessionQueue);
                }];
                break;
            }
            default: {
                // The user has previously denied access.
                self.setupResult = TTCamSetupResultCameraNotAuthorized;
                break;
            }
        }
        _devicePosition = AVCaptureDevicePositionFront;
        _frontOrientation = AVCaptureVideoOrientationPortrait;
        _backOrientation = AVCaptureVideoOrientationPortrait;
        _frontMirrored = YES;
        _backMirrored = YES;
        _pixelFormat = TTPixelFormatYUV;
        _sessionPreset = AVCaptureSessionPreset1920x1080;
        _fps = 50;
        _enableAutoFocus = YES;
    }
    return self;
}

- (void)dealloc {
    [self removeObservers];
}
// MARK: - Private
- (void)configureSession {
    if (self.setupResult != TTCamSetupResultSuccess) {
        return;
    }
    NSError* error = nil;
    [self.session beginConfiguration];
    self.session.sessionPreset = self.sessionPreset;
    // Add video input.
    AVCaptureDevice *videoDevice = [TTCameraCapture deviceWithPosition:self.devicePosition];
    AVCaptureDeviceInput* videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
    if (!videoDeviceInput) {
        NSLog(@"Could not create video device input: %@", error);
        self.setupResult = TTCamSetupResultSessionConfigurationFailed;
        [self.session commitConfiguration];
        return;
    }
    if ([self.session canAddInput:videoDeviceInput]) {
        [self.session addInput:videoDeviceInput];
        self.videoDeviceInput = videoDeviceInput;
    } else {
        NSLog(@"Could not add video device input to the session");
        self.setupResult = TTCamSetupResultSessionConfigurationFailed;
        [self.session commitConfiguration];
        return;
    }
    // Add audio input.
    AVCaptureDevice* audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    AVCaptureDeviceInput* audioDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:&error];
    if (!audioDeviceInput) {
        NSLog(@"Could not create audio device input: %@", error);
    }
    if ([self.session canAddInput:audioDeviceInput]) {
        [self.session addInput:audioDeviceInput];
    } else {
        NSLog(@"Could not add audio device input to the session");
    }
    
    // Add output.
    AVCaptureVideoDataOutput *videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    AVCaptureAudioDataOutput *audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    [self.session addOutput:videoDataOutput];
    [self.session addOutput:audioDataOutput];
    OSType pixelFormatType = (self.pixelFormat == TTPixelFormatYUV) ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange : kCVPixelFormatType_32BGRA;
    videoDataOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt: pixelFormatType]
                                                                forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    self.videoDataOutput = videoDataOutput;
    
    // Use serial queue to receive audio / video data
    dispatch_queue_t videoQueue = dispatch_queue_create("videoQueue", NULL);
    dispatch_queue_t audioQueue = dispatch_queue_create("audioQueue", NULL);
    [videoDataOutput setSampleBufferDelegate:self queue:videoQueue];
    [audioDataOutput setSampleBufferDelegate:self queue:audioQueue];
    
    [self orientationAndMirroredWithPosition:self.devicePosition];
    //[self setFrameRate:self.fps];
    //[self setCameraForLFRWithFrameRate:self.fps];
    //[self setActiveFormatWithFrameRate:40 width:1080 andHeight:1920];
    [self.session commitConfiguration];
}

/// 设置画面方向和镜像
/// @param position 摄像头位置
- (void)orientationAndMirroredWithPosition:(AVCaptureDevicePosition)position {
    AVCaptureConnection *connection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    if (position == AVCaptureDevicePositionFront) {
        [connection setVideoOrientation:self.frontOrientation];
        [connection setVideoMirrored:self.frontMirrored];
    } else if (position == AVCaptureDevicePositionBack) {
        [connection setVideoOrientation:self.backOrientation];
        [connection setVideoMirrored:self.backMirrored];
    }
}
/// 计算采集帧率
- (void)calculatorCaptureFps {
    static int count = 0;
    static float lastTime = 0;
    CMClockRef hostClockRef = CMClockGetHostTimeClock();
    CMTime hostTime = CMClockGetTime(hostClockRef);
    float nowTime = CMTimeGetSeconds(hostTime);
    if(nowTime - lastTime >= 1) {
        self.captureFps = count;
         NSLog(@"capture fps %d", count);
        lastTime = nowTime;
        count = 0;
    } else {
        count ++;
    }
}

// MARK: - Delegate
- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if ([output isKindOfClass:[AVCaptureVideoDataOutput class]]) {
        //[self calculatorCaptureFps];
//        CVPixelBufferRef pix = CMSampleBufferGetImageBuffer(sampleBuffer);
//        NSLog(@"capture outputSize %@", NSStringFromCGSize(CGSizeMake(CVPixelBufferGetWidth(pix), CVPixelBufferGetHeight(pix))));
        if ([self.delegate respondsToSelector:@selector(ttCam:didOutputVideoSampleBuffer:)]) {
            [self.delegate ttCam:self didOutputVideoSampleBuffer:sampleBuffer];
        }
    } else if ([output isKindOfClass:[AVCaptureAudioDataOutput class]]) {
        if ([self.delegate respondsToSelector:@selector(ttCam:didOutputAudioSampleBuffer:)]) {
            [self.delegate ttCam:self didOutputAudioSampleBuffer:sampleBuffer];
        }
    }
}
// MARK: - Notification
- (void)addObservers {
    [self.session addObserver:self forKeyPath:@"running" options:NSKeyValueObservingOptionNew context:SessionRunningContext];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:self.videoDeviceInput.device];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:self.session];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionWasInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(sessionInterruptionEnded:) name:AVCaptureSessionInterruptionEndedNotification object:self.session];
}

- (void)removeObservers {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [self.session removeObserver:self forKeyPath:@"running" context:SessionRunningContext];
}

- (void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    if (context == SessionRunningContext) {
        self.sessionRunning = [change[NSKeyValueChangeNewKey] boolValue];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)subjectAreaDidChange:(NSNotification*)notification {
    CGPoint devicePoint = CGPointMake(0.5, 0.5);
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeContinuousAutoExposure atDevicePoint:devicePoint monitorSubjectAreaChange:NO];
}

- (void)sessionRuntimeError:(NSNotification*)notification {
    NSError* error = notification.userInfo[AVCaptureSessionErrorKey];
    NSLog(@"Capture session runtime error: %@", error);
    
    // If media services were reset, and the last start succeeded, restart the session.
    if (error.code == AVErrorMediaServicesWereReset) {
        dispatch_async(self.sessionQueue, ^{
            if (self.isSessionRunning) {
                [self.session startRunning];
                self.sessionRunning = self.session.isRunning;
            }
        });
    }
}

- (void)sessionWasInterrupted:(NSNotification*)notification {
    BOOL showResumeButton = NO;
    
    AVCaptureSessionInterruptionReason reason = [notification.userInfo[AVCaptureSessionInterruptionReasonKey] integerValue];
    NSLog(@"Capture session was interrupted with reason %ld", (long)reason);
    
    if (reason == AVCaptureSessionInterruptionReasonAudioDeviceInUseByAnotherClient ||
        reason == AVCaptureSessionInterruptionReasonVideoDeviceInUseByAnotherClient) {
        showResumeButton = YES;
    } else if (reason == AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableWithMultipleForegroundApps) {
        
    } else if (@available(iOS 11.1, *)) {
        if (reason == AVCaptureSessionInterruptionReasonVideoDeviceNotAvailableDueToSystemPressure) {
            NSLog(@"Session stopped running due to shutdown system pressure level.");
        }
    } else {
        // Fallback on earlier versions
    }
}

- (void)sessionInterruptionEnded:(NSNotification*)notification {
    NSLog(@"Capture session interruption ended");
}
/// 切换摄像头
- (void)switchCaptureDevices {
    AVCaptureDevice* currentVideoDevice = self.videoDeviceInput.device;
    AVCaptureDevicePosition position = currentVideoDevice.position;
    switch (position) {
        case AVCaptureDevicePositionUnspecified:
        case AVCaptureDevicePositionFront:
            position = AVCaptureDevicePositionBack;
            break;
        case AVCaptureDevicePositionBack:
        default:
            NSLog(@"Unknown capture position. Defaulting to front");
            position = AVCaptureDevicePositionFront;
    }
    AVCaptureDevice *newVideoDevice = [TTCameraCapture deviceWithPosition:position];
    AVCaptureDeviceInput *videoDeviceInput = [AVCaptureDeviceInput deviceInputWithDevice:newVideoDevice error:NULL];
    [self.session beginConfiguration];
    // Remove the existing device input first, since using the front and back camera simultaneously is not supported.
    [self.session removeInput:self.videoDeviceInput];
    if ([self.session canAddInput:videoDeviceInput]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureDeviceSubjectAreaDidChangeNotification object:currentVideoDevice];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(subjectAreaDidChange:) name:AVCaptureDeviceSubjectAreaDidChangeNotification object:newVideoDevice];
        [self.session addInput:videoDeviceInput];
        self.videoDeviceInput = videoDeviceInput;
    } else {
        [self.session addInput:self.videoDeviceInput];
    }
    [self orientationAndMirroredWithPosition:position];
    //[self setActiveFormatWithFrameRate:40 width:1080 andHeight:1920];
    [self.session commitConfiguration];
}

/// 对焦(通过移动镜片改变其到传感器之间的距离实现的)
/// @param focusMode 聚焦 locked:指镜片处于固定位置;AutoFocus 指一开始相机会先自动对焦一次，然后便处于 Locked 模式;ContinuousAutoFocus 指当场景改变，相机会自动重新对焦到画面的中心点。
/// @param exposureMode 曝光 locked:指示曝光应该锁定在其当前值;AutoExpose 指示设备应该自动调整曝光一次 然后便处于 Locked 模式; ContinuousAutoExposure 表示设备应在需要时自动调整曝光; Custom 指示设备只能根据用户提供的ISO、曝光率值来调整曝光率。
/// @param point 点（从左上角 {0，0} 到右下角 {1，1}，{0.5，0.5} 为画面的中心点）
/// @param monitorSubjectAreaChange 是否应该监控视频主题区域的变化，例如照明变化、实际移动等。更改时发送AVCaptureDeviceSubjectAreaDidChangeNotification在客户端可以设置此属性的值之前，接收器必须被锁定以使用lockForConfiguration进行配置。
- (void)focusWithMode:(AVCaptureFocusMode)focusMode exposeWithMode:(AVCaptureExposureMode)exposureMode atDevicePoint:(CGPoint)point monitorSubjectAreaChange:(BOOL)monitorSubjectAreaChange {
    dispatch_async(self.sessionQueue, ^{
        AVCaptureDevice *device = self.videoDeviceInput.device;
        NSError* error = nil;
        if ([device lockForConfiguration:&error]) {
            /*
             Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
             Call set(Focus/Exposure)Mode() to apply the new point of interest.
            */
            if (device.isFocusPointOfInterestSupported && [device isFocusModeSupported:focusMode]) {
                device.focusPointOfInterest = point;
                device.focusMode = focusMode;
            }
            if (device.isExposurePointOfInterestSupported && [device isExposureModeSupported:exposureMode]) {
                device.exposurePointOfInterest = point;
                device.exposureMode = exposureMode;
            }
            device.subjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange;
            [device unlockForConfiguration];
        }
        else {
            NSLog(@"Could not lock device for configuration: %@", error);
        }
    });
}
// MARK: - Public
- (void)setVideoZoomFactor:(CGFloat)videoZoomFactor {
    _videoZoomFactor = videoZoomFactor;
    AVCaptureDevice *device = self.videoDeviceInput.device;
    if ([device respondsToSelector:@selector(videoZoomFactor)]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            if (videoZoomFactor <= device.activeFormat.videoMaxZoomFactor) {
                device.videoZoomFactor = videoZoomFactor;
            } else {
                NSLog(@"Unable to set videoZoom: (max %f, asked %f)", device.activeFormat.videoMaxZoomFactor, videoZoomFactor);
            }
            
            [device unlockForConfiguration];
        } else {
            NSLog(@"Unable to set videoZoom: %@", error.localizedDescription);
        }
    }
}

- (CGFloat)maxVideoZoomFactor {
    return self.videoDeviceInput.device.activeFormat.videoMaxZoomFactor;
}

- (void)setEnableAutoFocus:(BOOL)enableAutoFocus {
    _enableAutoFocus = enableAutoFocus;
    AVCaptureDevice *device = self.videoDeviceInput.device;
    if ([device isFocusModeSupported:AVCaptureFocusModeLocked]) {
        NSError *error;
        if ([device lockForConfiguration:&error]) {
            [device setFocusMode: enableAutoFocus ? AVCaptureFocusModeAutoFocus : AVCaptureFocusModeLocked];
            [device unlockForConfiguration];
        }
    }
}

- (AVCaptureFocusMode)focusMode {
    return self.videoDeviceInput.device.focusMode;
}

- (void)setFlashMode:(TTFlashMode)flashMode {
    _flashMode = flashMode;
    AVCaptureDevice *device = self.videoDeviceInput.device;
    NSError *error = nil;
    if (device.hasFlash) {
        if ([device lockForConfiguration:&error]) {
            if (flashMode == TTFlashModeLight) {
                if ([device isTorchModeSupported:AVCaptureTorchModeOn]) {
                    [device setTorchMode:AVCaptureTorchModeOn];
                }
                if ([device isFlashModeSupported:AVCaptureFlashModeOff]) {
                    [device setFlashMode:AVCaptureFlashModeOff];
                }
            } else {
                if ([device isTorchModeSupported:AVCaptureTorchModeOff]) {
                    [device setTorchMode:AVCaptureTorchModeOff];
                }
                if ([device isFlashModeSupported:(AVCaptureFlashMode)flashMode]) {
                    [device setFlashMode:(AVCaptureFlashMode)flashMode];
                }
            }
            [device unlockForConfiguration];
        }
    }
}
- (BOOL)hasFlash {
    return self.videoDeviceInput.device.hasFlash;
}

- (TTCamSetupResult)prepare {
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    dispatch_async(self.sessionQueue, ^{
        [self configureSession];
        dispatch_semaphore_signal(sem);
    });
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
    return self.setupResult;
}

- (void)startRunning {
    if (self.setupResult != TTCamSetupResultSuccess) {
        return;
    }
    dispatch_async(self.sessionQueue, ^{
        [self addObservers];
        [self.session startRunning];
        self.sessionRunning = self.session.isRunning;
    });
}

- (void)stopRunning {
    if (self.setupResult != TTCamSetupResultSuccess) {
        return;
    }
    dispatch_async(self.sessionQueue, ^{
        [self.session stopRunning];
        [self removeObservers];
    });
}

- (void)switchCaptureDevicesCompletion:(void (^ __nullable)(void))completion {
    dispatch_async(self.sessionQueue, ^{
        [self switchCaptureDevices];
        if (completion) {
            dispatch_async(dispatch_get_main_queue(), completion);
        }
    });
}

- (void)autoFocusAtPoint:(CGPoint)point {
    [self focusWithMode:AVCaptureFocusModeAutoFocus exposeWithMode:AVCaptureExposureModeAutoExpose atDevicePoint:point monitorSubjectAreaChange:YES];
}

- (void)continuousFocusAtPoint:(CGPoint)point {
    [self focusWithMode:AVCaptureFocusModeContinuousAutoFocus exposeWithMode:AVCaptureExposureModeAutoExpose atDevicePoint:point monitorSubjectAreaChange:YES];
}

- (void)setFrameRate:(int)framePerSeconds {
    CMTime fps = CMTimeMake(1, framePerSeconds);
    AVCaptureDevice *device = self.videoDeviceInput.device;
    if (device != nil) {
        NSError * error = nil;
        BOOL formatSupported = [TTCameraCapture formatInRange:device.activeFormat frameRate:framePerSeconds];
        
        if (formatSupported) {
            if ([device lockForConfiguration:&error]) {
                device.activeVideoMaxFrameDuration = fps;
                device.activeVideoMinFrameDuration = fps;
                [device unlockForConfiguration];
            } else {
                NSLog(@"Failed to set FramePerSeconds into camera device: %@", error.description);
            }
        } else {
            NSLog(@"Unsupported frame rate %ld on current device format.", (long)framePerSeconds);
        }
    }
}

- (BOOL)setActiveFormatWithFrameRate:(CMTimeScale)frameRate width:(int)width andHeight:(int)height {
    AVCaptureDevice *device = self.videoDeviceInput.device;
    CMVideoDimensions dimensions;
    dimensions.width = width;
    dimensions.height = height;
    NSError *error;
    BOOL foundSupported = NO;
    
    if (device != nil) {
        AVCaptureDeviceFormat *bestFormat = nil;
        
        for (AVCaptureDeviceFormat *format in device.formats) {
            if ([TTCameraCapture formatInRange:format frameRate:frameRate dimensions:dimensions]) {
                if (bestFormat == nil) {
                    bestFormat = format;
                } else {
                    CMVideoDimensions bestDimensions = CMVideoFormatDescriptionGetDimensions(bestFormat.formatDescription);
                    CMVideoDimensions currentDimensions = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
                    
                    if (currentDimensions.width < bestDimensions.width && currentDimensions.height < bestDimensions.height) {
                        bestFormat = format;
                    } else if (currentDimensions.width == bestDimensions.width && currentDimensions.height == bestDimensions.height) {
                        if ([TTCameraCapture maxFrameRateForFormat:bestFormat minFrameRate:frameRate] > [TTCameraCapture maxFrameRateForFormat:format minFrameRate:frameRate]) {
                            bestFormat = format;
                        }
                    }
                }
            }
        }
        
        if (bestFormat != nil) {
            if ([device lockForConfiguration:&error]) {
                CMTime frameDuration = CMTimeMake(1, frameRate);
                
                device.activeFormat = bestFormat;
                foundSupported = true;
                
                device.activeVideoMinFrameDuration = frameDuration;
                device.activeVideoMaxFrameDuration = frameDuration;
                
                [device unlockForConfiguration];
            }
        } else {
            if (error != nil) {
                error = [TTCameraCapture createError:[NSString stringWithFormat:@"No format that supports framerate %d and dimensions %d/%d was found", (int)frameRate, dimensions.width, dimensions.height]];
            }
        }
    } else {
        if (error != nil) {
            error = [TTCameraCapture createError:@"The camera must be initialized before setting active format"];
        }
    }
    
    if (foundSupported && error != nil) {
        error = nil;
    }
    
    return foundSupported;
}
@end
