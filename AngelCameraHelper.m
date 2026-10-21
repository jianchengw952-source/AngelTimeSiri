#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreGraphics/CoreGraphics.h>
#import <ImageIO/ImageIO.h>
#import <CoreImage/CoreImage.h>
#import <VideoToolbox/VideoToolbox.h>
#import <os/log.h>
#include <signal.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>

static NSString *agSharedBaseDir(void) {
    return @"/tmp";
}

static NSString *agSharedFrameFilePath(void) {
    return [agSharedBaseDir() stringByAppendingPathComponent:@"ag_live_cam_frame.jpg"];
}

static NSString *agSharedStatusFilePath(void) {
    return [agSharedBaseDir() stringByAppendingPathComponent:@"ag_cam_status.json"];
}

static NSString *agSharedStopFlagPath(void) {
    return [agSharedBaseDir() stringByAppendingPathComponent:@"ag_cam_stop.flag"];
}

static const char *kDebugLogPath = "/tmp/ag_cam_debug.log";

static volatile const char *gHelperStep = "STARTUP";
static volatile void *gFaultAddr = NULL;

static void agLogStep(const char *step) {
    gHelperStep = step;
    int fd = open(kDebugLogPath, O_WRONLY | O_CREAT | O_APPEND, 0666);
    if (fd >= 0) {
        write(fd, step, strlen(step));
        write(fd, "\n", 1);
        close(fd);
    }
}

// 崩溃信号捕获器：精准记录崩溃发生的步骤名、信号与非法内存地址
static void agSignalCrashAction(int sig, siginfo_t *info, void *ucontext) {
    gFaultAddr = info ? info->si_addr : NULL;
    char buf[512];
    snprintf(buf, sizeof(buf), 
             "{\"state\":\"FAILED\",\"detail\":\"辅助进程在步骤 [%s] 崩溃: SIG=%d (addr=%p)\"}", 
             gHelperStep ? gHelperStep : "UNKNOWN", sig, gFaultAddr);
    int fd = open("/tmp/ag_cam_status.json", O_WRONLY | O_CREAT | O_TRUNC, 0666);
    if (fd >= 0) {
        write(fd, buf, strlen(buf));
        close(fd);
    }
    int lfd = open(kDebugLogPath, O_WRONLY | O_CREAT | O_APPEND, 0666);
    if (lfd >= 0) {
        char lbuf[256];
        snprintf(lbuf, sizeof(lbuf), "[FATAL CRASH] Step=%s, SIG=%d, Addr=%p\n", 
                 gHelperStep ? gHelperStep : "UNKNOWN", sig, gFaultAddr);
        write(lfd, lbuf, strlen(lbuf));
        close(lfd);
    }
    _exit(sig);
}

static void setupCrashHandlers(void) {
    struct sigaction sa;
    memset(&sa, 0, sizeof(sa));
    sa.sa_sigaction = agSignalCrashAction;
    sigemptyset(&sa.sa_mask);
    sa.sa_flags = SA_SIGINFO | SA_RESETHAND;
    sigaction(SIGSEGV, &sa, NULL);
    sigaction(SIGBUS, &sa, NULL);
    sigaction(SIGILL, &sa, NULL);
    sigaction(SIGABRT, &sa, NULL);
    sigaction(SIGFPE, &sa, NULL);
}

static void writeHelperStatusWithToken(NSString *state, NSString *detail, NSString *token) {
    if (!state) return;
    os_log(OS_LOG_DEFAULT, "[AngelCameraHelper] %{public}@: %{public}@", state, detail ?: @"");
    NSDictionary *dict = @{
        @"state": state ?: @"UNKNOWN",
        @"detail": detail ?: @"",
        @"token": token ?: @"",
        @"step": [NSString stringWithUTF8String:(const char *)(gHelperStep ?: "UNKNOWN")],
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    };
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    if (data) {
        int fd = open("/tmp/ag_cam_status.json", O_WRONLY | O_CREAT | O_TRUNC, 0666);
        if (fd >= 0) {
            write(fd, data.bytes, data.length);
            close(fd);
        }
    }
}

