//
//  TTCameraCapture+Tools.m
//  TuCamera
//
//  Created by 言有理 on 2021/11/17.
//

#import "TTCameraCapture+Tools.h"

@implementation TTCameraCapture (Tools)
+ (AVCaptureDevice *)deviceWithPosition:(AVCaptureDevicePosition)position {
    AVCaptureDevice *device;
    for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
        if ([d position] == position) {
            device = d;
        }
    }
    if (!device) {
        device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    return device;
}

+ (BOOL)formatInRange:(AVCaptureDeviceFormat*)format frameRate:(CMTimeScale)frameRate {
    CMVideoDimensions dimensions;
    dimensions.width = 0;
    dimensions.height = 0;
    
    return [TTCameraCapture formatInRange:format frameRate:frameRate dimensions:dimensions];
}

+ (BOOL)formatInRange:(AVCaptureDeviceFormat*)format frameRate:(CMTimeScale)frameRate dimensions:(CMVideoDimensions)dimensions {
    CMVideoDimensions size = CMVideoFormatDescriptionGetDimensions(format.formatDescription);
    
    if (size.width >= dimensions.width && size.height >= dimensions.height) {
        for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges) {
            if (range.minFrameDuration.timescale >= frameRate && range.maxFrameDuration.timescale <= frameRate) {
                return YES;
            }
        }
    }
    
    return NO;
}

+ (CMTimeScale)maxFrameRateForFormat:(AVCaptureDeviceFormat *)format minFrameRate:(CMTimeScale)minFrameRate {
    CMTimeScale lowerTimeScale = 0;
    for (AVFrameRateRange *range in format.videoSupportedFrameRateRanges) {
        if (range.minFrameDuration.timescale >= minFrameRate && (lowerTimeScale == 0 || range.minFrameDuration.timescale < lowerTimeScale)) {
            lowerTimeScale = range.minFrameDuration.timescale;
        }
    }
    
    return lowerTimeScale;
}

+ (NSError*)createError:(NSString*)errorDescription {
    return [NSError errorWithDomain:@"TTCameraCapture" code:200 userInfo:@{NSLocalizedDescriptionKey : errorDescription}];
}
@end
