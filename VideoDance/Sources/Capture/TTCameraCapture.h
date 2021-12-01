//
//  TTCameraCapture.h
//  TuCamera
//
//  Created by 言有理 on 2021/10/21.
//

#import <AVFoundation/AVFoundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(NSInteger, TTCamSetupResult) {
    TTCamSetupResultSuccess,
    TTCamSetupResultCameraNotAuthorized,
    TTCamSetupResultSessionConfigurationFailed
};
typedef NS_ENUM(NSInteger, TTFlashMode) {
    TTFlashModeOff  = AVCaptureFlashModeOff,
    TTFlashModeOn   = AVCaptureFlashModeOn,
    TTFlashModeAuto = AVCaptureFlashModeAuto,
    TTFlashModeLight
};
/**
 * @brief 视频帧的像素格式。
 */
typedef NS_ENUM(NSUInteger, TTPixelFormat) {

    /// YUV420P I420
    TTPixelFormatYUV,

    /// BGRA8888
    TTPixelFormatBGRA,
};
@class TTCameraCapture;
@protocol TTCameraCaptureListener <NSObject>

- (void)ttCam:(TTCameraCapture *)cameraCapture didOutputVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)ttCam:(TTCameraCapture *)cameraCapture didOutputAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer;

@end
@interface TTCameraCapture : NSObject
@property(nonatomic, weak) id<TTCameraCaptureListener> delegate;

/// 摄像头位置 默认前置.
@property(nonatomic) AVCaptureDevicePosition devicePosition;

/// 前置摄像头画面方向 默认竖直.
@property(nonatomic) AVCaptureVideoOrientation frontOrientation;

/// 后置摄像头画面方向 默认竖直.
@property(nonatomic) AVCaptureVideoOrientation backOrientation;

/// front mirrored
@property(nonatomic) BOOL frontMirrored;

/// back mirrored default YES.
@property(nonatomic) BOOL backMirrored;

/// pixel format default YUV.
@property(nonatomic) TTPixelFormat pixelFormat;

/// session preset default AVCaptureSessionPreset1920x1080.
@property(nonatomic) AVCaptureSessionPreset sessionPreset;

/// 帧率 default 18.
@property(nonatomic) int fps;

/// The zoom factor applied to the video.
@property (nonatomic) CGFloat videoZoomFactor;

/// The max zoom factor for the current device
@property (nonatomic, readonly) CGFloat maxVideoZoomFactor;

/// 是否开启自动聚焦 默认 YES.
@property(nonatomic) BOOL enableAutoFocus;
/// 获取当前 聚焦模式
@property(nonatomic, readonly) AVCaptureFocusMode focusMode;

/// 闪光灯
@property(nonatomic) TTFlashMode flashMode;

/// The value of this property is a BOOL indicating whether the receiver has a flash. The receiver's flashMode property can only be set when this property returns YES.
@property(nonatomic, readonly) BOOL hasFlash;

/// configure
- (TTCamSetupResult)prepare;

- (void)startRunning;
- (void)stopRunning;
/// 切换摄像头
- (void)switchCaptureDevicesCompletion:(void (^ __nullable)(void))completion;
/// 设置聚焦区域 AVCaptureFocusModeAutoFocus
- (void)autoFocusAtPoint:(CGPoint)point;
/// 设置聚焦区域 AVCaptureFocusModeContinuousAutoFocus
- (void)continuousFocusAtPoint:(CGPoint)point;
@end

NS_ASSUME_NONNULL_END