// 纯 C / ImageIO 高性能 JPEG 写入，直接写入目标文件并赋予 0666 权限，避免跨进程 rename 权限撕裂
static BOOL agWriteCGImageAsJPEG(CGImageRef cgImg, CGFloat quality, NSString *destPath) {
    if (!cgImg || !destPath) return NO;
    NSURL *fileURL = [NSURL fileURLWithPath:destPath];
    CGImageDestinationRef dest = CGImageDestinationCreateWithURL((__bridge CFURLRef)fileURL, CFSTR("public.jpeg"), 1, NULL);
    if (!dest) return NO;
    NSDictionary *opts = @{
        (__bridge id)kCGImageDestinationLossyCompressionQuality: @(quality)
    };
    CGImageDestinationAddImage(dest, cgImg, (__bridge CFDictionaryRef)opts);
    BOOL ok = CGImageDestinationFinalize(dest);
    CFRelease(dest);
    chmod([destPath UTF8String], 0666);
    return ok;
}

@interface AngelCamGrabber : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) AVCaptureSession *session;
@property (nonatomic, strong) AVCaptureDeviceInput *deviceInput;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property (nonatomic, strong) dispatch_queue_t sessionQueue;
@property (nonatomic, strong) dispatch_queue_t captureQueue;
@property (nonatomic, assign) NSTimeInterval lastWriteTime;
@property (nonatomic, assign) NSUInteger capturedFrameCount;
@property (nonatomic, copy) NSString *sessionToken;
@property (nonatomic, assign) BOOL isStopping;
@property (nonatomic, strong) NSTimer *heartbeatTimer;
@end

@implementation AngelCamGrabber

- (instancetype)initWithToken:(NSString *)token {
    self = [super init];
    if (self) {
        _capturedFrameCount = 0;
        _sessionToken = [token copy];
        _isStopping = NO;
        _sessionQueue = dispatch_queue_create("com.angelguardian.camsession", DISPATCH_QUEUE_SERIAL);
        _captureQueue = dispatch_queue_create("com.angelguardian.camdaemon", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

- (void)onSessionRuntimeError:(NSNotification *)note {
    NSError *err = note.userInfo[AVCaptureSessionErrorKey];
    NSString *detail = [NSString stringWithFormat:@"硬件相机运行错误(%ld): %@", (long)err.code, err.localizedDescription ?: @"未知错误"];
    writeHelperStatusWithToken(@"FAILED", detail, self.sessionToken);
}

- (void)onSessionDidStartRunning:(NSNotification *)note {
    agLogStep("11_RUNNING_NOTIFICATION");
    writeHelperStatusWithToken(@"CAMERA_RUNNING", @"硬件 Session 启动通知已收到，等待首帧画面...", self.sessionToken);
}

- (void)onSessionInterrupted:(NSNotification *)note {
    NSNumber *reason = note.userInfo[AVCaptureSessionInterruptionReasonKey];
    writeHelperStatusWithToken(@"INTERRUPTED", [NSString stringWithFormat:@"硬件相机被中断(Reason=%@)", reason ?: @"?"], self.sessionToken);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.3 * NSEC_PER_SEC)), self.sessionQueue, ^{
        if (self.session && !self.session.isRunning && !self.isStopping) {
            [self.session startRunning];
        }
    });
}

- (void)onHeartbeat:(NSTimer *)timer {
    if (self.isStopping || [[NSFileManager defaultManager] fileExistsAtPath:agSharedStopFlagPath()]) {
        self.isStopping = YES;
    }
}

