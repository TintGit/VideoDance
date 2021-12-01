//
//  ViewController.m
//  VideoDance
//
//  Created by 言有理 on 2021/12/1.
//

#import "ViewController.h"
#import "TTCameraCapture.h"
@interface ViewController ()<TTCameraCaptureListener>
@property(nonatomic, strong) TTCameraCapture *capture;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupCapture];
}
- (void)setupCapture {
    _capture = [[TTCameraCapture alloc] init];
    _capture.delegate = self;
    [_capture prepare];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.capture startRunning];
}

// MARK: - Delegate
// MARK: TTCameraCaptureListener - 相机采集
- (void)ttCam:(TTCameraCapture *)cameraCapture didOutputVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    
}

- (void)ttCam:(TTCameraCapture *)cameraCapture didOutputAudioSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    
}

@end
