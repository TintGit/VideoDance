//
//  TTCameraCapture+Tools.h
//  TuCamera
//
//  Created by 言有理 on 2021/11/17.
//


#import "TTCameraCapture.h"
NS_ASSUME_NONNULL_BEGIN

@interface TTCameraCapture (Tools)
+ (AVCaptureDevice *)deviceWithPosition:(AVCaptureDevicePosition)position;

+ (BOOL)formatInRange:(AVCaptureDeviceFormat*)format frameRate:(CMTimeScale)frameRate;
+ (BOOL)formatInRange:(AVCaptureDeviceFormat*)format frameRate:(CMTimeScale)frameRate dimensions:(CMVideoDimensions)dimensions;
+ (CMTimeScale)maxFrameRateForFormat:(AVCaptureDeviceFormat *)format minFrameRate:(CMTimeScale)minFrameRate;

+ (NSError*)createError:(NSString*)errorDescription;
@end

NS_ASSUME_NONNULL_END