- (void)startWithPosition:(AVCaptureDevicePosition)pos {
    agLogStep("4_SESSION_INIT");
    writeHelperStatusWithToken(@"CAMERA_INITIALIZING", (pos == AVCaptureDevicePositionFront ? @"正在初始化前置物理摄像头..." : @"正在初始化后置物理摄像头..."), self.sessionToken);

    self.session = [[AVCaptureSession alloc] init];
    if ([self.session respondsToSelector:@selector(setAutomaticallyConfiguresApplicationAudioSession:)]) {
        self.session.automaticallyConfiguresApplicationAudioSession = NO;
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSessionRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSessionDidStartRunning:) name:AVCaptureSessionDidStartRunningNotification object:self.session];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onSessionInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:self.session];

    agLogStep("5_SESSION_CONFIG_BEGIN");
    [self.session beginConfiguration];
    if ([self.session canSetSessionPreset:AVCaptureSessionPreset640x480]) {
        self.session.sessionPreset = AVCaptureSessionPreset640x480;
    } else if ([self.session canSetSessionPreset:AVCaptureSessionPresetMedium]) {
        self.session.sessionPreset = AVCaptureSessionPresetMedium;
    }

    agLogStep("6_DEVICE_DISCOVERY");
    AVCaptureDevice *dev = nil;
    @try {
        if (@available(iOS 10.0, *)) {
            dev = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:pos];
        }
    } @catch (NSException *e) {}

    if (!dev) {
        @try {
            for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
                if (d.position == pos) {
                    dev = d;
                    break;
                }
            }
        } @catch (NSException *e) {}
    }
    if (!dev) {
        @try {
            dev = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        } @catch (NSException *e) {}
    }

    if (!dev) {
        [self.session commitConfiguration];
        agLogStep("6_DEVICE_NOT_FOUND");
        writeHelperStatusWithToken(@"FAILED", @"未检测到物理摄像头硬件设备 (dev=nil)", self.sessionToken);
        return;
    }

    agLogStep("7_DEVICE_INPUT");
    NSError *err = nil;
    self.deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:dev error:&err];
    if (!self.deviceInput || err) {
        [self.session commitConfiguration];
        agLogStep("7_DEVICE_INPUT_FAILED");
        writeHelperStatusWithToken(@"FAILED", [NSString stringWithFormat:@"无法打开物理摄像头输入(%ld): %@", (long)err.code, err.localizedDescription ?: @"权限受限"], self.sessionToken);
        return;
    }

    if ([self.session canAddInput:self.deviceInput]) {
        [self.session addInput:self.deviceInput];
    } else {
        [self.session commitConfiguration];
        agLogStep("7_CAN_NOT_ADD_INPUT");
        writeHelperStatusWithToken(@"FAILED", @"Session 无法添加摄像头 Input", self.sessionToken);
        return;
    }

    agLogStep("8_VIDEO_OUTPUT");
    self.videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    self.videoOutput.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
    self.videoOutput.alwaysDiscardsLateVideoFrames = YES;
    [self.videoOutput setSampleBufferDelegate:self queue:self.captureQueue];

    if ([self.session canAddOutput:self.videoOutput]) {
        [self.session addOutput:self.videoOutput];
    } else {
        [self.session commitConfiguration];
        agLogStep("8_CAN_NOT_ADD_OUTPUT");
        writeHelperStatusWithToken(@"FAILED", @"Session 无法添加视频帧 Output", self.sessionToken);
        return;
    }

    AVCaptureConnection *conn = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];
    if (conn) {
        if (conn.isVideoOrientationSupported) {
            conn.videoOrientation = AVCaptureVideoOrientationPortrait;
        }
        if (pos == AVCaptureDevicePositionFront && conn.isVideoMirroringSupported) {
            conn.automaticallyAdjustsVideoMirroring = NO;
            conn.videoMirrored = YES;
        }
    }

    if (@available(iOS 16.0, *)) {
        if ([self.session respondsToSelector:@selector(isMultitaskingCameraAccessSupported)] && self.session.isMultitaskingCameraAccessSupported) {
            self.session.multitaskingCameraAccessEnabled = YES;
        }
    }

    agLogStep("9_COMMIT_CONFIG");
    [self.session commitConfiguration];

    agLogStep("10_START_RUNNING");
    [self.session startRunning];

    // 物理传感器硬件加电通常需要 1.0 ~ 2.0 秒，给予充裕的 3.0 秒就绪时间
    for (int i = 0; i < 60; i++) {
        if (self.session.isRunning) break;
        usleep(50000);
    }

    if (self.session.isRunning) {
        agLogStep("11_RUNNING_SUCCESS");
        writeHelperStatusWithToken(@"CAMERA_RUNNING", @"硬件 Session 已启动，等待首帧画面...", self.sessionToken);
    } else {
        agLogStep("11_RUNNING_WAITING_FRAMES");
        // 关键防护：不要过早声明 FAILED，让底层驱动平滑输出首帧
    }
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (self.isStopping) return;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - self.lastWriteTime < 0.18) return; // ~5.5 fps 实时写入
    self.lastWriteTime = now;

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!imageBuffer) return;

    agLogStep("13_CAPTURE_FRAME_READY");

    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);

    CGImageRef cgImg = NULL;
    if (baseAddress && width > 0 && height > 0) {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef cgContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        if (cgContext) {
            cgImg = CGBitmapContextCreateImage(cgContext);
            CGContextRelease(cgContext);
        }
        CGColorSpaceRelease(colorSpace);
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

    // 如果需要兜底 CIContext，必须强制开启软件 CPU 渲染 kCIContextUseSoftwareRenderer: @YES
    if (!cgImg) {
        static CIContext *swContext = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            swContext = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @YES}];
        });
        CIImage *ciImage = [CIImage imageWithCVPixelBuffer:imageBuffer];
        if (ciImage) {
            cgImg = [swContext createCGImage:ciImage fromRect:ciImage.extent];
        }
    }

    if (cgImg) {
        agLogStep("14_FRAME_CONVERTED_SUCCESS");
        BOOL ok = agWriteCGImageAsJPEG(cgImg, 0.60, agSharedFrameFilePath());
        CGImageRelease(cgImg);
        if (ok) {
            self.capturedFrameCount++;
            if (self.capturedFrameCount == 1) {
                agLogStep("15_FIRST_FRAME_STREAMING");
                writeHelperStatusWithToken(@"STREAMING", @"首帧画面捕获成功，进入实时流", self.sessionToken);
            } else if (self.capturedFrameCount % 20 == 0) {
                writeHelperStatusWithToken(@"STREAMING", [NSString stringWithFormat:@"实时画面流正常 (#%lu)", (unsigned long)self.capturedFrameCount], self.sessionToken);
            }
        }
    }
}

- (void)stop {
    self.isStopping = YES;
    if (self.heartbeatTimer) {
        [self.heartbeatTimer invalidate];
        self.heartbeatTimer = nil;
    }
    dispatch_sync(self.sessionQueue, ^{
        if (self.videoOutput) {
            [self.videoOutput setSampleBufferDelegate:nil queue:NULL];
        }
        if (self.session) {
            [[NSNotificationCenter defaultCenter] removeObserver:self];
            if (self.session.isRunning) {
                [self.session stopRunning];
            }
        }
    });
}

@end

int main(int argc, char *argv[]) {
    setupCrashHandlers();
    agLogStep("1_MAIN_START");

    @autoreleasepool {
        AVCaptureDevicePosition pos = AVCaptureDevicePositionBack;
        if (argc > 1 && strcmp(argv[1], "front") == 0) {
            pos = AVCaptureDevicePositionFront;
        }
        NSString *token = (argc > 2) ? [NSString stringWithUTF8String:argv[2]] : @"";
        NSString *stopFlag = agSharedStopFlagPath();
        NSString *frameFile = agSharedFrameFilePath();
        NSString *statusFile = agSharedStatusFilePath();

        agLogStep("2_CLEAN_OLD_FILES");
        [[NSFileManager defaultManager] removeItemAtPath:stopFlag error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:frameFile error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:statusFile error:nil];

        agLogStep("3_ALLOC_GRABBER");
        AngelCamGrabber *grabber = [[AngelCamGrabber alloc] initWithToken:token];

        grabber.heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:grabber selector:@selector(onHeartbeat:) userInfo:nil repeats:YES];

        // 核心突破：将相机 Session 配置与 startRunning 异步放入专用队列执行，确保主线程 RunLoop 立即无阻启动，绝不发生死锁挂起
        dispatch_async(grabber.sessionQueue, ^{
            [grabber startWithPosition:pos];
        });

        agLogStep("12_RUNLOOP_ENTER");
        while (!grabber.isStopping && ![[NSFileManager defaultManager] fileExistsAtPath:stopFlag]) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }

        agLogStep("16_GRABBER_STOP");
        [grabber stop];
        [[NSFileManager defaultManager] removeItemAtPath:frameFile error:nil];
        [[NSFileManager defaultManager] removeItemAtPath:stopFlag error:nil];
        writeHelperStatusWithToken(@"STOPPED", @"摄像头已正常关闭", token);
    }
    agLogStep("17_MAIN_EXIT");
    return 0;
}
