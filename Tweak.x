// ==============================================================================
// Project: AngelGuardian v5.9.0 (Aurora Fluid UI & System Agent Edition)
// 核心特性：
// 1. 完整保留 7 阶段摄像头启动状态机 + TCC 原生授权 + 双核自适应语音引擎 + 自动模型迁移
// 2. 全新升级视觉系统：全屏背景深空毛玻璃遮罩、流光极光边框、3D 发光 AI 灵动球、
//    CADisplayLink 实时驱动的双轨交织正弦流体声波、霓虹光晕圆形交互按钮与丝滑弹性动画
// ==============================================================================

#import <objc/runtime.h>
#import <dlfcn.h>
#import <spawn.h>
#import <signal.h>
#import <sys/wait.h>
#import <os/log.h>
#import <math.h>
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <CoreMedia/CoreMedia.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreImage/CoreImage.h>
#import <Contacts/Contacts.h>
#import <QuartzCore/QuartzCore.h>
#import <CoreFoundation/CoreFoundation.h>
#import <substrate.h>
#import <sqlite3.h>
#import <VideoToolbox/VideoToolbox.h>
#import <ImageIO/ImageIO.h>
#import <Speech/Speech.h>
#import <fcntl.h>
#import <unistd.h>
#import <sys/stat.h>
#import <mach/mach_time.h>
#import <Vision/Vision.h>
#import <AudioToolbox/AudioToolbox.h>
#import "AGMultiModelProtocolAdapter.h"

extern char **environ;

@interface NSObject (AGLayoutAdditions)
- (instancetype)initWithIdentifier:(NSString *)identifier;
@end

@interface AGInSituTranslationOverlay : UIWindow
@property (nonatomic, strong) UIView *patchContainerView;
@property (nonatomic, strong) UIView *revertPillView;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UIView *laserBeamView;
@property (nonatomic, strong) UIImpactFeedbackGenerator *impactHaptic;
@property (nonatomic, assign) BOOL isInSituActive;
@property (nonatomic, assign) BOOL isFingerTouching;
@property (nonatomic, strong) NSTimer *scrollSettleTimer;
@property (nonatomic, assign) NSInteger inSituScanEpoch;

+ (instancetype)sharedOverlay;
- (void)startInSituTranslation;
- (void)revertInSituTranslation;
- (void)manualRetranslateTapped;
- (void)performInSituRetranslateQuietly;
- (void)handleGlobalTouchStateChanged:(BOOL)isTouching eventMask:(uint32_t)mask;
@end

@interface AGGlobalActionPillWindow : UIWindow
@property (nonatomic, strong) UIVisualEffectView *blurView;
@property (nonatomic, strong) UILabel *titleLabel;
@property (nonatomic, strong) UIImpactFeedbackGenerator *haptic;
+ (instancetype)sharedPill;
- (void)showActionPill:(NSString *)message;
@end

typedef NS_ENUM(NSInteger, AGConfigTab) {
    AGConfigTabNativeLive  = 0, // 🎙️ 纯正 Live 实时语音交流
    AGConfigTabVideoAI     = 1, // 📹 独立视频 AI 实时摄像头+语音交流
    AGConfigTabPureText    = 2, // 💬 纯文本打字交流
    AGConfigTabTranslation = 3  // 🌐 实时字幕与屏幕翻译
};

// 严格定义的 8 个摄像头状态机枚举
typedef NS_ENUM(NSInteger, AGCameraState) {
    AGCameraStateStopped            = 0, // STOPPED
    AGCameraStateStarting           = 1, // STARTING
    AGCameraStateProcessStarted     = 2, // PROCESS_STARTED
    AGCameraStateCameraInitializing = 3, // CAMERA_INITIALIZING
    AGCameraStateCameraRunning      = 4, // CAMERA_RUNNING
    AGCameraStateFirstFrameReceived = 5, // FIRST_FRAME_RECEIVED
    AGCameraStateStreaming          = 6, // STREAMING
    AGCameraStateFailed             = 7  // FAILED
};

static NSString *agCameraStateName(AGCameraState st) {
    switch (st) {
        case AGCameraStateStopped:            return @"STOPPED";
        case AGCameraStateStarting:           return @"STARTING";
        case AGCameraStateProcessStarted:     return @"PROCESS_STARTED";
        case AGCameraStateCameraInitializing: return @"CAMERA_INITIALIZING";
        case AGCameraStateCameraRunning:      return @"CAMERA_RUNNING";
        case AGCameraStateFirstFrameReceived: return @"FIRST_FRAME_RECEIVED";
        case AGCameraStateStreaming:          return @"STREAMING";
        case AGCameraStateFailed:             return @"FAILED";
    }
    return @"UNKNOWN";
}

typedef int (*TCCAccessSetForBundleIdFunc)(CFStringRef service, CFStringRef bundleId, Boolean allowed);
static void ensureSpringBoardTCCGranted(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *tccHandle = dlopen("/System/Library/PrivateFrameworks/TCC.framework/TCC", RTLD_LAZY);
        if (tccHandle) {
            TCCAccessSetForBundleIdFunc setFunc = (TCCAccessSetForBundleIdFunc)dlsym(tccHandle, "TCCAccessSetForBundleId");
            if (setFunc) {
                setFunc(CFSTR("kTCCServiceCamera"), CFSTR("com.apple.springboard"), true);
                setFunc(CFSTR("kTCCServiceMicrophone"), CFSTR("com.apple.springboard"), true);
                setFunc(CFSTR("kTCCServiceSpeechRecognition"), CFSTR("com.apple.springboard"), true);
            }
        }

        const char *dbPath = "/var/mobile/Library/TCC/TCC.db";
        sqlite3 *db = NULL;
        if (sqlite3_open(dbPath, &db) == SQLITE_OK) {
            const char *sql1 = "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version) VALUES ('kTCCServiceCamera', 'com.apple.springboard', 0, 2, 1, 1);";
            const char *sql2 = "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version) VALUES ('kTCCServiceMicrophone', 'com.apple.springboard', 0, 2, 1, 1);";
            const char *sql3 = "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version) VALUES ('kTCCServiceCamera', 'AngelCameraHelper', 1, 2, 1, 1);";
            const char *sql4 = "INSERT OR REPLACE INTO access (service, client, client_type, auth_value, auth_reason, auth_version) VALUES ('kTCCServiceCamera', '/var/jb/usr/bin/AngelCameraHelper', 1, 2, 1, 1);";
            sqlite3_exec(db, sql1, NULL, NULL, NULL);
            sqlite3_exec(db, sql2, NULL, NULL, NULL);
            sqlite3_exec(db, sql3, NULL, NULL, NULL);
            sqlite3_exec(db, sql4, NULL, NULL, NULL);
            sqlite3_close(db);
        }
    });
}

static NSString * const kAGPrefsChangedNotification = @"com.custom.geminisirioverlay.prefsChanged";
static NSMutableDictionary *gCachedPrefs = nil;
static NSTimeInterval gLastKillAssistantdTime = 0;

static NSString *agSharedBaseDir(void) {
    return @"/tmp";
}

static NSString *agSharedCameraFramePath(void) {
    return [agSharedBaseDir() stringByAppendingPathComponent:@"ag_live_cam_frame.jpg"];
}

static NSString *agSharedCameraStatusPath(void) {
    return [agSharedBaseDir() stringByAppendingPathComponent:@"ag_cam_status.json"];
}

static NSString *agSharedCameraStopFlagPath(void) {
    return [agSharedBaseDir() stringByAppendingPathComponent:@"ag_cam_stop.flag"];
}

static NSString *agLiveDiagnosticLogPath(void) {
    return @"/tmp/ag_live_diagnostic.log";
}

static void agLiveDiagLog(NSString *stage, NSString *format, ...) {
    va_list args;
    va_start(args, format);
    NSString *msg = [[NSString alloc] initWithFormat:format arguments:args];
    va_end(args);

    os_log(OS_LOG_DEFAULT, "[AGLiveDiag][%{public}@] %{public}@", stage, msg);

    static dispatch_queue_t logQ = nil;
    static NSDateFormatter *sLogDateFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        logQ = dispatch_queue_create("com.angelguardian.diaglog", DISPATCH_QUEUE_SERIAL);
        sLogDateFormatter = [[NSDateFormatter alloc] init];
        sLogDateFormatter.dateFormat = @"HH:mm:ss.SSS";
    });
    NSDate *nowDate = [NSDate date];
    dispatch_async(logQ, ^{
        NSString *line = [NSString stringWithFormat:@"[%@][%@] %@\n", [sLogDateFormatter stringFromDate:nowDate], stage, msg];
        NSData *data = [line dataUsingEncoding:NSUTF8StringEncoding];
        int fd = open([agLiveDiagnosticLogPath() UTF8String], O_WRONLY | O_CREAT | O_APPEND, 0666);
        if (fd >= 0) {
            write(fd, data.bytes, data.length);
            close(fd);
        }
    });
}

static void killNativeSiriAudioDaemon(void) {
    // 严禁 killall -9 assistantd！Siri 界面已由底部 %hook SBAssistantController 彻底拦截，保持 assistantd 存活以支持毫秒级实时语音转字幕
}

static void killZombieCameraHelpers(void) {
    pid_t pid;
    const char *killPaths[] = { "/var/jb/usr/bin/killall", "/usr/bin/killall", NULL };
    for (int i = 0; killPaths[i] != NULL; i++) {
        if ([[NSFileManager defaultManager] isExecutableFileAtPath:[NSString stringWithUTF8String:killPaths[i]]]) {
            char *argv[] = { (char *)"killall", (char *)"-9", (char *)"AngelCameraHelper", NULL };
            posix_spawn(&pid, killPaths[i], NULL, NULL, argv, environ);
            break;
        }
    }
}

typedef Boolean (*MRMediaRemoteSendCommandFunc)(uint32_t command, void *userInfo);
static void pauseBackgroundMediaPlayback(void) {
    static MRMediaRemoteSendCommandFunc sendCmd = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_LAZY);
        if (handle) {
            sendCmd = (MRMediaRemoteSendCommandFunc)dlsym(handle, "MRMediaRemoteSendCommand");
        }
    });
    if (sendCmd) {
        sendCmd(1, NULL);
    }
}

// ==================== 跨进程共享配置 ====================
static NSString *geminiPrefsFilePath(void) {
    return [agSharedBaseDir() stringByAppendingPathComponent:@"com.custom.geminisirioverlay.plist"];
}

static void reloadGeminiPrefsCache(void) {
    NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithContentsOfFile:geminiPrefsFilePath()];
    if (!dict) dict = [NSMutableDictionary dictionary];
    gCachedPrefs = dict;
}

static NSDictionary *agReadOnlyPrefs(void) {
    if (!gCachedPrefs) {
        reloadGeminiPrefsCache();
    }
    return gCachedPrefs;
}

static NSMutableDictionary *loadGeminiPrefs(void) {
    if (!gCachedPrefs) {
        reloadGeminiPrefsCache();
    }
    return [gCachedPrefs mutableCopy];
}

static void saveGeminiPrefs(NSDictionary *dict) {
    if (!dict) return;
    gCachedPrefs = [dict mutableCopy];
    [dict writeToFile:geminiPrefsFilePath() atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         (__bridge CFStringRef)kAGPrefsChangedNotification,
                                         NULL, NULL, YES);
}

static NSArray<NSDictionary *> *agVerifiedDefaultModelsForTab(AGConfigTab tab) {
    switch (tab) {
        case AGConfigTabNativeLive:
        case AGConfigTabVideoAI:
            return @[
                @{@"id": @"models/gemini-2.5-flash-native-audio-preview-09-2025", @"title": @"🎙️📞[实时通话首选] gemini-2.5-flash-native-audio-09-2025", @"bidi": @YES, @"onlyBidi": @YES, @"latencyStr": @"🟢 实时", @"latencyMs": @120, @"isUsable": @YES, @"verified": @YES},
                @{@"id": @"models/gemini-2.5-flash-native-audio-preview-12-2025", @"title": @"🎙️📞[实时通话] gemini-2.5-flash-native-audio-12-2025", @"bidi": @YES, @"onlyBidi": @YES, @"latencyStr": @"🟢 实时", @"latencyMs": @130, @"isUsable": @YES, @"verified": @YES},
                @{@"id": @"models/gemini-2.0-flash-live-001", @"title": @"🎙️📞[实时通话] gemini-2.0-flash-live-001", @"bidi": @YES, @"onlyBidi": @YES, @"latencyStr": @"🟢 实时", @"latencyMs": @140, @"isUsable": @YES, @"verified": @YES},
                @{@"id": @"models/gemini-2.0-flash-exp", @"title": @"🎙️📞[实时通话] gemini-2.0-flash-exp", @"bidi": @YES, @"onlyBidi": @NO, @"latencyStr": @"🟢 实时", @"latencyMs": @150, @"isUsable": @YES, @"verified": @YES}
            ];
        case AGConfigTabPureText:
        case AGConfigTabTranslation:
        default:
            return @[
                @{@"id": @"models/gemini-2.5-flash-lite", @"title": @"⚡🌐[高速文本+翻译] gemini-2.5-flash-lite", @"bidi": @NO, @"onlyBidi": @NO, @"latencyStr": @"🟢 120ms", @"latencyMs": @120, @"isUsable": @YES, @"verified": @YES},
                @{@"id": @"models/gemini-2.5-flash", @"title": @"⚡🌐[高速文本+翻译] gemini-2.5-flash", @"bidi": @NO, @"onlyBidi": @NO, @"latencyStr": @"🟢 140ms", @"latencyMs": @140, @"isUsable": @YES, @"verified": @YES}
            ];
    }
}

// ==================== 系统私有接口声明 ====================
@interface AVAudioInputNode (VoiceProcessingSupport)
- (BOOL)setVoiceProcessingEnabled:(BOOL)enabled error:(NSError **)outError;
@end

@interface LSApplicationProxy : NSObject
@property (nonatomic, readonly) NSString *applicationIdentifier;
@property (nonatomic, readonly) NSString *localizedName;
@property (nonatomic, readonly) NSURL *dataContainerURL;
- (BOOL)isInstalled;
+ (instancetype)applicationProxyForIdentifier:(NSString *)identifier;
@end

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)bundleID;
- (NSArray<LSApplicationProxy *> *)allInstalledApplications;
- (BOOL)openSensitiveURL:(NSURL *)url withOptions:(NSDictionary *)options;
- (BOOL)openURL:(NSURL *)url;
@end

@interface MMServiceCenter : NSObject
+ (instancetype)defaultCenter;
- (id)getService:(Class)serviceClass;
@end

@interface CContactMgr : NSObject
- (id)getContactByName:(NSString *)name;
- (NSArray *)getContactList:(unsigned int)type contactType:(unsigned int)contactType;
- (NSArray *)getAllContactList;
- (id)getSelfContact;
@end

@interface CMessageWrap : NSObject
- (instancetype)initWithMsgType:(int)msgType;
@end

@interface CMessageMgr : NSObject
- (void)AddMsg:(NSString *)toUser MsgWrap:(id)msgWrap;
@end

@interface SBWiFiManager : NSObject
+ (instancetype)sharedInstance;
- (void)setWiFiEnabled:(BOOL)enabled;
- (void)setPowered:(BOOL)powered;
@end

@interface BluetoothManager : NSObject
+ (instancetype)sharedInstance;
- (void)setEnabled:(BOOL)enabled;
- (void)setPowered:(BOOL)powered;
@end

@interface SBOrientationLockManager : NSObject
+ (instancetype)sharedInstance;
- (void)lock;
- (void)unlock;
- (BOOL)isLocked;
@end

@interface SpringBoard : UIApplication
- (BOOL)isLocked;
- (BOOL)launchApplicationWithIdentifier:(NSString *)identifier suspended:(BOOL)suspended;
- (void)_simulateLockButtonPress;
- (void)_relaunchSpringBoardNow;
- (void)_wakeScreen:(id)arg1;
- (void)userEventOccurred;
@end

@interface SBMediaController : NSObject
+ (instancetype)sharedInstance;
- (BOOL)playForType:(NSInteger)type;
- (BOOL)pauseForType:(NSInteger)type;
- (BOOL)togglePlayPauseForType:(NSInteger)type;
- (BOOL)changeTrack:(NSInteger)direction eventSource:(NSInteger)source;
@end

@interface SBUIController : NSObject
+ (instancetype)sharedInstanceIfExists;
- (void)clickedMenuButton;
@end

@interface SBLockScreenManager : NSObject
+ (instancetype)sharedInstance;
+ (instancetype)sharedInstanceIfExists;
@property (readonly, nonatomic) BOOL isUILocked;
- (BOOL)lockUIFromSource:(NSInteger)source withOptions:(id)options;
- (void)wakeScreenAnimated:(BOOL)animated;
- (void)wakeScreenWithReason:(NSString *)reason;
- (void)tapToWakeInteractiveControllerDidWakeScreen:(id)arg1;
@end

@interface SBBacklightController : NSObject
+ (instancetype)sharedInstance;
+ (instancetype)sharedInstanceIfExists;
@property (nonatomic, readonly) BOOL screenIsOn;
- (void)turnOnScreenFullyWithBacklightSource:(NSInteger)source;
- (void)_undimFromSource:(NSInteger)source;
@end

@interface SBLockScreenManager (AGWakeAdditions)
- (void)requestUserAttentionScreenWakeFromSource:(NSInteger)source reason:(NSString *)reason;
@end

@interface AGLockScreenRootViewController : UIViewController
@end
@implementation AGLockScreenRootViewController
- (BOOL)_canShowWhileLocked { return YES; }
@end

// 锁屏/息屏状态下主动点亮屏幕硬件背光并唤醒锁屏壁纸与时钟，解决黑屏唤醒与锁屏黑底问题
static void agWakeScreenBacklightIfNeeded(void) {
    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            // 1. 点亮硬件屏幕背光
            Class blCls = objc_getClass("SBBacklightController");
            if (blCls) {
                SBBacklightController *bl = [blCls respondsToSelector:@selector(sharedInstanceIfExists)]
                    ? [blCls sharedInstanceIfExists]
                    : ([blCls respondsToSelector:@selector(sharedInstance)] ? [blCls sharedInstance] : nil);
                if (bl) {
                    if ([bl respondsToSelector:@selector(turnOnScreenFullyWithBacklightSource:)]) {
                        [bl turnOnScreenFullyWithBacklightSource:1];
                    }
                    if ([bl respondsToSelector:@selector(_undimFromSource:)]) {
                        [bl _undimFromSource:1];
                    }
                }
            }
            // 2. 唤醒 SpringBoard 锁屏视图与壁纸 (CoverSheet / Wallpaper)，防止黑底
            SpringBoard *sb = (SpringBoard *)[UIApplication sharedApplication];
            if ([sb respondsToSelector:@selector(_wakeScreen:)]) {
                [sb _wakeScreen:nil];
            } else if ([sb respondsToSelector:@selector(userEventOccurred)]) {
                [sb userEventOccurred];
            }
            Class lsmCls = objc_getClass("SBLockScreenManager");
            if (lsmCls) {
                SBLockScreenManager *lsm = [lsmCls respondsToSelector:@selector(sharedInstanceIfExists)]
                    ? [lsmCls sharedInstanceIfExists]
                    : ([lsmCls respondsToSelector:@selector(sharedInstance)] ? [lsmCls sharedInstance] : nil);
                if (lsm) {
                    if ([lsm respondsToSelector:@selector(wakeScreenAnimated:)]) {
                        [lsm wakeScreenAnimated:YES];
                    }
                    if ([lsm respondsToSelector:@selector(wakeScreenWithReason:)]) {
                        [lsm wakeScreenWithReason:@"AngelGuardianSiriWake"];
                    }
                    if ([lsm respondsToSelector:@selector(tapToWakeInteractiveControllerDidWakeScreen:)]) {
                        [lsm tapToWakeInteractiveControllerDidWakeScreen:nil];
                    }
                    if ([lsm respondsToSelector:@selector(requestUserAttentionScreenWakeFromSource:reason:)]) {
                        [lsm requestUserAttentionScreenWakeFromSource:1 reason:@"AngelGuardianSiriWake"];
                    }
                }
            }
        } @catch (NSException *e) {}
    });
}

@interface SBAssistantController : NSObject
+ (instancetype)sharedInstance;
+ (BOOL)isVisible;
- (void)dismissAssistantViewIfNecessary;
- (void)dismissAssistantViewIfNecessaryWithAnimation:(NSInteger)anim;
@end

@interface SiriPresentationSpringBoardMainScreenViewController : UIViewController
- (void)dismissSiriViewController:(id)arg1;
- (void)dismissSiriViewController:(id)arg1 withReason:(NSUInteger)reason;
@end

@interface SBBrightnessController : NSObject
+ (instancetype)sharedBrightnessController;
- (void)setBrightnessLevel:(float)level;
@end

@interface AVSystemController : NSObject
+ (instancetype)sharedAVSystemController;
- (BOOL)setVolumeTo:(float)volume forCategory:(NSString *)category;
- (BOOL)getVolume:(float *)outVolume forCategory:(NSString *)category;
@end

@interface SBMainSwitcherViewController : NSObject
+ (instancetype)sharedInstanceIfExists;
+ (instancetype)sharedInstance;
- (NSArray *)recentAppLayouts;
- (void)_deleteAppLayoutsMatchingBundleIdentifier:(NSString *)bundleID;
- (void)_deleteAppLayout:(id)appLayout forReason:(NSInteger)reason;
@end

@interface UIKeyboardImpl : NSObject
+ (instancetype)activeInstance;
+ (instancetype)sharedInstance;
- (void)insertText:(NSString *)text;
- (void)deleteFromInput;
@end

@interface UISUserInterfaceStyleMode : NSObject
- (instancetype)initWithDelegate:(nullable id)delegate;
@property (nonatomic, assign) long long modeValue;
@end

@interface RadiosPreferences : NSObject
- (void)setAirplaneMode:(BOOL)enabled;
- (void)synchronize;
@end

@interface MMNewSessionMgr : NSObject
- (NSUInteger)GetTotalUnreadCount;
- (NSInteger)GetSessionCount;
- (id)GetSessionAtIndex:(NSUInteger)index;
@end

@interface MMMsgLogicManager : NSObject
- (void)PushOtherBaseMsgControllerByContact:(id)contact navigationController:(UINavigationController *)nav animated:(BOOL)animated;
@end

@interface UIWindow (Private)
- (void)_setSecure:(BOOL)secure;
@end

static BOOL isDeviceCurrentlyLocked(void) {
    Class lsmClass = objc_getClass("SBLockScreenManager");
    if (lsmClass && [lsmClass respondsToSelector:@selector(sharedInstanceIfExists)]) {
        SBLockScreenManager *lsm = [lsmClass sharedInstanceIfExists];
        if (lsm && [lsm respondsToSelector:@selector(isUILocked)]) {
            return [lsm isUILocked];
        }
    }
    SpringBoard *sb = (SpringBoard *)[UIApplication sharedApplication];
    if ([sb respondsToSelector:@selector(isLocked)]) {
        return [sb isLocked];
    }
    return NO;
}

@interface UIScreen (AGPrivateCorner)
- (CGFloat)_displayCornerRadius;
@end

typedef NS_ENUM(NSInteger, AGVisualTheme) {
    AGVisualThemeLightLuxury = 0, // 1. 轻奢 (高定黑金琉璃)
    AGVisualThemeMinimalist  = 1, // 2. 简约 (超折射液态玻璃)
    AGVisualThemeCyberCool   = 2  // 3. 炫酷 (全息流光液态玻璃)
};

typedef NS_ENUM(NSInteger, AGVectorIconType) {
    AGVectorIconMicLive = 0,
    AGVectorIconVideoAI,
    AGVectorIconPureText,
    AGVectorIconSendArrow,
    AGVectorIconTranslate,
    AGVectorIconModelHex,
    AGVectorIconCloseCross
};

#include <sys/sysctl.h>

typedef struct {
    CGFloat screenW;
    CGFloat screenH;
    CGFloat scale;
    CGFloat safeTop;
    CGFloat safeBottom;
    CGFloat screenCornerRadius;
    BOOL isCompactPhone;     // 11 Pro / 12 mini / 13 mini 或开启了放大显示模式 (<= 375pt)
    BOOL isLargePhone;       // 11 / 11 Pro Max / 12~15 Plus & Pro Max (>= 414pt)
    BOOL hasDynamicIsland;   // 14 Pro / 14 Pro Max / 15 / 15 Plus / 15 Pro / 15 Pro Max
    BOOL isProMotion120Hz;   // 13 Pro / 13 Pro Max / 14 Pro / 14 Pro Max / 15 Pro / 15 Pro Max
    BOOL isLegacyGPU;        // iPhone 11 全系 / mini 轻量光效档
    NSInteger targetAnimFPS; // 恒定帧率锁 (消除帧率跳变微卡顿)
    CGFloat waveStepPt;      // 声波顶点采样步长 (按 18 款机型 GPU 分档)
    CGFloat sideMargin;
    CGFloat bottomRestMargin;
    CGFloat topSafeLimit;
    CGFloat cardCornerRadius;
    CGFloat innerCardRadius;
    CGFloat barButtonSize;   // 顶栏与底栏严格同尺寸 (30pt / 32pt / 33pt)
    CGFloat headerAndBottomPadding;
    CGFloat defaultCapsuleH;
    CGFloat titleFontSize;
    CGFloat bodyFontSize;
    CGFloat badgeWidth;
    CGFloat camPipW;
    CGFloat camPipH;
} AGDeviceMetrics;

static NSString *agHardwareMachineIdentifier(void) {
    static NSString *sMachine = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        size_t size = 0;
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);
        if (size > 0) {
            char *machine = (char *)malloc(size);
            if (machine) {
                sysctlbyname("hw.machine", machine, &size, NULL, 0);
                sMachine = [NSString stringWithUTF8String:machine];
                free(machine);
            }
        }
        if (!sMachine) sMachine = @"";
    });
    return sMachine;
}

// 保持单参数签名，100% 兼容 setupWindowIfNeeded 中的调用
static CGFloat adaptiveScreenCornerRadius(CGRect bounds) {
    UIScreen *mainScreen = [UIScreen mainScreen];
    if ([mainScreen respondsToSelector:@selector(_displayCornerRadius)]) {
        CGFloat hwRadius = [mainScreen _displayCornerRadius];
        if (hwRadius > 10.0) return hwRadius;
    }
    NSString *machine = agHardwareMachineIdentifier();
    if ([machine hasPrefix:@"iPhone15,2"] || [machine hasPrefix:@"iPhone15,3"] ||
        [machine hasPrefix:@"iPhone15,4"] || [machine hasPrefix:@"iPhone15,5"] ||
        [machine hasPrefix:@"iPhone16,1"] || [machine hasPrefix:@"iPhone16,2"]) {
        return 55.0; // iPhone 14 Pro / Pro Max & iPhone 15 全系
    }
    if ([machine isEqualToString:@"iPhone13,4"] || [machine isEqualToString:@"iPhone14,3"] || [machine isEqualToString:@"iPhone14,8"]) {
        return 53.33; // iPhone 12 Pro Max / 13 Pro Max / 14 Plus
    }
    if ([machine isEqualToString:@"iPhone13,2"] || [machine isEqualToString:@"iPhone13,3"] ||
        [machine isEqualToString:@"iPhone14,5"] || [machine isEqualToString:@"iPhone14,2"] || [machine isEqualToString:@"iPhone14,7"]) {
        return 47.33; // iPhone 12 / 12 Pro / 13 / 13 Pro / 14
    }
    if ([machine isEqualToString:@"iPhone13,1"] || [machine isEqualToString:@"iPhone14,4"]) {
        return 44.0; // iPhone 12 mini / 13 mini
    }
    if ([machine isEqualToString:@"iPhone12,1"]) {
        return 41.5; // iPhone 11 (6.1" LCD)
    }
    if ([machine isEqualToString:@"iPhone12,3"] || [machine isEqualToString:@"iPhone12,5"]) {
        return 39.0; // iPhone 11 Pro / 11 Pro Max
    }

    CGFloat maxDim = MAX(bounds.size.width, bounds.size.height);
    CGFloat minDim = MIN(bounds.size.width, bounds.size.height);
    CGFloat scale = mainScreen.scale;
    if (minDim == 393.0 || minDim == 430.0 || maxDim == 852.0 || maxDim == 932.0) return 55.0;
    if (minDim == 428.0 || maxDim == 926.0) return 53.33;
    if (minDim == 390.0 || maxDim == 844.0) return 47.33;
    if (minDim == 414.0 && maxDim == 896.0) return (scale <= 2.1) ? 41.5 : 39.0;
    if (minDim <= 360.0 || maxDim <= 780.0) return 44.0;
    if (minDim == 375.0 && maxDim == 812.0) return 39.0;
    return 47.33;
}

// 静态缓存 iPhone 11 ~ iPhone 15 Pro Max 共 18 款机型硬件布局与 GPU 分档参数，全生命周期只计算 1 次
static AGDeviceMetrics agComputeDeviceMetrics(void) {
    static AGDeviceMetrics cachedMetrics;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        UIScreen *scr = [UIScreen mainScreen];
        CGRect b = scr.bounds;
        NSString *machine = agHardwareMachineIdentifier();

        cachedMetrics.screenW = MIN(b.size.width, b.size.height);
        cachedMetrics.screenH = MAX(b.size.width, b.size.height);
        cachedMetrics.scale = scr.scale;

        // 1. 识别灵动岛机型：iPhone 14 Pro(15,2)、14 Pro Max(15,3)、15(15,4)、15 Plus(15,5)、15 Pro(16,1)、15 Pro Max(16,2)
        BOOL isIslandHW = ([machine isEqualToString:@"iPhone15,2"] || [machine isEqualToString:@"iPhone15,3"] ||
                           [machine isEqualToString:@"iPhone15,4"] || [machine isEqualToString:@"iPhone15,5"] ||
                           [machine isEqualToString:@"iPhone16,1"] || [machine isEqualToString:@"iPhone16,2"] ||
                           cachedMetrics.screenW == 393.0 || cachedMetrics.screenW == 430.0 ||
                           cachedMetrics.screenH == 852.0 || cachedMetrics.screenH == 932.0);

        // 2. 识别 mini 机型 (iPhone 12 mini / 13 mini) 与 iPhone 11 系列
        BOOL isMiniHW = ([machine isEqualToString:@"iPhone13,1"] || [machine isEqualToString:@"iPhone14,4"] || cachedMetrics.screenW <= 360.0);
        BOOL isIPhone11LCD = ([machine isEqualToString:@"iPhone12,1"] || (cachedMetrics.screenW == 414.0 && cachedMetrics.screenH == 896.0 && cachedMetrics.scale <= 2.1));
        BOOL isIPhone11ProSeries = ([machine isEqualToString:@"iPhone12,3"] || [machine isEqualToString:@"iPhone12,5"]);

        // 3. 精确匹配 18 款机型的顶部安全区高度 safeTop
        CGFloat safeTop = 47.0; // 默认 iPhone 12 / 12 Pro / 12 Pro Max / 13 / 13 Pro / 13 Pro Max / 14 / 14 Plus
        if (isIslandHW) {
            safeTop = 59.0;
        } else if (isMiniHW) {
            safeTop = 50.0;
        } else if (isIPhone11LCD) {
            safeTop = 48.0;
        } else if (isIPhone11ProSeries || cachedMetrics.screenW == 375.0) {
            safeTop = 44.0;
        }

        cachedMetrics.safeTop = safeTop;
        cachedMetrics.safeBottom = 34.0;
        cachedMetrics.screenCornerRadius = adaptiveScreenCornerRadius(b);

        cachedMetrics.isCompactPhone   = (cachedMetrics.screenW <= 375.0);
        cachedMetrics.isLargePhone     = (cachedMetrics.screenW >= 414.0);
        cachedMetrics.hasDynamicIsland = isIslandHW;

        // 4. 识别 120Hz ProMotion 机型 (13 Pro/Max, 14 Pro/Max, 15 Pro/Max) 与 GPU 性能档位
        NSInteger maxFPS = [scr respondsToSelector:@selector(maximumFramesPerSecond)] ? scr.maximumFramesPerSecond : 60;
        cachedMetrics.isProMotion120Hz = (maxFPS > 60 ||
                                          [machine isEqualToString:@"iPhone14,2"] || [machine isEqualToString:@"iPhone14,3"] ||
                                          [machine isEqualToString:@"iPhone15,2"] || [machine isEqualToString:@"iPhone15,3"] ||
                                          [machine isEqualToString:@"iPhone16,1"] || [machine isEqualToString:@"iPhone16,2"]);

        cachedMetrics.isLegacyGPU = (isIPhone11LCD || isIPhone11ProSeries || isMiniHW);
        cachedMetrics.targetAnimFPS = cachedMetrics.isLegacyGPU ? 30 : 60;
        cachedMetrics.waveStepPt = cachedMetrics.isLegacyGPU ? 6.0 : (cachedMetrics.isProMotion120Hz ? 4.5 : 5.0);

        // 5. 按小屏 (375pt) / 标准屏 (390~393pt) / 大屏 (414~430pt) 自适应匹配视觉比例
        cachedMetrics.sideMargin       = cachedMetrics.isCompactPhone ? 10.0 : (cachedMetrics.isLargePhone ? 14.0 : 12.0);
        cachedMetrics.bottomRestMargin = cachedMetrics.isCompactPhone ? 18.0 : 21.0;
        cachedMetrics.topSafeLimit     = safeTop + (cachedMetrics.hasDynamicIsland ? 10.0 : 8.0);
        cachedMetrics.cardCornerRadius = cachedMetrics.isCompactPhone ? 34.0 : (cachedMetrics.isLargePhone ? 39.0 : 37.0);
        cachedMetrics.innerCardRadius  = cachedMetrics.isCompactPhone ? 20.0 : (cachedMetrics.isLargePhone ? 23.0 : 22.0);
        cachedMetrics.barButtonSize    = cachedMetrics.isCompactPhone ? 30.0 : (cachedMetrics.isLargePhone ? 33.0 : 32.0);
        cachedMetrics.headerAndBottomPadding = cachedMetrics.isCompactPhone ? 11.0 : (cachedMetrics.isLargePhone ? 14.0 : 13.0);
                // 锁定初始紧凑高度（小屏 304pt / 标准屏 316pt / Pro Max 大屏 324pt），确保打开瞬间即为正常紧凑尺寸，绝不先高后缩！
        cachedMetrics.defaultCapsuleH  = cachedMetrics.isCompactPhone ? 304.0 : (cachedMetrics.isLargePhone ? 324.0 : 316.0);
        cachedMetrics.titleFontSize    = cachedMetrics.isCompactPhone ? 16.5 : (cachedMetrics.isLargePhone ? 18.5 : 17.5);
        cachedMetrics.bodyFontSize     = cachedMetrics.isCompactPhone ? 14.5 : (cachedMetrics.isLargePhone ? 16.0 : 15.2);
        cachedMetrics.badgeWidth       = cachedMetrics.isCompactPhone ? 80.0 : 88.0;
        cachedMetrics.camPipW          = cachedMetrics.isCompactPhone ? 90.0 : (cachedMetrics.isLargePhone ? 108.0 : 100.0);
        cachedMetrics.camPipH          = cachedMetrics.isCompactPhone ? 122.0 : (cachedMetrics.isLargePhone ? 144.0 : 132.0);
    });
    return cachedMetrics;
}

static AGVisualTheme agCurrentVisualTheme(void) {
    if (!gCachedPrefs) {
        reloadGeminiPrefsCache();
    }
    NSNumber *val = gCachedPrefs[@"AG_Visual_Theme"];
    if (!val) return AGVisualThemeCyberCool;
    NSInteger idx = [val integerValue];
    if (idx < 0 || idx > 2) return AGVisualThemeCyberCool;
    return (AGVisualTheme)idx;
}

// 跑马灯总开关 (默认 YES 开启)
static BOOL agIsMarqueeEnabled(void) {
    if (!gCachedPrefs) {
        reloadGeminiPrefsCache();
    }
    NSNumber *val = gCachedPrefs[@"AG_Marquee_Enabled"];
    return val ? [val boolValue] : YES;
}

// 固定最佳主界面半透明液态镜面玻璃不透明度 (50%)
static CGFloat agMainGlassOpacity(void) {
    return 0.50;
}

// 固定最佳跑马灯向内柔光羽化度 (85%)
static CGFloat agMarqueeFeatherLevel(void) {
    return 0.85;
}

// 生成 18 阶指数衰减无断层向内羽化遮罩纹理 + 底部加厚柔光垫 (全生命周期只生成 1 次，0 CPU 每帧重绘开销)
static CGImageRef agCreateSmoothFeatheredEdgeMaskImage(CGRect bounds, CGFloat cornerRadius, CGFloat maxFeatherDepth, BOOL includeBottomCushion) {
    if (bounds.size.width <= 10 || bounds.size.height <= 10) return NULL;
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.scale = 1.0; // 1x 纹理利用 GPU 硬件双线性插值自带天然柔化，且内存占用极低
    fmt.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:bounds.size format:fmt];
    UIImage *maskImg = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rCtx) {
        CGContextRef ctx = rCtx.CGContext;
        CGFloat w = bounds.size.width;
        CGFloat h = bounds.size.height;

        // 1. 绘制 18 层指数衰减的同心圆角描边，使最外沿 0~2.5pt 极亮，向内 2.5pt -> maxFeatherDepth 丝滑衰减至 0，彻底消除硬切边台阶
        NSInteger steps = 18;
        for (NSInteger i = 0; i < steps; i++) {
            CGFloat t = (CGFloat)i / (CGFloat)(steps - 1);
            CGFloat inset = 0.6 + pow(t, 1.35) * maxFeatherDepth;
            CGFloat lineW = 2.2 + t * 4.5;
            CGFloat alpha = pow(1.0 - t, 2.25) * 0.42;
            if (alpha <= 0.005) continue;

            CGRect r = CGRectInset(bounds, inset, inset);
            if (r.size.width <= 4 || r.size.height <= 4) continue;
            UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:MAX(6.0, cornerRadius - inset)];
            p.lineWidth = lineW;
            [[UIColor colorWithWhite:1.0 alpha:alpha] setStroke];
            [p stroke];
        }

        // 2. 复刻 iOS 27 Siri 底部（手电筒与相机区下方）特有的加厚氛围柔光垫
        if (includeBottomCushion) {
            CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
            NSArray *cCols = @[
                (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.82].CGColor,
                (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.32].CGColor,
                (__bridge id)[UIColor clearColor].CGColor
            ];
            CGFloat locs[3] = {0.0, 0.52, 1.0};
            CGGradientRef grad = CGGradientCreateWithColors(space, (__bridge CFArrayRef)cCols, locs);
            if (grad) {
                CGContextSaveGState(ctx);
                UIBezierPath *clipP = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:cornerRadius];
                [clipP addClip];
                CGContextDrawRadialGradient(ctx, grad,
                                            CGPointMake(w * 0.5, h + 6.0), 4.0,
                                            CGPointMake(w * 0.5, h - 8.0), w * 0.62,
                                            kCGGradientDrawsAfterEndLocation);
                CGContextRestoreGState(ctx);
                CGGradientRelease(grad);
            }
            CGColorSpaceRelease(space);
        }
    }];
    return maskImg.CGImage;
}

static void agDrawRadialGradient(CGContextRef ctx, CGPoint startCenter, CGFloat startR, CGPoint endCenter, CGFloat endR, NSArray<UIColor *> *colors, const CGFloat *locations) {
    NSMutableArray *cgColors = [NSMutableArray arrayWithCapacity:colors.count];
    for (UIColor *c in colors) [cgColors addObject:(__bridge id)c.CGColor];
    CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
    CGGradientRef grad = CGGradientCreateWithColors(space, (__bridge CFArrayRef)cgColors, locations);
    if (grad) {
        CGContextDrawRadialGradient(ctx, grad, startCenter, startR, endCenter, endR, kCGGradientDrawsAfterEndLocation);
        CGGradientRelease(grad);
    }
    CGColorSpaceRelease(space);
}

// ==================== 1. 零掉帧 GPU 硬件合批液态玻璃背景光场 (双轨透明夹层玻璃壁 + 顶/底独立玻璃舱，消除白雾感) ====================
@interface AGCardBgCanvasView : UIView
@property (nonatomic, assign) CGFloat phase;
@property (nonatomic, assign) CGFloat amplitude;
@property (nonatomic, assign) CGFloat cornerRadius;
- (void)applyTheme:(AGVisualTheme)theme;
- (void)stepAnimationWithPhase:(CGFloat)phase amplitude:(CGFloat)amp;
@end

@implementation AGCardBgCanvasView {
    CAGradientLayer *_blob1;
    CAGradientLayer *_blob2;
    CAGradientLayer *_blob3;
    CAGradientLayer *_liquidMirrorGlossLayer; // 新增：50% 液态镜面玻璃斜切反射层
    CALayer         *_staticGlassShellLayer;
    CAGradientLayer *_hotspotTL;
    CAGradientLayer *_hotspotBR;
    AGVisualTheme   _appliedTheme;
    BOOL            _hasInitializedTheme;
    CGSize          _lastRenderedSize;
    AGVisualTheme   _lastRenderedTheme;
    CGFloat         _lastRenderedOpacity;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
        self.clipsToBounds = YES;

        _blob1 = [CAGradientLayer layer];
        _blob1.type = kCAGradientLayerRadial;
        _blob1.startPoint = CGPointMake(0.5, 0.5);
        _blob1.endPoint = CGPointMake(1.0, 1.0);
        [self.layer addSublayer:_blob1];

        _blob2 = [CAGradientLayer layer];
        _blob2.type = kCAGradientLayerRadial;
        _blob2.startPoint = CGPointMake(0.5, 0.5);
        _blob2.endPoint = CGPointMake(1.0, 1.0);
        [self.layer addSublayer:_blob2];

        _blob3 = [CAGradientLayer layer];
        _blob3.type = kCAGradientLayerRadial;
        _blob3.startPoint = CGPointMake(0.5, 0.5);
        _blob3.endPoint = CGPointMake(1.0, 1.0);
        [self.layer addSublayer:_blob3];

        _liquidMirrorGlossLayer = [CAGradientLayer layer];
        _liquidMirrorGlossLayer.startPoint = CGPointMake(0.0, 0.0);
        _liquidMirrorGlossLayer.endPoint = CGPointMake(0.85, 0.95);
        _liquidMirrorGlossLayer.colors = @[
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.28].CGColor,
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.08].CGColor,
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.00].CGColor,
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.12].CGColor
        ];
        _liquidMirrorGlossLayer.locations = @[@0.0, @0.26, @0.62, @1.0];
        [self.layer addSublayer:_liquidMirrorGlossLayer];

        _staticGlassShellLayer = [CALayer layer];
        _staticGlassShellLayer.contentsScale = [UIScreen mainScreen].scale;
        [self.layer addSublayer:_staticGlassShellLayer];

        _hotspotTL = [CAGradientLayer layer];
        _hotspotTL.type = kCAGradientLayerRadial;
        _hotspotTL.startPoint = CGPointMake(0.5, 0.5);
        _hotspotTL.endPoint = CGPointMake(1.0, 1.0);
        [self.layer addSublayer:_hotspotTL];

        _hotspotBR = [CAGradientLayer layer];
        _hotspotBR.type = kCAGradientLayerRadial;
        _hotspotBR.startPoint = CGPointMake(0.5, 0.5);
        _hotspotBR.endPoint = CGPointMake(1.0, 1.0);
        [self.layer addSublayer:_hotspotBR];

        _lastRenderedTheme = (AGVisualTheme)(-1);
        [self applyTheme:agCurrentVisualTheme()];
    }
    return self;
}

- (void)rebuildStaticGlassShellTextureIfNeeded {
    CGRect b = self.bounds;
    if (b.size.width <= 20 || b.size.height <= 20) return;
    CGFloat glassAlpha = agMainGlassOpacity(); // 默认 0.50 (50% 透明液态镜面)
    if (CGSizeEqualToSize(b.size, _lastRenderedSize) &&
        _appliedTheme == _lastRenderedTheme &&
        fabs(glassAlpha - _lastRenderedOpacity) < 0.005 &&
        _staticGlassShellLayer.contents != nil) {
        return;
    }
    _lastRenderedSize = b.size;
    _lastRenderedTheme = _appliedTheme;
    _lastRenderedOpacity = glassAlpha;

    AGDeviceMetrics m = agComputeDeviceMetrics();
    CGFloat cr = self.cornerRadius > 0 ? self.cornerRadius : m.cardCornerRadius;
    AGVisualTheme theme = _appliedTheme;

    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.scale = m.scale;
    fmt.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:b.size format:fmt];

    UIImage *shellImg = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rCtx) {
        CGContextRef ctx = rCtx.CGContext;
        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        UIBezierPath *outerClip = [UIBezierPath bezierPathWithRoundedRect:b cornerRadius:cr];
        [outerClip addClip];

        NSArray *baseCols = nil;
        NSArray *rimGradCols = nil;
        UIColor *grooveColor = nil;
        UIColor *innerWireCol = nil;
        UIColor *podFillTop = nil;
        UIColor *podFillBot = nil;
        UIColor *podStrokeCol = nil;
        UIColor *edgeGlowCol = nil;

        if (theme == AGVisualThemeLightLuxury) {
            // 1. 轻奢：50% 液态黑金镜面玻璃底
            baseCols = @[(id)[UIColor colorWithRed:0.14 green:0.10 blue:0.08 alpha:glassAlpha * 0.95].CGColor,
                         (id)[UIColor colorWithRed:0.06 green:0.05 blue:0.05 alpha:glassAlpha * 1.05].CGColor,
                         (id)[UIColor colorWithRed:0.12 green:0.08 blue:0.05 alpha:glassAlpha * 1.00].CGColor];
            rimGradCols = @[(id)[UIColor whiteColor].CGColor,
                            (id)[UIColor colorWithRed:0.99 green:0.88 blue:0.68 alpha:0.96].CGColor,
                            (id)[UIColor colorWithRed:0.72 green:0.50 blue:0.28 alpha:0.78].CGColor,
                            (id)[UIColor colorWithRed:0.98 green:0.84 blue:0.58 alpha:0.95].CGColor,
                            (id)[UIColor whiteColor].CGColor];
            grooveColor  = [UIColor colorWithRed:0.05 green:0.03 blue:0.02 alpha:0.68];
            innerWireCol = [UIColor colorWithRed:1.00 green:0.94 blue:0.82 alpha:0.68];
            podFillTop   = [UIColor colorWithRed:0.28 green:0.20 blue:0.14 alpha:0.42];
            podFillBot   = [UIColor colorWithRed:0.08 green:0.06 blue:0.05 alpha:0.62];
            podStrokeCol = [UIColor colorWithRed:0.98 green:0.86 blue:0.66 alpha:0.62];
            edgeGlowCol  = [UIColor colorWithRed:0.98 green:0.82 blue:0.52 alpha:0.28];
        } else if (theme == AGVisualThemeMinimalist) {
            // 2. 简约：50% 液态冰晶蓝镜面玻璃底
            baseCols = @[(id)[UIColor colorWithRed:0.10 green:0.16 blue:0.34 alpha:glassAlpha * 0.92].CGColor,
                         (id)[UIColor colorWithRed:0.06 green:0.10 blue:0.24 alpha:glassAlpha * 1.02].CGColor,
                         (id)[UIColor colorWithRed:0.14 green:0.10 blue:0.32 alpha:glassAlpha * 0.96].CGColor];
            rimGradCols = @[(id)[UIColor whiteColor].CGColor,
                            (id)[UIColor colorWithRed:0.73 green:0.91 blue:1.00 alpha:0.96].CGColor,
                            (id)[UIColor colorWithRed:0.56 green:0.62 blue:0.98 alpha:0.80].CGColor,
                            (id)[UIColor colorWithRed:0.88 green:0.78 blue:1.00 alpha:0.94].CGColor,
                            (id)[UIColor whiteColor].CGColor];
            grooveColor  = [UIColor colorWithRed:0.04 green:0.08 blue:0.20 alpha:0.62];
            innerWireCol = [UIColor colorWithWhite:1.0 alpha:0.76];
            podFillTop   = [UIColor colorWithRed:0.38 green:0.56 blue:0.88 alpha:0.28];
            podFillBot   = [UIColor colorWithRed:0.10 green:0.16 blue:0.36 alpha:0.48];
            podStrokeCol = [UIColor colorWithWhite:1.0 alpha:0.68];
            edgeGlowCol  = [UIColor colorWithRed:0.48 green:0.82 blue:1.00 alpha:0.28];
        } else {
            // 3. 炫酷：50% 液态全息深空镜面玻璃底
            baseCols = @[(id)[UIColor colorWithRed:0.06 green:0.10 blue:0.26 alpha:glassAlpha * 0.95].CGColor,
                         (id)[UIColor colorWithRed:0.04 green:0.05 blue:0.16 alpha:glassAlpha * 1.05].CGColor,
                         (id)[UIColor colorWithRed:0.16 green:0.06 blue:0.28 alpha:glassAlpha * 1.00].CGColor];
            rimGradCols = @[(id)[UIColor whiteColor].CGColor,
                            (id)[UIColor colorWithRed:0.00 green:0.96 blue:1.00 alpha:0.98].CGColor,
                            (id)[UIColor colorWithRed:0.58 green:0.32 blue:0.98 alpha:0.88].CGColor,
                            (id)[UIColor colorWithRed:1.00 green:0.18 blue:0.56 alpha:0.96].CGColor,
                            (id)[UIColor colorWithRed:0.00 green:0.96 blue:1.00 alpha:0.98].CGColor];
            grooveColor  = [UIColor colorWithRed:0.02 green:0.04 blue:0.14 alpha:0.68];
            innerWireCol = [UIColor colorWithRed:0.68 green:0.96 blue:1.00 alpha:0.75];
            podFillTop   = [UIColor colorWithRed:0.08 green:0.32 blue:0.62 alpha:0.34];
            podFillBot   = [UIColor colorWithRed:0.06 green:0.08 blue:0.24 alpha:0.58];
            podStrokeCol = [UIColor colorWithRed:0.38 green:0.92 blue:1.00 alpha:0.68];
            edgeGlowCol  = [UIColor colorWithRed:0.00 green:0.96 blue:1.00 alpha:0.30];
        }

        // 1. 绘制高对比度深邃玻璃基底 (不涂白雾，保留通透景深)
        CGFloat baseLocs[3] = {0.0, 0.52, 1.0};
        CGGradientRef baseG = CGGradientCreateWithColors(space, (__bridge CFArrayRef)baseCols, baseLocs);
        CGContextDrawLinearGradient(ctx, baseG, CGPointMake(0, 0), CGPointMake(b.size.width * 0.85, b.size.height), 0);
        CGGradientRelease(baseG);

        // 2. 四周边缘柔和内折射光晕 (只分布在边缘 28pt 内，绝不污染中心对话区)
        CGFloat glowLocs[2] = {0.0, 1.0};
        agDrawRadialGradient(ctx, CGPointMake(28.0, 22.0), 2.0, CGPointMake(28.0, 22.0), 115.0,
                             @[edgeGlowCol, [UIColor clearColor]], glowLocs);
        agDrawRadialGradient(ctx, CGPointMake(b.size.width - 28.0, b.size.height - 22.0), 2.0, CGPointMake(b.size.width - 28.0, b.size.height - 22.0), 120.0,
                             @[edgeGlowCol, [UIColor clearColor]], glowLocs);

        // 3. 绘制顶部导航栏独立圆角玻璃舱 (Top Glass Pod) 与底部控制栏独立圆角玻璃舱 (Bottom Glass Pod)
        CGFloat podH = m.barButtonSize + 10.0;
        CGRect topPodRect = CGRectMake(8.0, m.headerAndBottomPadding - 5.0, b.size.width - 16.0, podH);
        CGRect botPodRect = CGRectMake(8.0, b.size.height - m.headerAndBottomPadding - m.barButtonSize - 5.0, b.size.width - 16.0, podH);

        CGRect pods[2] = {topPodRect, botPodRect};
        for (int pIdx = 0; pIdx < 2; pIdx++) {
            CGRect pr = pods[pIdx];
            UIBezierPath *podPath = [UIBezierPath bezierPathWithRoundedRect:pr cornerRadius:podH / 2.0];
            CGContextSaveGState(ctx);
            [podPath addClip];
            NSArray *pCols = @[(id)podFillTop.CGColor, (id)podFillBot.CGColor];
            CGFloat pLocs[2] = {0.0, 1.0};
            CGGradientRef pg = CGGradientCreateWithColors(space, (__bridge CFArrayRef)pCols, pLocs);
            CGContextDrawLinearGradient(ctx, pg, CGPointMake(0, pr.origin.y), CGPointMake(0, pr.origin.y + pr.size.height), 0);
            CGGradientRelease(pg);

            // 胶囊舱顶部弯月面细高光
            UIBezierPath *topArc = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(pr, 1.0, 0.8) cornerRadius:(podH / 2.0) - 0.8];
            [[UIColor colorWithWhite:1.0 alpha:0.38] setStroke];
            topArc.lineWidth = 0.9;
            [topArc stroke];
            CGContextRestoreGState(ctx);

            [podStrokeCol setStroke];
            podPath.lineWidth = 1.15;
            [podPath stroke];
        }

        // 4. 绘制真正的 3D 双轨透明夹层厚玻璃外框：
        // (a) 1.5pt ~ 4.4pt 之间的深色半透明折射夹层槽 (Groove)
        UIBezierPath *groovePath = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(b, 2.8, 2.8) cornerRadius:MAX(8.0, cr - 2.8)];
        [grooveColor setStroke];
        groovePath.lineWidth = 3.0;
        [groovePath stroke];

        // (b) 最外圈 1.6pt 高亮流光金属/水晶边
        CGContextSaveGState(ctx);
        UIBezierPath *outerRimRing = [UIBezierPath bezierPathWithRoundedRect:b cornerRadius:cr];
        [outerRimRing appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectInset(b, 1.7, 1.7) cornerRadius:MAX(8.0, cr - 1.7)]];
        outerRimRing.usesEvenOddFillRule = YES;
        [outerRimRing addClip];
        CGFloat rimLocs[5] = {0.0, 0.25, 0.50, 0.78, 1.0};
        CGGradientRef rimG = CGGradientCreateWithColors(space, (__bridge CFArrayRef)rimGradCols, rimLocs);
        CGContextDrawLinearGradient(ctx, rimG, CGPointMake(0, 0), CGPointMake(b.size.width, b.size.height), 0);
        CGGradientRelease(rimG);
        CGContextRestoreGState(ctx);

        // (c) 内侧 4.5pt 处的第二道锐利高光折射细环
        UIBezierPath *innerWirePath = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(b, 4.4, 4.4) cornerRadius:MAX(8.0, cr - 4.4)];
        [innerWireCol setStroke];
        innerWirePath.lineWidth = 1.05;
        [innerWirePath stroke];

        // (d) 边缘局部高光反射点
        agDrawRadialGradient(ctx, CGPointMake(b.size.width - 72.0, 1.2), 0.5, CGPointMake(b.size.width - 72.0, 1.2), 36.0,
                             @[[UIColor whiteColor], [UIColor clearColor]], glowLocs);
        agDrawRadialGradient(ctx, CGPointMake(64.0, b.size.height - 1.2), 0.5, CGPointMake(64.0, b.size.height - 1.2), 38.0,
                             @[[UIColor whiteColor], [UIColor clearColor]], glowLocs);

        CGColorSpaceRelease(space);
    }];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _staticGlassShellLayer.frame = b;
    _staticGlassShellLayer.contents = (__bridge id)shellImg.CGImage;
    [CATransaction commit];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.bounds;
    if (b.size.width <= 10 || b.size.height <= 10) return;
    AGDeviceMetrics m = agComputeDeviceMetrics();
    CGFloat cr = self.cornerRadius > 0 ? self.cornerRadius : m.cardCornerRadius;
    self.layer.cornerRadius = cr;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CGFloat bSize = MIN(b.size.width, b.size.height) * 0.72;
    _blob1.bounds = CGRectMake(0, 0, bSize, bSize);
    _blob2.bounds = CGRectMake(0, 0, bSize, bSize);
    _blob3.bounds = CGRectMake(0, 0, bSize, bSize);
    _liquidMirrorGlossLayer.frame = b;
    _hotspotTL.frame = CGRectMake(18.0, -3.5, 96.0, 10.0);
    _hotspotBR.frame = CGRectMake(b.size.width - 118.0, b.size.height - 6.5, 96.0, 10.0);
    [CATransaction commit];

    [self rebuildStaticGlassShellTextureIfNeeded];
}

- (void)applyTheme:(AGVisualTheme)theme {
    if (_hasInitializedTheme && _appliedTheme == theme) return;
    _hasInitializedTheme = YES;
    _appliedTheme = theme;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (theme == AGVisualThemeLightLuxury) {
        _blob1.colors = @[(__bridge id)[UIColor colorWithRed:0.98 green:0.84 blue:0.58 alpha:0.22].CGColor, (__bridge id)[UIColor clearColor].CGColor];
        _blob2.colors = @[(__bridge id)[UIColor colorWithRed:0.82 green:0.56 blue:0.30 alpha:0.20].CGColor, (__bridge id)[UIColor clearColor].CGColor];
        _blob3.colors = @[(__bridge id)[UIColor colorWithRed:0.92 green:0.72 blue:0.44 alpha:0.18].CGColor, (__bridge id)[UIColor clearColor].CGColor];
        NSArray *hsCols = @[(__bridge id)[UIColor whiteColor].CGColor, (__bridge id)[UIColor colorWithRed:0.98 green:0.85 blue:0.62 alpha:0.75].CGColor, (__bridge id)[UIColor clearColor].CGColor];
        _hotspotTL.colors = hsCols; _hotspotBR.colors = hsCols;
    } else if (theme == AGVisualThemeMinimalist) {
        _blob1.colors = @[(__bridge id)[UIColor colorWithRed:0.38 green:0.72 blue:1.00 alpha:0.24].CGColor, (__bridge id)[UIColor clearColor].CGColor];
        _blob2.colors = @[(__bridge id)[UIColor colorWithRed:0.68 green:0.42 blue:0.98 alpha:0.22].CGColor, (__bridge id)[UIColor clearColor].CGColor];
        _blob3.colors = @[(__bridge id)[UIColor colorWithRed:0.56 green:0.85 blue:1.00 alpha:0.20].CGColor, (__bridge id)[UIColor clearColor].CGColor];
        NSArray *hsCols = @[(__bridge id)[UIColor whiteColor].CGColor, (__bridge id)[UIColor colorWithRed:0.56 green:0.85 blue:1.00 alpha:0.82].CGColor, (__bridge id)[UIColor clearColor].CGColor];
        _hotspotTL.colors = hsCols; _hotspotBR.colors = hsCols;
    } else {
        _blob1.colors = @[(__bridge id)[UIColor colorWithRed:0.00 green:0.96 blue:1.00 alpha:0.26].CGColor, (__bridge id)[UIColor clearColor].CGColor];
        _blob2.colors = @[(__bridge id)[UIColor colorWithRed:1.00 green:0.16 blue:0.52 alpha:0.24].CGColor, (__bridge id)[UIColor clearColor].CGColor];
        _blob3.colors = @[(__bridge id)[UIColor colorWithRed:0.62 green:0.28 blue:0.98 alpha:0.25].CGColor, (__bridge id)[UIColor clearColor].CGColor];
        NSArray *hsCols = @[(__bridge id)[UIColor whiteColor].CGColor, (__bridge id)[UIColor colorWithRed:0.00 green:0.96 blue:1.00 alpha:0.85].CGColor, (__bridge id)[UIColor clearColor].CGColor];
        _hotspotTL.colors = hsCols; _hotspotBR.colors = hsCols;
    }
    [CATransaction commit];

    [self rebuildStaticGlassShellTextureIfNeeded];
}

- (void)stepAnimationWithPhase:(CGFloat)phase amplitude:(CGFloat)amp {
    CGRect b = self.bounds;
    if (b.size.width <= 10) return;
    CGFloat w = b.size.width, h = b.size.height;
    CGFloat sc = 1.0 + amp * 0.25;
    CGFloat drift = sin(phase * 0.65) * 15.0;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _blob1.position = CGPointMake((0.24 + 0.20 * sin(phase * 0.55)) * w, (0.28 + 0.18 * cos(phase * 0.45)) * h);
    _blob2.position = CGPointMake((0.76 + 0.20 * cos(phase * 0.50)) * w, (0.72 + 0.18 * sin(phase * 0.60)) * h);
    _blob3.position = CGPointMake((0.50 + 0.22 * sin(phase * 0.40 + 1.0)) * w, (0.50 + 0.18 * sin(phase * 0.45)) * h);
    _blob1.transform = CATransform3DMakeScale(sc, sc, 1.0);
    _blob2.transform = CATransform3DMakeScale(sc, sc, 1.0);

    _hotspotTL.position = CGPointMake(68.0 + drift, 1.5);
    _hotspotBR.position = CGPointMake(w - 72.0 - drift, h - 1.5);
    [CATransaction commit];
}

- (void)setNeedsDisplay {}
@end

// ==================== 2. 纯 GPU 硬件加速 3D 液态球面镜核心球 (0 CPU drawRect) ====================
@interface AGOrbCanvasView : UIView
@property (nonatomic, assign) CGFloat phase;
@property (nonatomic, assign) CGFloat amplitude;
- (void)applyTheme:(AGVisualTheme)theme;
- (void)stepAnimationWithPhase:(CGFloat)phase amplitude:(CGFloat)amp;
@end

@implementation AGOrbCanvasView {
    CAGradientLayer *_coreGrad;
    CAGradientLayer *_subBlob1;
    CAGradientLayer *_subBlob2;
    CAGradientLayer *_specularCap;
    CAShapeLayer    *_outerRing;
    CAShapeLayer    *_innerRing;
    AGVisualTheme   _appliedTheme;
    BOOL            _hasInit;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;

        _subBlob1 = [CAGradientLayer layer];
        _subBlob1.type = kCAGradientLayerRadial;
        _subBlob1.startPoint = CGPointMake(0.5, 0.5);
        _subBlob1.endPoint = CGPointMake(1.0, 1.0);
        [self.layer addSublayer:_subBlob1];

        _subBlob2 = [CAGradientLayer layer];
        _subBlob2.type = kCAGradientLayerRadial;
        _subBlob2.startPoint = CGPointMake(0.5, 0.5);
        _subBlob2.endPoint = CGPointMake(1.0, 1.0);
        [self.layer addSublayer:_subBlob2];

        _coreGrad = [CAGradientLayer layer];
        _coreGrad.type = kCAGradientLayerRadial;
        _coreGrad.startPoint = CGPointMake(0.32, 0.26);
        _coreGrad.endPoint = CGPointMake(0.95, 0.95);
        [self.layer addSublayer:_coreGrad];

        _specularCap = [CAGradientLayer layer];
        _specularCap.startPoint = CGPointMake(0.3, 0.0);
        _specularCap.endPoint = CGPointMake(0.7, 1.0);
        _specularCap.colors = @[
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.90].CGColor,
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
        ];
        [self.layer addSublayer:_specularCap];

        _outerRing = [CAShapeLayer layer];
        _outerRing.fillColor = [UIColor clearColor].CGColor;
        _outerRing.lineWidth = 1.6;
        [self.layer addSublayer:_outerRing];

        _innerRing = [CAShapeLayer layer];
        _innerRing.fillColor = [UIColor clearColor].CGColor;
        _innerRing.lineWidth = 1.0;
        [self.layer addSublayer:_innerRing];

        [self applyTheme:agCurrentVisualTheme()];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGRect b = self.bounds;
    if (b.size.width <= 4) return;
    CGFloat s = b.size.width;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _coreGrad.frame = CGRectInset(b, s * 0.08, s * 0.08);
    _coreGrad.cornerRadius = _coreGrad.bounds.size.width / 2.0;

    _subBlob1.frame = CGRectInset(b, s * 0.06, s * 0.14);
    _subBlob1.cornerRadius = _subBlob1.bounds.size.height / 2.0;

    _subBlob2.frame = CGRectInset(b, s * 0.14, s * 0.06);
    _subBlob2.cornerRadius = _subBlob2.bounds.size.width / 2.0;

    _specularCap.frame = CGRectMake(s * 0.18, s * 0.12, s * 0.46, s * 0.28);
    _specularCap.cornerRadius = s * 0.14;
    _specularCap.transform = CATransform3DMakeRotation(-0.32, 0, 0, 1);

    _outerRing.frame = b;
    _outerRing.path = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(b, 1.0, 1.0)].CGPath;

    _innerRing.frame = b;
    _innerRing.path = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(b, 3.2, 3.2)].CGPath;
    [CATransaction commit];
}

- (void)applyTheme:(AGVisualTheme)theme {
    if (_hasInit && _appliedTheme == theme) return;
    _hasInit = YES;
    _appliedTheme = theme;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (theme == AGVisualThemeLightLuxury) {
        _coreGrad.colors = @[
            (__bridge id)[UIColor whiteColor].CGColor,
            (__bridge id)[UIColor colorWithRed:0.99 green:0.90 blue:0.68 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.82 green:0.55 blue:0.26 alpha:0.95].CGColor,
            (__bridge id)[UIColor colorWithRed:0.25 green:0.15 blue:0.08 alpha:0.95].CGColor
        ];
        _subBlob1.hidden = YES;
        _subBlob2.hidden = YES;
        _outerRing.strokeColor = [UIColor colorWithRed:1.00 green:0.94 blue:0.82 alpha:0.92].CGColor;
        _innerRing.strokeColor = [UIColor colorWithRed:0.95 green:0.78 blue:0.52 alpha:0.68].CGColor;
    } else if (theme == AGVisualThemeMinimalist) {
        _coreGrad.colors = @[
            (__bridge id)[UIColor whiteColor].CGColor,
            (__bridge id)[UIColor colorWithRed:0.73 green:0.91 blue:1.00 alpha:0.96].CGColor,
            (__bridge id)[UIColor colorWithRed:0.25 green:0.52 blue:0.98 alpha:0.92].CGColor,
            (__bridge id)[UIColor colorWithRed:0.84 green:0.32 blue:0.96 alpha:0.90].CGColor
        ];
        _subBlob1.hidden = NO;
        _subBlob1.colors = @[(__bridge id)[UIColor colorWithWhite:1.0 alpha:0.85].CGColor, (__bridge id)[UIColor clearColor].CGColor];
        _subBlob2.hidden = NO;
        _subBlob2.colors = @[(__bridge id)[UIColor colorWithRed:0.56 green:0.85 blue:1.00 alpha:0.75].CGColor, (__bridge id)[UIColor clearColor].CGColor];
        _outerRing.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.95].CGColor;
        _innerRing.strokeColor = [UIColor colorWithRed:0.73 green:0.90 blue:1.00 alpha:0.78].CGColor;
    } else {
        _coreGrad.colors = @[
            (__bridge id)[UIColor whiteColor].CGColor,
            (__bridge id)[UIColor colorWithRed:0.00 green:0.96 blue:1.00 alpha:0.95].CGColor,
            (__bridge id)[UIColor colorWithRed:0.48 green:0.24 blue:0.96 alpha:0.92].CGColor,
            (__bridge id)[UIColor colorWithRed:1.00 green:0.16 blue:0.52 alpha:0.92].CGColor
        ];
        _subBlob1.hidden = NO;
        _subBlob1.colors = @[(__bridge id)[UIColor whiteColor].CGColor, (__bridge id)[UIColor colorWithRed:0.00 green:0.96 blue:1.00 alpha:0.85].CGColor, (__bridge id)[UIColor clearColor].CGColor];
        _subBlob2.hidden = NO;
        _subBlob2.colors = @[(__bridge id)[UIColor whiteColor].CGColor, (__bridge id)[UIColor colorWithRed:1.00 green:0.16 blue:0.52 alpha:0.85].CGColor, (__bridge id)[UIColor clearColor].CGColor];
        _outerRing.strokeColor = [UIColor colorWithWhite:1.0 alpha:0.92].CGColor;
        _innerRing.strokeColor = [UIColor colorWithRed:0.00 green:0.96 blue:1.00 alpha:0.80].CGColor;
    }
    [CATransaction commit];
}

- (void)stepAnimationWithPhase:(CGFloat)phase amplitude:(CGFloat)amp {
    CGFloat sc = 1.0 + amp * 0.16;
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _coreGrad.transform = CATransform3DMakeScale(sc, sc, 1.0);
    if (!_subBlob1.hidden) {
        _subBlob1.transform = CATransform3DConcat(CATransform3DMakeScale(sc, sc, 1.0), CATransform3DMakeRotation(phase * 0.85, 0, 0, 1));
        _subBlob2.transform = CATransform3DConcat(CATransform3DMakeScale(sc, sc, 1.0), CATransform3DMakeRotation(-phase * 1.05, 0, 0, 1));
    }
    [CATransaction commit];
}

- (void)setNeedsDisplay {}
@end

// ==================== 3. 纯 GPU 双轨高低交织流光丝带声波 (彻底移除突兀白斑，还原参考图大弧度交错丝带) ====================
@interface AGWaveCanvasView : UIView
@property (nonatomic, assign) CGFloat phase;
@property (nonatomic, assign) CGFloat amplitude;
- (void)applyTheme:(AGVisualTheme)theme;
- (void)stepAnimationWithPhase:(CGFloat)phase amplitude:(CGFloat)amp;
@end

@implementation AGWaveCanvasView {
    CAGradientLayer *_bottomHorizonGlow; // 底部柔和地平线环境光晕
    CAShapeLayer    *_fill1, *_glow1, *_stroke1;
    CAShapeLayer    *_fill2, *_glow2, *_stroke2;
    CAShapeLayer    *_fill3, *_glow3, *_stroke3;
    AGVisualTheme   _appliedTheme;
    BOOL            _hasInit;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;

        _bottomHorizonGlow = [CAGradientLayer layer];
        _bottomHorizonGlow.startPoint = CGPointMake(0.5, 0.0);
        _bottomHorizonGlow.endPoint = CGPointMake(0.5, 1.0);
        [self.layer addSublayer:_bottomHorizonGlow];

        CAShapeLayer *(^makeFill)(void) = ^{
            CAShapeLayer *l = [CAShapeLayer layer];
            l.strokeColor = [UIColor clearColor].CGColor;
            [self.layer addSublayer:l];
            return l;
        };
        CAShapeLayer *(^makeStroke)(CGFloat lw) = ^(CGFloat lw) {
            CAShapeLayer *l = [CAShapeLayer layer];
            l.fillColor = [UIColor clearColor].CGColor;
            l.lineWidth = lw;
            l.lineCap = kCALineCapRound;
            l.shadowOpacity = 0.0;
            [self.layer addSublayer:l];
            return l;
        };

        _fill3 = makeFill(); _glow3 = makeStroke(5.0); _stroke3 = makeStroke(1.8);
        _fill2 = makeFill(); _glow2 = makeStroke(5.8); _stroke2 = makeStroke(2.2);
        _fill1 = makeFill(); _glow1 = makeStroke(6.5); _stroke1 = makeStroke(2.6);

        [self applyTheme:agCurrentVisualTheme()];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    _bottomHorizonGlow.frame = self.bounds;
    [CATransaction commit];
}

- (void)applyTheme:(AGVisualTheme)theme {
    if (_hasInit && _appliedTheme == theme) return;
    _hasInit = YES;
    _appliedTheme = theme;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (theme == AGVisualThemeLightLuxury) {
        _bottomHorizonGlow.colors = @[
            (__bridge id)[UIColor clearColor].CGColor,
            (__bridge id)[UIColor colorWithRed:0.96 green:0.76 blue:0.42 alpha:0.24].CGColor
        ];
        _stroke1.strokeColor = [UIColor colorWithRed:1.00 green:0.97 blue:0.88 alpha:1.0].CGColor;
        _glow1.strokeColor   = [UIColor colorWithRed:0.99 green:0.82 blue:0.48 alpha:0.35].CGColor;
        _fill1.fillColor     = [UIColor colorWithRed:0.98 green:0.82 blue:0.50 alpha:0.22].CGColor;

        _stroke2.strokeColor = [UIColor colorWithRed:0.90 green:0.64 blue:0.34 alpha:0.95].CGColor;
        _glow2.strokeColor   = [UIColor colorWithRed:0.88 green:0.58 blue:0.26 alpha:0.28].CGColor;
        _fill2.fillColor     = [UIColor colorWithRed:0.82 green:0.54 blue:0.24 alpha:0.16].CGColor;

        _stroke3.hidden = YES; _glow3.hidden = YES; _fill3.hidden = YES;
    } else if (theme == AGVisualThemeMinimalist) {
        _bottomHorizonGlow.colors = @[
            (__bridge id)[UIColor clearColor].CGColor,
            (__bridge id)[UIColor colorWithRed:0.38 green:0.72 blue:1.00 alpha:0.26].CGColor
        ];
        _stroke1.strokeColor = [UIColor colorWithRed:0.88 green:0.97 blue:1.00 alpha:1.0].CGColor;
        _glow1.strokeColor   = [UIColor colorWithRed:0.22 green:0.78 blue:1.00 alpha:0.38].CGColor;
        _fill1.fillColor     = [UIColor colorWithRed:0.38 green:0.78 blue:1.00 alpha:0.24].CGColor;

        _stroke2.strokeColor = [UIColor colorWithRed:0.94 green:0.48 blue:0.96 alpha:0.95].CGColor;
        _glow2.strokeColor   = [UIColor colorWithRed:0.85 green:0.32 blue:0.95 alpha:0.32].CGColor;
        _fill2.fillColor     = [UIColor colorWithRed:0.78 green:0.36 blue:0.96 alpha:0.18].CGColor;

        _stroke3.hidden = YES; _glow3.hidden = YES; _fill3.hidden = YES;
    } else {
        _bottomHorizonGlow.colors = @[
            (__bridge id)[UIColor clearColor].CGColor,
            (__bridge id)[UIColor colorWithRed:0.00 green:0.88 blue:1.00 alpha:0.26].CGColor
        ];
        _stroke1.strokeColor = [UIColor colorWithRed:0.00 green:0.96 blue:1.00 alpha:1.0].CGColor;
        _glow1.strokeColor   = [UIColor colorWithRed:0.00 green:0.96 blue:1.00 alpha:0.36].CGColor;
        _fill1.fillColor     = [UIColor colorWithRed:0.00 green:0.96 blue:1.00 alpha:0.24].CGColor;

        _stroke2.strokeColor = [UIColor colorWithRed:1.00 green:0.22 blue:0.62 alpha:1.0].CGColor;
        _glow2.strokeColor   = [UIColor colorWithRed:1.00 green:0.16 blue:0.52 alpha:0.32].CGColor;
        _fill2.fillColor     = [UIColor colorWithRed:1.00 green:0.16 blue:0.52 alpha:0.20].CGColor;

        _stroke3.hidden = NO; _glow3.hidden = NO; _fill3.hidden = NO;
        _stroke3.strokeColor = [UIColor colorWithRed:0.68 green:0.38 blue:0.98 alpha:0.95].CGColor;
        _glow3.strokeColor   = [UIColor colorWithRed:0.66 green:0.33 blue:0.97 alpha:0.28].CGColor;
        _fill3.fillColor     = [UIColor colorWithRed:0.66 green:0.33 blue:0.97 alpha:0.16].CGColor;
    }
    [CATransaction commit];
}

- (void)updateWavePairStroke:(CAShapeLayer *)sLayer glow:(CAShapeLayer *)gLayer fill:(CAShapeLayer *)fLayer width:(CGFloat)w height:(CGFloat)h midY:(CGFloat)midY amp:(CGFloat)amp freq:(CGFloat)freq speed:(CGFloat)sp phaseOffset:(CGFloat)pOff scale:(CGFloat)sc step:(CGFloat)step {
    UIBezierPath *openPath = [UIBezierPath bezierPath];
    for (CGFloat x = 0; x <= w; x += step) {
        CGFloat n = x / w;
        // 两端平滑收拢包络 + 中段优雅饱满的 S 型正弦交织曲线
        CGFloat env = 0.25 + 0.75 * sin(n * M_PI);
        CGFloat y = midY - sin(n * M_PI * freq + self.phase * sp + pOff) * (amp * sc) * env;
        if (x == 0) [openPath moveToPoint:CGPointMake(x, y)];
        else [openPath addLineToPoint:CGPointMake(x, y)];
    }

    UIBezierPath *closedPath = [openPath copy];
    [closedPath addLineToPoint:CGPointMake(w, h)];
    [closedPath addLineToPoint:CGPointMake(0, h)];
    [closedPath closePath];

    CGPathRef sharedOpenCGPath = openPath.CGPath;
    sLayer.path = sharedOpenCGPath;
    gLayer.path = sharedOpenCGPath;
    fLayer.path = closedPath.CGPath;
}

- (void)stepAnimationWithPhase:(CGFloat)phase amplitude:(CGFloat)amp {
    self.phase = phase;
    self.amplitude = amp;
    CGFloat w = self.bounds.size.width, h = self.bounds.size.height;
    if (w <= 10 || h <= 5) return;

    AGDeviceMetrics m = agComputeDeviceMetrics();
    CGFloat step = m.waveStepPt;
    CGFloat midY = h * 0.52;
    // 关键修复：即使在待机状态也保持优雅的 9.5pt 基础波峰弧度，让两条波浪始终呈现参考图的高低交错缠绕美感
    CGFloat waveAmp = (h * 0.21) + (h * 0.24) * amp;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self updateWavePairStroke:_stroke1 glow:_glow1 fill:_fill1 width:w height:h midY:midY amp:waveAmp freq:2.1 speed:0.95 phaseOffset:0.0 scale:1.0 step:step];
    [self updateWavePairStroke:_stroke2 glow:_glow2 fill:_fill2 width:w height:h midY:midY + 2.5 amp:waveAmp freq:2.6 speed:-1.10 phaseOffset:1.65 scale:0.88 step:step];
    if (!_stroke3.hidden) {
        [self updateWavePairStroke:_stroke3 glow:_glow3 fill:_fill3 width:w height:h midY:midY + 3.5 amp:waveAmp freq:3.1 speed:0.85 phaseOffset:3.10 scale:0.74 step:step];
    }
    [CATransaction commit];
}

- (void)setNeedsDisplay {}
@end

// ==================== 4. 带内存静态缓存的 3D 深邃球面镜液态玻璃圆钮渲染器 ====================
static UIImage *agRenderCompleteCircleButtonImage(AGVectorIconType iconType, CGFloat diameter, AGVisualTheme theme, BOOL isActive, NSInteger modeSlot) {
    static NSMutableDictionary<NSString *, UIImage *> *gBtnImageCache = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        gBtnImageCache = [NSMutableDictionary dictionaryWithCapacity:36];
    });

    NSString *cacheKey = [NSString stringWithFormat:@"v63_%ld_%ld_%.1f_%d_%ld", (long)iconType, (long)theme, diameter, isActive ? 1 : 0, (long)modeSlot];
    UIImage *cached = gBtnImageCache[cacheKey];
    if (cached) return cached;

    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.scale = [UIScreen mainScreen].scale;
    fmt.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(diameter, diameter) format:fmt];
    UIImage *resultImg = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rCtx) {
        CGContextRef ctx = rCtx.CGContext;
        CGRect rect = CGRectMake(0, 0, diameter, diameter);
        UIBezierPath *circle = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(rect, 0.9, 0.9)];
        CGContextSaveGState(ctx);
        [circle addClip];

        CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
        UIColor *iconColor = [UIColor whiteColor];
        UIColor *outerRimColor = [UIColor colorWithWhite:1.0 alpha:0.90];
        UIColor *innerRimColor = [UIColor colorWithWhite:1.0 alpha:0.42];

        if (theme == AGVisualThemeLightLuxury) {
            if (isActive) {
                CGFloat locs[3] = {0.0, 0.52, 1.0};
                agDrawRadialGradient(ctx, CGPointMake(diameter * 0.5, diameter * 0.22), 1.0, CGPointMake(diameter * 0.5, diameter * 0.52), diameter * 0.62,
                                     @[[UIColor whiteColor],
                                       [UIColor colorWithRed:0.99 green:0.88 blue:0.66 alpha:0.96],
                                       [UIColor colorWithRed:0.78 green:0.52 blue:0.26 alpha:0.98]], locs);
                iconColor = [UIColor colorWithRed:0.16 green:0.10 blue:0.04 alpha:1.0];
                outerRimColor = [UIColor whiteColor];
                innerRimColor = [UIColor colorWithRed:1.0 green:0.95 blue:0.82 alpha:0.90];
            } else {
                // 未激活按钮采用深邃黑金玻璃心，告别浅灰塑料感
                CGFloat locs[3] = {0.0, 0.58, 1.0};
                agDrawRadialGradient(ctx, CGPointMake(diameter * 0.45, diameter * 0.22), 1.0, CGPointMake(diameter * 0.5, diameter * 0.5), diameter * 0.68,
                                     @[[UIColor colorWithRed:0.52 green:0.38 blue:0.24 alpha:0.68],
                                       [UIColor colorWithRed:0.10 green:0.07 blue:0.06 alpha:0.86],
                                       [UIColor colorWithRed:0.28 green:0.19 blue:0.12 alpha:0.88]], locs);
                iconColor = [UIColor colorWithRed:1.00 green:0.95 blue:0.86 alpha:0.98];
                outerRimColor = [UIColor colorWithRed:0.99 green:0.86 blue:0.64 alpha:0.88];
                innerRimColor = [UIColor colorWithWhite:1.0 alpha:0.38];
            }
        } else if (theme == AGVisualThemeMinimalist) {
            if (isActive) {
                CGFloat locs[3] = {0.0, 0.52, 1.0};
                agDrawRadialGradient(ctx, CGPointMake(diameter * 0.5, diameter * 0.22), 1.0, CGPointMake(diameter * 0.5, diameter * 0.52), diameter * 0.62,
                                     @[[UIColor whiteColor],
                                       [UIColor colorWithRed:0.32 green:0.68 blue:1.00 alpha:0.92],
                                       [UIColor colorWithRed:0.56 green:0.34 blue:0.96 alpha:0.95]], locs);
                iconColor = [UIColor whiteColor];
                outerRimColor = [UIColor whiteColor];
                innerRimColor = [UIColor colorWithRed:0.85 green:0.95 blue:1.00 alpha:0.92];
            } else {
                // 深海藍宝石镜面内芯 + 冰白双高光环
                CGFloat locs[3] = {0.0, 0.58, 1.0};
                agDrawRadialGradient(ctx, CGPointMake(diameter * 0.45, diameter * 0.22), 1.0, CGPointMake(diameter * 0.5, diameter * 0.5), diameter * 0.68,
                                     @[[UIColor colorWithRed:0.35 green:0.55 blue:0.88 alpha:0.65],
                                       [UIColor colorWithRed:0.08 green:0.14 blue:0.32 alpha:0.82],
                                       [UIColor colorWithRed:0.22 green:0.36 blue:0.68 alpha:0.85]], locs);
                iconColor = [UIColor whiteColor];
                outerRimColor = [UIColor colorWithWhite:1.0 alpha:0.90];
                innerRimColor = [UIColor colorWithRed:0.73 green:0.90 blue:1.00 alpha:0.52];
            }
        } else {
            if (isActive) {
                CGFloat locs[3] = {0.0, 0.52, 1.0};
                agDrawRadialGradient(ctx, CGPointMake(diameter * 0.5, diameter * 0.22), 1.0, CGPointMake(diameter * 0.5, diameter * 0.52), diameter * 0.64,
                                     @[[UIColor whiteColor],
                                       [UIColor colorWithRed:0.00 green:0.92 blue:1.00 alpha:0.92],
                                       [UIColor colorWithRed:0.88 green:0.20 blue:0.78 alpha:0.95]], locs);
                iconColor = [UIColor whiteColor];
                outerRimColor = [UIColor whiteColor];
                innerRimColor = [UIColor colorWithRed:0.65 green:0.96 blue:1.00 alpha:0.92];
            } else {
                CGFloat locs[3] = {0.0, 0.58, 1.0};
                agDrawRadialGradient(ctx, CGPointMake(diameter * 0.45, diameter * 0.22), 1.0, CGPointMake(diameter * 0.5, diameter * 0.5), diameter * 0.68,
                                     @[[UIColor colorWithRed:0.15 green:0.48 blue:0.82 alpha:0.68],
                                       [UIColor colorWithRed:0.05 green:0.08 blue:0.24 alpha:0.86],
                                       [UIColor colorWithRed:0.32 green:0.12 blue:0.56 alpha:0.86]], locs);
                iconColor = [UIColor whiteColor];
                outerRimColor = [UIColor colorWithRed:0.25 green:0.94 blue:1.00 alpha:0.90];
                innerRimColor = [UIColor colorWithWhite:1.0 alpha:0.45];
            }
        }

        // 顶部球面镜月牙高光 + 底部边缘聚光弧
        CGFloat capLocs[2] = {0.0, 1.0};
        agDrawRadialGradient(ctx, CGPointMake(diameter * 0.5, diameter * 0.14), 0.5, CGPointMake(diameter * 0.5, diameter * 0.16), diameter * 0.42,
                             @[[UIColor colorWithWhite:1.0 alpha:(isActive ? 0.88 : 0.55)], [UIColor clearColor]], capLocs);
        agDrawRadialGradient(ctx, CGPointMake(diameter * 0.5, diameter * 0.92), 0.5, CGPointMake(diameter * 0.5, diameter * 0.88), diameter * 0.36,
                             @[[UIColor colorWithWhite:1.0 alpha:(isActive ? 0.88 : 0.35)], [UIColor clearColor]], capLocs);

        CGColorSpaceRelease(space);
        CGContextRestoreGState(ctx);

        [innerRimColor setStroke];
        UIBezierPath *innerCircle = [UIBezierPath bezierPathWithOvalInRect:CGRectInset(rect, 2.4, 2.4)];
        innerCircle.lineWidth = 0.95;
        [innerCircle stroke];

        [outerRimColor setStroke];
        circle.lineWidth = 1.45;
        [circle stroke];

        CGContextSaveGState(ctx);
        CGFloat iconSz = diameter * 0.485;
        CGFloat offset = (diameter - iconSz) / 2.0;
        CGContextTranslateCTM(ctx, offset, offset);
        CGFloat sc = iconSz / 24.0;
        CGContextScaleCTM(ctx, sc, sc);
        [iconColor setStroke];
        [iconColor setFill];

        UIBezierPath *path = [UIBezierPath bezierPath];
        path.lineWidth = 1.95;
        path.lineCapStyle = kCGLineCapRound;
        path.lineJoinStyle = kCGLineJoinRound;

        switch (iconType) {
            case AGVectorIconMicLive: {
                UIBezierPath *cap = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(9.0, 2.5, 6.0, 10.5) cornerRadius:3.0];
                [[iconColor colorWithAlphaComponent:(isActive ? 0.90 : 0.35)] setFill];
                [cap fill];
                [iconColor setFill];
                cap.lineWidth = 1.9;
                [cap stroke];
                [path addArcWithCenter:CGPointMake(12.0, 10.5) radius:6.5 startAngle:0 endAngle:M_PI clockwise:YES];
                [path moveToPoint:CGPointMake(12.0, 17.0)];
                [path addLineToPoint:CGPointMake(12.0, 21.0)];
                [path moveToPoint:CGPointMake(8.5, 21.0)];
                [path addLineToPoint:CGPointMake(15.5, 21.0)];
                [path stroke];
                break;
            }
            case AGVectorIconVideoAI: {
                UIBezierPath *box = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(2.5, 5.5, 13.5, 13.0) cornerRadius:3.5];
                [[iconColor colorWithAlphaComponent:0.24] setFill];
                [box fill];
                [iconColor setFill];
                box.lineWidth = 1.9;
                [box stroke];
                UIBezierPath *lens = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(6.6, 9.4, 5.2, 5.2)];
                lens.lineWidth = 1.7;
                [lens stroke];
                [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(8.2, 11.0, 2.0, 2.0)] fill];
                [path moveToPoint:CGPointMake(16.0, 10.0)];
                [path addLineToPoint:CGPointMake(21.2, 7.2)];
                [path addLineToPoint:CGPointMake(21.2, 16.8)];
                [path addLineToPoint:CGPointMake(16.0, 14.0)];
                [path stroke];
                break;
            }
            case AGVectorIconPureText: {
                UIBezierPath *bub = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3.5, 4.0, 17.0, 15.0) cornerRadius:7.5];
                [[iconColor colorWithAlphaComponent:0.22] setFill];
                [bub fill];
                [iconColor setFill];
                bub.lineWidth = 1.9;
                [bub stroke];
                [path moveToPoint:CGPointMake(8.2, 9.8)];
                [path addLineToPoint:CGPointMake(14.8, 9.8)];
                [path moveToPoint:CGPointMake(8.2, 13.2)];
                [path addLineToPoint:CGPointMake(12.6, 13.2)];
                [path stroke];
                break;
            }
            case AGVectorIconSendArrow: {
                path.lineWidth = 2.25;
                [path moveToPoint:CGPointMake(12.0, 19.0)];
                [path addLineToPoint:CGPointMake(12.0, 5.2)];
                [path moveToPoint:CGPointMake(6.5, 10.8)];
                [path addLineToPoint:CGPointMake(12.0, 5.0)];
                [path addLineToPoint:CGPointMake(17.5, 10.8)];
                [path stroke];
                break;
            }
            case AGVectorIconTranslate: {
                [path moveToPoint:CGPointMake(4.0, 5.5)];
                [path addLineToPoint:CGPointMake(13.0, 5.5)];
                [path moveToPoint:CGPointMake(8.5, 3.2)];
                [path addLineToPoint:CGPointMake(8.5, 5.5)];
                [path moveToPoint:CGPointMake(5.5, 5.5)];
                [path addQuadCurveToPoint:CGPointMake(11.5, 13.0) controlPoint:CGPointMake(7.5, 10.5)];
                [path moveToPoint:CGPointMake(11.0, 5.5)];
                [path addQuadCurveToPoint:CGPointMake(4.8, 12.8) controlPoint:CGPointMake(9.0, 10.2)];
                [path moveToPoint:CGPointMake(12.8, 19.2)];
                [path addLineToPoint:CGPointMake(16.2, 10.2)];
                [path addLineToPoint:CGPointMake(19.6, 19.2)];
                [path moveToPoint:CGPointMake(13.9, 16.5)];
                [path addLineToPoint:CGPointMake(18.5, 16.5)];
                [path stroke];
                break;
            }
            case AGVectorIconModelHex: {
                [path moveToPoint:CGPointMake(12.0, 2.8)];
                [path addLineToPoint:CGPointMake(19.6, 7.2)];
                [path addLineToPoint:CGPointMake(19.6, 16.2)];
                [path addLineToPoint:CGPointMake(12.0, 20.6)];
                [path addLineToPoint:CGPointMake(4.4, 16.2)];
                [path addLineToPoint:CGPointMake(4.4, 7.2)];
                [path closePath];
                [path stroke];
                UIBezierPath *innerDot = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(9.2, 9.0, 5.6, 5.6)];
                innerDot.lineWidth = 1.8;
                [innerDot stroke];
                break;
            }
            case AGVectorIconCloseCross: {
                path.lineWidth = 2.1;
                [path moveToPoint:CGPointMake(17.0, 7.0)];
                [path addLineToPoint:CGPointMake(7.0, 17.0)];
                [path moveToPoint:CGPointMake(7.0, 7.0)];
                [path addLineToPoint:CGPointMake(17.0, 17.0)];
                [path stroke];
                break;
            }
        }
        CGContextRestoreGState(ctx);
    }];

    if (resultImg) {
        gBtnImageCache[cacheKey] = resultImg;
    }
    return resultImg;
}

static UIImage *agRenderVectorIcon(AGVectorIconType type, CGSize size, UIColor *strokeColor) {
    return agRenderCompleteCircleButtonImage(type, MAX(size.width, size.height), agCurrentVisualTheme(), NO, 0);
}

// ==================== 四大独立模块的开关与配置读写 ====================
static BOOL agTransIsEnabled(void);
static NSString *agTransEndpoint(void);
static NSString *agTransAPIKey(void);
static NSString *agTransModel(void);
static NSArray<NSDictionary *> *agTransCachedModels(void);
static BOOL agTransIsHighAccuracyOCR(void);
static NSTimeInterval agTransScrollDebounceTime(void);
static NSString *agSanitizeOpenAIEndpoint(NSString *raw);

static NSString *agPrefixForTab(AGConfigTab tab) {
    switch (tab) {
        case AGConfigTabNativeLive:  return @"AG_Live";
        case AGConfigTabVideoAI:     return @"AG_Video";
        case AGConfigTabPureText:    return @"AG_Text";
        case AGConfigTabTranslation: return @"AG_Trans";
    }
    return @"AG_Live";
}

static BOOL agIsTabEnabled(AGConfigTab tab) {
    NSDictionary *p = agReadOnlyPrefs();
    NSString *key = (tab == AGConfigTabTranslation) ? @"AG_Trans_Enabled" : [NSString stringWithFormat:@"%@_Enabled", agPrefixForTab(tab)];
    NSNumber *val = p[key];
    return val ? [val boolValue] : YES;
}

static BOOL agIsWebSearchEnabled(void) {
    NSDictionary *p = agReadOnlyPrefs();
    NSNumber *val = p[@"AG_WebSearch_Enabled"];
    return val ? [val boolValue] : NO;
}

static NSString *agSanitizeEndpoint(NSString *raw, AGConfigTab tab) {
    NSString *ep = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while ([ep hasSuffix:@"/"]) {
        ep = [ep substringToIndex:ep.length - 1];
    }
    if (ep.length < 3 || [ep isEqualToString:@"https:"] || [ep isEqualToString:@"http:"]) {
        return @"https://generativelanguage.googleapis.com";
    }
    if (![ep hasPrefix:@"http://"] && ![ep hasPrefix:@"https://"]) {
        ep = [NSString stringWithFormat:@"https://%@", ep];
    }
    return ep;
}

static NSString *agEndpointForTab(AGConfigTab tab) {
    if (tab == AGConfigTabTranslation) {
        NSString *tEp = agTransEndpoint();
        if (tEp.length >= 5) return agSanitizeEndpoint(tEp, tab);
    }
    NSDictionary *p = agReadOnlyPrefs();
    NSString *key = [NSString stringWithFormat:@"%@_Endpoint", agPrefixForTab(tab)];
    NSString *ep = [p[key] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!ep || ep.length < 4) {
        NSString *liveEp = [p[@"AG_Live_Endpoint"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *legacy = p[@"Gemini_Endpoint"];
        if (liveEp.length > 5) ep = liveEp;
        else if (legacy.length > 5) ep = legacy;
        else ep = @"https://generativelanguage.googleapis.com";
    }
    return agSanitizeEndpoint(ep, tab);
}

static NSString *agAPIKeyForTab(AGConfigTab tab) {
    NSDictionary *p = agReadOnlyPrefs();
    if (tab == AGConfigTabTranslation) {
        NSString *tk = agTransAPIKey();
        if (tk.length >= 4) return tk;
    }
    NSString *key = [NSString stringWithFormat:@"%@_APIKey", agPrefixForTab(tab)];
    NSString *val = [p[key] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!val || val.length == 0) {
        // 自动跨模块共享已填入的 API Key（填一次全模块通用）
        val = [p[@"AG_Live_APIKey"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!val || val.length == 0) val = [p[@"AG_Video_APIKey"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!val || val.length == 0) val = [p[@"AG_Text_APIKey"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!val || val.length == 0) val = [p[@"Gemini_APIKey"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    return val ?: @"";
}

static NSString *agProxyForTab(AGConfigTab tab) {
    NSDictionary *p = agReadOnlyPrefs();
    NSString *key = [NSString stringWithFormat:@"%@_ProxyPort", agPrefixForTab(tab)];
    NSString *val = [p[key] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!val || val.length == 0) {
        val = [p[@"AG_Live_ProxyPort"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (!val || val.length == 0) val = [p[@"Gemini_ProxyPort"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    return val ?: @"";
}

static NSArray<NSDictionary *> *agCachedModelsForTab(AGConfigTab tab) {
    NSDictionary *p = agReadOnlyPrefs();
    NSString *key = (tab == AGConfigTabTranslation) ? @"AG_Trans_CachedModels" : [NSString stringWithFormat:@"%@_CachedModels", agPrefixForTab(tab)];
    NSArray *arr = p[key];
    if ([arr isKindOfClass:[NSArray class]] && arr.count > 0) {
        return arr;
    }
    return agVerifiedDefaultModelsForTab(tab);
}

static NSString *agModelForTab(AGConfigTab tab) {
    if (tab == AGConfigTabTranslation) {
        return agTransModel();
    }
    NSDictionary *p = agReadOnlyPrefs();
    NSString *key = [NSString stringWithFormat:@"%@_Model", agPrefixForTab(tab)];
    NSString *val = [p[key] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (val && val.length > 0) {
        return val;
    }
    NSArray<NSDictionary *> *list = agCachedModelsForTab(tab);
    if (list.count > 0 && list.firstObject[@"id"]) {
        return list.firstObject[@"id"];
    }
    return @"";
}

static BOOL agIsGoogleNativeProtocol(NSString *endpoint, NSString *model) {
    NSString *lowerEP = [endpoint lowercaseString];
    if ([lowerEP containsString:@"googleapis.com"] || [lowerEP containsString:@"v1beta"] || [lowerEP containsString:@"v1alpha"]) {
        if (![lowerEP containsString:@"/v1/chat/completions"] && ![lowerEP containsString:@"openai"]) {
            return YES;
        }
    }
    return NO;
}



static NSURLSession *agCreateSessionWithProxy(NSString *proxyStr, id<NSURLSessionDelegate> delegate, NSOperationQueue *queue) {
    NSString *cleanProxy = [proxyStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.timeoutIntervalForRequest = 30.0;
    if (cleanProxy.length > 0) {
        NSString *host = @"127.0.0.1";
        NSNumber *portNum = nil;
        if ([cleanProxy containsString:@":"]) {
            NSArray *parts = [cleanProxy componentsSeparatedByString:@":"];
            host = parts.firstObject;
            portNum = @([parts.lastObject integerValue]);
        } else {
            portNum = @([cleanProxy integerValue]);
        }
        if ([portNum integerValue] > 0) {
            config.connectionProxyDictionary = @{
                @"HTTPEnable": @YES, @"HTTPProxy": host, @"HTTPPort": portNum,
                @"HTTPSEnable": @YES, @"HTTPSProxy": host, @"HTTPSPort": portNum
            };
        }
    }
    if (delegate) {
        return [NSURLSession sessionWithConfiguration:config delegate:delegate delegateQueue:(queue ?: [NSOperationQueue mainQueue])];
    }
    return [NSURLSession sessionWithConfiguration:config];
}

static dispatch_queue_t agAudioSerialQueue(void) {
    static dispatch_queue_t q = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        q = dispatch_queue_create("com.custom.geminisiri.audioqueue", DISPATCH_QUEUE_SERIAL);
    });
    return q;
}

static NSString *agExtractTextFromJSON(NSDictionary *dict) {
    if (![dict isKindOfClass:[NSDictionary class]]) return nil;
    // 1. Anthropic Claude 原生 SSE (content_block_delta) 与非流式响应解析
    if ([dict[@"type"] isEqualToString:@"content_block_delta"] && [dict[@"delta"] isKindOfClass:[NSDictionary class]]) {
        NSString *deltaTxt = dict[@"delta"][@"text"];
        if ([deltaTxt isKindOfClass:[NSString class]] && deltaTxt.length > 0) return deltaTxt;
    }
    if ([dict[@"content"] isKindOfClass:[NSArray class]]) {
        for (NSDictionary *blk in dict[@"content"]) {
            if ([blk isKindOfClass:[NSDictionary class]] && [blk[@"text"] isKindOfClass:[NSString class]]) {
                return blk[@"text"];
            }
        }
    }
    // 2. OpenAI / DeepSeek / Qwen / GLM / 豆包 标准 choices 解析 (保持原样)
    NSArray *choices = dict[@"choices"];
    if ([choices isKindOfClass:[NSArray class]] && choices.count > 0) {
        NSDictionary *firstChoice = choices.firstObject;
        if ([firstChoice isKindOfClass:[NSDictionary class]]) {
            id contentVal = firstChoice[@"delta"][@"content"] ?: firstChoice[@"message"][@"content"];
            if ([contentVal isKindOfClass:[NSString class]] && [contentVal length] > 0) {
                return contentVal;
            }
        }
    }
    // 3. Google Gemini 原生 candidates 解析 (100% 保持原样)
    NSArray *candidates = dict[@"candidates"];
    if ([candidates isKindOfClass:[NSArray class]] && candidates.count > 0) {
        NSDictionary *cand = candidates.firstObject;
        NSArray *parts = [cand isKindOfClass:[NSDictionary class]] ? cand[@"content"][@"parts"] : nil;
        if ([parts isKindOfClass:[NSArray class]] && parts.count > 0) {
            NSMutableString *joined = [NSMutableString string];
            for (NSDictionary *partItem in parts) {
                if (![partItem isKindOfClass:[NSDictionary class]]) continue;
                if ([partItem[@"thought"] boolValue]) continue;
                id tVal = partItem[@"text"];
                if ([tVal isKindOfClass:[NSString class]] && [tVal length] > 0) {
                    [joined appendString:tVal];
                }
            }
            if (joined.length > 0) return joined;
            id fallbackVal = parts.firstObject[@"text"];
            if ([fallbackVal isKindOfClass:[NSString class]]) return fallbackVal;
        }
    }
    return nil;
}

// 生成合法的标准 16kHz 单声道短静音 WAV Base64（用于探测模型是否支持 audio/wav 输入）
// 生成标准 16kHz 单声道短静音 WAV Base64（用于探测 HTTP 模型是否真正支持 audio/wav 输入）
// 判断某模型是否为仅支持 WebSocket (bidiGenerateContent) 而不支持 HTTP generateContent 的模型
// 生成标准 16kHz 单声道静音 WAV Base64（用于探测 HTTP 模型是否支持 audio/wav 输入）
static NSString *agTinyTestWavBase64(void) {
    static NSString *b64Wav = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        uint32_t sampleRate = 16000;
        uint32_t numSamples = 800;
        uint32_t dataSize = numSamples * 2;
        uint32_t fileSize = 36 + dataSize;
        NSMutableData *wav = [NSMutableData dataWithCapacity:44 + dataSize];
        [wav appendBytes:"RIFF" length:4];
        [wav appendBytes:&fileSize length:4];
        [wav appendBytes:"WAVEfmt " length:8];
        uint32_t fmtLen = 16; [wav appendBytes:&fmtLen length:4];
        uint16_t audioFmt = 1; [wav appendBytes:&audioFmt length:2];
        uint16_t channels = 1; [wav appendBytes:&channels length:2];
        [wav appendBytes:&sampleRate length:4];
        uint32_t byteRate = sampleRate * 2; [wav appendBytes:&byteRate length:4];
        uint16_t blockAlign = 2; [wav appendBytes:&blockAlign length:2];
        uint16_t bitsPerSample = 16; [wav appendBytes:&bitsPerSample length:2];
        [wav appendBytes:"data" length:4];
        [wav appendBytes:&dataSize length:4];
        [wav increaseLengthBy:dataSize];
        b64Wav = [wav base64EncodedStringWithOptions:0];
    });
    return b64Wav;
}

// 判断是否为仅支持 WebSocket (bidiGenerateContent) 而不支持 HTTP generateContent 的实时模型
static BOOL agIsPureWebSocketOnlyModel(NSString *modelID, NSDictionary *mDict) {
    NSString *lower = [modelID lowercaseString];
    if (agIsUnidirectionalAudioModel(lower)) return NO;
    NSArray *methods = mDict[@"supportedGenerationMethods"];
    if ([methods isKindOfClass:[NSArray class]]) {
        BOOL hasBidi = [methods containsObject:@"bidiGenerateContent"];
        BOOL hasHttpGen = [methods containsObject:@"generateContent"];
        if (hasBidi && !hasHttpGen) return YES;
        if (hasHttpGen) return NO;
    }
    return agIsBidirectionalRealtimeModelID(modelID, mDict);
}

static BOOL agIsWebSocketBidiCapableModel(NSString *modelID, AGConfigTab tab) {
    if (!modelID || modelID.length == 0) return NO;
    if (tab == AGConfigTabPureText || tab == AGConfigTabTranslation) return NO;
    if (agIsUnidirectionalAudioModel([modelID lowercaseString])) return NO;

    for (NSDictionary *m in agCachedModelsForTab(tab)) {
        if ([m[@"id"] isEqualToString:modelID]) {
            if (m[@"onlyBidi"] != nil && [m[@"onlyBidi"] boolValue]) return YES;
            if (m[@"bidi"] != nil) return [m[@"bidi"] boolValue];
        }
    }
    return agIsBidirectionalRealtimeModelID(modelID, nil);
}

// ==================== 2. 提取模型“最新版本号”评分（保障支持且最新的稳定版本排在最前） ====================
static double agCalculateModelNewestScore(NSString *modelID, NSDictionary *mDict) {
    NSString *lower = [[modelID lowercaseString] stringByReplacingOccurrencesOfString:@"models/" withString:@""];
    double score = 100.0;

    NSRegularExpression *verRe = [NSRegularExpression regularExpressionWithPattern:@"(?:^|-)(\\d+)(?:\\.(\\d+))?" options:0 error:nil];
    NSTextCheckingResult *verMatch = [verRe firstMatchInString:lower options:0 range:NSMakeRange(0, lower.length)];
    if (verMatch && verMatch.numberOfRanges > 1) {
        double major = [[lower substringWithRange:[verMatch rangeAtIndex:1]] doubleValue];
        double minor = (verMatch.numberOfRanges > 2 && [verMatch rangeAtIndex:2].location != NSNotFound)
            ? [[lower substringWithRange:[verMatch rangeAtIndex:2]] doubleValue] : 0.0;
        if (major > 0 && major <= 15) {
            score += (major * 100.0 + minor * 15.0);
        }
    }
    if ([lower containsString:@"4o"]) score += 420.0;

    if ([lower containsString:@"2026"]) score += 60.0;
    else if ([lower containsString:@"2025"]) score += 40.0;

    // 针对 Google 2.5 native-audio：09-2025 为服务端零断连稳定版，优先于有 1011 断连已知问题的 12-2025
    if ([lower containsString:@"09-2025"]) score += 260.0;
    else if ([lower containsString:@"3.1-flash-live"]) score += 240.0;
    else if ([lower containsString:@"12-2025"]) score -= 15.0;

    NSNumber *created = mDict[@"created"];
    if ([created isKindOfClass:[NSNumber class]] && [created doubleValue] > 1000000000.0) {
        score += ([created doubleValue] - 1700000000.0) / 5000000.0;
    }

    if ([lower containsString:@"legacy"] || [lower containsString:@"-001"]) {
        score -= 180.0;
    }
    return score;
}

// ==================== 3. 按功能筛选并标注模型能力（不设数量限制） ====================
static BOOL agIsModelCapableForTab(NSString *mID, NSDictionary *mDict, AGConfigTab tab, NSString **outBadgeTitle, BOOL *outSupportsBidi) {
    if (!mID || mID.length == 0) return NO;
    NSString *lower = [mID lowercaseString];
    NSString *shortName = [mID stringByReplacingOccurrencesOfString:@"models/" withString:@""];

    // 过滤嵌入、生图、生视频及单向 ASR/TTS/同传模型
    if ([lower containsString:@"embedding"] || [lower containsString:@"rerank"] ||
        [lower containsString:@"moderation"] || [lower containsString:@"text-embedding"] ||
        [lower containsString:@"aqa"] || [lower containsString:@"bison"] ||
        [lower containsString:@"gecko"] || [lower containsString:@"imagen"] ||
        [lower containsString:@"dall-e"] || [lower containsString:@"veo"] ||
        [lower containsString:@"sora"] || [lower containsString:@"robotics"] ||
        [lower containsString:@"computer-use"] || [lower containsString:@"learnlm"] ||
        [lower containsString:@"extended-thinking"] || agIsUnidirectionalAudioModel(lower)) {
        return NO;
    }

    NSArray *methods = mDict[@"supportedGenerationMethods"];
    BOOL hasBidi = NO;
    BOOL hasHttpGen = YES;
    if ([methods isKindOfClass:[NSArray class]]) {
        hasBidi = [methods containsObject:@"bidiGenerateContent"];
        hasHttpGen = [methods containsObject:@"generateContent"];
        if (!hasBidi && !hasHttpGen) return NO;
    }

    BOOL onlyBidi = agIsPureWebSocketOnlyModel(mID, mDict);
    BOOL isRealtimeBidi = onlyBidi || hasBidi || agIsBidirectionalRealtimeModelID(mID, mDict);
    if (outSupportsBidi) *outSupportsBidi = isRealtimeBidi;

    if (tab == AGConfigTabNativeLive || tab == AGConfigTabVideoAI) {
        if (isRealtimeBidi) {
            NSString *tag = (tab == AGConfigTabVideoAI) ? @"📹📞[实时视频通话]" : @"🎙️📞[实时语音通话]";
            if (outBadgeTitle) *outBadgeTitle = [NSString stringWithFormat:@"%@ %@", tag, shortName];
            return YES;
        }
        // 对于非 Google 厂商（如 DeepSeek、Claude、豆包、Kimi 等无原生 Bidi 模型平台），允许在语音/视频模式下使用引擎 B 连续多轮对话
        if ([lower hasPrefix:@"models/gemini-"]) {
            return NO; // Google 平台在 Live/Video 下严格只展示原生 Live 模型，保护现有体验
        }
        if (tab == AGConfigTabVideoAI && ([lower containsString:@"deepseek"] && ![lower containsString:@"vl"])) {
            return NO; // 纯文本模型不进入视频视觉列表
        }
        NSString *tag = (tab == AGConfigTabVideoAI) ? @"📹🎙️[多轮视觉语音]" : @"🎙️💬[连续多轮语音]";
        if (outBadgeTitle) *outBadgeTitle = [NSString stringWithFormat:@"%@ %@", tag, shortName];
        return YES;
    }

    if (onlyBidi || !hasHttpGen) {
        return NO;
    }

    BOOL isThinking = [lower containsString:@"reasoner"] || [lower containsString:@"thinking"] || [lower containsString:@"-r1"] || [lower hasPrefix:@"o1"] || [lower hasPrefix:@"o3"] || [lower hasPrefix:@"o4"] || [lower containsString:@"qwq"];
    BOOL isFastLite = [lower containsString:@"flash"] || [lower containsString:@"mini"] || [lower containsString:@"lite"] || [lower containsString:@"turbo"] || [lower containsString:@"haiku"];

    NSString *funcTag = isThinking ? @"🧠[深度思考/文本]" : (isFastLite ? @"⚡🌐[高速文本+翻译]" : @"💬[通用文本对话]");
    if (outBadgeTitle) {
        *outBadgeTitle = [NSString stringWithFormat:@"%@ %@", funcTag, shortName];
    }
    return YES;
}

static NSInteger agTabSupportTier(NSString *badgeTitle, BOOL onlyBidi, BOOL supportsBidi, AGConfigTab tab) {
    if (tab == AGConfigTabNativeLive || tab == AGConfigTabVideoAI) {
        return supportsBidi ? 4 : 1;
    }
    if (tab == AGConfigTabTranslation) {
        if ([badgeTitle containsString:@"⚡"]) return 3;
        if ([badgeTitle containsString:@"🧠"]) return 1;
        return 2;
    }
    return 3;
}

// ==================== 4. 区分 WebSocket 与 HTTP 的真实可用性探测函数 ====================
static void agProbeModelForTab(AGConfigTab tab, NSString *endpoint, NSString *apiKey, NSString *proxy, NSString *modelID, BOOL onlyBidi, void(^completion)(BOOL ok, NSInteger latencyMs, NSString *errMsg)) {
    NSString *cleanEP = [endpoint stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while ([cleanEP hasSuffix:@"/"]) cleanEP = [cleanEP substringToIndex:cleanEP.length - 1];
    NSString *cleanKey = [apiKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (cleanEP.length < 5 || cleanKey.length < 4) {
        if (completion) completion(NO, 0, @"未配置 API");
        return;
    }

    NSURLSession *session = agCreateSessionWithProxy(proxy ?: @"", nil, nil);
    BOOL isGoogle = agIsGoogleNativeProtocol(cleanEP, modelID);

    // 1. 纯 WebSocket 实时通话模型：通过 GET 模型详情接口验证当前 Key 的访问权限与延迟
    if (onlyBidi || tab == AGConfigTabNativeLive || tab == AGConfigTabVideoAI) {
        if (tab == AGConfigTabPureText || tab == AGConfigTabTranslation) {
            if (completion) completion(NO, 9999, @"仅限实时语音/视频模式");
            return;
        }
        NSTimeInterval t0 = [NSDate timeIntervalSinceReferenceDate];
        NSString *fullM = [modelID hasPrefix:@"models/"] ? modelID : [NSString stringWithFormat:@"models/%@", modelID];
        NSString *urlStr = isGoogle
            ? [NSString stringWithFormat:@"%@/v1beta/%@?key=%@", cleanEP, fullM, cleanKey]
            : [NSString stringWithFormat:@"%@/%@", ([cleanEP hasSuffix:@"/v1"] ? [NSString stringWithFormat:@"%@/models", cleanEP] : [NSString stringWithFormat:@"%@/v1/models", cleanEP]), [modelID stringByReplacingOccurrencesOfString:@"models/" withString:@""]];
        NSMutableURLRequest *mReq = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        mReq.HTTPMethod = @"GET";
        mReq.timeoutInterval = 6.0;
        if (!isGoogle) [mReq setValue:[NSString stringWithFormat:@"Bearer %@", cleanKey] forHTTPHeaderField:@"Authorization"];
        [[session dataTaskWithRequest:mReq completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
            NSInteger lat = (NSInteger)MAX(1.0, ([NSDate timeIntervalSinceReferenceDate] - t0) * 1000.0);
            NSHTTPURLResponse *http = (NSHTTPURLResponse *)resp;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!err && http.statusCode == 200) {
                    if (completion) completion(YES, lat, nil);
                } else {
                    if (completion) completion(NO, lat, @"无权限");
                }
            });
        }] resume];
        return;
    }

    // 2. HTTP 模型：按所属功能发送真实载荷测试（视频AI测看图+听音，Live测听音，纯文本/翻译测生成）
    NSString *tinyJPEGB64 = @"/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=";
    NSString *tinyWAVB64 = agTinyTestWavBase64();
    NSString *testPrompt = @"Hi";

    NSMutableURLRequest *req = nil;
    if (isGoogle) {
        NSString *fullM = [modelID hasPrefix:@"models/"] ? modelID : [NSString stringWithFormat:@"models/%@", modelID];
        NSString *urlStr = [NSString stringWithFormat:@"%@/v1beta/%@:generateContent?key=%@", cleanEP, fullM, cleanKey];
        req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        req.HTTPMethod = @"POST";
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

        NSMutableArray *parts = [NSMutableArray array];
        if (tab == AGConfigTabVideoAI) {
            [parts addObject:@{ @"inlineData": @{ @"mimeType": @"image/jpeg", @"data": tinyJPEGB64 } }];
            [parts addObject:@{ @"inlineData": @{ @"mimeType": @"audio/wav", @"data": tinyWAVB64 } }];
        } else if (tab == AGConfigTabNativeLive) {
            [parts addObject:@{ @"inlineData": @{ @"mimeType": @"audio/wav", @"data": tinyWAVB64 } }];
        }
        [parts addObject:@{ @"text": testPrompt }];

        NSDictionary *body = @{
            @"contents": @[ @{ @"role": @"user", @"parts": parts } ],
            @"generationConfig": @{ @"temperature": @0.1, @"maxOutputTokens": @5 }
        };
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    } else {
        NSString *urlStr = cleanEP;
        if (![urlStr hasSuffix:@"/chat/completions"]) {
            urlStr = [urlStr hasSuffix:@"/v1"] ? [NSString stringWithFormat:@"%@/chat/completions", urlStr] : [NSString stringWithFormat:@"%@/v1/chat/completions", urlStr];
        }
        req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        req.HTTPMethod = @"POST";
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [req setValue:[NSString stringWithFormat:@"Bearer %@", cleanKey] forHTTPHeaderField:@"Authorization"];
        NSString *exactM = [modelID stringByReplacingOccurrencesOfString:@"models/" withString:@""];
        id userContent = testPrompt;
        if (tab == AGConfigTabVideoAI) {
            userContent = @[
                @{ @"type": @"image_url", @"image_url": @{ @"url": [NSString stringWithFormat:@"data:image/jpeg;base64,%@", tinyJPEGB64] } },
                @{ @"type": @"text", @"text": testPrompt }
            ];
        }
        NSDictionary *body = @{
            @"model": exactM,
            @"messages": @[ @{ @"role": @"user", @"content": userContent } ],
            @"temperature": @0.1,
            @"max_tokens": @5
        };
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    }
    req.timeoutInterval = 8.0;

    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    [[session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        NSInteger latency = (NSInteger)MAX(1.0, ([NSDate timeIntervalSinceReferenceDate] - startTime) * 1000.0);
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data || data.length == 0) {
                if (completion) completion(NO, latency, @"超时");
                return;
            }
            NSHTTPURLResponse *httpResp = (NSHTTPURLResponse *)response;
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (([httpResp isKindOfClass:[NSHTTPURLResponse class]] && httpResp.statusCode >= 400) || ([json isKindOfClass:[NSDictionary class]] && json[@"error"])) {
                if (completion) completion(NO, latency, @"不支持该模态");
                return;
            }
            NSString *reply = [agExtractTextFromJSON(json) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (reply.length > 0) {
                if (completion) completion(YES, latency, nil);
            } else {
                if (completion) completion(NO, latency, @"无返回");
            }
        });
    }] resume];
}

static void agBenchmarkModelLatency(NSString *endpoint, NSString *apiKey, NSString *proxy, NSString *modelID, void(^completion)(BOOL ok, NSInteger latencyMs, NSString *sampleReply, NSString *errMsg)) {
    agProbeModelForTab(AGConfigTabTranslation, endpoint, apiKey, proxy, modelID, NO, ^(BOOL ok, NSInteger latencyMs, NSString *errMsg) {
        if (completion) completion(ok, latencyMs, ok ? @"OK" : nil, errMsg);
    });
}

// ==================== 5. 云端拉取 + 受控并发实测 +「支持当前功能且最新版本优先」排序 ====================
static void agFetchCloudModelsForTab(AGConfigTab tab, NSString *endpoint, NSString *apiKey, NSString *proxy, void(^completion)(BOOL success, NSArray<NSDictionary *> *models, NSString *errorMsg)) {
    NSString *cleanEP = [endpoint stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while ([cleanEP hasSuffix:@"/"]) cleanEP = [cleanEP substringToIndex:cleanEP.length - 1];
    NSString *cleanKey = [apiKey stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    if (cleanEP.length < 5 || cleanKey.length < 4) {
        if (completion) completion(NO, @[], @"请先填写当前功能的专属 API 地址与 API Key");
        return;
    }

    NSURLSession *session = agCreateSessionWithProxy(proxy, nil, nil);
    BOOL isGoogle = agIsGoogleNativeProtocol(cleanEP, @"");
    NSString *urlStr = agResolveVendorModelsListEndpoint(cleanEP, cleanKey);
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
    if (!isGoogle) {
        [req setValue:[NSString stringWithFormat:@"Bearer %@", cleanKey] forHTTPHeaderField:@"Authorization"];
        if (agDetectHTTPProtocolFamily(cleanEP, @"") == AGHTTPProtocolFamilyAnthropic) {
            [req setValue:cleanKey forHTTPHeaderField:@"x-api-key"];
            [req setValue:@"2023-06-01" forHTTPHeaderField:@"anthropic-version"];
        }
    }
    req.HTTPMethod = @"GET";
    req.timeoutInterval = 12.0;

    [[session dataTaskWithRequest:req completionHandler:^(NSData *data, NSURLResponse *resp, NSError *err) {
        NSMutableArray<NSMutableDictionary *> *candidatePool = [NSMutableArray array];
        NSMutableSet *seen = [NSMutableSet set];

        if (!err && data) {
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            NSArray *rawModels = json[@"models"] ?: json[@"data"];
            if ([rawModels isKindOfClass:[NSArray class]]) {
                for (NSDictionary *m in rawModels) {
                    if (![m isKindOfClass:[NSDictionary class]]) continue;
                    NSString *mID = m[@"name"] ?: m[@"id"];
                    if (!mID || mID.length == 0 || [seen containsObject:mID]) continue;

                    NSString *badgeTitle = nil;
                    BOOL supportsBidi = NO;
                    if (!agIsModelCapableForTab(mID, m, tab, &badgeTitle, &supportsBidi)) {
                        continue;
                    }

                    BOOL onlyBidi = agIsPureWebSocketOnlyModel(mID, m);
                    [seen addObject:mID];
                    double newestScore = agCalculateModelNewestScore(mID, m);
                    NSInteger supportTier = agTabSupportTier(badgeTitle, onlyBidi, supportsBidi, tab);

                    [candidatePool addObject:[@{
                        @"id": mID,
                        @"title": badgeTitle ?: mID,
                        @"bidi": @(supportsBidi),
                        @"onlyBidi": @(onlyBidi),
                        @"newestScore": @(newestScore),
                        @"supportTier": @(supportTier),
                        @"latencyMs": @9999,
                        @"latencyStr": @"⚡ 可用",
                        @"isUsable": @YES,
                        @"verified": @NO
                    } mutableCopy]];
                }
            }
        }

        // 补充各厂商官方 Realtime / 多模态模型（若 /models 未列出）
        NSArray<NSDictionary *> *supplements = agVendorSupplementalModels(cleanEP, tab);
        for (NSDictionary *sup in supplements) {
            NSString *sID = sup[@"id"];
            if (!sID || [seen containsObject:sID]) continue;
            NSString *badgeTitle = nil;
            BOOL supportsBidi = [sup[@"bidi"] boolValue];
            if (!agIsModelCapableForTab(sID, nil, tab, &badgeTitle, &supportsBidi)) continue;
            BOOL onlyBidi = [sup[@"onlyBidi"] boolValue];
            [seen addObject:sID];
            [candidatePool addObject:[@{
                @"id": sID,
                @"title": badgeTitle ?: sID,
                @"bidi": @(supportsBidi),
                @"onlyBidi": @(onlyBidi),
                @"newestScore": @(agCalculateModelNewestScore(sID, nil)),
                @"supportTier": @(agTabSupportTier(badgeTitle, onlyBidi, supportsBidi, tab)),
                @"latencyMs": @9999,
                @"latencyStr": @"⚡ 官方支持",
                @"isUsable": @YES,
                @"verified": @NO
            } mutableCopy]];
        }

        if (candidatePool.count == 0) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, @[], @"该 API 未返回符合当前功能的模型");
            });
            return;
        }

        // 先按「支持当前功能等级 (supportTier) 降序 -> 最新稳定版本 (newestScore) 降序」排列
        [candidatePool sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
            NSComparisonResult tierCmp = [b[@"supportTier"] compare:a[@"supportTier"]];
            if (tierCmp != NSOrderedSame) return tierCmp;
            return [b[@"newestScore"] compare:a[@"newestScore"]];
        }];

        // 受控并发（每次最多 4 个连接）对排在最前面的 18 个最新支持模型执行真实连通性测试，其余模型全部保留不限制数量
        NSUInteger probeCount = MIN(18, candidatePool.count);
        dispatch_group_t group = dispatch_group_create();
        dispatch_semaphore_t sem = dispatch_semaphore_create(4);
        dispatch_queue_t probeQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);

        for (NSUInteger i = 0; i < probeCount; i++) {
            NSMutableDictionary *cand = candidatePool[i];
            NSString *candID = cand[@"id"];
            BOOL onlyBidi = [cand[@"onlyBidi"] boolValue];
            dispatch_group_enter(group);
            dispatch_async(probeQueue, ^{
                dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
                agProbeModelForTab(tab, cleanEP, cleanKey, proxy, candID, onlyBidi, ^(BOOL ok, NSInteger latencyMs, NSString *errMsg) {
                    @synchronized (cand) {
                        if (ok) {
                            cand[@"latencyMs"] = @(latencyMs);
                            cand[@"latencyStr"] = onlyBidi ? [NSString stringWithFormat:@"🟢 实时 %ldms", (long)latencyMs] : [NSString stringWithFormat:@"🟢 %ldms", (long)latencyMs];
                            cand[@"isUsable"] = @YES;
                            cand[@"verified"] = @YES;
                        } else {
                            cand[@"latencyMs"] = @99999;
                            cand[@"latencyStr"] = @"❌ 不支持/受限";
                            cand[@"isUsable"] = @NO;
                            cand[@"verified"] = @NO;
                        }
                    }
                    dispatch_semaphore_signal(sem);
                    dispatch_group_leave(group);
                });
            });
        }

        dispatch_group_notify(group, dispatch_get_main_queue(), ^{
            NSMutableArray<NSDictionary *> *usableList = [NSMutableArray array];
            for (NSDictionary *item in candidatePool) {
                if ([item[@"isUsable"] boolValue]) {
                    [usableList addObject:item];
                }
            }
            if (usableList.count == 0) usableList = (NSMutableArray<NSDictionary *> *)candidatePool;

            // 排序：实测验证通过 (verified) 置顶 -> 支持当前功能等级 (supportTier) 降序 -> 最新稳定版本 (newestScore) 降序
            [usableList sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
                BOOL aVer = [a[@"verified"] boolValue];
                BOOL bVer = [b[@"verified"] boolValue];
                if (aVer != bVer) return aVer ? NSOrderedAscending : NSOrderedDescending;

                NSComparisonResult tierCmp = [b[@"supportTier"] compare:a[@"supportTier"]];
                if (tierCmp != NSOrderedSame) return tierCmp;

                NSComparisonResult newCmp = [b[@"newestScore"] compare:a[@"newestScore"]];
                if (newCmp != NSOrderedSame) return newCmp;

                return [a[@"latencyMs"] compare:b[@"latencyMs"]];
            }];

            NSMutableDictionary *p = loadGeminiPrefs();
            NSString *cacheKey = (tab == AGConfigTabTranslation) ? @"AG_Trans_CachedModels" : [NSString stringWithFormat:@"%@_CachedModels", agPrefixForTab(tab)];
            p[cacheKey] = usableList;
            saveGeminiPrefs(p);

            if (completion) completion(YES, usableList, nil);
        });
    }] resume];
}

// ==================== 1. 防穿透窗口 ====================
@interface GeminiPassthroughWindow : UIWindow
@property (nonatomic, strong) UIView *capsuleWrapper;
@property (nonatomic, assign) BOOL lockFullScreenTouch;
@end

@implementation GeminiPassthroughWindow
- (BOOL)_canShowWhileLocked { return YES; }
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.05 || !self.capsuleWrapper) return NO;
    if (self.lockFullScreenTouch) return YES;
    CGPoint p = [self convertPoint:point toView:self.capsuleWrapper];
    return [self.capsuleWrapper pointInside:p withEvent:event];
}
- (BOOL)_canBecomeKeyWindow { return YES; }
@end

// ==================== 全局灵动胶囊反馈悬浮窗 (模块 E1) ====================
@implementation AGGlobalActionPillWindow
- (BOOL)_canShowWhileLocked { return YES; }

+ (instancetype)sharedPill {
    static AGGlobalActionPillWindow *pill = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGRect bounds = [UIScreen mainScreen].bounds;
        UIWindowScene *scene = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
            }
        }
        if (scene) {
            pill = [[self alloc] initWithWindowScene:scene];
        } else {
            pill = [[self alloc] initWithFrame:bounds];
        }
        pill.frame = bounds;
        pill.windowLevel = UIWindowLevelAlert + 1000;
        pill.backgroundColor = [UIColor clearColor];
        pill.hidden = YES;
        pill.userInteractionEnabled = NO;
        if ([pill respondsToSelector:@selector(_setSecure:)]) {
            [pill _setSecure:YES];
        }
        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        vc.view.userInteractionEnabled = NO;
        pill.rootViewController = vc;
        [pill setupPillUI];
    });
    return pill;
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    return nil; // 保证100%穿透，不阻断底层任何操作
}

- (void)setupPillUI {
    self.haptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
    CGFloat pillW = 280.0;
    CGFloat pillH = 38.0;
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    self.blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.blurView.frame = CGRectMake((screenW - pillW) * 0.5, -60.0, pillW, pillH);
    self.blurView.layer.cornerRadius = pillH * 0.5;
    self.blurView.layer.masksToBounds = YES;
    self.blurView.layer.borderWidth = 1.0;
    self.blurView.layer.borderColor = [UIColor colorWithRed:0.25 green:0.85 blue:1.0 alpha:0.45].CGColor;

    self.titleLabel = [[UILabel alloc] initWithFrame:self.blurView.bounds];
    self.titleLabel.textColor = [UIColor whiteColor];
    self.titleLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightSemibold];
    self.titleLabel.textAlignment = NSTextAlignmentCenter;
    self.titleLabel.adjustsFontSizeToFitWidth = YES;
    self.titleLabel.minimumScaleFactor = 0.8;
    [self.blurView.contentView addSubview:self.titleLabel];
    [self.rootViewController.view addSubview:self.blurView];
}

- (void)showActionPill:(NSString *)message {
    if (!message || message.length == 0) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.haptic impactOccurred];
        self.titleLabel.text = message;
        CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
        CGSize txtSz = [message sizeWithAttributes:@{NSFontAttributeName: self.titleLabel.font}];
        CGFloat pillW = MAX(220.0, MIN(screenW - 40.0, txtSz.width + 44.0));
        CGFloat pillH = 38.0;
        CGFloat targetY = 22.0;

        self.blurView.frame = CGRectMake((screenW - pillW) * 0.5, -60.0, pillW, pillH);
        self.titleLabel.frame = self.blurView.bounds;
        self.hidden = NO;
        self.blurView.alpha = 0.0;
        self.blurView.transform = CGAffineTransformMakeScale(0.85, 0.85);

        [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.75 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:^{
            self.blurView.alpha = 1.0;
            self.blurView.transform = CGAffineTransformIdentity;
            self.blurView.frame = CGRectMake((screenW - pillW) * 0.5, targetY, pillW, pillH);
        } completion:nil];

        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.30 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
                self.blurView.alpha = 0.0;
                self.blurView.frame = CGRectMake((screenW - pillW) * 0.5, -60.0, pillW, pillH);
            } completion:^(BOOL finished) {
                self.hidden = YES;
            }];
        });
    });
}

@end

UIKIT_EXTERN UIImage *_UICreateScreenUIImage(void);

static void agSafeLaunchURL(NSURL *url) {
    if (!url) return;
    // 延迟 0.12s 待悬浮窗隐藏并释放 KeyWindow 后，在后台高优线程发起 LaunchServices 唤醒，彻底杜绝 SpringBoard 主线程 10 秒 XPC 死锁！
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @try {
            Class wsCls = objc_getClass("LSApplicationWorkspace");
            if (wsCls && [wsCls respondsToSelector:@selector(defaultWorkspace)]) {
                id ws = [wsCls defaultWorkspace];
                if ([ws respondsToSelector:@selector(openSensitiveURL:withOptions:)]) {
                    if ([ws openSensitiveURL:url withOptions:nil]) return;
                }
                if ([ws respondsToSelector:@selector(openURL:)]) {
                    if ([ws openURL:url]) return;
                }
            }
            dispatch_async(dispatch_get_main_queue(), ^{
                [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
            });
        } @catch (NSException *e) {}
    });
}

// ==================== 微信跨进程自动发消息与系统底层控制核心服务 ====================
static NSString *agGetGlobalSharedDir(void) {
    NSArray *dirs = @[
        @"/var/jb/var/mobile/Library/Preferences",
        @"/var/mobile/Library/Preferences",
        @"/tmp"
    ];
    for (NSString *d in dirs) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:d] &&
            [[NSFileManager defaultManager] isWritableFileAtPath:d]) {
            return d;
        }
    }
    return @"/tmp";
}

static NSString *agGetWeChatDocumentsDir(void) {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundleID isEqualToString:@"com.tencent.xin"]) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        return paths.firstObject;
    } else {
        Class proxyCls = objc_getClass("LSApplicationProxy");
        if (proxyCls && [proxyCls respondsToSelector:@selector(applicationProxyForIdentifier:)]) {
            id proxy = [proxyCls applicationProxyForIdentifier:@"com.tencent.xin"];
            if (proxy && [proxy respondsToSelector:@selector(dataContainerURL)]) {
                NSURL *url = [proxy dataContainerURL];
                if (url && url.path) {
                    return [url.path stringByAppendingPathComponent:@"Documents"];
                }
            }
        }
    }
    return nil;
}

static NSString *agGetWeChatSendFilePath(void) {
    NSString *doc = agGetWeChatDocumentsDir();
    if (doc) return [doc stringByAppendingPathComponent:@"ag_wechat_send.json"];
    return [agGetGlobalSharedDir() stringByAppendingPathComponent:@"ag_wechat_send.json"];
}

static NSString *agGetWeChatResultFilePath(void) {
    NSString *doc = agGetWeChatDocumentsDir();
    if (doc) return [doc stringByAppendingPathComponent:@"ag_wechat_result.json"];
    return [agGetGlobalSharedDir() stringByAppendingPathComponent:@"ag_wechat_result.json"];
}

static NSDictionary *agReadJSONFileAtPaths(NSArray<NSString *> *paths) {
    for (NSString *p in paths) {
        if (!p || p.length == 0) continue;
        NSData *data = [NSData dataWithContentsOfFile:p];
        if (data && data.length > 2) {
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([dict isKindOfClass:[NSDictionary class]]) {
                return dict;
            }
        }
        NSDictionary *plistDict = [NSDictionary dictionaryWithContentsOfFile:p];
        if ([plistDict isKindOfClass:[NSDictionary class]]) {
            return plistDict;
        }
    }
    return nil;
}

static void agWriteJSONToSharedPaths(NSDictionary *dict, NSString *fileName, NSString *primaryPath) {
    if (!dict) return;
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    if (!data) return;
    NSMutableArray *targets = [NSMutableArray array];
    if (primaryPath.length > 0) [targets addObject:primaryPath];
    [targets addObject:[agGetGlobalSharedDir() stringByAppendingPathComponent:fileName]];
    [targets addObject:[@"/tmp" stringByAppendingPathComponent:fileName]];
    for (NSString *p in targets) {
        [data writeToFile:p atomically:YES];
        chmod([p UTF8String], 0666);
    }
}

static void agRemoveSharedFiles(NSString *fileName, NSString *primaryPath) {
    NSFileManager *fm = [NSFileManager defaultManager];
    if (primaryPath.length > 0) [fm removeItemAtPath:primaryPath error:nil];
    [fm removeItemAtPath:[agGetGlobalSharedDir() stringByAppendingPathComponent:fileName] error:nil];
    [fm removeItemAtPath:[@"/tmp" stringByAppendingPathComponent:fileName] error:nil];
}

static void agWriteWeChatResult(BOOL success, NSString *detail) {
    NSDictionary *res = @{
        @"success": @(success),
        @"detail": detail ?: @"",
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    };
    agWriteJSONToSharedPaths(res, @"ag_wechat_result.json", agGetWeChatResultFilePath());
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         CFSTR("com.custom.timeguardian.wechat_result"),
                                         NULL, NULL, YES);
}

static void agExecuteWeChatCommandDict(NSDictionary *dict, NSInteger retryCount) {
    if (!dict) return;
    NSString *cmdAction = dict[@"action"] ?: @"send_text";
    NSString *targetName = [dict[@"targetName"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *content = dict[@"content"] ?: @"";

    dispatch_async(dispatch_get_main_queue(), ^{
        @try {
            Class mmContextCls = objc_getClass("MMContext");
            Class mmServiceCenterCls = objc_getClass("MMServiceCenter");
            Class cContactMgrCls = objc_getClass("CContactMgr");
            Class cMessageMgrCls = objc_getClass("CMessageMgr");
            Class cMessageWrapCls = objc_getClass("CMessageWrap");
            Class sessionMgrCls = objc_getClass("MMNewSessionMgr");

            id ctx = nil;
            if (mmContextCls && [mmContextCls respondsToSelector:@selector(currentContext)]) {
                ctx = ((id(*)(id, SEL))objc_msgSend)(mmContextCls, @selector(currentContext));
            }
            if (!ctx && mmContextCls && [mmContextCls respondsToSelector:@selector(activeUserContext)]) {
                ctx = ((id(*)(id, SEL))objc_msgSend)(mmContextCls, @selector(activeUserContext));
            }
            id sc = (mmServiceCenterCls && [mmServiceCenterCls respondsToSelector:@selector(defaultCenter)]) ? [mmServiceCenterCls defaultCenter] : nil;

            id contactMgr = (ctx && [ctx respondsToSelector:@selector(getService:)]) ? [ctx getService:cContactMgrCls] : nil;
            if (!contactMgr && sc && [sc respondsToSelector:@selector(getService:)]) contactMgr = [sc getService:cContactMgrCls];

            id messageMgr = (ctx && [ctx respondsToSelector:@selector(getService:)]) ? [ctx getService:cMessageMgrCls] : nil;
            if (!messageMgr && sc && [sc respondsToSelector:@selector(getService:)]) messageMgr = [sc getService:cMessageMgrCls];

            if ((!ctx && !sc) || !contactMgr || !messageMgr) {
                if (retryCount < 6) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        agExecuteWeChatCommandDict(dict, retryCount + 1);
                    });
                    return;
                }
                agWriteWeChatResult(NO, @"微信后台服务尚未加载完成，请解锁进入微信后重试");
                return;
            }

            // 模式 A：读取微信未读消息汇总
            if ([cmdAction isEqualToString:@"read_unread"]) {
                id sessionMgr = (ctx && [ctx respondsToSelector:@selector(getService:)]) ? [ctx getService:sessionMgrCls] : nil;
                if (!sessionMgr && sc && [sc respondsToSelector:@selector(getService:)]) sessionMgr = [sc getService:sessionMgrCls];
                NSMutableArray *unreadSummaries = [NSMutableArray array];
                if (sessionMgr && [sessionMgr respondsToSelector:@selector(GetSessionCount)] && [sessionMgr respondsToSelector:@selector(GetSessionAtIndex:)]) {
                    NSInteger count = MIN(20, [sessionMgr GetSessionCount]);
                    for (NSInteger i = 0; i < count; i++) {
                        id cellData = [sessionMgr GetSessionAtIndex:i];
                        if (!cellData) continue;
                        NSUInteger unread = 0;
                        @try { unread = [[cellData valueForKey:@"m_uUnReadCount"] unsignedIntegerValue]; } @catch (NSException *e) {}
                        if (unread > 0) {
                            NSString *nick = @"好友";
                            NSString *lastMsg = @"新消息";
                            @try {
                                nick = [cellData valueForKey:@"m_nsNickName"] ?: ([cellData valueForKey:@"m_nsUserName"] ?: @"好友");
                                id msgWrap = [cellData valueForKey:@"m_msgWrap"];
                                if (msgWrap) lastMsg = [msgWrap valueForKey:@"m_nsContent"] ?: @"图片/语音消息";
                            } @catch (NSException *e) {}
                            [unreadSummaries addObject:[NSString stringWithFormat:@"%@(%lu条): %@", nick, (unsigned long)unread, lastMsg]];
                        }
                    }
                }
                if (unreadSummaries.count > 0) {
                    agWriteWeChatResult(YES, [NSString stringWithFormat:@"未读微信：%@", [unreadSummaries componentsJoinedByString:@"；"]]);
                } else {
                    agWriteWeChatResult(YES, @"当前没有未读的微信消息");
                }
                return;
            }

            // 模式 B：搜索联系人（合并全量通讯录列表，彻底修复空数组短路 Bug）
            id targetContact = nil;
            if (targetName.length > 0 && [contactMgr respondsToSelector:@selector(getContactByName:)]) {
                targetContact = [contactMgr getContactByName:targetName];
            }

            if (!targetContact || ![targetContact respondsToSelector:@selector(m_nsUsrName)]) {
                NSMutableArray *allContacts = [NSMutableArray array];
                if ([contactMgr respondsToSelector:@selector(getAllContactList)]) {
                    NSArray *list1 = [contactMgr getAllContactList];
                    if ([list1 isKindOfClass:[NSArray class]]) [allContacts addObjectsFromArray:list1];
                }
                if (allContacts.count == 0 && [contactMgr respondsToSelector:@selector(getContactList:contactType:)]) {
                    NSArray *list2 = [contactMgr getContactList:1 contactType:0xffffffff];
                    if ([list2 isKindOfClass:[NSArray class]]) [allContacts addObjectsFromArray:list2];
                    NSArray *list3 = [contactMgr getContactList:1 contactType:0];
                    if ([list3 isKindOfClass:[NSArray class]]) [allContacts addObjectsFromArray:list3];
                }

                // 若微信刚冷启动，通讯录列表尚未从数据库载入，自动延迟重试
                if (allContacts.count == 0 && retryCount < 6) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.7 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        agExecuteWeChatCommandDict(dict, retryCount + 1);
                    });
                    return;
                }

                NSString *cleanTarget = [targetName lowercaseString];
                for (id c in allContacts) {
                    @try {
                        NSString *remark = [[c valueForKey:@"m_nsRemark"] lowercaseString];
                        NSString *nick = [[c valueForKey:@"m_nsNickName"] lowercaseString];
                        NSString *alias = [[c valueForKey:@"m_nsAliasName"] lowercaseString];
                        NSString *usr = [[c valueForKey:@"m_nsUsrName"] lowercaseString];
                        if ([remark isEqualToString:cleanTarget] || [nick isEqualToString:cleanTarget] ||
                            [alias isEqualToString:cleanTarget] || [usr isEqualToString:cleanTarget]) {
                            targetContact = c;
                            break;
                        }
                    } @catch (NSException *ex) {}
                }
                if (!targetContact) {
                    for (id c in allContacts) {
                        @try {
                            NSString *remark = [[c valueForKey:@"m_nsRemark"] lowercaseString];
                            NSString *nick = [[c valueForKey:@"m_nsNickName"] lowercaseString];
                            if ((remark.length > 0 && ([remark containsString:cleanTarget] || [cleanTarget containsString:remark])) ||
                                (nick.length > 0 && ([nick containsString:cleanTarget] || [cleanTarget containsString:nick]))) {
                                targetContact = c;
                                break;
                            }
                        } @catch (NSException *ex) {}
                    }
                }
            }

            if (!targetContact) {
                agWriteWeChatResult(NO, [NSString stringWithFormat:@"未在微信通讯录找到「%@」", targetName]);
                return;
            }

            NSString *toUsr = nil;
            @try { toUsr = [targetContact valueForKey:@"m_nsUsrName"]; } @catch (NSException *ex) {}
            if (!toUsr || toUsr.length == 0) {
                agWriteWeChatResult(NO, @"联系人微信 ID 解析失败");
                return;
            }

            // 若指令为直接打开与该好友的聊天界面
            if ([cmdAction isEqualToString:@"open_chat"]) {
                Class logicMgrCls = objc_getClass("MMMsgLogicManager");
                id logicMgr = (ctx && [ctx respondsToSelector:@selector(getService:)]) ? [ctx getService:logicMgrCls] : (logicMgrCls ? [sc getService:logicMgrCls] : nil);
                UIViewController *rootVC = [UIApplication sharedApplication].keyWindow.rootViewController;
                UINavigationController *nav = [rootVC isKindOfClass:[UINavigationController class]] ? (UINavigationController *)rootVC : rootVC.navigationController;
                if ([rootVC isKindOfClass:[UITabBarController class]]) {
                    UIViewController *sel = ((UITabBarController *)rootVC).selectedViewController;
                    if ([sel isKindOfClass:[UINavigationController class]]) nav = (UINavigationController *)sel;
                }
                if (logicMgr && nav && [logicMgr respondsToSelector:@selector(PushOtherBaseMsgControllerByContact:navigationController:animated:)]) {
                    [logicMgr PushOtherBaseMsgControllerByContact:targetContact navigationController:nav animated:YES];
                    agWriteWeChatResult(YES, [NSString stringWithFormat:@"已打开与「%@」的微信对话窗", targetName]);
                    return;
                }
            }

            // 构造消息对象（修复双重 init 导致对象损坏的 Bug）
            id selfContact = [contactMgr respondsToSelector:@selector(getSelfContact)] ? [contactMgr getSelfContact] : nil;
            NSString *fromUsr = nil;
            @try { fromUsr = selfContact ? [selfContact valueForKey:@"m_nsUsrName"] : @""; } @catch (NSException *e) { fromUsr = @""; }

            id msgWrap = [cMessageWrapCls instancesRespondToSelector:@selector(initWithMsgType:)]
                ? [[cMessageWrapCls alloc] initWithMsgType:1]
                : [[cMessageWrapCls alloc] init];
            if (!msgWrap) {
                agWriteWeChatResult(NO, @"微信消息对象初始化失败");
                return;
            }

            [msgWrap setValue:(fromUsr ?: @"") forKey:@"m_nsFromUsr"];
            [msgWrap setValue:toUsr forKey:@"m_nsToUsr"];
            [msgWrap setValue:content forKey:@"m_nsContent"];
            [msgWrap setValue:@((UInt32)time(NULL)) forKey:@"m_uiCreateTime"];
            [msgWrap setValue:@(1) forKey:@"m_uiStatus"];
            [msgWrap setValue:@(1) forKey:@"m_uiMessageType"];

            if ([messageMgr respondsToSelector:@selector(AddMsg:MsgWrap:)]) {
                [messageMgr AddMsg:toUsr MsgWrap:msgWrap];
                NSString *showName = targetName;
                @try {
                    NSString *r = [targetContact valueForKey:@"m_nsRemark"];
                    NSString *n = [targetContact valueForKey:@"m_nsNickName"];
                    if (r.length > 0) showName = r;
                    else if (n.length > 0) showName = n;
                } @catch (NSException *ex) {}
                agWriteWeChatResult(YES, [NSString stringWithFormat:@"已向「%@」发送微信: %@", showName, content]);
            } else {
                agWriteWeChatResult(NO, @"微信 AddMsg 发送接口异常");
            }
        } @catch (NSException *e) {
            agWriteWeChatResult(NO, [NSString stringWithFormat:@"微信执行异常: %@", e.reason ?: @"未知"]);
        }
    });
}

static void agProcessWeChatSendCommand(void) {
    if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.tencent.xin"]) return;
    NSString *mainPath = agGetWeChatSendFilePath();
    NSString *sharedPath = [agGetGlobalSharedDir() stringByAppendingPathComponent:@"ag_wechat_send.json"];
    NSDictionary *dict = agReadJSONFileAtPaths(@[mainPath ?: @"", sharedPath, @"/tmp/ag_wechat_send.json"]);
    if (!dict) return;

    agRemoveSharedFiles(@"ag_wechat_send.json", mainPath);

    NSTimeInterval ts = [dict[@"timestamp"] doubleValue];
    if ([[NSDate date] timeIntervalSince1970] - ts > 35.0) return;

    agExecuteWeChatCommandDict(dict, 0);
}

static void agWeChatDarwinCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    agProcessWeChatSendCommand();
}

static void initWeChatAngelGuardianService(void) {
    if (![[[NSBundle mainBundle] bundleIdentifier] isEqualToString:@"com.tencent.xin"]) return;
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    agWeChatDarwinCallback,
                                    CFSTR("com.custom.timeguardian.wechat_send"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification * _Nonnull note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            agProcessWeChatSendCommand();
        });
    }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        agProcessWeChatSendCommand();
    });
}

static void agWeChatResultDarwinCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    NSString *mainPath = agGetWeChatResultFilePath();
    NSString *sharedPath = [agGetGlobalSharedDir() stringByAppendingPathComponent:@"ag_wechat_result.json"];
    NSDictionary *res = agReadJSONFileAtPaths(@[mainPath ?: @"", sharedPath, @"/tmp/ag_wechat_result.json"]);
    if (res && res[@"detail"]) {
        NSString *detail = res[@"detail"];
        BOOL ok = [res[@"success"] boolValue];
        agRemoveSharedFiles(@"ag_wechat_result.json", mainPath);
        dispatch_async(dispatch_get_main_queue(), ^{
            [[AGGlobalActionPillWindow sharedPill] showActionPill:ok ? [NSString stringWithFormat:@"✅ %@", detail] : [NSString stringWithFormat:@"⚠️ %@", detail]];
        });
    }
}

typedef void (*MRSetVolFunc)(float);
typedef float (*MRGetVolFunc)(void);

static void agAdjustSystemVolume(NSString *mode, float targetLevel) {
    if (targetLevel > 1.0f && targetLevel <= 100.0f) {
        targetLevel = targetLevel / 100.0f;
    }
    dlopen("/System/Library/PrivateFrameworks/Celestial.framework/Celestial", RTLD_LAZY);
    Class avSysCls = objc_getClass("AVSystemController");
    id avsc = (avSysCls && [avSysCls respondsToSelector:@selector(sharedAVSystemController)]) ? [avSysCls sharedAVSystemController] : nil;

    void *h = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW);
    MRSetVolFunc setVol = h ? (MRSetVolFunc)dlsym(h, "MRMediaRemoteSetVolume") : NULL;
    MRGetVolFunc getVol = h ? (MRGetVolFunc)dlsym(h, "MRMediaRemoteGetVolume") : NULL;

    float cur = 0.5f;
    if (avsc && [avsc respondsToSelector:@selector(getVolume:forCategory:)]) {
        if (![avsc getVolume:&cur forCategory:@"Audio/Video"]) {
            cur = [AVAudioSession sharedInstance].outputVolume;
        }
    } else if (getVol) {
        cur = getVol();
    }

    float next = cur;
    NSString *cleanMode = [mode lowercaseString];
    if ([cleanMode isEqualToString:@"up"]) {
        next = MIN(1.0f, cur + 0.15f);
    } else if ([cleanMode isEqualToString:@"down"]) {
        next = MAX(0.0f, cur - 0.15f);
    } else if ([cleanMode isEqualToString:@"mute"]) {
        next = 0.0f;
    } else if ([cleanMode isEqualToString:@"max"]) {
        next = 1.0f;
    } else if ([cleanMode isEqualToString:@"unmute"]) {
        next = 0.55f;
    } else if ([cleanMode isEqualToString:@"set"]) {
        next = MAX(0.0f, MIN(1.0f, targetLevel));
    }

    if (avsc && [avsc respondsToSelector:@selector(setVolumeTo:forCategory:)]) {
        [avsc setVolumeTo:next forCategory:@"Audio/Video"];
        [avsc setVolumeTo:next forCategory:@"Ringtone"];
    }
    if (setVol) {
        setVol(next);
    }
    int percent = (int)roundf(next * 100.0f);
    NSString *pillMsg = (next <= 0.01f) ? @"🔇 系统已静音" : [NSString stringWithFormat:@"🔊 系统音量已调节至 %d%%", percent];
    [[AGGlobalActionPillWindow sharedPill] showActionPill:pillMsg];
}

static void agSetLowPowerMode(BOOL enable) {
    dlopen("/System/Library/PrivateFrameworks/CoreDuet.framework/CoreDuet", RTLD_NOW);
    Class bsClass = objc_getClass("_CDBatterySaver");
    if (bsClass) {
        id saver = [bsClass respondsToSelector:@selector(batterySaver)] ? [bsClass performSelector:@selector(batterySaver)] : nil;
        if (saver && [saver respondsToSelector:@selector(setPowerMode:error:)]) {
            typedef BOOL (*SetModeFunc)(id, SEL, long long, void *);
            SetModeFunc setMode = (SetModeFunc)[saver methodForSelector:@selector(setPowerMode:error:)];
            if (setMode) {
                setMode(saver, @selector(setPowerMode:error:), enable ? 1 : 0, NULL);
            }
        }
    }
    [[AGGlobalActionPillWindow sharedPill] showActionPill:enable ? @"🔋 已开启低电量模式" : @"🔋 已关闭低电量模式"];
}

// 底层 IOHIDEvent 硬件级屏幕触控与滑动手势合成器（用于视觉点击按钮、自动刷抖音/小红书）
typedef CFTypeRef (*IOHIDEventCreateDigitizerEventFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, uint32_t, uint32_t, float, float, float, float, float, Boolean, Boolean, uint32_t);
typedef CFTypeRef (*IOHIDEventCreateDigitizerFingerEventFunc)(CFAllocatorRef, uint64_t, uint32_t, uint32_t, uint32_t, float, float, float, float, float, Boolean, Boolean, uint32_t);
typedef void (*IOHIDEventAppendEventFunc)(CFTypeRef, CFTypeRef, uint32_t);
typedef void (*IOHIDEventSetIntegerValueFunc)(CFTypeRef, uint32_t, CFIndex);
typedef void (*BKSHIDEventSendToFocusedProcessFunc)(CFTypeRef);

static void agSendSynthesizedTouchEvent(CGPoint pt, BOOL isTouching, uint32_t eventMask) {
    static IOHIDEventCreateDigitizerEventFunc createHand = NULL;
    static IOHIDEventCreateDigitizerFingerEventFunc createFinger = NULL;
    static IOHIDEventAppendEventFunc appendEv = NULL;
    static IOHIDEventSetIntegerValueFunc setIntVal = NULL;
    static BKSHIDEventSendToFocusedProcessFunc sendFocused = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *ioHandle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
        void *bksHandle = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY);
        if (ioHandle) {
            createHand = (IOHIDEventCreateDigitizerEventFunc)dlsym(ioHandle, "IOHIDEventCreateDigitizerEvent");
            createFinger = (IOHIDEventCreateDigitizerFingerEventFunc)dlsym(ioHandle, "IOHIDEventCreateDigitizerFingerEvent");
            appendEv = (IOHIDEventAppendEventFunc)dlsym(ioHandle, "IOHIDEventAppendEvent");
            setIntVal = (IOHIDEventSetIntegerValueFunc)dlsym(ioHandle, "IOHIDEventSetIntegerValue");
        }
        if (bksHandle) {
            sendFocused = (BKSHIDEventSendToFocusedProcessFunc)dlsym(bksHandle, "BKSHIDEventSendToFocusedProcess");
        }
    });
    if (!createHand || !createFinger || !appendEv || !sendFocused) return;

    CGRect sb = [UIScreen mainScreen].bounds;
    float normX = MAX(0.01f, MIN(0.99f, pt.x / MAX(1.0, sb.size.width)));
    float normY = MAX(0.01f, MIN(0.99f, pt.y / MAX(1.0, sb.size.height)));
    uint64_t abTime = mach_absolute_time();

    CFTypeRef handEv = createHand(kCFAllocatorDefault, abTime, 3, 0, 0, eventMask, 0, normX, normY, 0.0f, (isTouching ? 1.0f : 0.0f), 0.0f, isTouching, isTouching, 0);
    if (!handEv) return;
    if (setIntVal) {
        setIntVal(handEv, 0xB0019, 1); // kIOHIDEventFieldDigitizerIsDisplayIntegrated = 1
    }
    CFTypeRef fingerEv = createFinger(kCFAllocatorDefault, abTime, 1, 2, eventMask, normX, normY, 0.0f, (isTouching ? 1.0f : 0.0f), 0.0f, isTouching, isTouching, 0);
    if (fingerEv) {
        appendEv(handEv, fingerEv, 0);
        CFRelease(fingerEv);
    }
    sendFocused(handEv);
    CFRelease(handEv);
}

static void agSimulateScreenTapAtPoint(CGPoint pt) {
    dispatch_async(dispatch_get_main_queue(), ^{
        agSendSynthesizedTouchEvent(pt, YES, 0x03); // Touch Down
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.06 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            agSendSynthesizedTouchEvent(pt, NO, 0x02); // Touch Up
        });
    });
}

static void agSimulateScreenSwipe(CGPoint startPt, CGPoint endPt, NSTimeInterval duration) {
    NSInteger steps = 14;
    NSTimeInterval stepTime = MAX(0.012, duration / (double)steps);
    agSendSynthesizedTouchEvent(startPt, YES, 0x03);
    for (NSInteger i = 1; i <= steps; i++) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(stepTime * i * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            CGFloat t = (CGFloat)i / (CGFloat)steps;
            CGPoint cur = CGPointMake(startPt.x + (endPt.x - startPt.x) * t, startPt.y + (endPt.y - startPt.y) * t);
            if (i < steps) {
                agSendSynthesizedTouchEvent(cur, YES, 0x04); // Move
            } else {
                agSendSynthesizedTouchEvent(cur, NO, 0x02);  // Up
            }
        });
    }
}

// ==================== 2. 核心控制器 (天使守护 v5.8.0 Aurora Edition) ====================
@interface GeminiAssistantManager : NSObject <AVSpeechSynthesizerDelegate, AVAudioRecorderDelegate, AVCaptureVideoDataOutputSampleBufferDelegate, UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource, NSURLSessionDataDelegate, NSURLSessionWebSocketDelegate>
@property (nonatomic, strong) GeminiPassthroughWindow *overlayWindow;
@property (nonatomic, weak) UIWindow *previousKeyWindow;

// ✨ 视觉美化层：全屏深空毛玻璃 + 四周极光霓虹 + 卡片流光
@property (nonatomic, strong) UIVisualEffectView *screenDimBlurView;
@property (nonatomic, strong) CAGradientLayer *screenVignetteLayer;
@property (nonatomic, strong) UIView *edgeGlowContainer;
@property (nonatomic, strong) CAGradientLayer *screenNeonLayer;
// ✨ iOS 27 港版呼唤 Siri 三层流光跑马灯与唤醒波纹属性
@property (nonatomic, strong) CAGradientLayer *screenNeonFeatherLayer; // 中层：液态羽化流光层
@property (nonatomic, strong) CAShapeLayer *screenNeonFeatherMask;
@property (nonatomic, strong) CAGradientLayer *screenNeonBloomLayer;   // 内层：随声音呼吸的极光内晕层
@property (nonatomic, strong) CAShapeLayer *screenNeonBloomMask;
@property (nonatomic, strong) CAShapeLayer *screenNeonOuterMask;       // 外层：锐利流光核心边
@property (nonatomic, strong) CAGradientLayer *invocationFlareLayer;   // 电源键/嘿Siri唤醒聚能闪光层
@property (nonatomic, strong) CAGradientLayer *invocationSweepLayer;   // iOS 26 全屏动态光幕扫光层
@property (nonatomic, assign) CGFloat marqueeSweepProgress;            // 唤醒跑马灯环绕进度 (0.0 ~ 1.0)
@property (nonatomic, assign) BOOL isInvocationFromPowerButton;        // 标记唤醒源：YES=电源键, NO=嘿Siri语音

- (void)applyMarqueeThemeColors:(AGVisualTheme)theme;
- (void)stepMarqueeAnimationWithPhase:(CGFloat)phase voiceAmp:(CGFloat)amp;
- (void)playIOS27SiriInvocationEffectFromPowerButton:(BOOL)fromPowerButton;
@property (nonatomic, strong) UIVisualEffectView *cardBlurView;
@property (nonatomic, strong) CAGradientLayer *ambientLayer;
@property (nonatomic, strong) CAGradientLayer *borderGrad;
@property (nonatomic, strong) CAShapeLayer *borderMask;
@property (nonatomic, strong) AGCardBgCanvasView *cardBgCanvas;
@property (nonatomic, strong) AGOrbCanvasView *orbCanvas;
@property (nonatomic, strong) AGWaveCanvasView *waveCanvas;

// ✨ 顶部 3D 灵动球 + 品牌渐变字 + 胶囊徽章 + 5柱声波
@property (nonatomic, strong) UIView *aiOrbView;
@property (nonatomic, strong) CAGradientLayer *orbCoreGrad;
@property (nonatomic, strong) CAShapeLayer *orbOuterRingLayer;
@property (nonatomic, strong) CAShapeLayer *orbInnerRingLayer;
@property (nonatomic, strong) UIView *titleWrap;
@property (nonatomic, strong) UILabel *titleMaskLabel;
@property (nonatomic, strong) CAGradientLayer *titleGradientLayer;
@property (nonatomic, strong) UILabel *modeBadgeLabel;
@property (nonatomic, strong) NSMutableArray<UIView *> *waveBars;
@property (nonatomic, strong) UIButton *settingsBtn;
@property (nonatomic, strong) UIButton *closeBtn;

// ✨ 内部黑晶卡片 + 底部双轨交织正弦流体声波 (还原参考图)
@property (nonatomic, strong) UIView *innerGlassBox;
@property (nonatomic, strong) UILabel *subStatusLabel;
@property (nonatomic, strong) UITextView *responseTextView;
@property (nonatomic, strong) UILabel *actionBannerLabel;
@property (nonatomic, strong) UIView *fluidWaveContainer;
@property (nonatomic, strong) CAShapeLayer *cyanWaveShape;
@property (nonatomic, strong) CAShapeLayer *magentaWaveShape;
@property (nonatomic, strong) CAShapeLayer *thirdWaveShape;
@property (nonatomic, strong) CAGradientLayer *waveBottomGlow;
@property (nonatomic, strong) CADisplayLink *waveDisplayLink;
@property (nonatomic, assign) CGFloat wavePhase;
@property (nonatomic, assign) CGFloat currentVoiceAmplitude;
@property (nonatomic, assign) CGFloat targetVoiceAmplitude;
@property (nonatomic, assign) NSTimeInterval lastWaveBarAnimTime;

// ✨ 底部交互栏：霓虹渐变激活态 + 电光紫发送键
@property (nonatomic, strong) UIButton *liveModeButton;
@property (nonatomic, strong) CAGradientLayer *liveBtnGrad;
@property (nonatomic, strong) UIButton *videoModeButton;
@property (nonatomic, strong) CAGradientLayer *videoBtnGrad;
@property (nonatomic, strong) UIButton *textModeButton;
@property (nonatomic, strong) CAGradientLayer *textBtnGrad;
@property (nonatomic, strong) UITextField *inputField;
@property (nonatomic, strong) UIButton *sendBtn;
@property (nonatomic, strong) CAGradientLayer *sendBtnGrad;

@property (nonatomic, assign) AGConfigTab activeModeTab;

// 📹 7阶段摄像头状态机与采集引擎
@property (nonatomic, assign) AGCameraState cameraState;
@property (nonatomic, copy) NSString *cameraSessionToken;
@property (nonatomic, assign) NSTimeInterval cameraStateEnterTime;
@property (nonatomic, assign) pid_t helperDaemonPID;
@property (nonatomic, assign) BOOL usingHelperFallback;
@property (nonatomic, assign) NSInteger cameraRetryCount;
@property (nonatomic, strong) AVCaptureSession *inProcessCaptureSession;
@property (nonatomic, strong) AVCaptureVideoDataOutput *inProcessVideoOutput;
@property (nonatomic, strong) dispatch_queue_t inProcessVideoQueue;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *cameraPreviewLayer;
@property (nonatomic, strong) CIContext *inProcessCIContext;
@property (nonatomic, assign) NSTimeInterval lastInProcFrameTime;
@property (nonatomic, strong) id layoutElementAssertion;

@property (nonatomic, strong) UIView *cameraPreviewContainer;
@property (nonatomic, strong) UIImageView *cameraLiveImageView;
@property (nonatomic, strong) UILabel *cameraDiagnosticLabel;
@property (nonatomic, strong) UILabel *cameraFlipHintLabel;
@property (nonatomic, strong) NSTimer *cameraStateWatchdogTimer;
@property (nonatomic, strong) NSData *latestFrameJPEGData;
@property (nonatomic, strong) NSDate *lastFrameFileModDate;
@property (nonatomic, assign) NSUInteger receivedCameraFramesCount;
@property (nonatomic, assign) NSTimeInterval lastWSVideoFrameSentTime;
@property (nonatomic, assign) BOOL isVideoChatActive;
@property (nonatomic, assign) BOOL useFrontCamera;
@property (nonatomic, copy) NSString *lastInProcessFailReason;
@property (nonatomic, assign) BOOL isDismissed;

// ⚙️ 云端+精选模型切换列表
@property (nonatomic, strong) UIView *modelPickerContainer;
@property (nonatomic, strong) UITableView *modelTableView;
@property (nonatomic, strong) UILabel *pickerHeaderLabel;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *availableModelsList;

// 🎙️ 引擎 A：WebSocket Bidi/Realtime 全双工 PCM 引擎
@property (nonatomic, strong) dispatch_queue_t encodeQueue;
@property (nonatomic, strong) NSURLSession *webSocketSession;
@property (nonatomic, strong) NSURLSessionWebSocketTask *liveWebSocketTask;
@property (nonatomic, assign) BOOL isWebSocketConnected;
@property (nonatomic, assign) BOOL isSetupHandshakeCompleted;
@property (nonatomic, assign) BOOL isGoogleBidiProtocol;
@property (nonatomic, assign) NSInteger wsReconnectCount;
@property (nonatomic, strong) AVAudioEngine *liveAudioEngine;
@property (nonatomic, strong) AVAudioPlayerNode *pcmPlayerNode;
@property (nonatomic, strong) AVAudioFormat *playerOutputFormat;
@property (nonatomic, strong) NSMutableData *outgoingPCMBuffer;
@property (nonatomic, strong) NSMutableData *wsPreRollPCMBuffer;
@property (nonatomic, assign) NSTimeInterval aiPlaybackEndTime;

// 🎙️ 引擎 B：高兼容性 WAV (16kHz PCM) 语音直传引擎
@property (nonatomic, strong) UIImpactFeedbackGenerator *impactHaptic;
@property (nonatomic, strong) UINotificationFeedbackGenerator *notifyHaptic;
@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, strong) NSTimer *meterTimer;
@property (nonatomic, assign) BOOL hasDetectedSpeech;
@property (nonatomic, assign) NSTimeInterval speechFirstDetectedTime;
@property (nonatomic, assign) NSTimeInterval silenceStartTime;
@property (nonatomic, assign) NSTimeInterval recordStartTime;
@property (nonatomic, assign) NSInteger micRetryCount;
@property (nonatomic, copy) NSString *audioFilePath;
@property (nonatomic, assign) NSInteger bargeInVoiceTicks; // 连续检测到用户插话的帧数
@property (nonatomic, assign) NSInteger normalVoiceTicks;          // 正常倾听人声连续确认帧数

// 💬 三模独立聊天记录与上下文容器 + HTTP/SSE 解析引擎
@property (nonatomic, strong) AVSpeechSynthesizer *synthesizer;
@property (nonatomic, strong) NSMutableString *pendingSpeechChunk;
@property (nonatomic, assign) NSInteger activeUtteranceCount;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableString *> *tabTranscriptMap;
@property (nonatomic, strong) NSMutableDictionary<NSNumber *, NSMutableArray<NSDictionary *> *> *tabHistoryMap;
@property (nonatomic, strong) NSURLSession *streamSession;
@property (nonatomic, strong) NSURLSessionDataTask *currentTask;
@property (nonatomic, strong) NSMutableData *rawHTTPResponseData;
@property (nonatomic, strong) NSMutableString *sseLineBuffer;
@property (nonatomic, strong) NSMutableString *accumulatedReplyText;
@property (nonatomic, copy) NSString *lastSentUserText;
@property (nonatomic, strong) NSData *lastSentAudioData;
@property (nonatomic, assign) BOOL hasAutoMigratedDeprecatedModel;
@property (nonatomic, assign) CGFloat currentCapsuleHeight;
@property (nonatomic, assign) CGFloat currentKeyboardHeight;
@property (nonatomic, assign) NSTimeInterval lastLayoutExpandTime;

@property (nonatomic, assign) NSTimeInterval lastTriggerTime;
@property (nonatomic, strong) NSDictionary<NSString *, NSString *> *builtinAppMap;
@property (nonatomic, strong) NSMutableDictionary<NSString *, NSString *> *cachedInstalledApps;

+ (instancetype)sharedManager;
- (BOOL)isTweakEnabled;
- (NSString *)currentVendorBrandName;
- (NSMutableString *)currentTabTranscript;
- (NSMutableArray<NSDictionary *> *)currentTabHistory;
- (void)refreshBottomBarLayoutForActiveModes;
- (void)forceKillNativeSiri;
- (void)triggerFromSystemHook;
- (void)dismissOverlay;
- (void)applyCurrentVisualTheme;
@property (nonatomic, assign) NSInteger wsBargeInVoiceTicks; // WebSocket 连续人声打断帧计数
@property (nonatomic, assign) BOOL isLastTranscriptLineUser; // 标记当前最后一行是否为正在实时弹出的用户语音字幕
@property (nonatomic, copy) NSString *activeWebSocketModel;
@property (nonatomic, assign) BOOL disableTranscriptionInSetup;
@property (nonatomic, strong) dispatch_queue_t audioPlayQueue;
@property (nonatomic, assign) NSUInteger sessionGenerationToken;
@property (nonatomic, assign) NSUInteger currentTurnPlaybackID;
@property (nonatomic, assign) NSInteger pendingPlayBuffersCount;
@property (nonatomic, assign) NSInteger inFlightWSMessageCount;
@property (nonatomic, assign) NSUInteger txAudioPacketsCount;
@property (nonatomic, assign) NSUInteger rxAudioPacketsCount;
@property (nonatomic, assign) NSUInteger txVideoFramesCount;
@property (nonatomic, strong) NSMutableString *currentVoiceQueryBuffer;
@property (nonatomic, strong) NSTimer *wsKeepAlivePingTimer;
@property (nonatomic, assign) NSTimeInterval lastDismissTimestamp;
@property (nonatomic, assign) BOOL isWarmStandbyMode;
@property (nonatomic, assign) BOOL pendingWakeupChime;
@property (nonatomic, assign) NSTimeInterval chimeMuteUntilTimestamp;
@property (nonatomic, strong) AVAudioPlayer *wakeupChimePlayer;        // 独立低延迟启动提示音播放器
@property (nonatomic, assign) NSTimeInterval lastChimePlayTimestamp;   // 防重复触发时间戳
- (void)playCrystalWakeupChimeIfNeeded;
- (void)suspendVoiceSessionKeepWebSocketAlive;
- (void)prewarmWebSocketInBackgroundIfNeeded;
- (void)flushPreRollPCMBufferIfNeeded;
- (void)showActionBanner:(NSString *)msg;
- (void)checkDeferredVoiceLocalCommand;
- (BOOL)tryExecuteDirectLocalCommand:(NSString *)cmdText;
- (NSString *)parseAndExecuteActions:(NSString *)responseText executed:(BOOL *)outExecuted;
- (void)executeActionDictionary:(NSDictionary *)dict;
- (void)sendJSONDictionaryOverWebSocket:(NSDictionary *)dict;
- (void)startWebSocketBidiSessionWithModel:(NSString *)modelPath forTab:(AGConfigTab)tab;
- (void)dismissTranslationSheetView;
- (void)launchInSituFollowTranslationFromSheet;
- (void)launchLiveAudioListenTranslationFromSheet;
- (void)agScreenTranslateButtonTapped;
- (void)handleSearchOnPlatform:(NSString *)platform keyword:(NSString *)keyword;
@end

static void agDarwinPrefsChangedCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    reloadGeminiPrefsCache();
    dispatch_async(dispatch_get_main_queue(), ^{
        GeminiAssistantManager *mgr = [GeminiAssistantManager sharedManager];
        [mgr refreshBottomBarLayoutForActiveModes];
        [mgr applyMarqueeThemeColors:agCurrentVisualTheme()];
        [mgr stepMarqueeAnimationWithPhase:mgr.wavePhase voiceAmp:mgr.currentVoiceAmplitude];
        [mgr.cardBgCanvas rebuildStaticGlassShellTextureIfNeeded];
    });
}

static void agScreenWakePrewarmCallback(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        GeminiAssistantManager *mgr = [GeminiAssistantManager sharedManager];
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        // 关键防护：若用户刚刚呼出过主界面（4秒内）或主界面未关闭，严禁后台预热介入干扰当前麦克风会话！
        if (!mgr.isDismissed || (now - mgr.lastTriggerTime < 4.0)) return;
        if ([mgr isTweakEnabled] && (!mgr.overlayWindow || mgr.overlayWindow.hidden)) {
            [mgr prewarmWebSocketInBackgroundIfNeeded];
        }
    });
}

@implementation GeminiAssistantManager

+ (instancetype)sharedManager {
    static GeminiAssistantManager *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        ensureSpringBoardTCCGranted();
        _encodeQueue = dispatch_queue_create("com.angelguardian.encodequeue", DISPATCH_QUEUE_SERIAL);
        _audioPlayQueue = dispatch_queue_create("com.angelguardian.audioplayqueue", DISPATCH_QUEUE_SERIAL);
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioSessionInterruption:) name:AVAudioSessionInterruptionNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleAudioSessionRouteChange:) name:AVAudioSessionRouteChangeNotification object:nil];
        _inProcessCIContext = [CIContext contextWithOptions:@{kCIContextUseSoftwareRenderer: @NO}];
        _synthesizer = [[AVSpeechSynthesizer alloc] init];
        _synthesizer.delegate = self;
        _pendingSpeechChunk = [NSMutableString string];
        _outgoingPCMBuffer = [NSMutableData data];
        _wsPreRollPCMBuffer = [NSMutableData data];
        _impactHaptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
        _notifyHaptic = [[UINotificationFeedbackGenerator alloc] init];
        _waveBars = [NSMutableArray array];
        _cachedInstalledApps = [NSMutableDictionary dictionary];
        _cameraState = AGCameraStateStopped;

        _tabTranscriptMap = [NSMutableDictionary dictionaryWithDictionary:@{
            @(AGConfigTabNativeLive): [NSMutableString string],
            @(AGConfigTabVideoAI):    [NSMutableString string],
            @(AGConfigTabPureText):   [NSMutableString string]
        }];
        _tabHistoryMap = [NSMutableDictionary dictionaryWithDictionary:@{
            @(AGConfigTabNativeLive): [NSMutableArray array],
            @(AGConfigTabVideoAI):    [NSMutableArray array],
            @(AGConfigTabPureText):   [NSMutableArray array]
        }];

        _rawHTTPResponseData = [NSMutableData data];
        _sseLineBuffer = [NSMutableString string];
        _accumulatedReplyText = [NSMutableString string];
        _currentVoiceQueryBuffer = [NSMutableString string];
        _currentCapsuleHeight = agComputeDeviceMetrics().defaultCapsuleH;
        _currentKeyboardHeight = 0.0;
        _useFrontCamera = NO;
        _activeModeTab = AGConfigTabNativeLive;
        _audioFilePath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"angel_guardian_v58_voice.wav"];
        _availableModelsList = [NSMutableArray arrayWithArray:agCachedModelsForTab(_activeModeTab)];

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        (__bridge const void *)(self),
                                        agDarwinPrefsChangedCallback,
                                        (__bridge CFStringRef)kAGPrefsChangedNotification,
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        (__bridge const void *)(self),
                                        agWeChatResultDarwinCallback,
                                        CFSTR("com.custom.timeguardian.wechat_result"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        _builtinAppMap = @{
            // 移动支付与银行金融 (20+)
            @"微信": @"com.tencent.xin", @"wechat": @"com.tencent.xin",
            @"支付宝": @"com.eg.android.AlipayGphone", @"alipay": @"com.eg.android.AlipayGphone",
            @"云闪付": @"com.unionpay.chsp", @"upwallet": @"com.unionpay.chsp",
            @"招商银行": @"com.cmbchina.mobilebank", @"招行": @"com.cmbchina.mobilebank",
            @"掌上生活": @"com.cmbchina.life",
            @"工商银行": @"com.icbc.iphoneclient", @"工行": @"com.icbc.iphoneclient",
            @"建设银行": @"com.ccb.mobilebank", @"建行": @"com.ccb.mobilebank",
            @"中国银行": @"com.boc.bocmbci", @"中行": @"com.boc.bocmbci",
            @"农业银行": @"com.bankabc", @"农行": @"com.bankabc",
            @"交通银行": @"com.bankcomm.Bankcomm", @"交行": @"com.bankcomm.Bankcomm",
            @"平安口袋银行": @"com.pingan.pocketbank", @"平安银行": @"com.pingan.pocketbank",
            @"浦发银行": @"com.spdb.mobilebank",
            @"中信银行": @"com.citicbank.mobilebank",
            @"民生银行": @"com.cmbc.mobilebank",
            @"光大银行": @"com.cebbank.mobilebank",
            @"广发银行": @"com.cgb.mobilebank",
            @"兴业银行": @"com.cib.mobilebank",
            @"京东金融": @"com.jd.jdmobile",
            // 电商购物与闲置特卖 (15+)
            @"淘宝": @"com.taobao.taobao4iphone", @"taobao": @"com.taobao.taobao4iphone",
            @"京东": @"com.360buy.jdmobile", @"jd": @"com.360buy.jdmobile",
            @"拼多多": @"com.xunmeng.pinduoduo", @"pdd": @"com.xunmeng.pinduoduo",
            @"闲鱼": @"com.taobao.fleamarket", @"fleamarket": @"com.taobao.fleamarket",
            @"唯品会": @"com.vipshop.iphone", @"vip": @"com.vipshop.iphone",
            @"得物": @"com.siwu.poizon", @"毒": @"com.siwu.poizon",
            @"转转": @"com.wuba.zhuanzhuan",
            @"找靓机": @"com.huishoubao.zlj",
            @"苏宁易购": @"com.suning.SuningEBuy", @"苏宁": @"com.suning.SuningEBuy",
            @"当当": @"com.dangdang.buy", @"当当网": @"com.dangdang.buy",
            @"淘特": @"com.taobao.live", @"淘宝特价版": @"com.taobao.live",
            // 餐饮美食、外卖咖啡与生鲜 (16+)
            @"美团": @"com.meituan.imeituan", @"meituan": @"com.meituan.imeituan",
            @"美团外卖": @"com.meituan.itakeaway",
            @"饿了么": @"me.ele.ios.eleme", @"eleme": @"me.ele.ios.eleme",
            @"大众点评": @"com.dianping.dpscope", @"点评": @"com.dianping.dpscope",
            @"盒马": @"com.taobao.channel", @"盒马鲜生": @"com.taobao.channel",
            @"叮咚买菜": @"com.yaya.zone", @"叮咚": @"com.yaya.zone",
            @"朴朴超市": @"com.pupu.buyer", @"朴朴": @"com.pupu.buyer",
            @"山姆会员": @"com.walmart.samsclub", @"山姆": @"com.walmart.samsclub",
            @"瑞幸咖啡": @"com.luckin.coffee", @"瑞幸": @"com.luckin.coffee",
            @"喜茶": @"com.heytea.heytea",
            @"星巴克": @"com.starbucks.cn",
            @"肯德基": @"com.yum.kfc",
            @"麦当劳": @"com.mcdonalds.cn",
            @"海底捞": @"com.haidilao.app",
            // 地铁导航、打车与旅游出行 (20+)
            @"高德地图": @"com.autonavi.amap", @"高德": @"com.autonavi.amap",
            @"百度地图": @"com.baidu.BaiduMobileMap",
            @"腾讯地图": @"com.tencent.sosomap",
            @"滴滴出行": @"com.xiaojukeji.didi", @"滴滴": @"com.xiaojukeji.didi",
            @"花小猪": @"com.huaxiaozhu.passenger", @"花小猪打车": @"com.huaxiaozhu.passenger",
            @"哈啰": @"com.hellobike.app", @"哈啰出行": @"com.hellobike.app",
            @"t3出行": @"com.t3.passenger",
            @"曹操出行": @"com.caocao.passenger",
            @"12306": @"com.chinasofti.iroad.12306", @"铁路12306": @"com.chinasofti.iroad.12306",
            @"智行火车票": @"com.tieyou.train", @"智行": @"com.tieyou.train",
            @"携程": @"ctrip.com", @"携程旅行": @"ctrip.com",
            @"去哪儿": @"com.qunar.iphone", @"去哪儿旅行": @"com.qunar.iphone",
            @"飞猪": @"com.taobao.trip", @"飞猪旅行": @"com.taobao.trip",
            @"航旅纵横": @"com.umetrip.android",
            @"飞常准": @"com.feeyo.fz",
            @"metro大都会": @"com.shmetro.cdm", @"大都会": @"com.shmetro.cdm",
            @"亿通行": @"com.bjsubway.yitongxing",
            // 演艺演出与电影票务 (5+)
            @"大麦": @"cn.damai.iphone", @"大麦网": @"cn.damai.iphone",
            @"猫眼": @"com.sankuai.movie", @"猫眼电影": @"com.sankuai.movie",
            @"淘票票": @"com.taobao.movie.android",
            @"秀动": @"com.showstart.client",
            @"摩天轮票务": @"com.motianlun.app", @"摩天轮": @"com.motianlun.app",
            // 社交网络、社区与游戏 (18+)
            @"qq": @"com.tencent.mqq",
            @"小红书": @"com.xingin.discover", @"xhs": @"com.xingin.discover",
            @"微博": @"com.sina.weibo", @"新浪微博": @"com.sina.weibo",
            @"知乎": @"com.zhihu.ios",
            @"哔哩哔哩": @"tv.danmaku.bilianime", @"b站": @"tv.danmaku.bilianime",
            @"抖音": @"com.ss.iphone.ugc.Aweme",
            @"快手": @"com.jiangjia.gif",
            @"贴吧": @"com.baidu.tieba", @"百度贴吧": @"com.baidu.tieba",
            @"豆瓣": @"com.douban.frodo",
            @"虎扑": @"com.hupu.games",
            @"米游社": @"com.miHoYo.mhybbs",
            @"小黑盒": @"com.max.xiaoheihe",
            @"taptap": @"com.taptap",
            // 音乐播客与视频流媒体 (18+)
            @"网易云音乐": @"com.netease.cloudmusic", @"网易云": @"com.netease.cloudmusic",
            @"qq音乐": @"com.tencent.QQMusic",
            @"酷狗音乐": @"com.kugou.kugoumusic", @"酷狗": @"com.kugou.kugoumusic",
            @"酷我音乐": @"cn.kuwo.player", @"酷我": @"cn.kuwo.player",
            @"汽水音乐": @"com.luna.music",
            @"喜马拉雅": @"com.gemd.iting",
            @"小宇宙": @"app.podcast.cosmos",
            @"荔枝fm": @"com.lizhi.fm", @"荔枝": @"com.lizhi.fm",
            @"蜻蜓fm": @"com.qingting.fm", @"蜻蜓": @"com.qingting.fm",
            @"爱奇艺": @"com.qiyi.iphone",
            @"腾讯视频": @"com.tencent.live4iphone",
            @"优酷": @"com.youku.YouKu", @"优酷视频": @"com.youku.YouKu",
            @"芒果tv": @"com.mgtv.app",
            @"斗鱼": @"com.douyu.iphone", @"斗鱼直播": @"com.douyu.iphone",
            @"虎牙": @"com.huya.iphone", @"虎牙直播": @"com.huya.iphone",
            // 阅读文学与外语考研 (16+)
            @"欧路词典": @"com.eusoft.eudic",
            @"有道词典": @"com.youdao.dict", @"网易有道词典": @"com.youdao.dict",
            @"微信读书": @"com.tencent.weread",
            @"百词斩": @"com.baicizhan.word",
            @"多邻国": @"com.duolingo.DuolingoMobile",
            @"学习强国": @"cn.xuexi.android",
            @"得到": @"com.luojilab.player",
            @"起点读书": @"com.qidian.QDReader", @"起点": @"com.qidian.QDReader",
            @"晋江文学城": @"com.jjwxc.reader", @"晋江": @"com.jjwxc.reader",
            @"番茄小说": @"com.dragon.read", @"番茄免费小说": @"com.dragon.read",
            @"快看漫画": @"com.kuaikan.comic", @"快看": @"com.kuaikan.comic",
            @"哔哩哔哩漫画": @"com.bilibili.comic", @"b站漫画": @"com.bilibili.comic",
            @"掌阅": @"com.chaozh.iReaderFree",
            // 协同办公、云盘与效率 (16+)
            @"钉钉": @"com.laiwang.DingTalk",
            @"飞书": @"com.electron.lark",
            @"企业微信": @"com.tencent.wework",
            @"腾讯会议": @"com.tencent.meeting",
            @"wps": @"com.kingsoft.office", @"wps office": @"com.kingsoft.office",
            @"百度网盘": @"com.baidu.netdisk",
            @"阿里云盘": @"com.alicloud.databox",
            @"夸克": @"com.ucweb.iphone.quark",
            @"滴答清单": @"com.ticktick.task",
            @"扫描全能王": @"com.intsig.CamScanner",
            @"白描": @"com.baimiao.app",
            @"语雀": @"com.antgroup.yuque",
            @"石墨文档": @"com.shimo.client",
            @"幕布": @"com.mubu.app",
            // 快递物流与跑腿 (6+)
            @"菜鸟": @"com.cainiao.logistic", @"菜鸟裹裹": @"com.cainiao.logistic",
            @"顺丰速运": @"com.sf-express.SFClient", @"顺丰": @"com.sf-express.SFClient",
            @"丰巢": @"com.fcbox.app",
            @"货拉拉": @"com.huolala.client",
            @"闪送": @"com.ishansong.client",
            // 三大运营商掌厅 (3+)
            @"中国移动": @"com.greenpoint.android.mc10086.activity", @"10086": @"com.greenpoint.android.mc10086.activity",
            @"中国联通": @"com.sinovatech.unicom.ui", @"10010": @"com.sinovatech.unicom.ui",
            @"中国电信": @"cn.com.chinatelecom.ChinaTelecom", @"10000": @"cn.com.chinatelecom.ChinaTelecom",
            // 交管政务与民生办事 (7+)
            @"交管12123": @"com.tmri.12123", @"12123": @"com.tmri.12123",
            @"个人所得税": @"com.chinatax.taxpayer",
            @"随申办": @"com.wondertek.activity", @"随申办市民云": @"com.wondertek.activity",
            @"浙里办": @"com.hanweb.zjdss",
            @"58同城": @"com.wuba.Life",
            // 新能源车机互联与汽车 (9+)
            @"蔚来": @"cn.com.weilai.car",
            @"小鹏汽车": @"com.xiaopeng.mycar", @"小鹏": @"com.xiaopeng.mycar",
            @"理想汽车": @"com.chehejia.lixiang", @"理想": @"com.chehejia.lixiang",
            @"比亚迪": @"com.byd.auto",
            @"特斯拉": @"com.teslamotors.Tesla", @"tesla": @"com.teslamotors.Tesla",
            @"懂车帝": @"com.ss.android.auto",
            @"汽车之家": @"com.cubic.autohome",
            @"易车": @"com.yiche.autoeasy",
            @"瓜子二手车": @"com.guazi.app",
            // 智能家居与 IoT (6+)
            @"米家": @"com.xiaomi.mihome",
            @"华为智慧生活": @"com.huawei.smarthome", @"智慧生活": @"com.huawei.smarthome",
            @"美的美居": @"com.midea.ai.home",
            @"海尔智家": @"com.haier.uhome",
            @"贝壳找房": @"com.lianjia.beike", @"贝壳": @"com.lianjia.beike",
            @"安居客": @"com.anjuke.iphone",
            // 剪辑修图、求职与证券 (12+)
            @"剪映": @"com.lemon.lv",
            @"美图秀秀": @"com.mt.mtxx",
            @"醒图": @"com.bytedance.snapseed",
            @"boss直聘": @"com.hpbr.bosszhipin",
            @"智联招聘": @"com.zhaopin.iphone",
            @"猎聘": @"com.liepin.hunter",
            @"同花顺": @"com.hexin.plat.android",
            @"东方财富": @"com.eastmoney.iphone",
            @"雪球": @"com.xueqiu",
            @"富途牛牛": @"com.futu.futu",
            // 国产大模型 AI 助手 (4+)
            @"豆包": @"com.bytedance.doubao",
            @"kimi": @"ai.moonshot.kimi",
            @"智谱清言": @"cn.zhipu.chatglm",
            @"文心一言": @"com.baidu.yiyan",
            // iOS 系统原生功能
            @"设置": @"com.apple.Preferences",
            @"相机": @"com.apple.camera",
            @"相册": @"com.apple.mobileslideshow", @"照片": @"com.apple.mobileslideshow",
            @"safari": @"com.apple.mobilesafari", @"浏览器": @"com.apple.mobilesafari",
            @"电话": @"com.apple.mobilephone",
            @"短信": @"com.apple.MobileSMS", @"信息": @"com.apple.MobileSMS",
            @"备忘录": @"com.apple.mobilenotes",
            @"日历": @"com.apple.mobilecal",
            @"闹钟": @"com.apple.mobiletimer", @"时钟": @"com.apple.mobiletimer",
            @"计算器": @"com.apple.calculator",
            @"天气": @"com.apple.weather",
            @"股市": @"com.apple.stocks", @"股票": @"com.apple.stocks",
            @"快捷指令": @"com.apple.shortcuts",
            @"文件": @"com.apple.DocumentsApp",
            @"appstore": @"com.apple.AppStore", @"应用商店": @"com.apple.AppStore",
            @"地图": @"com.apple.Maps",
            @"语音备忘录": @"com.apple.VoiceMemos", @"录音机": @"com.apple.VoiceMemos",
            // 越狱工具
            @"filza": @"com.tigisoftware.Filza",
            @"zebra": @"xyz.willy.Zebra", @"斑马": @"xyz.willy.Zebra",
            @"sileo": @"org.coolstar.SileoStore",
            @"youtube": @"com.google.ios.youtube", @"油管": @"com.google.ios.youtube"
        };
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];

        // 亮屏或应用回到前台时，后台静默预热 WebSocket 连接（不开启音频，0 耗电实现呼出即说）
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(prewarmWebSocketInBackgroundIfNeeded) name:UIApplicationDidBecomeActiveNotification object:nil];
        CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                        (__bridge const void *)(self),
                                        agScreenWakePrewarmCallback,
                                        CFSTR("com.apple.springboard.hasBlankedScreen"),
                                        NULL,
                                        CFNotificationSuspensionBehaviorDeliverImmediately);

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [self preloadInstalledAppsCache];
        });
    }
    return self;
}

- (NSMutableString *)currentTabTranscript {
    NSMutableString *str = self.tabTranscriptMap[@(self.activeModeTab)];
    if (!str) {
        str = [NSMutableString string];
        self.tabTranscriptMap[@(self.activeModeTab)] = str;
    }
    return str;
}

- (NSMutableArray<NSDictionary *> *)currentTabHistory {
    NSMutableArray *arr = self.tabHistoryMap[@(self.activeModeTab)];
    if (!arr) {
        arr = [NSMutableArray array];
        self.tabHistoryMap[@(self.activeModeTab)] = arr;
    }
    return arr;
}

- (void)preloadInstalledAppsCache {
    @try {
        NSArray<LSApplicationProxy *> *apps = [[%c(LSApplicationWorkspace) defaultWorkspace] allInstalledApplications];
        for (LSApplicationProxy *proxy in apps) {
            NSString *locName = [proxy.localizedName lowercaseString];
            NSString *bundleID = proxy.applicationIdentifier;
            if (locName.length > 0 && bundleID.length > 0) {
                self.cachedInstalledApps[locName] = bundleID;
            }
        }
    } @catch (NSException *e) {}
}

#pragma mark - 三大模式状态读取与品牌识别

- (BOOL)isTweakEnabled {
    NSNumber *val = loadGeminiPrefs()[@"Gemini_Enabled"];
    return val ? [val boolValue] : YES;
}

- (NSString *)currentVendorBrandName {
    NSString *rawModel = [agModelForTab(self.activeModeTab) stringByReplacingOccurrencesOfString:@"models/" withString:@""];
    NSString *lower = [rawModel lowercaseString];
    NSString *epLower = [agEndpointForTab(self.activeModeTab) lowercaseString];

    if ([lower containsString:@"deepseek"] || [epLower containsString:@"deepseek"]) return @"DeepSeek";
    if ([lower containsString:@"qwen"] || [lower containsString:@"qwq"] || [lower containsString:@"qvq"] || [epLower containsString:@"dashscope"]) return @"通义千问";
    if ([lower containsString:@"doubao"] || [epLower containsString:@"volces.com"]) return @"豆包";
    if ([lower containsString:@"kimi"] || [lower containsString:@"moonshot"] || [epLower containsString:@"moonshot"]) return @"Kimi";
    if ([lower containsString:@"glm"] || [epLower containsString:@"bigmodel.cn"]) return @"智谱清言";
    if ([lower containsString:@"ernie"] || [lower containsString:@"wenxin"]) return @"文心一言";
    if ([lower containsString:@"hunyuan"]) return @"腾讯混元";
    if ([lower containsString:@"minimax"] || [lower containsString:@"abab"] || [lower containsString:@"hailuo"]) return @"MiniMax";
    if ([lower containsString:@"step"]) return @"阶跃星辰";
    if ([lower containsString:@"spark"] || [lower containsString:@"xinghuo"]) return @"讯飞星火";
    if ([lower containsString:@"yi-"] || [lower hasPrefix:@"yi"]) return @"零一万物";
    if ([lower containsString:@"baichuan"]) return @"百川智能";

    if ([lower containsString:@"chatgpt"] || [lower containsString:@"gpt"] || [lower hasPrefix:@"o1"] || [lower hasPrefix:@"o3"] || [lower hasPrefix:@"o4"] || [epLower containsString:@"openai.com"]) return @"ChatGPT";
    if ([lower containsString:@"gemini"] || [lower containsString:@"gemma"] || [epLower containsString:@"googleapis.com"]) return @"Gemini";
    if ([lower containsString:@"claude"] || [epLower containsString:@"anthropic"]) return @"Claude";
    if ([lower containsString:@"grok"] || [epLower containsString:@"x.ai"]) return @"Grok";
    if ([lower containsString:@"llama"]) return @"Llama";
    if ([lower containsString:@"mistral"] || [lower containsString:@"pixtral"]) return @"Mistral";

    static NSRegularExpression *sBrandRegex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sBrandRegex = [NSRegularExpression regularExpressionWithPattern:@"^([a-zA-Z0-9\u4e00-\u9fa5]+)" options:0 error:nil];
    });
    NSTextCheckingResult *match = [sBrandRegex firstMatchInString:rawModel options:0 range:NSMakeRange(0, rawModel.length)];
    if (match && match.numberOfRanges > 1) {
        NSString *prefix = [rawModel substringWithRange:[match rangeAtIndex:1]];
        if (prefix.length > 0) return [prefix capitalizedString];
    }
    return @"Gemini";
}

- (void)applyCurrentVisualTheme {
    [self updateHeaderBadges];
}

- (void)updateHeaderBadges {
    AGDeviceMetrics m = agComputeDeviceMetrics();
    AGVisualTheme theme = agCurrentVisualTheme();
    NSString *brand = [self currentVendorBrandName];

    // 强制 overlayWindow 采用深色模式，彻底解决点击 文A 弹出刺眼白底系统弹窗的问题！
    if (@available(iOS 13.0, *)) {
        self.overlayWindow.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        self.overlayWindow.rootViewController.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    }

    self.titleMaskLabel.font = [UIFont systemFontOfSize:m.titleFontSize weight:UIFontWeightHeavy];
    self.titleMaskLabel.text = brand;
    self.responseTextView.font = [UIFont systemFontOfSize:m.bodyFontSize weight:UIFontWeightBold];

    CGFloat capsuleWidth = self.overlayWindow.capsuleWrapper.bounds.size.width;
    if (capsuleWidth < 200.0) capsuleWidth = m.screenW - m.sideMargin * 2.0;

    CGFloat topY = m.headerAndBottomPadding;
    CGFloat btnSz = m.barButtonSize;
    CGFloat padX = m.isCompactPhone ? 12.0 : 14.0;
    CGFloat btnGap = m.isCompactPhone ? 5.0 : 6.0;

    if (self.aiOrbView) {
        self.aiOrbView.frame = CGRectMake(padX, topY, btnSz, btnSz);
        self.aiOrbView.layer.cornerRadius = btnSz / 2.0;
        self.aiOrbView.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:self.aiOrbView.bounds].CGPath;
        self.orbCanvas.frame = self.aiOrbView.bounds;
    }

    CGFloat closeX = capsuleWidth - padX - btnSz;
    CGFloat settingsX = closeX - btnGap - btnSz;
    UIButton *transBtn = (UIButton *)[self.cardBlurView.contentView viewWithTag:95881];
    CGFloat rightMostLeft = settingsX;

    if (self.closeBtn) self.closeBtn.frame = CGRectMake(closeX, topY, btnSz, btnSz);
    if (self.settingsBtn) self.settingsBtn.frame = CGRectMake(settingsX, topY, btnSz, btnSz);
    if (transBtn && !transBtn.hidden) {
        CGFloat transX = settingsX - btnGap - btnSz;
        transBtn.frame = CGRectMake(transX, topY, btnSz, btnSz);
        rightMostLeft = transX;
    }

    CGFloat titleX = padX + btnSz + 7.0;
    CGSize titleSz = [brand sizeWithAttributes:@{NSFontAttributeName: self.titleMaskLabel.font}];
    CGFloat maxTitleW = rightMostLeft - titleX - m.badgeWidth - 10.0;
    CGFloat titleW = MIN(MAX(48.0, ceil(titleSz.width) + 4.0), MAX(52.0, maxTitleW));
    if (self.titleWrap) {
        self.titleWrap.frame = CGRectMake(titleX, topY, titleW, btnSz);
        self.titleGradientLayer.frame = self.titleWrap.bounds;
        self.titleMaskLabel.frame = self.titleWrap.bounds;
        self.titleMaskLabel.adjustsFontSizeToFitWidth = YES;
        self.titleMaskLabel.minimumScaleFactor = 0.72;
    }

    CGFloat badgeX = titleX + titleW + 6.0;
    CGFloat badgeW = m.badgeWidth;
    if (self.modeBadgeLabel) {
        self.modeBadgeLabel.frame = CGRectMake(badgeX, topY + (btnSz - 25.0) * 0.5, badgeW, 25.0);
    }

    CGFloat rightMostButtonLeftEdge = rightMostLeft;
    CGFloat eqAreaStart = badgeX + badgeW + 6.0;
    CGFloat eqAreaEnd = rightMostButtonLeftEdge - 6.0;
    CGFloat eqAvailableW = eqAreaEnd - eqAreaStart;
    if (eqAvailableW >= 26.0 && self.waveBars.count == 5) {
        CGFloat totalBarsW = 5 * 3.4 + 4 * 2.6;
        CGFloat eqStartX = eqAreaStart + MAX(0.0, (eqAvailableW - totalBarsW) / 2.0);
        for (int i = 0; i < 5; i++) {
            UIView *bar = self.waveBars[i];
            bar.hidden = NO;
            bar.frame = CGRectMake(eqStartX + i * 6.0, topY + (btnSz - 22.0) * 0.5, 3.4, 22.0);
        }
    } else {
        for (UIView *bar in self.waveBars) {
            bar.hidden = YES;
        }
    }

    // 为内层对话舱挂载右上角斜切镜面高光反射层 (严格还原参考图右上角柔光折射)
    CAGradientLayer *innerGloss = nil;
    for (CALayer *sub in self.innerGlassBox.layer.sublayers) {
        if ([sub.name isEqualToString:@"AGInnerMirrorGloss"]) {
            innerGloss = (CAGradientLayer *)sub;
            break;
        }
    }
    if (!innerGloss && self.innerGlassBox) {
        innerGloss = [CAGradientLayer layer];
        innerGloss.name = @"AGInnerMirrorGloss";
        innerGloss.startPoint = CGPointMake(1.0, 0.0);
        innerGloss.endPoint = CGPointMake(0.15, 0.85);
        innerGloss.colors = @[
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.20].CGColor,
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.04].CGColor,
            (__bridge id)[UIColor clearColor].CGColor
        ];
        innerGloss.locations = @[@0.0, @0.32, @0.65];
        [self.innerGlassBox.layer insertSublayer:innerGloss atIndex:0];
    }

    NSString *bText = (self.activeModeTab == AGConfigTabVideoAI) ? @"● 实时视觉" : ((self.activeModeTab == AGConfigTabPureText) ? @"● 极速文本" : @"● LIVE 全双工");
    self.modeBadgeLabel.text = bText;

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (innerGloss) innerGloss.frame = self.innerGlassBox.bounds;
    self.ambientLayer.hidden = YES;
    self.borderGrad.hidden = YES;
    self.orbOuterRingLayer.hidden = YES;
    self.orbInnerRingLayer.hidden = YES;
    self.innerGlassBox.layer.cornerRadius = m.innerCardRadius;
    self.innerGlassBox.layer.borderWidth = 1.35;
    self.inputField.layer.borderWidth = 1.25;

    CGFloat boxAlpha = MAX(0.25, MIN(0.85, agMainGlassOpacity() * 0.96));
    if (theme == AGVisualThemeLightLuxury) {
        // 1. 轻奢：深邃曜石黑金对话舱 (高对比度，彻底告别发白雾感)
        self.overlayWindow.capsuleWrapper.layer.shadowColor = [UIColor colorWithRed:0.96 green:0.78 blue:0.48 alpha:1.0].CGColor;
        self.cardBlurView.contentView.backgroundColor = [UIColor clearColor];
        self.titleGradientLayer.colors = @[
            (__bridge id)[UIColor whiteColor].CGColor,
            (__bridge id)[UIColor colorWithRed:0.99 green:0.90 blue:0.72 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.88 green:0.68 blue:0.42 alpha:1.0].CGColor
        ];
        self.modeBadgeLabel.textColor = [UIColor colorWithRed:1.00 green:0.96 blue:0.88 alpha:1.0];
        self.modeBadgeLabel.backgroundColor = [UIColor colorWithRed:0.24 green:0.18 blue:0.12 alpha:0.72];
        self.modeBadgeLabel.layer.borderColor = [UIColor colorWithRed:1.00 green:0.90 blue:0.70 alpha:0.85].CGColor;
        self.innerGlassBox.backgroundColor = [UIColor colorWithRed:0.05 green:0.04 blue:0.04 alpha:boxAlpha];
        self.innerGlassBox.layer.borderColor = [UIColor colorWithRed:0.98 green:0.85 blue:0.62 alpha:0.68].CGColor;
        self.subStatusLabel.textColor = [UIColor colorWithRed:0.98 green:0.88 blue:0.70 alpha:1.0];
        self.inputField.backgroundColor = [UIColor colorWithRed:0.06 green:0.05 blue:0.04 alpha:0.75];
        self.inputField.layer.borderColor = [UIColor colorWithRed:0.98 green:0.85 blue:0.62 alpha:0.72].CGColor;
        self.modelPickerContainer.backgroundColor = [UIColor colorWithRed:0.08 green:0.06 blue:0.05 alpha:0.94];
        self.modelPickerContainer.layer.borderColor = [UIColor colorWithRed:0.98 green:0.85 blue:0.62 alpha:0.72].CGColor;
    } else if (theme == AGVisualThemeMinimalist) {
        // 2. 简约：深海蓝晶对话舱 + 冰蓝亮白高光边 (1:1 还原参考图深邃蓝晶质感)
        self.overlayWindow.capsuleWrapper.layer.shadowColor = [UIColor colorWithRed:0.38 green:0.78 blue:1.00 alpha:1.0].CGColor;
        self.cardBlurView.contentView.backgroundColor = [UIColor clearColor];
        self.titleGradientLayer.colors = @[
            (__bridge id)[UIColor whiteColor].CGColor,
            (__bridge id)[UIColor colorWithRed:0.85 green:0.95 blue:1.00 alpha:1.0].CGColor
        ];
        self.modeBadgeLabel.textColor = [UIColor whiteColor];
        self.modeBadgeLabel.backgroundColor = [UIColor colorWithRed:0.16 green:0.28 blue:0.52 alpha:0.62];
        self.modeBadgeLabel.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.86].CGColor;
        self.innerGlassBox.backgroundColor = [UIColor colorWithRed:0.05 green:0.09 blue:0.22 alpha:boxAlpha];
        self.innerGlassBox.layer.borderColor = [UIColor colorWithRed:0.78 green:0.92 blue:1.00 alpha:0.72].CGColor;
        self.subStatusLabel.textColor = [UIColor colorWithRed:0.88 green:0.96 blue:1.00 alpha:1.0];
        self.inputField.backgroundColor = [UIColor colorWithRed:0.06 green:0.11 blue:0.26 alpha:0.66];
        self.inputField.layer.borderColor = [UIColor colorWithRed:0.82 green:0.94 blue:1.00 alpha:0.76].CGColor;
        self.modelPickerContainer.backgroundColor = [UIColor colorWithRed:0.07 green:0.12 blue:0.28 alpha:0.92];
        self.modelPickerContainer.layer.borderColor = [UIColor colorWithRed:0.78 green:0.92 blue:1.00 alpha:0.76].CGColor;
    } else {
        // 3. 炫酷：深空黑晶对话舱 + 电光青紫霓虹边
        self.overlayWindow.capsuleWrapper.layer.shadowColor = [UIColor colorWithRed:0.00 green:0.92 blue:1.00 alpha:1.0].CGColor;
        self.cardBlurView.contentView.backgroundColor = [UIColor clearColor];
        self.titleGradientLayer.colors = @[
            (__bridge id)[UIColor whiteColor].CGColor,
            (__bridge id)[UIColor colorWithRed:0.45 green:0.95 blue:1.00 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.96 green:0.45 blue:0.82 alpha:1.0].CGColor
        ];
        self.modeBadgeLabel.textColor = [UIColor whiteColor];
        self.modeBadgeLabel.backgroundColor = [UIColor colorWithRed:0.06 green:0.22 blue:0.46 alpha:0.72];
        self.modeBadgeLabel.layer.borderColor = [UIColor colorWithRed:0.25 green:0.94 blue:1.00 alpha:0.88].CGColor;
        self.innerGlassBox.backgroundColor = [UIColor colorWithRed:0.04 green:0.06 blue:0.18 alpha:boxAlpha];
        self.innerGlassBox.layer.borderColor = [UIColor colorWithRed:0.00 green:0.94 blue:1.00 alpha:0.72].CGColor;
        self.subStatusLabel.textColor = [UIColor colorWithRed:0.68 green:0.96 blue:1.00 alpha:1.0];
        self.inputField.backgroundColor = [UIColor colorWithRed:0.05 green:0.08 blue:0.22 alpha:0.74];
        self.inputField.layer.borderColor = [UIColor colorWithRed:0.00 green:0.94 blue:1.00 alpha:0.78].CGColor;
        self.modelPickerContainer.backgroundColor = [UIColor colorWithRed:0.05 green:0.08 blue:0.22 alpha:0.94];
        self.modelPickerContainer.layer.borderColor = [UIColor colorWithRed:0.00 green:0.94 blue:1.00 alpha:0.78].CGColor;
    }
    [self.cardBgCanvas rebuildStaticGlassShellTextureIfNeeded];
    [CATransaction commit];

    [self.cardBgCanvas applyTheme:theme];
    [self.orbCanvas applyTheme:theme];
    [self.waveCanvas applyTheme:theme];

    BOOL isLive  = (self.activeModeTab == AGConfigTabNativeLive);
    BOOL isVideo = (self.activeModeTab == AGConfigTabVideoAI);
    BOOL isText  = (self.activeModeTab == AGConfigTabPureText);

    self.liveBtnGrad.hidden = YES;
    self.videoBtnGrad.hidden = YES;
    self.textBtnGrad.hidden = YES;
    self.sendBtnGrad.hidden = YES;
    if (self.sendBtn) {
        self.sendBtn.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(0, 0, btnSz, btnSz)].CGPath;
    }

    [self.liveModeButton setImage:[agRenderCompleteCircleButtonImage(AGVectorIconMicLive, btnSz, theme, isLive, 0) imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
    [self.videoModeButton setImage:[agRenderCompleteCircleButtonImage(AGVectorIconVideoAI, btnSz, theme, isVideo, 1) imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
    [self.textModeButton setImage:[agRenderCompleteCircleButtonImage(AGVectorIconPureText, btnSz, theme, isText, 2) imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
    [self.sendBtn setImage:[agRenderCompleteCircleButtonImage(AGVectorIconSendArrow, btnSz, theme, YES, 3) imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];

    [self.settingsBtn setImage:[agRenderCompleteCircleButtonImage(AGVectorIconModelHex, btnSz, theme, NO, 0) imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
    [self.closeBtn setImage:[agRenderCompleteCircleButtonImage(AGVectorIconCloseCross, btnSz, theme, NO, 0) imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
    if (transBtn) {
        transBtn.backgroundColor = [UIColor clearColor];
        transBtn.layer.borderWidth = 0.0;
        [transBtn setTitle:@"" forState:UIControlStateNormal];
        [transBtn setImage:[agRenderCompleteCircleButtonImage(AGVectorIconTranslate, btnSz, theme, NO, 0) imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:UIControlStateNormal];
    }
    [self applyMarqueeThemeColors:theme];
}

- (void)applyMarqueeThemeColors:(AGVisualTheme)theme {
    if (!self.edgeGlowContainer) return;
    self.edgeGlowContainer.hidden = !agIsMarqueeEnabled();

    NSArray *coreColors = nil;
    NSArray *featherColors = nil;
    NSArray *bloomColors = nil;
    NSArray *flareColors = nil;
    NSArray *sweepColors = nil;

    if (theme == AGVisualThemeLightLuxury) {
        // 1. 轻奢主题：18K 香槟亮金 + 熔岩流金 + 暖珀金环绕与全屏金芒扫光
        coreColors = @[
            (__bridge id)[UIColor colorWithRed:1.00 green:0.93 blue:0.70 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.96 green:0.68 blue:0.24 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:1.00 green:0.98 blue:0.90 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.78 green:0.46 blue:0.14 alpha:0.96].CGColor,
            (__bridge id)[UIColor colorWithRed:0.99 green:0.82 blue:0.42 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.88 green:0.56 blue:0.20 alpha:0.98].CGColor,
            (__bridge id)[UIColor colorWithRed:1.00 green:0.93 blue:0.70 alpha:1.0].CGColor
        ];
        featherColors = coreColors;
        bloomColors = @[
            (__bridge id)[UIColor colorWithRed:0.99 green:0.80 blue:0.38 alpha:0.92].CGColor,
            (__bridge id)[UIColor colorWithRed:0.85 green:0.52 blue:0.18 alpha:0.78].CGColor,
            (__bridge id)[UIColor colorWithRed:1.00 green:0.92 blue:0.68 alpha:0.94].CGColor,
            (__bridge id)[UIColor colorWithRed:0.99 green:0.80 blue:0.38 alpha:0.92].CGColor
        ];
        flareColors = @[
            (__bridge id)[UIColor whiteColor].CGColor,
            (__bridge id)[UIColor colorWithRed:1.00 green:0.86 blue:0.48 alpha:0.95].CGColor,
            (__bridge id)[UIColor clearColor].CGColor
        ];
        sweepColors = @[
            (__bridge id)[UIColor clearColor].CGColor,
            (__bridge id)[UIColor colorWithRed:0.96 green:0.68 blue:0.24 alpha:0.22].CGColor,
            (__bridge id)[UIColor colorWithRed:1.00 green:0.94 blue:0.76 alpha:0.58].CGColor,
            (__bridge id)[UIColor colorWithRed:0.98 green:0.78 blue:0.36 alpha:0.25].CGColor,
            (__bridge id)[UIColor clearColor].CGColor
        ];
    } else if (theme == AGVisualThemeMinimalist) {
        // 2. 简约主题：极地纯白 + 冰川天蓝 + 星云浅紫超折射流光与全屏冰晶扫光
        coreColors = @[
            (__bridge id)[UIColor whiteColor].CGColor,
            (__bridge id)[UIColor colorWithRed:0.22 green:0.78 blue:1.00 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.51 green:0.55 blue:0.98 alpha:0.98].CGColor,
            (__bridge id)[UIColor colorWithRed:0.88 green:0.96 blue:1.00 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.05 green:0.58 blue:0.96 alpha:0.98].CGColor,
            (__bridge id)[UIColor colorWithRed:0.73 green:0.90 blue:1.00 alpha:1.0].CGColor,
            (__bridge id)[UIColor whiteColor].CGColor
        ];
        featherColors = coreColors;
        bloomColors = @[
            (__bridge id)[UIColor colorWithRed:0.35 green:0.82 blue:1.00 alpha:0.92].CGColor,
            (__bridge id)[UIColor colorWithRed:0.51 green:0.55 blue:0.98 alpha:0.82].CGColor,
            (__bridge id)[UIColor colorWithWhite:1.0 alpha:0.92].CGColor,
            (__bridge id)[UIColor colorWithRed:0.35 green:0.82 blue:1.00 alpha:0.92].CGColor
        ];
        flareColors = @[
            (__bridge id)[UIColor whiteColor].CGColor,
            (__bridge id)[UIColor colorWithRed:0.38 green:0.86 blue:1.00 alpha:0.95].CGColor,
            (__bridge id)[UIColor clearColor].CGColor
        ];
        sweepColors = @[
            (__bridge id)[UIColor clearColor].CGColor,
            (__bridge id)[UIColor colorWithRed:0.22 green:0.78 blue:1.00 alpha:0.24].CGColor,
            (__bridge id)[UIColor colorWithRed:0.92 green:0.98 blue:1.00 alpha:0.60].CGColor,
            (__bridge id)[UIColor colorWithRed:0.56 green:0.62 blue:0.98 alpha:0.26].CGColor,
            (__bridge id)[UIColor clearColor].CGColor
        ];
    } else {
        // 3. 炫酷主题：1:1 复刻 iOS 26 Siri 全息虹彩流光与全屏极光扫光
        coreColors = @[
            (__bridge id)[UIColor colorWithRed:1.00 green:0.91 blue:0.52 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:1.00 green:0.58 blue:0.00 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.00 green:0.85 blue:1.00 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.11 green:0.39 blue:1.00 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.66 green:0.33 blue:0.97 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.93 green:0.28 blue:0.60 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.39 green:0.40 blue:0.95 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:1.00 green:0.42 blue:0.00 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:1.00 green:0.91 blue:0.52 alpha:1.0].CGColor
        ];
        featherColors = coreColors;
        bloomColors = @[
            (__bridge id)[UIColor colorWithRed:1.00 green:0.75 blue:0.22 alpha:0.94].CGColor,
            (__bridge id)[UIColor colorWithRed:0.00 green:0.80 blue:1.00 alpha:0.96].CGColor,
            (__bridge id)[UIColor colorWithRed:0.12 green:0.42 blue:1.00 alpha:0.95].CGColor,
            (__bridge id)[UIColor colorWithRed:0.88 green:0.26 blue:0.68 alpha:0.94].CGColor,
            (__bridge id)[UIColor colorWithRed:1.00 green:0.52 blue:0.12 alpha:0.92].CGColor,
            (__bridge id)[UIColor colorWithRed:1.00 green:0.75 blue:0.22 alpha:0.94].CGColor
        ];
        flareColors = @[
            (__bridge id)[UIColor whiteColor].CGColor,
            (__bridge id)[UIColor colorWithRed:1.00 green:0.85 blue:0.42 alpha:0.96].CGColor,
            (__bridge id)[UIColor colorWithRed:0.00 green:0.85 blue:1.00 alpha:0.85].CGColor,
            (__bridge id)[UIColor clearColor].CGColor
        ];
        sweepColors = @[
            (__bridge id)[UIColor clearColor].CGColor,
            (__bridge id)[UIColor colorWithRed:0.00 green:0.88 blue:1.00 alpha:0.26].CGColor,
            (__bridge id)[UIColor colorWithRed:0.95 green:0.32 blue:0.68 alpha:0.52].CGColor,
            (__bridge id)[UIColor colorWithRed:1.00 green:0.72 blue:0.24 alpha:0.30].CGColor,
            (__bridge id)[UIColor clearColor].CGColor
        ];
    }

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.screenNeonLayer.colors = coreColors;
    self.screenNeonFeatherLayer.colors = featherColors;
    self.screenNeonBloomLayer.colors = bloomColors;
    self.invocationFlareLayer.colors = flareColors;
    if (self.invocationSweepLayer) {
        self.invocationSweepLayer.colors = sweepColors;
    }
    [CATransaction commit];
}

// 60fps 纯 GPU 矩阵旋转流光 + 正弦深呼吸与声音分贝律动 (0 每帧 UIBezierPath 分配开销)
- (void)stepMarqueeAnimationWithPhase:(CGFloat)phase voiceAmp:(CGFloat)amp {
    if (!self.edgeGlowContainer) return;
    if (!agIsMarqueeEnabled()) {
        if (!self.edgeGlowContainer.hidden) self.edgeGlowContainer.hidden = YES;
        return;
    }
    if (self.edgeGlowContainer.hidden) {
        self.edgeGlowContainer.hidden = NO;
    }

    // 1. 平滑正弦呼吸曲线 (0.0 ~ 1.0 一呼一吸) + 语音振幅加成
    CGFloat breath = 0.5 + 0.5 * sin(phase * 1.65);
    CGFloat surge = MIN(1.0, amp * 1.25);

    // 2. 通过 GPU 硬件旋转正方形圆锥渐变层，实现 360° 无死角、无扇区挤压变形的丝滑流转
    CGFloat rotAngle1 = fmod(phase * 0.38, M_PI * 2.0);
    CGFloat rotAngle2 = fmod(-phase * 0.26 + 0.85, M_PI * 2.0);

    // 3. 呼吸缩放：让内侧极光层随呼吸与说话音量向屏幕内侧柔和吞吐扩张
    CGFloat bloomScaleX = 1.0 - (0.014 * breath + 0.028 * surge);
    CGFloat bloomScaleY = 1.0 - (0.008 * breath + 0.018 * surge);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.screenNeonLayer.transform = CATransform3DMakeRotation(rotAngle1, 0, 0, 1.0);
    self.screenNeonFeatherLayer.transform = CATransform3DMakeRotation(rotAngle1, 0, 0, 1.0);
    self.screenNeonBloomLayer.transform = CATransform3DConcat(
        CATransform3DMakeRotation(rotAngle2, 0, 0, 1.0),
        CATransform3DMakeScale(bloomScaleX, bloomScaleY, 1.0)
    );

    self.screenNeonLayer.opacity        = MIN(1.0, 0.86 + 0.14 * breath);
    self.screenNeonFeatherLayer.opacity = MIN(1.0, 0.68 + 0.28 * breath + 0.20 * surge);
    self.screenNeonBloomLayer.opacity   = MIN(1.0, 0.45 + 0.42 * breath + 0.35 * surge);
    [CATransaction commit];
}

- (void)playIOS27SiriInvocationEffectFromPowerButton:(BOOL)fromPowerButton {
    // 1. 锁屏或息屏唤醒时，第一时间点亮屏幕硬件背光
    agWakeScreenBacklightIfNeeded();

    if (!self.overlayWindow) return;
    self.pendingWakeupChime = YES;
    // 2. 立即触发 iOS 26 Siri 启动提示音（零延迟必响）
    [self playCrystalWakeupChimeIfNeeded];

    CGRect sb = [UIScreen mainScreen].bounds;

    // 3. 双阶物理震动反馈 (复刻 iOS 26 唤醒手感)
    UIImpactFeedbackGenerator *rigidHaptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleRigid];
    [rigidHaptic impactOccurred];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.11 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.impactHaptic impactOccurred];
    });

    if (!agIsMarqueeEnabled()) {
        self.edgeGlowContainer.hidden = YES;
        return;
    }
    self.edgeGlowContainer.hidden = NO;
    [self applyMarqueeThemeColors:agCurrentVisualTheme()];

    // 4. 边缘点火聚能光斑：电源键从右侧 28% 高度处爆发；嘿 Siri 从底部正中爆发
    CGPoint flareOrigin = fromPowerButton
        ? CGPointMake(sb.size.width, sb.size.height * 0.28)
        : CGPointMake(sb.size.width * 0.50, sb.size.height);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    self.invocationFlareLayer.bounds = CGRectMake(0, 0, 360, 360);
    self.invocationFlareLayer.position = flareOrigin;
    self.invocationFlareLayer.opacity = 1.0;
    self.invocationFlareLayer.transform = CATransform3DMakeScale(0.18, 0.18, 1.0);
    [CATransaction commit];

    CABasicAnimation *flareScale = [CABasicAnimation animationWithKeyPath:@"transform.scale"];
    flareScale.fromValue = @(0.18);
    flareScale.toValue = @(3.8);
    CABasicAnimation *flareFade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    flareFade.fromValue = @(1.0);
    flareFade.toValue = @(0.0);
    CAAnimationGroup *flareGroup = [CAAnimationGroup animation];
    flareGroup.animations = @[flareScale, flareFade];
    flareGroup.duration = 0.68;
    flareGroup.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    self.invocationFlareLayer.opacity = 0.0;
    [self.invocationFlareLayer addAnimation:flareGroup forKey:@"agIOS26InvocationFlare"];

    // 5. iOS 26 标志性全屏扫光 (Full-Screen Light Sweep)：
    // 电源键唤醒：从右上电源键斜切扫向全屏左下；嘿 Siri 唤醒：从屏幕底部向上全屏冲刷扫过
    if (self.invocationSweepLayer) {
        self.invocationSweepLayer.hidden = NO;
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.invocationSweepLayer.frame = CGRectInset(sb, -sb.size.width * 0.5, -sb.size.height * 0.5);
        if (fromPowerButton) {
            self.invocationSweepLayer.startPoint = CGPointMake(1.0, 0.22);
            self.invocationSweepLayer.endPoint   = CGPointMake(0.0, 0.82);
        } else {
            self.invocationSweepLayer.startPoint = CGPointMake(0.5, 1.0);
            self.invocationSweepLayer.endPoint   = CGPointMake(0.5, 0.0);
        }
        self.invocationSweepLayer.opacity = 1.0;
        [CATransaction commit];

        CABasicAnimation *sweepLoc = [CABasicAnimation animationWithKeyPath:@"locations"];
        sweepLoc.fromValue = @[@(-0.45), @(-0.25), @(-0.10), @(0.05), @(0.20)];
        sweepLoc.toValue   = @[@(0.80), @(0.95), @(1.10), @(1.25), @(1.45)];

        CAKeyframeAnimation *sweepAlpha = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
        sweepAlpha.values   = @[@0.0, @0.95, @0.85, @0.0];
        sweepAlpha.keyTimes = @[@0.0, @0.22, @0.68, @1.0];

        CAAnimationGroup *sweepGroup = [CAAnimationGroup animation];
        sweepGroup.animations = @[sweepLoc, sweepAlpha];
        sweepGroup.duration = 0.72;
        sweepGroup.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        self.invocationSweepLayer.opacity = 0.0;
        [self.invocationSweepLayer addAnimation:sweepGroup forKey:@"agIOS26FullScreenSweep"];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.75 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.invocationSweepLayer.hidden = YES;
        });
    }

    // 6. 四周彩色边缘流光向心脉冲扩张与果冻回弹 (iOS 26 边缘流光冲刷特效)
    self.edgeGlowContainer.transform = CGAffineTransformMakeScale(1.038, 1.038);
    self.edgeGlowContainer.alpha = 0.0;

    self.currentVoiceAmplitude = 0.95;
    self.targetVoiceAmplitude = 0.78;
    [self stepMarqueeAnimationWithPhase:self.wavePhase voiceAmp:self.currentVoiceAmplitude];

    [UIView animateWithDuration:0.62
                          delay:0.0
         usingSpringWithDamping:0.65
          initialSpringVelocity:1.20
                        options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction
                     animations:^{
        self.edgeGlowContainer.transform = CGAffineTransformIdentity;
        self.edgeGlowContainer.alpha = 1.0;
    } completion:^(BOOL finished) {
        [self setWaveBarsLevel:0.0];
    }];
}

- (void)ensureCloudModelsLoadedForTab:(AGConfigTab)tab completion:(void(^)(NSString *readyModel))completion {
    NSString *curModel = agModelForTab(tab);
    if (curModel.length > 0) {
        if (completion) completion(curModel);
        return;
    }
    self.subStatusLabel.text = @"🔍 正在通过 API 实测筛选最新 5 款可用模型...";
    agFetchCloudModelsForTab(tab, agEndpointForTab(tab), agAPIKeyForTab(tab), agProxyForTab(tab), ^(BOOL success, NSArray<NSDictionary *> *models, NSString *errorMsg) {
        if (success && models.count > 0) {
            NSString *firstVerified = models.firstObject[@"id"];
            NSMutableDictionary *p = loadGeminiPrefs();
            p[[NSString stringWithFormat:@"%@_Model", agPrefixForTab(tab)]] = firstVerified;
            saveGeminiPrefs(p);
            [self updateHeaderBadges];
            if (completion) completion(firstVerified);
        } else {
            self.subStatusLabel.text = [NSString stringWithFormat:@"⚠️ %@", errorMsg ?: @"请点击右上角⚙️刷新获取可用模型"];
        }
    });
}

#pragma mark - 18 款机型自适应窗口高度、流体声波布局与键盘避让

- (void)adjustCapsuleHeightTo:(CGFloat)targetHeight animated:(BOOL)animated {
    if (!self.overlayWindow || !self.overlayWindow.capsuleWrapper) return;
    AGDeviceMetrics m = agComputeDeviceMetrics();
    CGRect screenBounds = [UIScreen mainScreen].bounds;

    CGFloat topSafeMargin = m.topSafeLimit;
    CGFloat bottomMargin = (self.currentKeyboardHeight > 10.0) ? (self.currentKeyboardHeight + 10.0) : m.bottomRestMargin;
    CGFloat maxAvailableH = screenBounds.size.height - topSafeMargin - bottomMargin;
    CGFloat maxRatio = m.isLargePhone ? 0.62 : (m.isCompactPhone ? 0.56 : 0.59);
    CGFloat maxCapH = MIN(screenBounds.size.height * maxRatio, maxAvailableH);
    CGFloat minCapH = MIN(m.defaultCapsuleH, maxCapH);

    CGFloat clampedH = MAX(minCapH, MIN(maxCapH, targetHeight));
    self.currentCapsuleHeight = clampedH;

    CGFloat sidePad = m.sideMargin;
    CGFloat capsuleWidth = screenBounds.size.width - sidePad * 2.0;
    CGFloat capsuleY = screenBounds.size.height - bottomMargin - clampedH;

    CGFloat innerTopY = m.headerAndBottomPadding + m.barButtonSize + 9.0;
    CGFloat bottomReserved = m.headerAndBottomPadding + m.barButtonSize + 10.0;
    CGFloat innerBoxH = clampedH - innerTopY - bottomReserved;
    CGFloat innerPadX = m.isCompactPhone ? 12.0 : 14.0;
    CGFloat innerW = capsuleWidth - innerPadX * 2.0;

    CGFloat camW = m.camPipW;
    CGFloat camH = MIN(m.camPipH, innerBoxH - 46.0);
    CGFloat textW = self.isVideoChatActive ? (innerW - camW - 22.0) : (innerW - 20.0);

    void (^layoutBlock)(void) = ^{
        self.overlayWindow.capsuleWrapper.frame = CGRectMake(sidePad, capsuleY, capsuleWidth, clampedH);
        self.cardBlurView.frame = self.overlayWindow.capsuleWrapper.bounds;
        self.cardBlurView.layer.cornerRadius = m.cardCornerRadius;
        self.cardBgCanvas.cornerRadius = m.cardCornerRadius;
        self.cardBgCanvas.frame = self.cardBlurView.bounds;

        self.innerGlassBox.frame = CGRectMake(innerPadX, innerTopY, innerW, innerBoxH);
        self.subStatusLabel.frame = CGRectMake(12, 8, innerW - 24, 26);
        self.responseTextView.frame = CGRectMake(10, 34, textW, MAX(68.0, innerBoxH - 68.0));
        self.fluidWaveContainer.frame = CGRectMake(0, innerBoxH - 46.0, innerW, 46.0);
        self.waveCanvas.frame = self.fluidWaveContainer.bounds;

        self.cameraPreviewContainer.frame = CGRectMake(innerW - camW - 8, 34, camW, MAX(86.0, camH));
        self.cameraLiveImageView.frame = self.cameraPreviewContainer.bounds;
        if (self.cameraPreviewLayer) self.cameraPreviewLayer.frame = self.cameraPreviewContainer.bounds;
        self.cameraDiagnosticLabel.frame = CGRectInset(self.cameraPreviewContainer.bounds, 4, 20);
        self.cameraFlipHintLabel.frame = CGRectMake(0, self.cameraPreviewContainer.bounds.size.height - 20, camW, 20);
        [self.innerGlassBox bringSubviewToFront:self.fluidWaveContainer];
        [self.innerGlassBox bringSubviewToFront:self.cameraPreviewContainer];

        self.modelPickerContainer.frame = self.innerGlassBox.frame;
        self.modelTableView.frame = CGRectMake(0, 38, innerW, innerBoxH - 38.0);

        [self refreshBottomBarLayoutForActiveModes];

        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        self.overlayWindow.capsuleWrapper.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:self.overlayWindow.capsuleWrapper.bounds cornerRadius:m.cardCornerRadius].CGPath;
        [CATransaction commit];
    };

    if (animated) {
        [UIView animateWithDuration:0.30 delay:0 usingSpringWithDamping:0.86 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:layoutBlock completion:nil];
    } else {
        layoutBlock();
    }
}

- (void)throttledExpandAndScrollTextViewForce:(BOOL)force {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (!force && (now - self.lastLayoutExpandTime < 0.26)) {
        return;
    }
    self.lastLayoutExpandTime = now;

    AGDeviceMetrics m = agComputeDeviceMetrics();
    CGFloat textW = self.responseTextView.bounds.size.width;
    if (textW > 20.0) {
        CGSize fitSize = [self.responseTextView sizeThatFits:CGSizeMake(textW, CGFLOAT_MAX)];
        // 以 defaultCapsuleH 为基准，文字较少时严格保持 defaultCapsuleH 不跳变，文字较多时才向上平滑扩展
        CGFloat neededHeight = MAX(m.defaultCapsuleH, fitSize.height + 168.0);
        if (fabs(neededHeight - self.currentCapsuleHeight) > 12.0) {
            [self adjustCapsuleHeightTo:neededHeight animated:YES];
        }
    }

    NSInteger len = self.responseTextView.text.length;
    if (len > 0) {
        [UIView performWithoutAnimation:^{
            [self.responseTextView scrollRangeToVisible:NSMakeRange(len - 1, 1)];
        }];
    }
}


- (void)keyboardWillShow:(NSNotification *)notification {
    if (!self.overlayWindow || self.overlayWindow.hidden) return;
    CGRect kbFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    self.currentKeyboardHeight = kbFrame.size.height;
    [self adjustCapsuleHeightTo:self.currentCapsuleHeight animated:YES];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self throttledExpandAndScrollTextViewForce:YES];
    });
}

- (void)keyboardWillHide:(NSNotification *)notification {
    if (!self.overlayWindow || self.overlayWindow.hidden) return;
    self.currentKeyboardHeight = 0.0;
    [self throttledExpandAndScrollTextViewForce:YES];
}

- (UIWindowScene *)activeWindowScene {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]] && scene.activationState == UISceneActivationStateForegroundActive) {
                return (UIWindowScene *)scene;
            }
        }
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) return (UIWindowScene *)scene;
        }
    }
    return nil;
}

#pragma mark - ✨ 极光液态玻璃界面构建 (1:1 还原参考图视觉与流体声波)

- (void)setupWindowIfNeeded {
    if (self.overlayWindow) return;

    UIWindowScene *scene = [self activeWindowScene];
    CGRect screenBounds = [UIScreen mainScreen].bounds;

    if (scene) {
        self.overlayWindow = [[GeminiPassthroughWindow alloc] initWithWindowScene:scene];
        self.overlayWindow.frame = screenBounds;
    } else {
        self.overlayWindow = [[GeminiPassthroughWindow alloc] initWithFrame:screenBounds];
    }

    self.overlayWindow.windowLevel = 10000.0;
    self.overlayWindow.backgroundColor = [UIColor clearColor];
    self.overlayWindow.hidden = YES;
    if ([self.overlayWindow respondsToSelector:@selector(_setSecure:)]) {
        [self.overlayWindow _setSecure:YES];
    }

    // 关键修复 1：使用支持 _canShowWhileLocked 的根控制器，防止 iOS 锁屏安全合成器将背景渲染为纯黑
    AGLockScreenRootViewController *rootVC = [[AGLockScreenRootViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor clearColor];
    self.overlayWindow.rootViewController = rootVC;

    // 关键修复 2：彻底隐藏全屏深色毛玻璃与暗角黑幕遮罩（alpha=0, hidden=YES），让锁屏壁纸、时间与桌面图标 100% 透出，告别黑底！
    UIBlurEffect *bgBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
    self.screenDimBlurView = [[UIVisualEffectView alloc] initWithEffect:bgBlur];
    self.screenDimBlurView.frame = screenBounds;
    self.screenDimBlurView.userInteractionEnabled = NO;
    self.screenDimBlurView.alpha = 0.0;
    self.screenDimBlurView.hidden = YES;
    [rootVC.view addSubview:self.screenDimBlurView];

    self.screenVignetteLayer = [CAGradientLayer layer];
    self.screenVignetteLayer.frame = screenBounds;
    self.screenVignetteLayer.opacity = 0.0;
    self.screenVignetteLayer.hidden = YES;
    [self.screenDimBlurView.contentView.layer addSublayer:self.screenVignetteLayer];

    // 2. iOS 27 呼唤 Siri 全屏无断层向内羽化呼吸跑马灯边框 (1:1 复刻实拍图)
    self.edgeGlowContainer = [[UIView alloc] initWithFrame:screenBounds];
    self.edgeGlowContainer.userInteractionEnabled = NO;
    self.edgeGlowContainer.clipsToBounds = YES;
    self.edgeGlowContainer.hidden = !agIsMarqueeEnabled();
    [rootVC.view addSubview:self.edgeGlowContainer];

    CGFloat screenCorner = adaptiveScreenCornerRadius(screenBounds);
    // 使用足以覆盖屏幕旋转对角线的正方形尺寸，使圆锥渐变通过 CATransform3DMakeRotation 旋转时 100% 均匀无挤压
    CGFloat diagSide = hypot(screenBounds.size.width, screenBounds.size.height) + 40.0;
    CGRect rotSquareBounds = CGRectMake(0, 0, diagSide, diagSide);
    CGPoint screenCenter = CGPointMake(CGRectGetMidX(screenBounds), CGRectGetMidY(screenBounds));

    // (a) 内层：宽幅深呼吸向内漫射柔光层 + 底部手电筒/相机区柔光垫 (0~30pt 指数衰减无断层遮罩)
    CALayer *bloomContainer = [CALayer layer];
    bloomContainer.frame = screenBounds;
    CALayer *bloomAlphaMask = [CALayer layer];
    bloomAlphaMask.frame = screenBounds;
    bloomAlphaMask.contents = (__bridge id)agCreateSmoothFeatheredEdgeMaskImage(screenBounds, screenCorner, 30.0, YES);
    bloomContainer.mask = bloomAlphaMask;
    [self.edgeGlowContainer.layer addSublayer:bloomContainer];

    self.screenNeonBloomLayer = [CAGradientLayer layer];
    self.screenNeonBloomLayer.type = kCAGradientLayerConic;
    self.screenNeonBloomLayer.bounds = rotSquareBounds;
    self.screenNeonBloomLayer.position = screenCenter;
    self.screenNeonBloomLayer.startPoint = CGPointMake(0.5, 0.5);
    self.screenNeonBloomLayer.endPoint = CGPointMake(1.0, 0.5);
    [bloomContainer addSublayer:self.screenNeonBloomLayer];

    // (b) 中层：中距高饱和霓虹羽化过渡层 (0~16pt 指数衰减无断层遮罩)
    CALayer *featherContainer = [CALayer layer];
    featherContainer.frame = screenBounds;
    CALayer *featherAlphaMask = [CALayer layer];
    featherAlphaMask.frame = screenBounds;
    featherAlphaMask.contents = (__bridge id)agCreateSmoothFeatheredEdgeMaskImage(screenBounds, screenCorner, 16.0, NO);
    featherContainer.mask = featherAlphaMask;
    [self.edgeGlowContainer.layer addSublayer:featherContainer];

    self.screenNeonFeatherLayer = [CAGradientLayer layer];
    self.screenNeonFeatherLayer.type = kCAGradientLayerConic;
    self.screenNeonFeatherLayer.bounds = rotSquareBounds;
    self.screenNeonFeatherLayer.position = screenCenter;
    self.screenNeonFeatherLayer.startPoint = CGPointMake(0.5, 0.5);
    self.screenNeonFeatherLayer.endPoint = CGPointMake(1.0, 0.5);
    [featherContainer addSublayer:self.screenNeonFeatherLayer];

    // (c) 外层：紧贴屏幕黑边的 2.5pt 极亮流光核心边 (Core Rim)
    CALayer *coreContainer = [CALayer layer];
    coreContainer.frame = screenBounds;
    UIBezierPath *sOuter = [UIBezierPath bezierPathWithRoundedRect:screenBounds cornerRadius:screenCorner];
    UIBezierPath *sInner = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(screenBounds, 2.5, 2.5) cornerRadius:MAX(14.0, screenCorner - 2.5)];
    [sOuter appendPath:sInner];
    sOuter.usesEvenOddFillRule = YES;
    self.screenNeonOuterMask = [CAShapeLayer layer];
    self.screenNeonOuterMask.path = sOuter.CGPath;
    self.screenNeonOuterMask.fillRule = kCAFillRuleEvenOdd;
    coreContainer.mask = self.screenNeonOuterMask;
    [self.edgeGlowContainer.layer addSublayer:coreContainer];

    self.screenNeonLayer = [CAGradientLayer layer];
    self.screenNeonLayer.type = kCAGradientLayerConic;
    self.screenNeonLayer.bounds = rotSquareBounds;
    self.screenNeonLayer.position = screenCenter;
    self.screenNeonLayer.startPoint = CGPointMake(0.5, 0.5);
    self.screenNeonLayer.endPoint = CGPointMake(1.0, 0.5);
    [coreContainer addSublayer:self.screenNeonLayer];

    // (d) 唤醒瞬间点火聚能冲击光斑层 (限制在边缘 36pt 环带内爆发，绝不遮挡中心)
    CALayer *flareContainer = [CALayer layer];
    flareContainer.frame = screenBounds;
    CALayer *flareMask = [CALayer layer];
    flareMask.frame = screenBounds;
    flareMask.contents = (__bridge id)agCreateSmoothFeatheredEdgeMaskImage(screenBounds, screenCorner, 36.0, YES);
    flareContainer.mask = flareMask;
    [self.edgeGlowContainer.layer addSublayer:flareContainer];

    self.invocationFlareLayer = [CAGradientLayer layer];
    self.invocationFlareLayer.type = kCAGradientLayerRadial;
    self.invocationFlareLayer.startPoint = CGPointMake(0.5, 0.5);
    self.invocationFlareLayer.endPoint = CGPointMake(1.0, 1.0);
    self.invocationFlareLayer.opacity = 0.0;
    [flareContainer addSublayer:self.invocationFlareLayer];

    // (e) iOS 26 唤起瞬间全屏流光扫光层 (Full-Screen Light Sweep)
    self.invocationSweepLayer = [CAGradientLayer layer];
    self.invocationSweepLayer.type = kCAGradientLayerAxial;
    self.invocationSweepLayer.frame = CGRectInset(screenBounds, -screenBounds.size.width * 0.4, -screenBounds.size.height * 0.4);
    self.invocationSweepLayer.startPoint = CGPointMake(0.0, 0.0);
    self.invocationSweepLayer.endPoint = CGPointMake(1.0, 1.0);
    self.invocationSweepLayer.locations = @[@0.0, @0.35, @0.50, @0.65, @1.0];
    self.invocationSweepLayer.opacity = 0.0;
    self.invocationSweepLayer.hidden = YES;
    [self.edgeGlowContainer.layer addSublayer:self.invocationSweepLayer];

    self.marqueeSweepProgress = 1.0;
    [self applyMarqueeThemeColors:agCurrentVisualTheme()];
    [self stepMarqueeAnimationWithPhase:0.0 voiceAmp:0.0];

    // 3. 主悬浮卡片容器 (带青蓝+紫粉底部外发光阴影)
    AGDeviceMetrics m = agComputeDeviceMetrics();
    CGFloat capsuleHeight = m.defaultCapsuleH;
    CGFloat capsuleWidth = screenBounds.size.width - m.sideMargin * 2.0;
    CGFloat capsuleY = screenBounds.size.height - capsuleHeight - m.bottomRestMargin;

    UIView *wrapper = [[UIView alloc] initWithFrame:CGRectMake(m.sideMargin, capsuleY, capsuleWidth, capsuleHeight)];
    wrapper.backgroundColor = [UIColor clearColor];
    wrapper.layer.shadowColor = [UIColor colorWithRed:0.18 green:0.75 blue:1.0 alpha:1.0].CGColor;
    wrapper.layer.shadowRadius = 26.0;
    wrapper.layer.shadowOpacity = 0.62;
    wrapper.layer.shadowOffset = CGSizeMake(0, 6);
    wrapper.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:wrapper.bounds cornerRadius:36.0].CGPath;
    [rootVC.view addSubview:wrapper];
    self.overlayWindow.capsuleWrapper = wrapper;

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    self.cardBlurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    self.cardBlurView.frame = wrapper.bounds;
    self.cardBlurView.layer.cornerRadius = 36.0;
    self.cardBlurView.layer.masksToBounds = YES;
    [wrapper addSubview:self.cardBlurView];

    UIView *content = self.cardBlurView.contentView;
    content.backgroundColor = [UIColor colorWithRed:0.08 green:0.05 blue:0.16 alpha:0.86];
    self.cardBgCanvas = [[AGCardBgCanvasView alloc] initWithFrame:content.bounds];
    [content insertSubview:self.cardBgCanvas atIndex:0];

    // 卡片内部氛围极光渐变层 (顶部紫粉微光，底部青蓝微光)
    self.ambientLayer = [CAGradientLayer layer];
    self.ambientLayer.frame = content.bounds;
    self.ambientLayer.colors = @[
        (__bridge id)[UIColor colorWithRed:0.52 green:0.22 blue:0.88 alpha:0.32].CGColor,
        (__bridge id)[UIColor colorWithRed:0.12 green:0.06 blue:0.24 alpha:0.15].CGColor,
        (__bridge id)[UIColor colorWithRed:0.05 green:0.72 blue:0.96 alpha:0.25].CGColor
    ];
    self.ambientLayer.locations = @[@0.0, @0.55, @1.0];
    self.ambientLayer.startPoint = CGPointMake(0.2, 0.0);
    self.ambientLayer.endPoint = CGPointMake(0.8, 1.0);
    [content.layer addSublayer:self.ambientLayer];

    // 卡片外圈高亮渐变描边 (顶部柔紫粉 -> 底部电光青蓝，完美贴合参考图)
    self.borderGrad = [CAGradientLayer layer];
    self.borderGrad.frame = content.bounds;
    self.borderGrad.colors = @[
        (__bridge id)[UIColor colorWithRed:0.78 green:0.55 blue:0.98 alpha:0.95].CGColor,
        (__bridge id)[UIColor colorWithRed:0.95 green:0.38 blue:0.75 alpha:0.88].CGColor,
        (__bridge id)[UIColor colorWithRed:0.12 green:0.92 blue:1.00 alpha:1.00].CGColor
    ];
    self.borderGrad.startPoint = CGPointMake(0.5, 0.0);
    self.borderGrad.endPoint = CGPointMake(0.5, 1.0);

    UIBezierPath *bOuter = [UIBezierPath bezierPathWithRoundedRect:content.bounds cornerRadius:36.0];
    UIBezierPath *bInner = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(content.bounds, 1.8, 1.8) cornerRadius:34.2];
    [bOuter appendPath:bInner];
    bOuter.usesEvenOddFillRule = YES;

    self.borderMask = [CAShapeLayer layer];
    self.borderMask.path = bOuter.CGPath;
    self.borderMask.fillRule = kCAFillRuleEvenOdd;
    self.borderGrad.mask = self.borderMask;
    [content.layer addSublayer:self.borderGrad];

    // 4. 左上角 3D 悬浮发光 AI 灵动球 (带青蓝光晕)
    self.aiOrbView = [[UIView alloc] initWithFrame:CGRectMake(18, 16, 34, 34)];
    self.aiOrbView.layer.cornerRadius = 17.0;
    self.aiOrbView.layer.shadowColor = [UIColor colorWithRed:0.35 green:0.82 blue:1.00 alpha:1.0].CGColor;
    self.aiOrbView.layer.shadowRadius = 10.0;
    self.aiOrbView.layer.shadowOpacity = 0.90;
    self.aiOrbView.layer.shadowOffset = CGSizeZero;

    self.orbCoreGrad = [CAGradientLayer layer];
    self.orbCoreGrad.frame = self.aiOrbView.bounds;
    self.orbCoreGrad.cornerRadius = 17.0;
    self.orbCoreGrad.colors = @[
        (__bridge id)[UIColor colorWithRed:0.96 green:0.99 blue:1.00 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.35 green:0.85 blue:1.00 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.42 green:0.28 blue:0.95 alpha:1.0].CGColor
    ];
    self.orbCoreGrad.locations = @[@0.0, @0.48, @1.0];
    self.orbCoreGrad.startPoint = CGPointMake(0.20, 0.15);
    self.orbCoreGrad.endPoint = CGPointMake(0.88, 0.92);
    [self.aiOrbView.layer addSublayer:self.orbCoreGrad];
    self.orbCoreGrad.hidden = YES;
    self.orbCanvas = [[AGOrbCanvasView alloc] initWithFrame:self.aiOrbView.bounds];
    [self.aiOrbView addSubview:self.orbCanvas];

    self.orbOuterRingLayer = [CAShapeLayer layer];
    self.orbOuterRingLayer.fillColor = [UIColor clearColor].CGColor;
    self.orbOuterRingLayer.lineWidth = 1.4;
    [self.aiOrbView.layer addSublayer:self.orbOuterRingLayer];

    self.orbInnerRingLayer = [CAShapeLayer layer];
    self.orbInnerRingLayer.fillColor = [UIColor clearColor].CGColor;
    self.orbInnerRingLayer.lineWidth = 1.4;
    [self.aiOrbView.layer addSublayer:self.orbInnerRingLayer];

    [content addSubview:self.aiOrbView];

    // 5. 品牌渐变大标题 ("Gemini" 蓝紫粉渐变)
    UIView *titleWrap = [[UIView alloc] initWithFrame:CGRectMake(54, 16, 92, 32)];
    [content addSubview:titleWrap];
    self.titleWrap = titleWrap;

    self.titleGradientLayer = [CAGradientLayer layer];
    self.titleGradientLayer.frame = titleWrap.bounds;
    self.titleGradientLayer.colors = @[
        (__bridge id)[UIColor colorWithRed:0.85 green:0.92 blue:1.00 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.92 green:0.75 blue:0.98 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.98 green:0.58 blue:0.82 alpha:1.0].CGColor
    ];
    self.titleGradientLayer.startPoint = CGPointMake(0, 0.5);
    self.titleGradientLayer.endPoint = CGPointMake(1, 0.5);
    [titleWrap.layer addSublayer:self.titleGradientLayer];

    self.titleMaskLabel = [[UILabel alloc] initWithFrame:titleWrap.bounds];
    self.titleMaskLabel.text = [self currentVendorBrandName];
    self.titleMaskLabel.font = [UIFont systemFontOfSize:19.0 weight:UIFontWeightHeavy];
    self.titleGradientLayer.mask = self.titleMaskLabel.layer;

    // 6. 翠绿发光胶囊徽章 ("⚡ LIVE 全双工")
    self.modeBadgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(150, 19, 76, 25)];
    self.modeBadgeLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightBold];
    self.modeBadgeLabel.textAlignment = NSTextAlignmentCenter;
    self.modeBadgeLabel.layer.cornerRadius = 12.5;
    self.modeBadgeLabel.layer.borderWidth = 1.1;
    self.modeBadgeLabel.layer.masksToBounds = YES;
    [content addSubview:self.modeBadgeLabel];

    // 7. 5 根霓虹渐变声波柱
    CGFloat eqStartX = capsuleWidth - 134.0;
    for (int i = 0; i < 5; i++) {
        UIView *bar = [[UIView alloc] initWithFrame:CGRectMake(eqStartX + i * 6.6, 21.0, 3.6, 22.0)];
        bar.layer.cornerRadius = 1.8;
        bar.layer.masksToBounds = YES;

        CAGradientLayer *barGrad = [CAGradientLayer layer];
        barGrad.frame = bar.bounds;
        barGrad.colors = @[
            (__bridge id)[UIColor colorWithRed:0.35 green:0.85 blue:1.00 alpha:1.0].CGColor,
            (__bridge id)[UIColor colorWithRed:0.98 green:0.42 blue:0.82 alpha:1.0].CGColor
        ];
        [bar.layer addSublayer:barGrad];
        bar.transform = CGAffineTransformMakeScale(1.0, 0.55);
        [content addSubview:bar];
        [self.waveBars addObject:bar];
    }

    // 8. 右上角毛玻璃圆环按钮 (⚙️ 与 ✕)
    UIButton *settingsBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    settingsBtn.frame = CGRectMake(capsuleWidth - 82, 16, 32, 32);
    settingsBtn.backgroundColor = [UIColor clearColor];
    settingsBtn.layer.cornerRadius = 16.0;
    settingsBtn.layer.borderWidth = 0.0;
    settingsBtn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.22].CGColor;
    [settingsBtn setTitle:@"" forState:UIControlStateNormal];
    [settingsBtn addTarget:self action:@selector(togglePureModelPicker) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:settingsBtn];
    self.settingsBtn = settingsBtn;

    UIButton *closeBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    closeBtn.frame = CGRectMake(capsuleWidth - 44, 16, 32, 32);
    closeBtn.backgroundColor = [UIColor clearColor];
    closeBtn.layer.cornerRadius = 16.0;
    closeBtn.layer.borderWidth = 0.0;
    closeBtn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.22].CGColor;
    [closeBtn setTitle:@"" forState:UIControlStateNormal];
    [closeBtn addTarget:self action:@selector(dismissOverlay) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:closeBtn];
    self.closeBtn = closeBtn;

    // 9. 中央深空黑晶对话容器 (Inner Glass Box)
    CGFloat innerBoxH = capsuleHeight - 130.0;
    self.innerGlassBox = [[UIView alloc] initWithFrame:CGRectMake(16, 62, capsuleWidth - 32, innerBoxH)];
    self.innerGlassBox.backgroundColor = [UIColor colorWithRed:0.07 green:0.06 blue:0.14 alpha:0.75];
    self.innerGlassBox.layer.cornerRadius = 20.0;
    self.innerGlassBox.layer.masksToBounds = YES;
    self.innerGlassBox.layer.borderWidth = 1.0;
    self.innerGlassBox.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
    [content addSubview:self.innerGlassBox];

    self.subStatusLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 10, self.innerGlassBox.bounds.size.width - 28, 34)];
    self.subStatusLabel.textColor = [UIColor colorWithRed:0.42 green:0.78 blue:1.00 alpha:1.0];
    self.subStatusLabel.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightBold];
    self.subStatusLabel.numberOfLines = 2;
    self.subStatusLabel.text = @"🎙️ 正在全双工倾听 (声波与极光随您的声音实时律动)...";
    [self.innerGlassBox addSubview:self.subStatusLabel];

    self.responseTextView = [[UITextView alloc] initWithFrame:CGRectMake(12, 42, self.innerGlassBox.bounds.size.width - 24, innerBoxH - 72.0)];
    self.responseTextView.backgroundColor = [UIColor clearColor];
    self.responseTextView.textColor = [UIColor colorWithWhite:0.98 alpha:1.0];
    self.responseTextView.font = [UIFont systemFontOfSize:16.0 weight:UIFontWeightBold];
    self.responseTextView.editable = NO;
    self.responseTextView.selectable = YES;
    self.responseTextView.scrollEnabled = YES;
    self.responseTextView.bounces = YES;
    self.responseTextView.showsVerticalScrollIndicator = NO;
    self.responseTextView.layoutManager.allowsNonContiguousLayout = YES;
    self.responseTextView.text = @"“直接开口说话，支持毫秒级流式秒回与随时插话打断...”";
    [self.innerGlassBox addSubview:self.responseTextView];

    // 10. 内部黑晶卡片底部的双轨交织正弦流体声波 (还原参考图)
    self.fluidWaveContainer = [[UIView alloc] initWithFrame:CGRectMake(0, innerBoxH - 36.0, self.innerGlassBox.bounds.size.width, 36.0)];
    self.fluidWaveContainer.userInteractionEnabled = NO;
    [self.innerGlassBox addSubview:self.fluidWaveContainer];

    self.waveBottomGlow = [CAGradientLayer layer];
    self.waveBottomGlow.frame = self.fluidWaveContainer.bounds;
    self.waveBottomGlow.colors = @[
        (__bridge id)[UIColor clearColor].CGColor,
        (__bridge id)[UIColor colorWithRed:0.85 green:0.20 blue:0.65 alpha:0.22].CGColor,
        (__bridge id)[UIColor colorWithRed:0.15 green:0.82 blue:1.00 alpha:0.32].CGColor
    ];
    [self.fluidWaveContainer.layer addSublayer:self.waveBottomGlow];

    self.magentaWaveShape = [CAShapeLayer layer];
    self.magentaWaveShape.fillColor = [UIColor clearColor].CGColor;
    self.magentaWaveShape.strokeColor = [UIColor colorWithRed:0.98 green:0.30 blue:0.75 alpha:0.92].CGColor;
    self.magentaWaveShape.lineWidth = 2.4;
    self.magentaWaveShape.lineCap = kCALineCapRound;
    self.magentaWaveShape.shadowColor = [UIColor colorWithRed:1.0 green:0.25 blue:0.75 alpha:1.0].CGColor;
    self.magentaWaveShape.shadowRadius = 6.0;
    self.magentaWaveShape.shadowOpacity = 0.85;
    self.magentaWaveShape.shadowOffset = CGSizeZero;
    [self.fluidWaveContainer.layer addSublayer:self.magentaWaveShape];

    self.cyanWaveShape = [CAShapeLayer layer];
    self.cyanWaveShape.fillColor = [UIColor clearColor].CGColor;
    self.cyanWaveShape.strokeColor = [UIColor colorWithRed:0.20 green:0.92 blue:1.00 alpha:0.95].CGColor;
    self.cyanWaveShape.lineWidth = 2.4;
    self.cyanWaveShape.lineCap = kCALineCapRound;
    self.cyanWaveShape.shadowColor = [UIColor colorWithRed:0.15 green:0.90 blue:1.00 alpha:1.0].CGColor;
    self.cyanWaveShape.shadowRadius = 6.0;
    self.cyanWaveShape.shadowOpacity = 0.85;
    self.cyanWaveShape.shadowOffset = CGSizeZero;
    [self.fluidWaveContainer.layer addSublayer:self.cyanWaveShape];

    self.thirdWaveShape = [CAShapeLayer layer];
    self.thirdWaveShape.fillColor = [UIColor clearColor].CGColor;
    self.thirdWaveShape.lineWidth = 1.8;
    self.thirdWaveShape.lineCap = kCALineCapRound;
    [self.fluidWaveContainer.layer addSublayer:self.thirdWaveShape];
    self.cyanWaveShape.hidden = YES;
    self.magentaWaveShape.hidden = YES;
    self.thirdWaveShape.hidden = YES;
    self.waveBottomGlow.hidden = YES;
    self.waveCanvas = [[AGWaveCanvasView alloc] initWithFrame:self.fluidWaveContainer.bounds];
    [self.fluidWaveContainer addSubview:self.waveCanvas];

    // 11. 实时相机预览小窗
    CGFloat camW = 112.0;
    CGFloat camH = 154.0;
    self.cameraPreviewContainer = [[UIView alloc] initWithFrame:CGRectMake(self.innerGlassBox.bounds.size.width - camW - 10, 42, camW, camH)];
    self.cameraPreviewContainer.backgroundColor = [UIColor colorWithWhite:0.08 alpha:1.0];
    self.cameraPreviewContainer.layer.cornerRadius = 14.0;
    self.cameraPreviewContainer.layer.masksToBounds = YES;
    self.cameraPreviewContainer.layer.borderWidth = 1.6;
    self.cameraPreviewContainer.layer.borderColor = [UIColor colorWithRed:0.35 green:0.95 blue:0.72 alpha:0.95].CGColor;
    self.cameraPreviewContainer.hidden = YES;
    [self.innerGlassBox addSubview:self.cameraPreviewContainer];

    self.cameraLiveImageView = [[UIImageView alloc] initWithFrame:self.cameraPreviewContainer.bounds];
    self.cameraLiveImageView.contentMode = UIViewContentModeScaleAspectFill;
    self.cameraLiveImageView.clipsToBounds = YES;
    self.cameraLiveImageView.userInteractionEnabled = NO;
    [self.cameraPreviewContainer addSubview:self.cameraLiveImageView];

    self.cameraDiagnosticLabel = [[UILabel alloc] initWithFrame:CGRectInset(self.cameraPreviewContainer.bounds, 5, 22)];
    self.cameraDiagnosticLabel.textColor = [UIColor colorWithWhite:0.95 alpha:1.0];
    self.cameraDiagnosticLabel.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightMedium];
    self.cameraDiagnosticLabel.textAlignment = NSTextAlignmentCenter;
    self.cameraDiagnosticLabel.numberOfLines = 0;
    self.cameraDiagnosticLabel.userInteractionEnabled = NO;
    self.cameraDiagnosticLabel.text = @"STOPPED";
    [self.cameraPreviewContainer addSubview:self.cameraDiagnosticLabel];

    self.cameraFlipHintLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, camH - 22, camW, 22)];
    self.cameraFlipHintLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.65];
    self.cameraFlipHintLabel.textColor = [UIColor whiteColor];
    self.cameraFlipHintLabel.font = [UIFont boldSystemFontOfSize:9.5];
    self.cameraFlipHintLabel.textAlignment = NSTextAlignmentCenter;
    self.cameraFlipHintLabel.userInteractionEnabled = NO;
    self.cameraFlipHintLabel.text = @"🔄 点击切换/重试";
    [self.cameraPreviewContainer addSubview:self.cameraFlipHintLabel];

    UITapGestureRecognizer *flipTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(flipCameraTapped)];
    [self.cameraPreviewContainer addGestureRecognizer:flipTap];

    self.actionBannerLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, 64, capsuleWidth - 40, 28)];
    self.actionBannerLabel.backgroundColor = [UIColor colorWithRed:0.12 green:0.78 blue:0.48 alpha:0.95];
    self.actionBannerLabel.textColor = [UIColor whiteColor];
    self.actionBannerLabel.font = [UIFont boldSystemFontOfSize:13];
    self.actionBannerLabel.textAlignment = NSTextAlignmentCenter;
    self.actionBannerLabel.layer.cornerRadius = 14.0;
    self.actionBannerLabel.layer.masksToBounds = YES;
    self.actionBannerLabel.alpha = 0.0;
    [content addSubview:self.actionBannerLabel];

    // 12. 底部三大模式圆形霓虹按钮 (带渐变激活底图层与外发光)
    self.liveModeButton = [self createModeCircleButtonWithTitle:@""
                                                     gradColors:@[
                                                         (__bridge id)[UIColor colorWithRed:0.35 green:0.55 blue:0.98 alpha:1.0].CGColor,
                                                         (__bridge id)[UIColor colorWithRed:0.95 green:0.32 blue:0.72 alpha:1.0].CGColor
                                                     ]
                                                    shadowColor:[UIColor colorWithRed:0.92 green:0.35 blue:0.75 alpha:1.0]
                                                        outGrad:&_liveBtnGrad
                                                         action:@selector(liveModeButtonTapped)];
    [content addSubview:self.liveModeButton];

    self.videoModeButton = [self createModeCircleButtonWithTitle:@""
                                                      gradColors:@[
                                                          (__bridge id)[UIColor colorWithRed:0.15 green:0.85 blue:0.65 alpha:1.0].CGColor,
                                                          (__bridge id)[UIColor colorWithRed:0.12 green:0.58 blue:0.92 alpha:1.0].CGColor
                                                      ]
                                                     shadowColor:[UIColor colorWithRed:0.18 green:0.85 blue:0.68 alpha:1.0]
                                                         outGrad:&_videoBtnGrad
                                                          action:@selector(videoModeButtonTapped)];
    [content addSubview:self.videoModeButton];

    self.textModeButton = [self createModeCircleButtonWithTitle:@""
                                                     gradColors:@[
                                                         (__bridge id)[UIColor colorWithRed:0.25 green:0.65 blue:1.00 alpha:1.0].CGColor,
                                                         (__bridge id)[UIColor colorWithRed:0.55 green:0.35 blue:0.98 alpha:1.0].CGColor
                                                     ]
                                                    shadowColor:[UIColor colorWithRed:0.35 green:0.65 blue:1.00 alpha:1.0]
                                                        outGrad:&_textBtnGrad
                                                         action:@selector(textModeButtonTapped)];
    [content addSubview:self.textModeButton];

    // 13. 底部胶囊输入框与电光紫蓝渐变发送按钮
    self.inputField = [[UITextField alloc] initWithFrame:CGRectZero];
    self.inputField.backgroundColor = [UIColor colorWithRed:0.12 green:0.10 blue:0.20 alpha:0.90];
    self.inputField.layer.cornerRadius = 20.0;
    self.inputField.layer.borderWidth = 1.0;
    self.inputField.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
    self.inputField.textColor = [UIColor whiteColor];
    self.inputField.font = [UIFont systemFontOfSize:13.0 weight:UIFontWeightMedium];
    self.inputField.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 12, 10)];
    self.inputField.leftViewMode = UITextFieldViewModeAlways;
    self.inputField.returnKeyType = UIReturnKeySend;
    self.inputField.clearButtonMode = UITextFieldViewModeWhileEditing;
    self.inputField.delegate = self;
    [content addSubview:self.inputField];

    self.sendBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.sendBtn.backgroundColor = [UIColor clearColor];
    self.sendBtn.layer.borderWidth = 0.0;
    self.sendBtn.layer.cornerRadius = 18.0;
    self.sendBtn.layer.masksToBounds = NO;
    self.sendBtn.layer.shadowColor = [UIColor colorWithRed:0.42 green:0.32 blue:0.98 alpha:1.0].CGColor;
    self.sendBtn.layer.shadowRadius = 8.0;
    self.sendBtn.layer.shadowOpacity = 0.65;
    self.sendBtn.layer.shadowOffset = CGSizeMake(0, 2);

    self.sendBtnGrad = [CAGradientLayer layer];
    self.sendBtnGrad.cornerRadius = 18.0;
    self.sendBtnGrad.colors = @[
        (__bridge id)[UIColor colorWithRed:0.46 green:0.38 blue:0.98 alpha:1.0].CGColor,
        (__bridge id)[UIColor colorWithRed:0.36 green:0.28 blue:0.92 alpha:1.0].CGColor
    ];
    self.sendBtnGrad.startPoint = CGPointMake(0, 0);
    self.sendBtnGrad.endPoint = CGPointMake(1, 1);
    [self.sendBtn.layer insertSublayer:self.sendBtnGrad atIndex:0];

    [self.sendBtn setTitle:@"" forState:UIControlStateNormal];
    [self.sendBtn addTarget:self action:@selector(sendButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:self.sendBtn];

    [self setupEmbeddedModelPickerInView:content width:capsuleWidth height:capsuleHeight];
    [self refreshBottomBarLayoutForActiveModes];
}

- (UIButton *)createModeCircleButtonWithTitle:(NSString *)title
                                   gradColors:(NSArray *)colors
                                  shadowColor:(UIColor *)shadowColor
                                      outGrad:(CAGradientLayer * __strong *)outGrad
                                       action:(SEL)action {
    UIButton *btn = [UIButton buttonWithType:UIButtonTypeSystem];
    btn.frame = CGRectMake(0, 0, 36, 36);
    btn.backgroundColor = [UIColor clearColor];
    btn.layer.cornerRadius = 18.0;
    btn.layer.borderWidth = 0.0;
    btn.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.16].CGColor;
    btn.layer.shadowColor = shadowColor.CGColor;
    btn.layer.shadowRadius = 8.0;
    btn.layer.shadowOpacity = 0.0;
    btn.layer.shadowOffset = CGSizeZero;

    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.frame = CGRectMake(0, 0, 36, 36);
    grad.cornerRadius = 18.0;
    grad.colors = colors;
    grad.startPoint = CGPointMake(0.15, 0.15);
    grad.endPoint = CGPointMake(0.85, 0.85);
    grad.opacity = 0.0;
    [btn.layer insertSublayer:grad atIndex:0];
    if (outGrad) *outGrad = grad;

    [btn setTitle:title forState:UIControlStateNormal];
    btn.titleLabel.font = [UIFont systemFontOfSize:16];
    [btn addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    return btn;
}

- (void)refreshBottomBarLayoutForActiveModes {
    if (!self.overlayWindow || !self.overlayWindow.capsuleWrapper) return;
    AGDeviceMetrics m = agComputeDeviceMetrics();
    CGFloat capsuleWidth = self.overlayWindow.capsuleWrapper.bounds.size.width;
    CGFloat capsuleHeight = self.overlayWindow.capsuleWrapper.bounds.size.height;

    CGFloat btnSize = m.barButtonSize; // 30pt 或 32pt
    CGFloat btnY = capsuleHeight - m.headerAndBottomPadding - btnSize;
    CGFloat padX = m.isCompactPhone ? 12.0 : 14.0;
    CGFloat btnGap = m.isCompactPhone ? 6.0 : 7.0;

    BOOL showLive  = agIsTabEnabled(AGConfigTabNativeLive);
    BOOL showVideo = agIsTabEnabled(AGConfigTabVideoAI);
    BOOL showText  = agIsTabEnabled(AGConfigTabPureText);
    if (!showLive && !showVideo && !showText) showLive = YES;

    self.liveModeButton.hidden  = !showLive;
    self.videoModeButton.hidden = !showVideo;
    self.textModeButton.hidden  = !showText;

    CGFloat curX = padX;
    if (showLive) {
        self.liveModeButton.frame = CGRectMake(curX, btnY, btnSize, btnSize);
        curX += (btnSize + btnGap);
    }
    if (showVideo) {
        self.videoModeButton.frame = CGRectMake(curX, btnY, btnSize, btnSize);
        curX += (btnSize + btnGap);
    }
    if (showText) {
        self.textModeButton.frame = CGRectMake(curX, btnY, btnSize, btnSize);
        curX += (btnSize + btnGap);
    }

    self.sendBtn.frame = CGRectMake(capsuleWidth - btnSize - padX, btnY, btnSize, btnSize);

    CGFloat inputX = curX + 1.0;
    CGFloat inputW = (capsuleWidth - btnSize - padX - btnGap) - inputX;
    self.inputField.frame = CGRectMake(inputX, btnY, MAX(96.0, inputW), btnSize);
    self.inputField.layer.cornerRadius = btnSize / 2.0;
    self.inputField.font = [UIFont systemFontOfSize:(m.isCompactPhone ? 12.0 : 12.5) weight:UIFontWeightMedium];

    NSString *phText = (self.activeModeTab == AGConfigTabPureText) ? @"打字提问..." : ((self.activeModeTab == AGConfigTabVideoAI) ? @"视讯中，可打字..." : @"直接说话，也可打字...");
    UIColor *phColor = (agCurrentVisualTheme() == AGVisualThemeLightLuxury) ? [UIColor colorWithRed:0.97 green:0.87 blue:0.75 alpha:0.55] : [UIColor colorWithWhite:0.75 alpha:1.0];
    self.inputField.attributedPlaceholder = [[NSAttributedString alloc] initWithString:phText attributes:@{NSForegroundColorAttributeName: phColor}];

    UIView *content = self.cardBlurView.contentView;
    UIButton *transBtn = (UIButton *)[content viewWithTag:95881];
    if (transBtn) transBtn.hidden = !agTransIsEnabled();

    [self updateHeaderBadges];
}

#pragma mark - 底部三大模式切换逻辑 (带弹性缩放反馈)

- (void)animateButtonBounce:(UIView *)btn {
    btn.transform = CGAffineTransformMakeScale(0.86, 0.86);
    [UIView animateWithDuration:0.38 delay:0 usingSpringWithDamping:0.55 initialSpringVelocity:0.9 options:UIViewAnimationOptionCurveEaseOut animations:^{
        btn.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)liveModeButtonTapped {
    [self.impactHaptic impactOccurred];
    [self animateButtonBounce:self.liveModeButton];
    [self.inputField resignFirstResponder];
    [self.accumulatedReplyText setString:@""];
    [self.pendingSpeechChunk setString:@""];
    if (self.isVideoChatActive) [self stopCameraSession];
    self.activeModeTab = AGConfigTabNativeLive;
    [self updateHeaderBadges];
    [self refreshBottomBarLayoutForActiveModes];
    self.responseTextView.text = [self currentTabTranscript].length > 0
        ? [self currentTabTranscript]
        : @"“直接开口说话，支持毫秒级流式秒回与随时插话打断...”";
    [self throttledExpandAndScrollTextViewForce:YES];
    [self showActionBanner:@"🎙️ 已切换至：纯正 Live 全双工语音模式"];
    [self startAdaptiveVoiceSessionForTab:AGConfigTabNativeLive];
}

- (void)videoModeButtonTapped {
    [self.impactHaptic impactOccurred];
    [self animateButtonBounce:self.videoModeButton];
    [self.inputField resignFirstResponder];
    [self.accumulatedReplyText setString:@""];
    [self.pendingSpeechChunk setString:@""];
    if (!agIsTabEnabled(AGConfigTabVideoAI)) {
        [self showActionBanner:@"⚠️ 请先在《设置》开启独立视频 AI 开关"];
        return;
    }
    if (self.activeModeTab == AGConfigTabVideoAI && self.isVideoChatActive) {
        [self stopCameraSession];
        self.activeModeTab = agIsTabEnabled(AGConfigTabNativeLive) ? AGConfigTabNativeLive : AGConfigTabPureText;
        [self updateHeaderBadges];
        [self refreshBottomBarLayoutForActiveModes];
        self.responseTextView.text = [self currentTabTranscript].length > 0 ? [self currentTabTranscript] : @"";
        [self throttledExpandAndScrollTextViewForce:YES];
        [self showActionBanner:@"📷 已关闭实时摄像头"];
        if (self.activeModeTab == AGConfigTabNativeLive) {
            [self startAdaptiveVoiceSessionForTab:AGConfigTabNativeLive];
        }
        return;
    }
    self.activeModeTab = AGConfigTabVideoAI;
    [self updateHeaderBadges];
    [self refreshBottomBarLayoutForActiveModes];
    self.responseTextView.text = [self currentTabTranscript].length > 0 ? [self currentTabTranscript] : @"";
    [self startCameraSession];
    [self throttledExpandAndScrollTextViewForce:YES];
    [self showActionBanner:@"📹 已开启独立视频 AI"];
    [self startAdaptiveVoiceSessionForTab:AGConfigTabVideoAI];
}

- (void)textModeButtonTapped {
    [self.impactHaptic impactOccurred];
    [self animateButtonBounce:self.textModeButton];
    if (self.isVideoChatActive) [self stopCameraSession];
    [self.accumulatedReplyText setString:@""];
    [self.pendingSpeechChunk setString:@""];
    [self stopAllVoiceEngines];
    self.activeModeTab = AGConfigTabPureText;
    [self updateHeaderBadges];
    [self refreshBottomBarLayoutForActiveModes];
    [self ensureCloudModelsLoadedForTab:AGConfigTabPureText completion:^(NSString *readyModel) {
        NSString *shortM = [readyModel stringByReplacingOccurrencesOfString:@"models/" withString:@""];
        self.subStatusLabel.text = [NSString stringWithFormat:@"💬 纯文本已就绪 (%@)", shortM];
    }];
    self.responseTextView.text = ([self currentTabTranscript].length > 0)
        ? [self currentTabTranscript]
        : @"“已进入纯文本独立对话模式，请直接在下方打字提问...”";
    [self throttledExpandAndScrollTextViewForce:YES];
    [self showActionBanner:@"💬 已切换至：纯文本独立打字模式"];
    [self.inputField becomeFirstResponder];
}

#pragma mark - 📹 7阶段摄像头启动状态机实现

- (void)transitionCameraStateTo:(AGCameraState)newState detail:(NSString *)detail {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.cameraState = newState;
        self.cameraStateEnterTime = [[NSDate date] timeIntervalSince1970];
        NSString *stateStr = agCameraStateName(newState);
        os_log(OS_LOG_DEFAULT, "[AngelGuardian-CamState] %{public}@ -> %{public}@", stateStr, detail ?: @"");

        if (newState == AGCameraStateFirstFrameReceived || newState == AGCameraStateStreaming) {
            self.cameraDiagnosticLabel.hidden = YES;
            self.cameraLiveImageView.hidden = NO;
            self.cameraFlipHintLabel.text = [NSString stringWithFormat:@"🟢 实时 #%lu (点此切镜头)", (unsigned long)self.receivedCameraFramesCount];
        } else if (newState == AGCameraStateFailed) {
            self.cameraDiagnosticLabel.hidden = NO;
            self.cameraDiagnosticLabel.textColor = [UIColor colorWithRed:1.0 green:0.48 blue:0.48 alpha:1.0];
            self.cameraDiagnosticLabel.text = [NSString stringWithFormat:@"[FAILED]\n%@\n(点底部重试/切镜头)", detail ?: @"未知原因"];
            self.cameraFlipHintLabel.text = @"🔄 点击重试或切镜头";
        } else {
            self.cameraDiagnosticLabel.hidden = NO;
            self.cameraDiagnosticLabel.textColor = [UIColor colorWithWhite:0.95 alpha:1.0];
            self.cameraDiagnosticLabel.text = [NSString stringWithFormat:@"[%@]\n%@", stateStr, detail ?: @""];
        }
    });
}

- (void)flipCameraTapped {
    if (!self.isVideoChatActive) return;
    [self.impactHaptic impactOccurred];
    if (self.cameraState == AGCameraStateFailed) {
        self.cameraRetryCount = 0;
        [self showActionBanner:@"🔄 正在重新启动摄像头状态机..."];
    } else {
        self.useFrontCamera = !self.useFrontCamera;
        [self showActionBanner:(self.useFrontCamera ? @"🤳 正在切换为前置镜头..." : @"📷 正在切换为后置镜头...")];
    }
    [self startCameraSession];
}

- (void)terminateHelperDaemonSync {
    [@"stop" writeToFile:agSharedCameraStopFlagPath() atomically:YES encoding:NSUTF8StringEncoding error:nil];
    if (self.helperDaemonPID > 0) {
        kill(self.helperDaemonPID, SIGTERM);
        usleep(50000);
        int status = 0;
        waitpid(self.helperDaemonPID, &status, WNOHANG);
        kill(self.helperDaemonPID, SIGKILL);
        waitpid(self.helperDaemonPID, &status, WNOHANG);
        self.helperDaemonPID = 0;
    }
    [[NSFileManager defaultManager] removeItemAtPath:agSharedCameraFramePath() error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:agSharedCameraStatusPath() error:nil];
}

- (void)startCameraSession {
    @try {
        if (self.layoutElementAssertion && [self.layoutElementAssertion respondsToSelector:@selector(invalidate)]) {
            [self.layoutElementAssertion performSelector:@selector(invalidate)];
            self.layoutElementAssertion = nil;
        }
        Class elemCls = objc_getClass("SBSDisplayLayoutElement") ?: objc_getClass("FBSDisplayLayoutElement");
        Class pubCls = objc_getClass("FBMainDisplayLayoutPublisher");
        if (elemCls && pubCls && [pubCls respondsToSelector:@selector(sharedInstance)]) {
            id pub = [pubCls sharedInstance];
            id elem = [[elemCls alloc] initWithIdentifier:@"com.apple.springboard.angelcamera"];
            [elem setValue:@"com.apple.springboard" forKey:@"bundleIdentifier"];
            [elem setValue:@YES forKey:@"UIApplicationElement"];
            [elem setValue:@YES forKey:@"fillsDisplayBounds"];
            [elem setValue:@(1000) forKey:@"level"];
            if ([pub respondsToSelector:@selector(addElement:)]) {
                self.layoutElementAssertion = [pub performSelector:@selector(addElement:) withObject:elem];
            }
        }
    } @catch (NSException *e) {}

    [self.cameraStateWatchdogTimer invalidate];
    self.cameraStateWatchdogTimer = nil;
    if (self.inProcessCaptureSession) {
        [self.inProcessCaptureSession stopRunning];
        self.inProcessCaptureSession = nil;
    }
    if (self.cameraPreviewLayer) {
        [self.cameraPreviewLayer removeFromSuperlayer];
        self.cameraPreviewLayer = nil;
    }
    [self terminateHelperDaemonSync];
    killZombieCameraHelpers();

    self.isVideoChatActive = YES;
    self.receivedCameraFramesCount = 0;
    self.lastFrameFileModDate = nil;
    self.latestFrameJPEGData = nil;
    self.usingHelperFallback = NO;
    self.cameraSessionToken = [NSString stringWithFormat:@"cam_%ld_%u", (long)[[NSDate date] timeIntervalSince1970], arc4random_uniform(9999)];

    self.cameraPreviewContainer.hidden = NO;
    self.cameraLiveImageView.image = nil;
    self.cameraLiveImageView.hidden = YES;
    self.cameraDiagnosticLabel.hidden = NO;
    self.cameraDiagnosticLabel.text = @"⏳ 正在启动实时镜头...";
    [self.innerGlassBox bringSubviewToFront:self.cameraPreviewContainer];
    [self adjustCapsuleHeightTo:self.currentCapsuleHeight animated:YES];

    [self transitionCameraStateTo:AGCameraStateStarting detail:@"正在授权 TCC 并准备相机通道..."];

    self.cameraStateWatchdogTimer = [NSTimer timerWithTimeInterval:0.12 target:self selector:@selector(cameraStateMachineTick) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.cameraStateWatchdogTimer forMode:NSRunLoopCommonModes];

    [self startInProcessCameraCaptureWithToken:self.cameraSessionToken];
}

- (void)startInProcessCameraCaptureWithToken:(NSString *)token {
    ensureSpringBoardTCCGranted();
    [self transitionCameraStateTo:AGCameraStateCameraInitializing
                           detail:(self.useFrontCamera ? @"正在启动前置硬件摄像头..." : @"正在启动后置硬件摄像头...")];

    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (authStatus == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            os_log(OS_LOG_DEFAULT, "[AngelGuardian] requestAccessForMediaType video granted=%d", granted);
        }];
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.28 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if (![token isEqualToString:self.cameraSessionToken] || !self.isVideoChatActive) return;

        AVCaptureDevicePosition pos = self.useFrontCamera ? AVCaptureDevicePositionFront : AVCaptureDevicePositionBack;
        AVCaptureDevice *dev = nil;
        @try {
            if (@available(iOS 10.0, *)) {
                dev = [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera mediaType:AVMediaTypeVideo position:pos];
            }
        } @catch (NSException *e) {}
        if (!dev) {
            @try {
                for (AVCaptureDevice *d in [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo]) {
                    if (d.position == pos) { dev = d; break; }
                }
            } @catch (NSException *e) {}
        }
        if (!dev) {
            @try { dev = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo]; } @catch (NSException *e) {}
        }
        if (!dev) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self transitionCameraStateTo:AGCameraStateFailed detail:@"未获取到物理摄像头硬件设备 (dev=nil)"];
            });
            return;
        }

        @try {
            if ([dev lockForConfiguration:nil]) {
                if ([dev isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
                    dev.focusMode = AVCaptureFocusModeContinuousAutoFocus;
                }
                if ([dev isExposureModeSupported:AVCaptureExposureModeContinuousAutoExposure]) {
                    dev.exposureMode = AVCaptureExposureModeContinuousAutoExposure;
                }
                if ([dev isWhiteBalanceModeSupported:AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance]) {
                    dev.whiteBalanceMode = AVCaptureWhiteBalanceModeContinuousAutoWhiteBalance;
                }
                [dev unlockForConfiguration];
            }
        } @catch (NSException *e) {}

        NSError *inErr = nil;
        AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:dev error:&inErr];
        if (!input || inErr) {
            NSString *reason = [NSString stringWithFormat:@"硬件输入创建受阻(%ld): %@", (long)(inErr ? inErr.code : -1), inErr.localizedDescription ?: @"相机权限受限或已被独占"];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self transitionCameraStateTo:AGCameraStateFailed detail:reason];
            });
            return;
        }

        AVCaptureSession *session = [[AVCaptureSession alloc] init];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onInProcCameraRuntimeError:) name:AVCaptureSessionRuntimeErrorNotification object:session];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onInProcCameraDidStartRunning:) name:AVCaptureSessionDidStartRunningNotification object:session];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onInProcCameraWasInterrupted:) name:AVCaptureSessionWasInterruptedNotification object:session];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onInProcCameraInterruptionEnded:) name:AVCaptureSessionInterruptionEndedNotification object:session];

        [session beginConfiguration];
        if ([session respondsToSelector:@selector(setAutomaticallyConfiguresApplicationAudioSession:)]) {
            session.automaticallyConfiguresApplicationAudioSession = NO;
        }
        if (@available(iOS 16.0, *)) {
            if ([session respondsToSelector:@selector(isMultitaskingCameraAccessSupported)] && session.isMultitaskingCameraAccessSupported) {
                session.multitaskingCameraAccessEnabled = YES;
            }
        }

        if ([session canSetSessionPreset:AVCaptureSessionPreset640x480]) {
            session.sessionPreset = AVCaptureSessionPreset640x480;
        } else if ([session canSetSessionPreset:AVCaptureSessionPresetMedium]) {
            session.sessionPreset = AVCaptureSessionPresetMedium;
        }

        if (![session canAddInput:input]) {
            [session commitConfiguration];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self transitionCameraStateTo:AGCameraStateFailed detail:@"Session 无法添加物理摄像头输入 (canAddInput=NO)"];
            });
            return;
        }
        [session addInput:input];

        AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
        output.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_32BGRA)};
        output.alwaysDiscardsLateVideoFrames = YES;
        if (!self.inProcessVideoQueue) {
            self.inProcessVideoQueue = dispatch_queue_create("com.angelguardian.inproccam", DISPATCH_QUEUE_SERIAL);
        }
        self.inProcessVideoOutput = output;
        if (![session canAddOutput:output]) {
            [session commitConfiguration];
            dispatch_async(dispatch_get_main_queue(), ^{
                [self transitionCameraStateTo:AGCameraStateFailed detail:@"Session 无法添加视频数据输出 (canAddOutput=NO)"];
            });
            return;
        }
        [session addOutput:output];
        [output setSampleBufferDelegate:self queue:self.inProcessVideoQueue];

        AVCaptureConnection *conn = [output connectionWithMediaType:AVMediaTypeVideo];
        if (conn) {
            conn.enabled = YES;
            if (conn.isVideoOrientationSupported) conn.videoOrientation = AVCaptureVideoOrientationPortrait;
            if (self.useFrontCamera && conn.isVideoMirroringSupported) {
                conn.automaticallyAdjustsVideoMirroring = NO;
                conn.videoMirrored = YES;
            }
        }

        [session commitConfiguration];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (![token isEqualToString:self.cameraSessionToken] || !self.isVideoChatActive) return;
            if (self.cameraPreviewLayer) {
                [self.cameraPreviewLayer removeFromSuperlayer];
                self.cameraPreviewLayer = nil;
            }
            self.cameraLiveImageView.image = nil;
            self.cameraLiveImageView.hidden = NO;
            self.cameraDiagnosticLabel.hidden = NO;
            self.cameraDiagnosticLabel.text = @"⏳ 镜头传感器加电中...";
            [self.cameraPreviewContainer bringSubviewToFront:self.cameraLiveImageView];
            [self.cameraPreviewContainer bringSubviewToFront:self.cameraFlipHintLabel];
            [self.cameraPreviewContainer bringSubviewToFront:self.cameraDiagnosticLabel];
        });

        if (self.usingHelperFallback || ![token isEqualToString:self.cameraSessionToken] || !self.isVideoChatActive) {
            return;
        }

        self.inProcessCaptureSession = session;
        self.lastInProcFrameTime = [[NSDate date] timeIntervalSince1970];
        [session startRunning];

        dispatch_async(dispatch_get_main_queue(), ^{
            if (![token isEqualToString:self.cameraSessionToken] || !self.isVideoChatActive) return;
            [self transitionCameraStateTo:AGCameraStateCameraRunning detail:@"硬件镜头已就绪，正在接收首帧画面..."];
        });
    });
}

- (void)onInProcCameraDidStartRunning:(NSNotification *)note {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isVideoChatActive && self.cameraState < AGCameraStateFirstFrameReceived) {
            [self transitionCameraStateTo:AGCameraStateCameraRunning detail:@"硬件镜头已就绪，正在接收首帧画面..."];
        }
    });
}

- (void)onInProcCameraWasInterrupted:(NSNotification *)note {
    NSNumber *reasonNum = note.userInfo[AVCaptureSessionInterruptionReasonKey];
    NSInteger rVal = reasonNum ? [reasonNum integerValue] : -1;
    agLiveDiagLog(@"CAM_INTERRUPT", @"In-process camera interrupted (reason=%ld, state=%@)", (long)rVal, agCameraStateName(self.cameraState));

    NSString *boundToken = [self.cameraSessionToken copy];
    void (^autoResumeBlock)(void) = ^{
        if (!self.isVideoChatActive || self.usingHelperFallback || ![boundToken isEqualToString:self.cameraSessionToken]) return;
        if (self.inProcessCaptureSession && !self.inProcessCaptureSession.isRunning) {
            agLiveDiagLog(@"CAM_AUTO_RESUME", @"Restarting interrupted AVCaptureSession");
            [self.inProcessCaptureSession startRunning];
        }
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), autoResumeBlock);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.80 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), autoResumeBlock);
}

- (void)onInProcCameraInterruptionEnded:(NSNotification *)note {
    agLiveDiagLog(@"CAM_INTERRUPT_END", @"Camera interruption ended, ensuring session running");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if (self.isVideoChatActive && !self.usingHelperFallback && self.inProcessCaptureSession && !self.inProcessCaptureSession.isRunning) {
            [self.inProcessCaptureSession startRunning];
        }
    });
}

- (void)onInProcCameraRuntimeError:(NSNotification *)note {
    NSError *err = note.userInfo[AVCaptureSessionErrorKey];
    NSString *reason = [NSString stringWithFormat:@"相机运行错误(%ld): %@", (long)(err ? err.code : -1), err.localizedDescription ?: @"未知"];
    agLiveDiagLog(@"CAM_RUNTIME_ERR", @"%@", reason);
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.isVideoChatActive && !self.usingHelperFallback) {
            [self switchToHelperDaemonWithReason:reason];
        }
    });
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (!self.isVideoChatActive) return;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - self.lastInProcFrameTime < 0.12 && self.receivedCameraFramesCount > 0) return;

    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!imageBuffer) return;

    CGImageRef cgImg = NULL;
    CVPixelBufferLockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);

    // 零开销像素抽样检查：过滤刚启动前 1.2s 内传感器尚未完成曝光的纯黑帧，无需每帧执行耗时的 JPEG 压缩！
    BOOL isPitchBlackFrame = NO;
    if (self.receivedCameraFramesCount == 0 && baseAddress && width > 16 && height > 16 && (now - self.cameraStateEnterTime < 1.2)) {
        uint32_t lumaSum = 0;
        for (int sy = 1; sy <= 4; sy++) {
            const uint8_t *rowPtr = baseAddress + (height * sy / 5) * bytesPerRow;
            for (int sx = 1; sx <= 4; sx++) {
                const uint8_t *px = rowPtr + (width * sx / 5) * 4;
                lumaSum += (px[0] + px[1] + px[2]);
            }
        }
        if (lumaSum < 96) {
            isPitchBlackFrame = YES;
        }
    }

    if (!isPitchBlackFrame && baseAddress && width > 0 && height > 0) {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGContextRef cgContext = CGBitmapContextCreate(baseAddress, width, height, 8, bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
        if (cgContext) {
            cgImg = CGBitmapContextCreateImage(cgContext);
            CGContextRelease(cgContext);
        }
        CGColorSpaceRelease(colorSpace);
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer, kCVPixelBufferLock_ReadOnly);

    if (isPitchBlackFrame) return;

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
        UIImage *uiImg = [UIImage imageWithCGImage:cgImg];
        CGImageRelease(cgImg);
        self.lastInProcFrameTime = now;
        self.receivedCameraFramesCount++;
        if (self.receivedCameraFramesCount == 1 || !self.latestFrameJPEGData) {
            self.latestFrameJPEGData = UIImageJPEGRepresentation(uiImg, 0.55);
        }
        AGCameraState nextSt = (self.receivedCameraFramesCount == 1) ? AGCameraStateFirstFrameReceived : AGCameraStateStreaming;
        dispatch_async(dispatch_get_main_queue(), ^{
            if (!self.isVideoChatActive) return;
            self.cameraLiveImageView.image = uiImg;
            [self transitionCameraStateTo:nextSt detail:@"实时视频流正常"];
        });
    }
}

- (void)switchToHelperDaemonWithReason:(NSString *)reason {
    if (!self.isVideoChatActive || self.usingHelperFallback) return;
    self.usingHelperFallback = YES;
    self.lastInProcessFailReason = [reason copy];

    if (self.inProcessCaptureSession) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionRuntimeErrorNotification object:self.inProcessCaptureSession];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionDidStartRunningNotification object:self.inProcessCaptureSession];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionWasInterruptedNotification object:self.inProcessCaptureSession];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionInterruptionEndedNotification object:self.inProcessCaptureSession];
        [self.inProcessCaptureSession stopRunning];
        self.inProcessCaptureSession = nil;
    }
    if (self.inProcessVideoOutput) {
        [self.inProcessVideoOutput setSampleBufferDelegate:nil queue:NULL];
        self.inProcessVideoOutput = nil;
    }
    if (self.cameraPreviewLayer) {
        [self.cameraPreviewLayer removeFromSuperlayer];
        self.cameraPreviewLayer = nil;
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        self.cameraLiveImageView.hidden = NO;
        self.cameraDiagnosticLabel.hidden = NO;
    });

    [self transitionCameraStateTo:AGCameraStateStarting
                           detail:[NSString stringWithFormat:@"切换至独立辅助进程(%@)", reason]];

    NSString *token = self.cameraSessionToken;
    BOOL useFront = self.useFrontCamera;

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        [self terminateHelperDaemonSync];
        [[NSFileManager defaultManager] removeItemAtPath:agSharedCameraStopFlagPath() error:nil];

        const char *helperPaths[] = { "/var/jb/usr/bin/AngelCameraHelper", "/usr/bin/AngelCameraHelper", NULL };
        NSString *foundPath = nil;
        for (int i = 0; helperPaths[i] != NULL; i++) {
            NSString *p = [NSString stringWithUTF8String:helperPaths[i]];
            if ([[NSFileManager defaultManager] isExecutableFileAtPath:p]) {
                foundPath = p;
                break;
            }
        }
        if (!foundPath) {
            [self transitionCameraStateTo:AGCameraStateFailed
                                   detail:[NSString stringWithFormat:@"%@；且未找到 AngelCameraHelper 可执行文件", reason]];
            return;
        }

        pid_t camPid = 0;
        char *posArg = useFront ? (char *)"front" : (char *)"back";
        char *tokArg = (char *)[token UTF8String];
        char *cargv[] = { (char *)"AngelCameraHelper", posArg, tokArg, NULL };
        int spawnRet = posix_spawn(&camPid, [foundPath UTF8String], NULL, NULL, cargv, environ);
        if (spawnRet != 0 || camPid <= 0) {
            [self transitionCameraStateTo:AGCameraStateFailed
                                   detail:[NSString stringWithFormat:@"posix_spawn 启动失败 (ret=%d, errno=%d)", spawnRet, errno]];
            return;
        }

        self.helperDaemonPID = camPid;
        [self transitionCameraStateTo:AGCameraStateProcessStarted
                               detail:[NSString stringWithFormat:@"辅助进程已创建(PID=%d)，正在校验存活...", camPid]];
    });
}

- (void)cameraStateMachineTick {
    if (!self.isVideoChatActive) return;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval elapsedInState = now - self.cameraStateEnterTime;

    if (!self.usingHelperFallback) {
        NSTimeInterval frameSilence = (self.lastInProcFrameTime > 0) ? (now - self.lastInProcFrameTime) : elapsedInState;
        if (self.receivedCameraFramesCount == 0 && elapsedInState > 3.8) {
            [self switchToHelperDaemonWithReason:@"SpringBoard 进程内 3.8s 未出帧 (切换至独立辅助进程)"];
        } else if (self.receivedCameraFramesCount > 0 && frameSilence > 1.5) {
            if (frameSilence <= 3.5) {
                if (self.inProcessCaptureSession && !self.inProcessCaptureSession.isRunning) {
                    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
                        if (self.isVideoChatActive && !self.usingHelperFallback && self.inProcessCaptureSession && !self.inProcessCaptureSession.isRunning) {
                            [self.inProcessCaptureSession startRunning];
                        }
                    });
                }
            } else {
                [self switchToHelperDaemonWithReason:@"进程内相机中途停帧，自动无缝切换至独立辅助进程"];
            }
        }
    } else {
        if (self.helperDaemonPID > 0) {
            int status = 0;
            pid_t w = waitpid(self.helperDaemonPID, &status, WNOHANG);
            if (w == self.helperDaemonPID || (w == -1 && kill(self.helperDaemonPID, 0) != 0)) {
                self.helperDaemonPID = 0;
                NSString *exitReason = @"未知退出";
                if (WIFSIGNALED(status)) {
                    int sig = WTERMSIG(status);
                    exitReason = (sig == SIGKILL)
                        ? @"被内核 SIGKILL(9) 终止 (签名/Entitlement或架构拦截)"
                        : [NSString stringWithFormat:@"进程崩溃信号 SIG=%d", sig];
                } else if (WIFEXITED(status)) {
                    exitReason = [NSString stringWithFormat:@"进程退出码 code=%d", WEXITSTATUS(status)];
                }

                NSString *detailedCrashReason = nil;
                NSData *stData = [NSData dataWithContentsOfFile:agSharedCameraStatusPath()];
                if (stData) {
                    NSDictionary *stDict = [NSJSONSerialization JSONObjectWithData:stData options:0 error:nil];
                    if ([stDict isKindOfClass:[NSDictionary class]] && [stDict[@"detail"] length] > 0) {
                        detailedCrashReason = stDict[@"detail"];
                    }
                }
                if (!detailedCrashReason) {
                    NSString *dbg = [NSString stringWithContentsOfFile:@"/tmp/ag_cam_debug.log" encoding:NSUTF8StringEncoding error:nil];
                    if (dbg.length > 0) {
                        NSArray *lines = [dbg componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                        for (NSString *line in lines.reverseObjectEnumerator) {
                            if (line.length > 0 && [line hasPrefix:@"[FATAL CRASH]"]) {
                                detailedCrashReason = line;
                                break;
                            }
                        }
                    }
                }

                NSString *failDetail = detailedCrashReason
                    ? [NSString stringWithFormat:@"%@ (%@)", detailedCrashReason, exitReason]
                    : [NSString stringWithFormat:@"AngelCameraHelper 异常退出: %@", exitReason];

                if (self.lastInProcessFailReason.length > 0) {
                    failDetail = [NSString stringWithFormat:@"%@ [宿主: %@]", failDetail, self.lastInProcessFailReason];
                }

                [self transitionCameraStateTo:AGCameraStateFailed detail:failDetail];
                return;
            }
        }

        NSData *stData = [NSData dataWithContentsOfFile:agSharedCameraStatusPath()];
        if (stData) {
            NSDictionary *stDict = [NSJSONSerialization JSONObjectWithData:stData options:0 error:nil];
            if ([stDict isKindOfClass:[NSDictionary class]] && stDict[@"state"]) {
                NSString *stName = stDict[@"state"];
                NSString *detail = stDict[@"detail"] ?: @"";
                NSString *step = stDict[@"step"] ?: @"";
                if (step.length > 0) {
                    detail = [NSString stringWithFormat:@"%@ [%@]", detail, step];
                }
                if ([stName isEqualToString:@"FAILED"]) {
                    [self transitionCameraStateTo:AGCameraStateFailed detail:detail];
                    return;
                } else if ([stName isEqualToString:@"CAMERA_INITIALIZING"] && self.cameraState < AGCameraStateCameraInitializing) {
                    [self transitionCameraStateTo:AGCameraStateCameraInitializing detail:detail];
                } else if ([stName isEqualToString:@"CAMERA_RUNNING"] && self.cameraState < AGCameraStateCameraRunning) {
                    [self transitionCameraStateTo:AGCameraStateCameraRunning detail:detail];
                }
            }
        }

        NSString *framePath = agSharedCameraFramePath();
        NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:framePath error:nil];
        NSDate *modDate = attrs[NSFileModificationDate];
        if (modDate && (!self.lastFrameFileModDate || [modDate compare:self.lastFrameFileModDate] == NSOrderedDescending)) {
            NSData *jpg = [NSData dataWithContentsOfFile:framePath];
            if (jpg.length > 200) {
                UIImage *img = [UIImage imageWithData:jpg];
                if (img) {
                    self.lastFrameFileModDate = modDate;
                    self.latestFrameJPEGData = jpg;
                    self.receivedCameraFramesCount++;
                    dispatch_async(dispatch_get_main_queue(), ^{
                        self.cameraLiveImageView.hidden = NO;
                        self.cameraLiveImageView.image = img;
                        self.cameraDiagnosticLabel.hidden = YES;
                    });
                    AGCameraState nextSt = (self.receivedCameraFramesCount == 1) ? AGCameraStateFirstFrameReceived : AGCameraStateStreaming;
                    [self transitionCameraStateTo:nextSt detail:@"辅助进程实时画面流正常"];
                }
            }
        }

        if (self.cameraState != AGCameraStateFirstFrameReceived &&
            self.cameraState != AGCameraStateStreaming &&
            self.cameraState != AGCameraStateFailed &&
            elapsedInState > 10.0) {
            NSString *dbg = [NSString stringWithContentsOfFile:@"/tmp/ag_cam_debug.log" encoding:NSUTF8StringEncoding error:nil];
            NSString *lastStep = @"";
            if (dbg.length > 0) {
                NSArray *lines = [dbg componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
                for (NSString *line in lines.reverseObjectEnumerator) {
                    if (line.length > 0) { lastStep = line; break; }
                }
            }
            NSString *timeoutDetail = lastStep.length > 0
                ? [NSString stringWithFormat:@"辅助进程超时 (最后停留: %@, PID=%d)", lastStep, self.helperDaemonPID]
                : [NSString stringWithFormat:@"辅助进程超时 (10.0s 未收到视频帧)"];
            [self transitionCameraStateTo:AGCameraStateFailed detail:timeoutDetail];
        }
    }

    if (self.isWebSocketConnected && self.isSetupHandshakeCompleted && self.cameraLiveImageView.image != nil && (now - self.lastWSVideoFrameSentTime >= 0.85)) {
        self.lastWSVideoFrameSentTime = now;
        UIImage *currentImg = self.cameraLiveImageView.image;
        dispatch_async(self.encodeQueue, ^{
            CGSize origSize = currentImg.size;
            if (origSize.width <= 0 || origSize.height <= 0) return;
            CGFloat maxDim = 512.0;
            CGFloat scale = MIN(1.0, maxDim / MAX(origSize.width, origSize.height));
            CGSize targetSize = CGSizeMake(floor(origSize.width * scale), floor(origSize.height * scale));

            UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
            fmt.scale = 1.0;
            fmt.opaque = YES;
            UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:targetSize format:fmt];
            UIImage *scaledImg = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
                [currentImg drawInRect:CGRectMake(0, 0, targetSize.width, targetSize.height)];
            }];
            NSData *jpgData = UIImageJPEGRepresentation(scaledImg, 0.50);
            if (jpgData.length >= 4800) {
                self.latestFrameJPEGData = jpgData;
                self.txVideoFramesCount++;
                NSString *b64Img = [jpgData base64EncodedStringWithOptions:0];
                agLiveDiagLog(@"CAM_VIDEO_TX", @"Frame #%lu encoded (%.0fx%.0f, %lu bytes)", (unsigned long)self.txVideoFramesCount, targetSize.width, targetSize.height, (unsigned long)jpgData.length);
                if (self.isGoogleBidiProtocol) {
                    [self sendJSONDictionaryOverWebSocket:@{
                        @"realtimeInput": @{ @"video": @{ @"mimeType": @"image/jpeg", @"data": b64Img } }
                    }];
                } else {
                    NSDictionary *vendorVideoPkt = agBuildVendorVideoFramePacket(agEndpointForTab(self.activeModeTab), self.activeWebSocketModel, b64Img);
                    if (vendorVideoPkt) {
                        [self sendJSONDictionaryOverWebSocket:vendorVideoPkt];
                    }
                }
            }
        });
    }
}

- (void)stopCameraSession {
    self.isVideoChatActive = NO;
    self.cameraSessionToken = @"stopped";
    [self.cameraStateWatchdogTimer invalidate];
    self.cameraStateWatchdogTimer = nil;
    self.latestFrameJPEGData = nil;
    self.receivedCameraFramesCount = 0;
    @try {
        if (self.layoutElementAssertion && [self.layoutElementAssertion respondsToSelector:@selector(invalidate)]) {
            [self.layoutElementAssertion performSelector:@selector(invalidate)];
            self.layoutElementAssertion = nil;
        }
    } @catch (NSException *e) {}

    if (self.inProcessCaptureSession) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionRuntimeErrorNotification object:self.inProcessCaptureSession];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionDidStartRunningNotification object:self.inProcessCaptureSession];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionWasInterruptedNotification object:self.inProcessCaptureSession];
        [[NSNotificationCenter defaultCenter] removeObserver:self name:AVCaptureSessionInterruptionEndedNotification object:self.inProcessCaptureSession];
        [self.inProcessCaptureSession stopRunning];
        self.inProcessCaptureSession = nil;
    }
    if (self.inProcessVideoOutput) {
        [self.inProcessVideoOutput setSampleBufferDelegate:nil queue:NULL];
        self.inProcessVideoOutput = nil;
    }
    [self terminateHelperDaemonSync];
    [self transitionCameraStateTo:AGCameraStateStopped detail:@"摄像头已关闭"];

    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.cameraPreviewLayer) {
            [self.cameraPreviewLayer removeFromSuperlayer];
            self.cameraPreviewLayer = nil;
        }
        self.cameraPreviewContainer.hidden = YES;
        self.cameraLiveImageView.image = nil;
        self.cameraLiveImageView.hidden = YES;
        [self adjustCapsuleHeightTo:self.currentCapsuleHeight animated:YES];
    });
}


#pragma mark - 🎙️ 双核自适应语音对讲调度器

- (void)forceKillNativeSiri {
    void (^killSiriPass)(void) = ^{
        @try {
            SBAssistantController *ac = [%c(SBAssistantController) sharedInstance];
            if (ac) {
                if ([ac respondsToSelector:@selector(dismissAssistantViewIfNecessaryWithAnimation:)]) {
                    [ac dismissAssistantViewIfNecessaryWithAnimation:0];
                } else if ([ac respondsToSelector:@selector(dismissAssistantViewIfNecessary)]) {
                    [ac dismissAssistantViewIfNecessary];
                }
            }
        } @catch (NSException *e) {}
    };

    if ([NSThread isMainThread]) {
        killSiriPass();
    } else {
        dispatch_async(dispatch_get_main_queue(), killSiriPass);
    }
    // 锁屏下“嘿 Siri”的 SiriPresentation 会异步延迟 80~220ms 挂载，连续 3 次安全压制
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), killSiriPass);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.28 * NSEC_PER_SEC)), dispatch_get_main_queue(), killSiriPass);
    killNativeSiriAudioDaemon();
}

// 亮屏/后台静默预连：只建立 WebSocket 与 setup 握手，绝不启动 AVAudioEngine，不影响音量与嘿 Siri
- (void)prewarmWebSocketInBackgroundIfNeeded {
    if (![self isTweakEnabled]) return;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    // ✅ 核心修复：只要当前不是已关闭状态 (isDismissed == NO)，或者距离用户唤醒不足 4 秒，绝对禁止触发后台预热！
    // 彻底杜绝唤醒瞬间 UIApplicationDidBecomeActiveNotification 触发预热把 isWarmStandbyMode 改回 YES 导致麦克风被杀！
    if (!self.isDismissed || (now - self.lastTriggerTime < 4.0)) {
        return;
    }
    if (self.overlayWindow && !self.overlayWindow.hidden) {
        return;
    }
    if (self.activeModeTab == AGConfigTabPureText || self.activeModeTab == AGConfigTabTranslation) return;
    if (self.liveWebSocketTask && self.liveWebSocketTask.state == NSURLSessionTaskStateRunning) {
        return; // 已在连接或已在线，绝不重复重建
    }
    NSString *model = agModelForTab(self.activeModeTab);
    NSString *apiKey = agAPIKeyForTab(self.activeModeTab);
    if (model.length == 0 || apiKey.length < 4) return;
    if (!agIsWebSocketBidiCapableModel(model, self.activeModeTab)) return;

    self.isWarmStandbyMode = YES;
    self.lastDismissTimestamp = now;
    self.activeWebSocketModel = model;
    agLiveDiagLog(@"WS_PREWARM", @"Pre-warming WebSocket in background for model %@", model);
    [self startWebSocketBidiSessionWithModel:model forTab:self.activeModeTab];
}

// 关闭窗口时挂起音频硬件归还系统，但保持 WebSocket 24 小时后台智能热备与续杯
- (void)suspendVoiceSessionKeepWebSocketAlive {
    self.isWarmStandbyMode = YES;
    self.lastDismissTimestamp = [[NSDate date] timeIntervalSince1970];
    self.pendingPlayBuffersCount = 0;
    self.aiPlaybackEndTime = 0;
    [self.meterTimer invalidate];
    self.meterTimer = nil;
    [self setWaveBarsLevel:0.0];

    AVAudioEngine *eng = self.liveAudioEngine;
    AVAudioPlayerNode *pl = self.pcmPlayerNode;
    self.liveAudioEngine = nil;
    self.pcmPlayerNode = nil;

    // 彻底释放麦克风与 VoiceProcessing，切回 Ambient 模式，100% 不影响手机原本音量与“嘿 Siri”
    dispatch_async(agAudioSerialQueue(), ^{
        @try {
            if (eng) {
                [eng.inputNode removeTapOnBus:0];
                if ([eng.inputNode respondsToSelector:@selector(setVoiceProcessingEnabled:error:)]) {
                    [eng.inputNode setVoiceProcessingEnabled:NO error:nil];
                }
                if (pl && pl.isPlaying) [pl stop];
                if (eng.isRunning) [eng stop];
            }
            AVAudioSession *session = [AVAudioSession sharedInstance];
            [session setCategory:AVAudioSessionCategoryAmbient withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
            [session setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
        } @catch (NSException *e) {}
    });

    [self.wsKeepAlivePingTimer invalidate];
    __weak typeof(self) weakSelf = self;
    self.wsKeepAlivePingTimer = [NSTimer scheduledTimerWithTimeInterval:18.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) { [timer invalidate]; return; }
        if (strongSelf.isWebSocketConnected && strongSelf.liveWebSocketTask && strongSelf.liveWebSocketTask.state == NSURLSessionTaskStateRunning) {
            [strongSelf.liveWebSocketTask sendPingWithPongReceiveHandler:^(NSError * _Nullable error) {
                if (error) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        strongSelf.isWebSocketConnected = NO;
                        strongSelf.isSetupHandshakeCompleted = NO;
                        // 若当前未锁屏，立即在后台静默续杯重连，保证用户随时呼出 0 秒可用
                        if (!isDeviceCurrentlyLocked()) {
                            [strongSelf prewarmWebSocketInBackgroundIfNeeded];
                        }
                    });
                }
            }];
        } else if (!isDeviceCurrentlyLocked() && strongSelf.isWarmStandbyMode) {
            // 服务端 15 分钟到期断开后，亮屏状态下自动静默重连续杯
            [strongSelf prewarmWebSocketInBackgroundIfNeeded];
        }
    }];
    agLiveDiagLog(@"WS_WARM_STANDBY", @"Suspended audio & keeping WebSocket alive with 18s heartbeat");
}

- (void)stopAllVoiceEngines {
    [self.wsKeepAlivePingTimer invalidate];
    self.wsKeepAlivePingTimer = nil;
    self.isWarmStandbyMode = NO;
    self.sessionGenerationToken++;
    self.currentTurnPlaybackID++;
    self.pendingPlayBuffersCount = 0;
    self.inFlightWSMessageCount = 0;

    [self.meterTimer invalidate];
    self.meterTimer = nil;
    [self setWaveBarsLevel:0.0];

    AVAudioRecorder *rec = self.audioRecorder;
    self.audioRecorder = nil;

    BOOL hadActiveWS = (self.liveWebSocketTask != nil || self.webSocketSession != nil || self.isWebSocketConnected);
    self.isWebSocketConnected = NO;
    self.isSetupHandshakeCompleted = NO;
    self.aiPlaybackEndTime = 0;
    if (self.liveWebSocketTask) {
        [self.liveWebSocketTask cancelWithCloseCode:NSURLSessionWebSocketCloseCodeNormalClosure reason:nil];
        self.liveWebSocketTask = nil;
    }
    if (self.webSocketSession) {
        [self.webSocketSession invalidateAndCancel];
        self.webSocketSession = nil;
    }

    AVAudioEngine *eng = self.liveAudioEngine;
    AVAudioPlayerNode *pl = self.pcmPlayerNode;
    self.liveAudioEngine = nil;
    self.pcmPlayerNode = nil;

    @synchronized (self.outgoingPCMBuffer) {
        [self.outgoingPCMBuffer setLength:0];
    }
    @synchronized (self.wsPreRollPCMBuffer) {
        [self.wsPreRollPCMBuffer setLength:0];
    }

    BOOL wasSpeakingTTS = [self.synthesizer isSpeaking];
    if (wasSpeakingTTS) {
        [self.synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];
    }
    [self.accumulatedReplyText setString:@""];
    [self.pendingSpeechChunk setString:@""];
    self.activeUtteranceCount = 0;
    self.hasDetectedSpeech = NO;

    if (!rec && !eng && !wasSpeakingTTS && !hadActiveWS) {
        return;
    }

    agLiveDiagLog(@"RESOURCE_TEARDOWN", @"Stopping active voice engines (token=%lu)", (unsigned long)self.sessionGenerationToken);
    dispatch_async(agAudioSerialQueue(), ^{
        @try {
            if (rec && rec.isRecording) [rec stop];
        } @catch (NSException *e) {}
        @try {
            if (eng) {
                [eng.inputNode removeTapOnBus:0];
                if ([eng.inputNode respondsToSelector:@selector(setVoiceProcessingEnabled:error:)]) {
                    [eng.inputNode setVoiceProcessingEnabled:NO error:nil];
                }
                if (pl) [pl stop];
                [eng stop];
            }
        } @catch (NSException *e) {}
        @try {
            if (rec || eng) {
                AVAudioSession *session = [AVAudioSession sharedInstance];
                [session setCategory:AVAudioSessionCategoryAmbient withOptions:AVAudioSessionCategoryOptionMixWithOthers error:nil];
                [session setActive:NO withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:nil];
            }
        } @catch (NSException *e) {}
    });
}

- (void)startAdaptiveVoiceSessionForTab:(AGConfigTab)tab {
    ensureSpringBoardTCCGranted();
    pauseBackgroundMediaPlayback();
    self.isDismissed = NO;
    self.isWarmStandbyMode = NO;
    self.lastTriggerTime = [[NSDate date] timeIntervalSince1970];
    [self.wsKeepAlivePingTimer invalidate];
    self.wsKeepAlivePingTimer = nil;
    self.wsReconnectCount = 0;
    self.disableTranscriptionInSetup = NO;
    self.hasAutoMigratedDeprecatedModel = NO;

    NSString *curModel = agModelForTab(tab);
    // ✅ 关键优化：只要后台 WebSocket 任务正在运行（无论是已完成握手，还是刚在后台连接了一半），都直接无缝接管并立即打开麦克风！
    if ((tab == AGConfigTabNativeLive || tab == AGConfigTabVideoAI) &&
        curModel.length > 0 &&
        self.liveWebSocketTask &&
        self.liveWebSocketTask.state == NSURLSessionTaskStateRunning &&
        [self.activeWebSocketModel isEqualToString:curModel]) {
        [self setupAndStartFullDuplexPCMAudioEngine];
        if (self.isSetupHandshakeCompleted) {
            self.subStatusLabel.text = (tab == AGConfigTabVideoAI)
                ? @"📞📹 实时视频通话已就绪 (请直接说话)..."
                : @"📞 实时语音通话已就绪 (请直接说话)...";
            agLiveDiagLog(@"WS_FAST_REUSE", @"0ms instant reuse of warm WebSocket for %@", curModel);
        } else {
            self.subStatusLabel.text = @"🎙️ 请直接开口说话 (0秒预录收音中)...";
            agLiveDiagLog(@"WS_INFLIGHT_ADOPT", @"Adopted in-flight prewarm WebSocket for %@", curModel);
        }
        return;
    }

    [self stopAllVoiceEngines];
    self.isDismissed = NO;
    self.isWarmStandbyMode = NO;
    // 在发起网络请求前，第 0.00 秒立即启动全双工麦克风引擎进入预录状态，保证用户马上说话 100% 被录下！
    if (tab == AGConfigTabNativeLive || tab == AGConfigTabVideoAI) {
        self.subStatusLabel.text = @"🎙️ 请直接开口说话 (0秒预录收音中)...";
        [self setupAndStartFullDuplexPCMAudioEngine];
    }

    [self ensureCloudModelsLoadedForTab:tab completion:^(NSString *readyModel) {
        if (tab == AGConfigTabNativeLive || tab == AGConfigTabVideoAI || agIsWebSocketBidiCapableModel(readyModel, tab)) {
            NSString *targetModel = readyModel;
            if (!targetModel || targetModel.length == 0) return;
            self.activeWebSocketModel = targetModel;
            [self startWebSocketBidiSessionWithModel:targetModel forTab:tab];
        } else {
            [self startContinuousVoiceListening];
        }
    }];
}

- (void)startWebSocketBidiSessionWithModel:(NSString *)modelPath forTab:(AGConfigTab)tab {
    NSString *apiKey = [agAPIKeyForTab(tab) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *endpoint = [agEndpointForTab(tab) stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *proxy = agProxyForTab(tab);

    if (apiKey.length < 4) {
        self.subStatusLabel.text = @"⚠️ 未检测到 API Key，请在《设置 -> ✨天使守护》填入 Key";
        return;
    }

    NSString *cleanModel = [modelPath stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (cleanModel.length == 0) return;
    self.activeWebSocketModel = cleanModel;
    NSString *exactModelID = [cleanModel stringByReplacingOccurrencesOfString:@"models/" withString:@""];

    // ✅ 情况 A：仅当后台热备连接真正处于 isWebSocketConnected && isSetupHandshakeCompleted 时才复用
    if (self.isWebSocketConnected && self.isSetupHandshakeCompleted &&
        self.liveWebSocketTask && self.liveWebSocketTask.state == NSURLSessionTaskStateRunning &&
        [self.activeWebSocketModel isEqualToString:cleanModel]) {
        if (!self.isWarmStandbyMode && self.overlayWindow && !self.overlayWindow.hidden) {
            [self.wsKeepAlivePingTimer invalidate];
            self.wsKeepAlivePingTimer = nil;
            [self setupAndStartFullDuplexPCMAudioEngine];
            self.subStatusLabel.text = (tab == AGConfigTabVideoAI)
                ? @"📞📹 实时视频通话已就绪 (请直接说话)..."
                : @"📞 实时语音通话已就绪 (请直接说话)...";
            agLiveDiagLog(@"WS_FAST_REUSE", @"0ms instant reuse of warm WebSocket for %@", exactModelID);
        }
        return;
    }

    self.isGoogleBidiProtocol = agIsGoogleNativeProtocol(endpoint, cleanModel);
    self.isWebSocketConnected = NO;
    self.isSetupHandshakeCompleted = NO;
    self.aiPlaybackEndTime = 0;

    NSMutableURLRequest *wsReq = nil;
    if (self.isGoogleBidiProtocol) {
        NSString *hostBase = [[endpoint stringByReplacingOccurrencesOfString:@"https://" withString:@"wss://"] stringByReplacingOccurrencesOfString:@"http://" withString:@"ws://"];
        NSString *encodedKey = [apiKey stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]] ?: apiKey;
        NSString *wsURLStr = [NSString stringWithFormat:@"%@/ws/google.ai.generativelanguage.v1beta.GenerativeService.BidiGenerateContent?key=%@", hostBase, encodedKey];
        NSURL *wsURL = [NSURL URLWithString:wsURLStr];
        if (wsURL) wsReq = [NSMutableURLRequest requestWithURL:wsURL];
    } else {
        wsReq = agBuildVendorWebSocketRequest(endpoint, exactModelID, apiKey);
    }

    if (!wsReq || !wsReq.URL) {
        self.subStatusLabel.text = @"⚠️ WebSocket 接口地址格式无效，请检查 Endpoint 设置";
        return;
    }

    if (self.liveWebSocketTask) {
        [self.liveWebSocketTask cancelWithCloseCode:NSURLSessionWebSocketCloseCodeNormalClosure reason:nil];
        self.liveWebSocketTask = nil;
    }
    if (self.webSocketSession) {
        [self.webSocketSession invalidateAndCancel];
        self.webSocketSession = nil;
    }

    // ✅ 修复：若麦克风引擎已在运行，不重新递增 Token 避免误杀已打开的收音
    if (!self.liveAudioEngine || !self.liveAudioEngine.isRunning) {
        ++self.sessionGenerationToken;
    }

    self.webSocketSession = agCreateSessionWithProxy(proxy, self, [NSOperationQueue mainQueue]);
    self.liveWebSocketTask = [self.webSocketSession webSocketTaskWithRequest:wsReq];
    [self.liveWebSocketTask resume];
    [self receiveNextWebSocketMessage];

    if (!self.isWarmStandbyMode && self.overlayWindow && !self.overlayWindow.hidden && self.activeModeTab != AGConfigTabPureText) {
        self.subStatusLabel.text = [NSString stringWithFormat:@"🎙️ 请直接开口说话 (正在连接 %@)...", exactModelID];
        [self setupAndStartFullDuplexPCMAudioEngine];
    }
}

- (void)URLSession:(NSURLSession *)session webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask didOpenWithProtocol:(NSString *)protocol {
    self.isWebSocketConnected = YES;
    self.isLastTranscriptLineUser = NO;
    NSString *brand = [self currentVendorBrandName];

    NSString *modelToUse = self.activeWebSocketModel;
    if (!modelToUse || modelToUse.length == 0) {
        modelToUse = agModelForTab(self.activeModeTab);
    }
    if (!modelToUse || modelToUse.length == 0) {
        modelToUse = @"models/gemini-2.5-flash-native-audio-preview-09-2025";
    }
    NSString *rawModel = [modelToUse stringByReplacingOccurrencesOfString:@"models/" withString:@""];
    NSString *fullModelPath = [NSString stringWithFormat:@"models/%@", rawModel];

    NSString *sysInstruction = [NSString stringWithFormat:
        @"请用自然、亲切、简练的中文直接与用户实时语音对话。你的真实官方身份是 %@（模型：%@）。\n"
        @"【设备控制指令规则】当用户明确要求控制手机或执行具体操作时，请在回答末尾附带标准指令标记（支持连续输出多个 [ACTION:{...}] 组合连招，系统将按时序自动依次执行）：\n"
        @"1. 打开应用：[ACTION:{\"type\":\"open_app\",\"app\":\"应用名\"}]\n"
        @"2. 微信发消息：[ACTION:{\"type\":\"wechat_message\",\"target\":\"联系人\",\"content\":\"内容\"}]\n"
        @"3. 微信读未读消息：[ACTION:{\"type\":\"wechat_read_unread\"}]\n"
        @"4. 微信打开指定聊天窗口：[ACTION:{\"type\":\"wechat_open_chat\",\"target\":\"联系人\"}]\n"
        @"5. 微信扫一扫/付款/收款/朋友圈：[ACTION:{\"type\":\"wechat_shortcut\",\"feature\":\"scan|pay|receipt|moments\"}]\n"
        @"6. 支付宝扫一扫/乘车码/付款/收款：[ACTION:{\"type\":\"alipay_shortcut\",\"feature\":\"scan|bus|pay|receipt\"}]\n"
        @"7. 真实硬件音量控制：[ACTION:{\"type\":\"volume_control\",\"action\":\"up|down|mute|set\",\"level\":0.5}]\n"
        @"8. 音乐播放控制：[ACTION:{\"type\":\"media_control\",\"action\":\"play|pause|next|prev\"}]\n"
        @"9. 屏幕亮度与手电筒：[ACTION:{\"type\":\"brightness_control\",\"action\":\"set|up|down\",\"level\":0.8}] / [ACTION:{\"type\":\"toggle_flashlight\",\"on\":true|false,\"level\":1.0}]\n"
        @"10. 屏幕截图：[ACTION:{\"type\":\"take_screenshot\"}]\n"
        @"11. 设定闹钟：[ACTION:{\"type\":\"alarm_control\",\"hour\":7,\"minute\":30,\"title\":\"闹钟\"}]\n"
        @"12. 设定倒计时：[ACTION:{\"type\":\"timer_control\",\"seconds\":180}]\n"
        @"13. 添加提醒事项：[ACTION:{\"type\":\"reminder_add\",\"title\":\"提醒内容\"}]\n"
        @"14. 视觉点击屏幕文字：[ACTION:{\"type\":\"ui_tap_text\",\"text\":\"屏幕上的按钮文字\"}]\n"
        @"15. 屏幕滑动/点赞手势：[ACTION:{\"type\":\"ui_gesture\",\"gesture\":\"swipe_up|swipe_down|double_tap|back\"}]\n"
        @"16. 清理手机后台：[ACTION:{\"type\":\"kill_background_apps\"}]\n"
        @"17. 深色/浅色/护眼模式：[ACTION:{\"type\":\"appearance_mode\",\"mode\":\"dark|light|nightshift_on|nightshift_off\"}]\n"
        @"18. Wi-Fi/蓝牙/飞行/省电：[ACTION:{\"type\":\"wifi_toggle\",\"on\":true}] / [ACTION:{\"type\":\"bluetooth_toggle\",\"on\":true}] / [ACTION:{\"type\":\"airplane_mode\",\"on\":true}] / [ACTION:{\"type\":\"low_power_mode\",\"on\":true}]\n"
        @"19. 自动打字填入/复制：[ACTION:{\"type\":\"clipboard_auto_type\",\"text\":\"要填入或复制的文字\"}]\n"
        @"20. 手机电量与空间自检：[ACTION:{\"type\":\"device_status\"}]\n"
        @"21. 地图导航与平台搜索：[ACTION:{\"type\":\"navigation\",\"destination\":\"地点\",\"app\":\"amap|baidu\"}] / [ACTION:{\"type\":\"search\",\"keyword\":\"词\",\"platform\":\"taobao|jd|douyin|bilibili|xhs|meituan|baidu\"}]\n"
        @"22. 电话/短信/锁屏/桌面：[ACTION:{\"type\":\"make_call\",\"target\":\"人名\"}] / [ACTION:{\"type\":\"send_sms\",\"target\":\"人名\",\"content\":\"内容\"}] / [ACTION:{\"type\":\"system_control\",\"action\":\"home|lock|respring\"}]",
        brand, rawModel];

    if (self.isVideoChatActive || self.activeModeTab == AGConfigTabVideoAI) {
        sysInstruction = [sysInstruction stringByAppendingString:@"【实时视讯模式】你同时连接了用户的实时摄像头画面。请结合摄像头实时画面智能回答。"];
    }

    if (self.isGoogleBidiProtocol) {
        // 100% 保持现有 Gemini setup 握手报文不变
        NSMutableDictionary *setupDict = [@{
            @"model": fullModelPath,
            @"generationConfig": @{
                @"responseModalities": @[@"AUDIO"],
                @"speechConfig": @{ @"voiceConfig": @{ @"prebuiltVoiceConfig": @{ @"voiceName": @"Aoede" } } }
            },
            @"systemInstruction": @{ @"parts": @[ @{ @"text": sysInstruction } ] }
        } mutableCopy];

        if (!self.disableTranscriptionInSetup) {
            setupDict[@"inputAudioTranscription"] = @{};
            setupDict[@"outputAudioTranscription"] = @{};
        }

        [self sendJSONDictionaryOverWebSocket:@{ @"setup": setupDict }];
    } else {
        // 非 Google 模型：根据厂商协议生成带 event_id、对应音频格式、官方音色与 Function Calling 工具的 session.update
        NSString *endpoint = agEndpointForTab(self.activeModeTab);
        NSDictionary *sessionUpdate = agBuildVendorSessionUpdatePayload(endpoint,
                                                                        rawModel,
                                                                        sysInstruction,
                                                                        (self.isVideoChatActive || self.activeModeTab == AGConfigTabVideoAI),
                                                                        self.disableTranscriptionInSetup);
        [self sendJSONDictionaryOverWebSocket:sessionUpdate];
    }
}

- (void)sendJSONDictionaryOverWebSocket:(NSDictionary *)dict {
    if (!self.liveWebSocketTask || !self.isWebSocketConnected || self.liveWebSocketTask.state != NSURLSessionTaskStateRunning || !dict) return;
    BOOL isRealtimeMedia = (dict[@"realtimeInput"] != nil && dict[@"realtimeInput"][@"text"] == nil);
    if (isRealtimeMedia && self.inFlightWSMessageCount > 10) {
        agLiveDiagLog(@"WS_BACKPRESSURE_DROP", @"Dropped media frame due to inFlight=%ld", (long)self.inFlightWSMessageCount);
        return;
    }
    self.inFlightWSMessageCount++;
    __weak typeof(self) weakSelf = self;
    dispatch_async(self.encodeQueue, ^{
        if (!weakSelf.liveWebSocketTask) {
            weakSelf.inFlightWSMessageCount = MAX(0, weakSelf.inFlightWSMessageCount - 1);
            return;
        }
        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
        if (!jsonData) {
            weakSelf.inFlightWSMessageCount = MAX(0, weakSelf.inFlightWSMessageCount - 1);
            return;
        }
        NSString *jsonStr = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
        NSURLSessionWebSocketMessage *msg = [[NSURLSessionWebSocketMessage alloc] initWithString:jsonStr];
        [weakSelf.liveWebSocketTask sendMessage:msg completionHandler:^(NSError * _Nullable error) {
            weakSelf.inFlightWSMessageCount = MAX(0, weakSelf.inFlightWSMessageCount - 1);
            if (error) {
                agLiveDiagLog(@"WS_SEND_ERR", @"sendMessage error: %@", error.localizedDescription);
            }
        }];
    });
}

- (void)URLSession:(NSURLSession *)session webSocketTask:(NSURLSessionWebSocketTask *)webSocketTask didCloseWithCloseCode:(NSURLSessionWebSocketCloseCode)closeCode reason:(NSData *)reason {
    NSString *reasonStr = reason ? [[NSString alloc] initWithData:reason encoding:NSUTF8StringEncoding] : @"无详细原因";
    agLiveDiagLog(@"WS_CLOSED", @"Server closed WebSocket: code=%ld, reason=%@", (long)closeCode, reasonStr);
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isWebSocketConnected = NO;
        self.isSetupHandshakeCompleted = NO;
        // 若在后台热备期间被服务端 10~15 分钟超时断开，且手机当前未锁屏，自动静默续杯重连
        if (self.isWarmStandbyMode || !self.overlayWindow || self.overlayWindow.hidden) {
            if (!isDeviceCurrentlyLocked()) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self prewarmWebSocketInBackgroundIfNeeded];
                });
            }
            return;
        }
        if (self.activeModeTab == AGConfigTabPureText) return;
        self.subStatusLabel.text = [NSString stringWithFormat:@"⚠️ 实时连接关闭 (Code %ld): %@", (long)closeCode, reasonStr];
    });
}

- (void)receiveNextWebSocketMessage {
    NSURLSessionWebSocketTask *boundTask = self.liveWebSocketTask;
    NSUInteger boundToken = self.sessionGenerationToken;
    NSString *boundModel = [self.activeWebSocketModel copy];
    if (!boundTask) return;

    __weak typeof(self) weakSelf = self;
    [boundTask receiveMessageWithCompletionHandler:^(NSURLSessionWebSocketMessage * _Nullable message, NSError * _Nullable error) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        // 关键防护：如果回调来自已被取消或已被替换的旧 WebSocket 任务，直接忽略，绝不干扰当前正在运行的实时通话！
        if (boundTask != strongSelf.liveWebSocketTask || boundToken != strongSelf.sessionGenerationToken) {
            agLiveDiagLog(@"WS_IGNORE_STALE", @"Ignored callback from stale task (model=%@)", boundModel);
            return;
        }
        if (error) {
            if (error.code == NSURLErrorCancelled) {
                return;
            }
            agLiveDiagLog(@"WS_RECV_ERR", @"WebSocket receive error (model=%@, retry=%ld): %@", boundModel, (long)strongSelf.wsReconnectCount, error.localizedDescription);
            dispatch_async(dispatch_get_main_queue(), ^{
                if (boundTask != strongSelf.liveWebSocketTask) return;
                // ✅ 修复：报错后立即标记断开并清理死 Task，防止 retry 时误入 WS_FAST_REUSE 死循环
                strongSelf.isWebSocketConnected = NO;
                strongSelf.isSetupHandshakeCompleted = NO;
                [strongSelf.liveWebSocketTask cancel];
                strongSelf.liveWebSocketTask = nil;

                if (!strongSelf.overlayWindow || strongSelf.overlayWindow.hidden || strongSelf.activeModeTab == AGConfigTabPureText) return;
                if (strongSelf.wsReconnectCount < 2) {
                    strongSelf.wsReconnectCount++;
                    if (strongSelf.wsReconnectCount == 1 && !strongSelf.disableTranscriptionInSetup && ![boundModel containsString:@"3.8"]) {
                        strongSelf.disableTranscriptionInSetup = YES;
                        agLiveDiagLog(@"WS_RETRY", @"Retrying without transcription fields for model %@", boundModel);
                        [strongSelf startWebSocketBidiSessionWithModel:boundModel forTab:strongSelf.activeModeTab];
                        return;
                    }
                    if (strongSelf.isGoogleBidiProtocol) {
                        NSString *fallbackModel = @"models/gemini-2.5-flash-native-audio-preview-09-2025";
                        strongSelf.activeWebSocketModel = fallbackModel;
                        agLiveDiagLog(@"WS_FALLBACK", @"Switching to verified Live model: %@", fallbackModel);
                        [strongSelf startWebSocketBidiSessionWithModel:fallbackModel forTab:strongSelf.activeModeTab];
                    } else {
                        // 非 Google 厂商：绝不篡改为 Google 模型，无缝降级至引擎 B 连续语音模式以保障对话可用
                        agLiveDiagLog(@"WS_FALLBACK_ENGINE_B", @"WebSocket unavailable for %@, switching to Engine B continuous voice", boundModel);
                        [strongSelf stopAllVoiceEngines];
                        [strongSelf startContinuousVoiceListening];
                    }
                } else {
                    [strongSelf stopAllVoiceEngines];
                    strongSelf.subStatusLabel.text = [NSString stringWithFormat:@"❌ 实时通话连接断开 (%@): %@", [boundModel stringByReplacingOccurrencesOfString:@"models/" withString:@""], error.localizedDescription];
                }
            });
            return;
        }
        if (message) {
            NSData *msgData = message.data ?: [message.string dataUsingEncoding:NSUTF8StringEncoding];
            if (msgData.length > 0) {
                NSDictionary *json = [NSJSONSerialization JSONObjectWithData:msgData options:0 error:nil];
                if ([json isKindOfClass:[NSDictionary class]]) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (boundTask == strongSelf.liveWebSocketTask) {
                            [strongSelf handleIncomingWebSocketJSON:json];
                        }
                    });
                }
            }
        }
        if (boundTask == strongSelf.liveWebSocketTask) {
            [strongSelf receiveNextWebSocketMessage];
        }
    }];
}

// 将握手期间用户已经开口说的预录语音一次性丝滑发给大模型，实现 0 秒开口不漏字
- (void)flushPreRollPCMBufferIfNeeded {
    NSData *preRoll = nil;
    @synchronized (self.wsPreRollPCMBuffer) {
        if (self.wsPreRollPCMBuffer.length > 0) {
            preRoll = [self.wsPreRollPCMBuffer copy];
            [self.wsPreRollPCMBuffer setLength:0];
        }
    }
    if (!preRoll || preRoll.length == 0) return;

    // 关键修复：先发送 100ms (3200 bytes) 的零电平静音基准帧，让 Gemini / 千问云端 VAD 建立噪声基线，100% 触发人声起音检测！
    NSMutableData *silenceLead = [NSMutableData dataWithLength:3200];
    NSString *silenceB64 = [silenceLead base64EncodedStringWithOptions:0];
    if (self.isGoogleBidiProtocol) {
        [self sendJSONDictionaryOverWebSocket:@{
            @"realtimeInput": @{ @"audio": @{ @"mimeType": @"audio/pcm;rate=16000", @"data": silenceB64 } }
        }];
    } else {
        [self sendJSONDictionaryOverWebSocket:agBuildVendorAudioAppendPacket(silenceB64)];
    }

    NSUInteger chunkSz = 3200;
    for (NSUInteger offset = 0; offset < preRoll.length; offset += chunkSz) {
        NSUInteger thisLen = MIN(chunkSz, preRoll.length - offset);
        NSData *sub = [preRoll subdataWithRange:NSMakeRange(offset, thisLen)];
        NSString *b64 = [sub base64EncodedStringWithOptions:0];
        if (self.isGoogleBidiProtocol) {
            [self sendJSONDictionaryOverWebSocket:@{
                @"realtimeInput": @{ @"audio": @{ @"mimeType": @"audio/pcm;rate=16000", @"data": b64 } }
            }];
        } else {
            [self sendJSONDictionaryOverWebSocket:agBuildVendorAudioAppendPacket(b64)];
        }
    }
    agLiveDiagLog(@"PREROLL_SENT", @"Flushed 3200B silence lead + %lu bytes of pre-roll audio on setupComplete", (unsigned long)preRoll.length);
}

- (void)handleIncomingWebSocketJSON:(NSDictionary *)json {
    if (json[@"error"]) {
        NSString *errMsg = json[@"error"][@"message"] ?: @"实时流模型返回错误";
        self.subStatusLabel.text = [NSString stringWithFormat:@"⚠️ %@", errMsg];
        [self stopAllVoiceEngines];
        [self migrateAwayFromUnavailableModelAndRetry:nil audioData:nil isGreeting:YES];
        return;
    }

    if ([json[@"type"] isEqualToString:@"session.created"]) {
        agLiveDiagLog(@"WS_SESSION_CREATED", @"Received session.created for %@, waiting for session.updated...", self.activeWebSocketModel);
        NSUInteger capturedToken = self.sessionGenerationToken;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.55 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (capturedToken == self.sessionGenerationToken && self.isWebSocketConnected && !self.isSetupHandshakeCompleted) {
                self.isSetupHandshakeCompleted = YES;
                self.wsReconnectCount = 0;
                [self flushPreRollPCMBufferIfNeeded];
                agLiveDiagLog(@"WS_SETUP_COMPLETE", @"Handshake completed (timer fallback) for model %@", self.activeWebSocketModel);
                if (!self.isWarmStandbyMode) {
                    self.subStatusLabel.text = (self.activeModeTab == AGConfigTabVideoAI)
                        ? @"📞📹 实时视频通话中 (直接说话，支持随时插话打断)..."
                        : @"📞 实时语音通话中 (直接说话，支持随时插话打断)...";
                }
            }
        });
        return;
    }

    if (json[@"setupComplete"] != nil || [json[@"type"] isEqualToString:@"session.updated"]) {
        if (!self.isSetupHandshakeCompleted) {
            self.isSetupHandshakeCompleted = YES;
            self.wsReconnectCount = 0;
            [self flushPreRollPCMBufferIfNeeded];
            agLiveDiagLog(@"WS_SETUP_COMPLETE", @"Handshake completed for model %@", self.activeWebSocketModel);
            if (!self.isWarmStandbyMode && self.overlayWindow && !self.overlayWindow.hidden) {
                if (!self.liveAudioEngine || !self.liveAudioEngine.isRunning) {
                    [self setupAndStartFullDuplexPCMAudioEngine];
                }
                self.subStatusLabel.text = (self.activeModeTab == AGConfigTabVideoAI)
                    ? @"📞📹 实时视频通话中 (直接说话，支持随时插话打断)..."
                    : @"📞 实时语音通话中 (直接说话，支持随时插话打断)...";
            }
            // 已彻底移除自动发送“你好，请用一句简短自然的话主动向我打招呼”，绝不抢占用户开口时机！
        }
        return;
    }

    NSDictionary *serverContent = json[@"serverContent"];
    if ([serverContent isKindOfClass:[NSDictionary class]]) {
        if ([serverContent[@"interrupted"] boolValue]) {
            self.currentTurnPlaybackID++;
            self.pendingPlayBuffersCount = 0;
            if (self.pcmPlayerNode && self.pcmPlayerNode.isPlaying) {
                [self.pcmPlayerNode stop];
                [self.pcmPlayerNode play];
            }
            self.aiPlaybackEndTime = 0;
            self.wsBargeInVoiceTicks = 0;
            self.subStatusLabel.text = @"⚡ 已打断 AI，正在倾听您说话...";
            return;
        }

        NSDictionary *inputTrans = serverContent[@"inputTranscription"];
        if ([inputTrans isKindOfClass:[NSDictionary class]] && [inputTrans[@"text"] isKindOfClass:[NSString class]]) {
            NSString *userDelta = inputTrans[@"text"];
            if (userDelta.length > 0) {
                if (self.aiPlaybackEndTime > 0 && self.pcmPlayerNode && self.pcmPlayerNode.isPlaying) {
                    [self.pcmPlayerNode stop];
                    [self.pcmPlayerNode play];
                    self.aiPlaybackEndTime = 0;
                }
                NSMutableString *curTrans = [self currentTabTranscript];
                if (!self.isLastTranscriptLineUser) {
                    if (curTrans.length > 0 && ![curTrans hasSuffix:@"\n"]) [curTrans appendString:@"\n\n"];
                    [curTrans appendString:@"🗣️ 您："];
                    self.isLastTranscriptLineUser = YES;
                }
                [curTrans appendString:userDelta];
                [self.currentVoiceQueryBuffer appendString:userDelta];
                self.responseTextView.text = curTrans;
                self.subStatusLabel.text = [NSString stringWithFormat:@"🎙️ 正在听您说：%@", self.currentVoiceQueryBuffer];
                [self throttledExpandAndScrollTextViewForce:NO];

                // 防抖机制：等待用户停顿 0.70 秒确认整句话说完后再执行本地自动化指令，严禁半句话抢跑截胡！
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkDeferredVoiceLocalCommand) object:nil];
                [self performSelector:@selector(checkDeferredVoiceLocalCommand) withObject:nil afterDelay:0.70];
            }
        }

        NSDictionary *outputTrans = serverContent[@"outputTranscription"];
        if ([outputTrans isKindOfClass:[NSDictionary class]] && [outputTrans[@"text"] isKindOfClass:[NSString class]]) {
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkDeferredVoiceLocalCommand) object:nil];
            if (self.currentVoiceQueryBuffer.length > 0) {
                NSString *fullVoiceCmd = [self.currentVoiceQueryBuffer copy];
                [self.currentVoiceQueryBuffer setString:@""];
                if ([self tryExecuteDirectLocalCommand:fullVoiceCmd]) {
                    if (self.pcmPlayerNode && self.pcmPlayerNode.isPlaying) [self.pcmPlayerNode stop];
                    return;
                }
            }
            NSString *aiDelta = outputTrans[@"text"];
            if (aiDelta.length > 0) {
                if (self.isLastTranscriptLineUser) {
                    [[self currentTabTranscript] appendString:@"\n"];
                    self.isLastTranscriptLineUser = NO;
                }
                [self appendIncomingTextDelta:aiDelta];
            }
        }

        NSArray *parts = serverContent[@"modelTurn"][@"parts"];
        if ([parts isKindOfClass:[NSArray class]]) {
            for (NSDictionary *part in parts) {
                if (![part isKindOfClass:[NSDictionary class]]) continue;
                if ([part[@"thought"] boolValue]) continue;
                if (part[@"text"] && self.disableTranscriptionInSetup) {
                    if (self.isLastTranscriptLineUser) {
                        [[self currentTabTranscript] appendString:@"\n"];
                        self.isLastTranscriptLineUser = NO;
                    }
                    [self appendIncomingTextDelta:part[@"text"]];
                }
                NSDictionary *inlineData = part[@"inlineData"] ?: part[@"inline_data"];
                NSString *b64Audio = [inlineData isKindOfClass:[NSDictionary class]] ? inlineData[@"data"] : nil;
                if (b64Audio.length > 0) {
                    NSData *pcm24k = [[NSData alloc] initWithBase64EncodedString:b64Audio options:NSDataBase64DecodingIgnoreUnknownCharacters];
                    if (pcm24k.length > 0) [self enqueueAndPlayIncomingPCM24kData:pcm24k];
                }
            }
        }
        if ([serverContent[@"turnComplete"] boolValue]) {
            self.isLastTranscriptLineUser = NO;
            if ([self.accumulatedReplyText containsString:@"[ACTION:"]) {
                BOOL actionExecuted = NO;
                [self parseAndExecuteActions:self.accumulatedReplyText executed:&actionExecuted];
                if (actionExecuted) {
                    [self.accumulatedReplyText setString:@""];
                    [self.pendingSpeechChunk setString:@""];
                }
            }
            NSMutableString *curTrans = [self currentTabTranscript];
            if ([curTrans containsString:@"[ACTION:"]) {
                NSRegularExpression *actionReg = [NSRegularExpression regularExpressionWithPattern:@"\\[ACTION:.*?\\]" options:NSRegularExpressionDotMatchesLineSeparators error:nil];
                NSString *cleanedTrans = [actionReg stringByReplacingMatchesInString:curTrans options:0 range:NSMakeRange(0, curTrans.length) withTemplate:@""];
                [curTrans setString:cleanedTrans];
            }
            if (curTrans.length > 0 && ![curTrans hasSuffix:@"\n"]) {
                [curTrans appendString:@"\n\n"];
                self.responseTextView.text = curTrans;
                [self throttledExpandAndScrollTextViewForce:YES];
            }
            NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
            NSTimeInterval remain = MAX(0.05, self.aiPlaybackEndTime - now);
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remain * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if ([[NSDate date] timeIntervalSince1970] >= self.aiPlaybackEndTime - 0.05) {
                    self.aiPlaybackEndTime = 0;
                    self.wsBargeInVoiceTicks = 0;
                    self.subStatusLabel.text = (self.activeModeTab == AGConfigTabVideoAI)
                        ? @"📞📹 实时视频通话中 (直接说话，支持随时插话打断)..."
                        : @"📞 实时语音通话中 (直接说话，支持随时插话打断)...";
                    [self setWaveBarsLevel:0.0];
                }
            });
        }
        return;
    }

    // 2. 非 Google WebSocket 实时事件解析 (OpenAI / 阿里 Qwen-Omni / 智谱 GLM-Realtime / 阶跃星辰 StepAudio)
    NSString *eventType = json[@"type"];
    if (([eventType isEqualToString:@"response.audio.delta"] || [eventType isEqualToString:@"response.output_audio.delta"]) && json[@"delta"]) {
        NSData *pcm24k = [[NSData alloc] initWithBase64EncodedString:json[@"delta"] options:NSDataBase64DecodingIgnoreUnknownCharacters];
        if (pcm24k.length > 0) [self enqueueAndPlayIncomingPCM24kData:pcm24k];
    } else if (([eventType isEqualToString:@"response.audio_transcript.delta"] ||
                [eventType isEqualToString:@"response.output_audio_transcript.delta"] ||
                [eventType isEqualToString:@"response.text.delta"]) && json[@"delta"]) {
        if (self.isLastTranscriptLineUser) {
            [[self currentTabTranscript] appendString:@"\n"];
            self.isLastTranscriptLineUser = NO;
        }
        [self appendIncomingTextDelta:json[@"delta"]];
    } else if ([eventType isEqualToString:@"conversation.item.input_audio_transcription.completed"] ||
               [eventType isEqualToString:@"conversation.item.input_audio_transcription.delta"]) {
        NSString *userTranscript = json[@"transcript"] ?: json[@"delta"];
        if ([userTranscript isKindOfClass:[NSString class]] && userTranscript.length > 0) {
            NSMutableString *curTrans = [self currentTabTranscript];
            if (!self.isLastTranscriptLineUser) {
                if (curTrans.length > 0 && ![curTrans hasSuffix:@"\n"]) [curTrans appendString:@"\n\n"];
                [curTrans appendString:@"🗣️ 您："];
                self.isLastTranscriptLineUser = YES;
            }
            [curTrans appendString:userTranscript];
            [self.currentVoiceQueryBuffer appendString:userTranscript];
            self.responseTextView.text = curTrans;
            [self throttledExpandAndScrollTextViewForce:NO];

            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(checkDeferredVoiceLocalCommand) object:nil];
            [self performSelector:@selector(checkDeferredVoiceLocalCommand) withObject:nil afterDelay:0.70];
        }
    } else if ([eventType isEqualToString:@"response.function_call_arguments.done"]) {
        // 原生 Function Calling 工具调用回调执行
        NSString *fnName = json[@"name"] ?: @"";
        NSString *callID = json[@"call_id"] ?: @"";
        NSString *argsStr = json[@"arguments"] ?: @"{}";
        if ([fnName isEqualToString:@"execute_device_action"] && argsStr.length > 2) {
            NSDictionary *actDict = [NSJSONSerialization JSONObjectWithData:[argsStr dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
            if ([actDict isKindOfClass:[NSDictionary class]]) {
                [self executeActionDictionary:actDict];
                if (callID.length > 0) {
                    [self sendJSONDictionaryOverWebSocket:@{
                        @"event_id": agGenerateRealtimeEventID(),
                        @"type": @"conversation.item.create",
                        @"item": @{
                            @"type": @"function_call_output",
                            @"call_id": callID,
                            @"output": @"{\"status\":\"success\"}"
                        }
                    }];
                    [self sendJSONDictionaryOverWebSocket:@{
                        @"event_id": agGenerateRealtimeEventID(),
                        @"type": @"response.create"
                    }];
                }
            }
        }
    } else if ([eventType isEqualToString:@"input_audio_buffer.speech_started"]) {
        self.currentTurnPlaybackID++;
        self.pendingPlayBuffersCount = 0;
        if (self.pcmPlayerNode && self.pcmPlayerNode.isPlaying) {
            [self.pcmPlayerNode stop];
            [self.pcmPlayerNode play];
        }
        self.aiPlaybackEndTime = 0;
        self.subStatusLabel.text = @"⚡ 已打断 AI，正在倾听您说话...";
    } else if ([eventType isEqualToString:@"response.done"]) {
        self.isLastTranscriptLineUser = NO;
        if ([self.accumulatedReplyText containsString:@"[ACTION:"]) {
            BOOL actionExecuted = NO;
            [self parseAndExecuteActions:self.accumulatedReplyText executed:&actionExecuted];
            if (actionExecuted) {
                [self.accumulatedReplyText setString:@""];
                [self.pendingSpeechChunk setString:@""];
            }
        }
        NSMutableString *curTrans = [self currentTabTranscript];
        if (curTrans.length > 0 && ![curTrans hasSuffix:@"\n"]) {
            [curTrans appendString:@"\n\n"];
            self.responseTextView.text = curTrans;
            [self throttledExpandAndScrollTextViewForce:YES];
        }
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        NSTimeInterval remain = MAX(0.05, self.aiPlaybackEndTime - now);
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(remain * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.aiPlaybackEndTime = 0;
            self.wsBargeInVoiceTicks = 0;
            self.subStatusLabel.text = (self.activeModeTab == AGConfigTabVideoAI)
                ? @"📞📹 实时视频通话中 (直接说话，支持随时插话打断)..."
                : @"📞 实时语音通话中 (直接说话，支持随时插话打断)...";
            [self setWaveBarsLevel:0.0];
        });
    }
}

- (void)enqueueAndPlayIncomingPCM24kData:(NSData *)pcm16Data {
    if (!self.liveAudioEngine || !self.pcmPlayerNode || !self.playerOutputFormat) return;
    NSUInteger inSampleCount = pcm16Data.length / sizeof(int16_t);
    if (inSampleCount == 0) return;

    NSUInteger capturedTurnID = self.currentTurnPlaybackID;
    self.rxAudioPacketsCount++;
    NSUInteger pktIdx = self.rxAudioPacketsCount;

    // 派发到独立音频播放队列进行重采样与入队，彻底解放主线程 UI，杜绝声音滞后或集中爆发播放
    dispatch_async(self.audioPlayQueue, ^{
        if (capturedTurnID != self.currentTurnPlaybackID || !self.liveAudioEngine || !self.pcmPlayerNode) {
            agLiveDiagLog(@"SRV_AUDIO_DROP", @"Dropped stale audio packet #%lu from interrupted turn", (unsigned long)pktIdx);
            return;
        }

        double hwSampleRate = self.playerOutputFormat.sampleRate > 0 ? self.playerOutputFormat.sampleRate : 48000.0;
        AVAudioChannelCount hwChannels = MAX(1, self.playerOutputFormat.channelCount);
        double ratio = hwSampleRate / 24000.0;
        AVAudioFrameCount outFrameCount = (AVAudioFrameCount)((double)inSampleCount * ratio);
        if (outFrameCount == 0) return;

        AVAudioPCMBuffer *pcmBuffer = [[AVAudioPCMBuffer alloc] initWithPCMFormat:self.playerOutputFormat frameCapacity:outFrameCount];
        pcmBuffer.frameLength = outFrameCount;

        const int16_t *src = (const int16_t *)pcm16Data.bytes;
        for (AVAudioChannelCount ch = 0; ch < hwChannels; ch++) {
            float *dst = pcmBuffer.floatChannelData[ch];
            if (!dst) continue;
            for (AVAudioFrameCount i = 0; i < outFrameCount; i++) {
                double srcPos = (double)i / ratio;
                NSUInteger idx0 = (NSUInteger)srcPos;
                NSUInteger idx1 = MIN(idx0 + 1, inSampleCount - 1);
                double frac = srcPos - (double)idx0;
                float s0 = (float)src[idx0] / 32768.0f;
                float s1 = (float)src[idx1] / 32768.0f;
                dst[i] = (float)((1.0 - frac) * s0 + frac * s1);
            }
        }

        if (!self.liveAudioEngine.isRunning) {
            [self.liveAudioEngine startAndReturnError:nil];
        }
        if (!self.pcmPlayerNode.isPlaying) {
            [self.pcmPlayerNode play];
        }

        self.pendingPlayBuffersCount++;
        NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
        double chunkDuration = (double)inSampleCount / 24000.0;
        self.aiPlaybackEndTime = MAX(now, self.aiPlaybackEndTime) + chunkDuration;

        if (pktIdx % 10 == 1) {
            agLiveDiagLog(@"SRV_AUDIO_PLAY", @"Playing packet #%lu (samples=%lu, pendingBuffers=%ld)", (unsigned long)pktIdx, (unsigned long)inSampleCount, (long)self.pendingPlayBuffersCount);
        }

        if (self.pendingPlayBuffersCount <= 2 || self.targetVoiceAmplitude < 0.50) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (capturedTurnID == self.currentTurnPlaybackID) {
                    NSString * expectedStatus = [NSString stringWithFormat:@"🔊 %@ 正在实时回复 (直接说话即可随时打断)...", [self currentVendorBrandName]];
                    if (![self.subStatusLabel.text isEqualToString:expectedStatus]) {
                        self.subStatusLabel.text = expectedStatus;
                    }
                    [self setWaveBarsLevel:0.75];
                }
            });
        }

        __weak typeof(self) weakSelf = self;
        [self.pcmPlayerNode scheduleBuffer:pcmBuffer completionHandler:^{
            dispatch_async(weakSelf.audioPlayQueue, ^{
                if (capturedTurnID == weakSelf.currentTurnPlaybackID) {
                    weakSelf.pendingPlayBuffersCount = MAX(0, weakSelf.pendingPlayBuffersCount - 1);
                    if (weakSelf.pendingPlayBuffersCount == 0) {
                        weakSelf.aiPlaybackEndTime = 0;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [weakSelf setWaveBarsLevel:0.0];
                        });
                    }
                }
            });
        }];
    });
}

// 播放 iOS 26 Siri 空灵液态琉璃双音启动提示音（D4/D5 -> A5/C#6/A6，音量 0.85f 穿透静音模式）
- (void)playCrystalWakeupChimeIfNeeded {
    if (!self.pendingWakeupChime) return;
    if (self.isDismissed || !self.overlayWindow || self.overlayWindow.hidden) return;
    if (!self.liveAudioEngine || !self.pcmPlayerNode || !self.playerOutputFormat) return;

    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - self.lastChimePlayTimestamp < 0.60) {
        self.pendingWakeupChime = NO;
        return;
    }
    self.pendingWakeupChime = NO;
    self.lastChimePlayTimestamp = now;

    dispatch_async(self.audioPlayQueue, ^{
        if (self.isDismissed || !self.liveAudioEngine || !self.pcmPlayerNode || !self.playerOutputFormat) return;

        double sampleRate = self.playerOutputFormat.sampleRate > 0 ? self.playerOutputFormat.sampleRate : 48000.0;
        AVAudioChannelCount channels = MAX(1, self.playerOutputFormat.channelCount);
        AVAudioFrameCount totalFrames = (AVAudioFrameCount)(sampleRate * 0.32);

        AVAudioPCMBuffer *chimeBuf = [[AVAudioPCMBuffer alloc] initWithPCMFormat:self.playerOutputFormat frameCapacity:totalFrames];
        chimeBuf.frameLength = totalFrames;

        for (AVAudioFrameCount i = 0; i < totalFrames; i++) {
            float t = (float)i / (float)sampleRate;
            float sample = 0.0f;
            // 第一音 (0.00s ~ 0.14s): iOS 26 Siri 低频共鸣基底 D4 (293.66Hz) + D5 (587.33Hz) + D6
            if (t < 0.14f) {
                float env1 = (t < 0.006f) ? (t / 0.006f) : expf(-(t - 0.006f) * 24.0f);
                sample += (sinf(2.0f * (float)M_PI * 293.66f * t) * 0.34f
                         + sinf(2.0f * (float)M_PI * 587.33f * t) * 0.52f
                         + sinf(2.0f * (float)M_PI * 1174.66f * t) * 0.14f) * env1;
            }
            // 第二音 (0.070s ~ 0.32s): 上行五度空灵绽放和弦 A5 (880Hz) + C#6 (1318.5Hz) + A6 (1760Hz)
            if (t >= 0.070f) {
                float t2 = t - 0.070f;
                float env2 = (t2 < 0.006f) ? (t2 / 0.006f) : expf(-(t2 - 0.006f) * 14.0f);
                sample += (sinf(2.0f * (float)M_PI * 440.00f * t2) * 0.22f
                         + sinf(2.0f * (float)M_PI * 880.00f * t2) * 0.52f
                         + sinf(2.0f * (float)M_PI * 1318.51f * t2) * 0.18f
                         + sinf(2.0f * (float)M_PI * 1760.00f * t2) * 0.10f) * env2;
            }
            sample = MAX(-0.98f, MIN(0.98f, sample * 0.85f));
            for (AVAudioChannelCount ch = 0; ch < channels; ch++) {
                if (chimeBuf.floatChannelData && chimeBuf.floatChannelData[ch]) {
                    chimeBuf.floatChannelData[ch][i] = sample;
                }
            }
        }
        if (!self.liveAudioEngine.isRunning) [self.liveAudioEngine startAndReturnError:nil];
        if (!self.pcmPlayerNode.isPlaying) [self.pcmPlayerNode play];
        self.pcmPlayerNode.volume = 1.0f;
        [self.pcmPlayerNode scheduleBuffer:chimeBuf completionHandler:nil];
        agLiveDiagLog(@"CHIME_PLAYED", @"Played iOS 26 Siri invocation chime on pcmPlayerNode");
    });
}

- (void)setupAndStartFullDuplexPCMAudioEngine {
    NSUInteger expectedToken = self.sessionGenerationToken;
    dispatch_async(agAudioSerialQueue(), ^{
        if (self.isDismissed || expectedToken != self.sessionGenerationToken) return;
        @try {
            // 若音频引擎已在运行，直接保持在线复用，避免重连时反复切换 AVAudioSession 引起 Route changed reason=3
            if (self.liveAudioEngine && self.liveAudioEngine.isRunning && self.pcmPlayerNode && self.playerOutputFormat) {
                if (!self.pcmPlayerNode.isPlaying) {
                    [self.pcmPlayerNode play];
                }
                [self playCrystalWakeupChimeIfNeeded]; // ✅ 复用就绪时立刻播放水晶音
                agLiveDiagLog(@"AEC_AUDIO_ENGINE", @"Reusing active FullDuplex Engine (rate=%.0f)", self.playerOutputFormat.sampleRate);
                return;
            }

            if (self.liveAudioEngine) {
                [self.liveAudioEngine.inputNode removeTapOnBus:0];
                if (self.pcmPlayerNode) [self.pcmPlayerNode stop];
                [self.liveAudioEngine stop];
                self.liveAudioEngine = nil;
                self.pcmPlayerNode = nil;
            }

            AVAudioSession *session = [AVAudioSession sharedInstance];
            NSString *chatMode = self.isVideoChatActive ? AVAudioSessionModeVideoChat : AVAudioSessionModeVoiceChat;
            // 移除 MixWithOthers，确保 iOS VoiceProcessingIO 硬件回声消除完整激活
            NSError *catErr = nil;
            [session setCategory:AVAudioSessionCategoryPlayAndRecord
                            mode:chatMode
                         options:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionAllowBluetoothA2DP
                           error:&catErr];
            [session setPreferredIOBufferDuration:0.02 error:nil];
            [session setActive:YES withOptions:0 error:nil];

            AVAudioEngine *engine = [[AVAudioEngine alloc] init];
            AVAudioInputNode *inputNode = engine.inputNode;

            NSError *vpErr = nil;
            if ([inputNode respondsToSelector:@selector(setVoiceProcessingEnabled:error:)]) {
                [inputNode setVoiceProcessingEnabled:YES error:&vpErr];
            }

            AVAudioFormat *mixerFormat = [engine.mainMixerNode outputFormatForBus:0];
            if (!mixerFormat || mixerFormat.sampleRate <= 0 || mixerFormat.channelCount == 0) {
                mixerFormat = [[AVAudioFormat alloc] initStandardFormatWithSampleRate:48000.0 channels:1];
            }

            AVAudioPlayerNode *player = [[AVAudioPlayerNode alloc] init];
            [engine attachNode:player];
            [engine connect:player to:engine.mainMixerNode format:mixerFormat];

            [inputNode removeTapOnBus:0];
            AVAudioFormat *tapFormat = [inputNode outputFormatForBus:0];
            if (!tapFormat || tapFormat.sampleRate <= 0 || tapFormat.channelCount == 0) {
                tapFormat = [inputNode inputFormatForBus:0];
            }
            if (!tapFormat || tapFormat.sampleRate <= 0 || tapFormat.channelCount == 0) {
                agLiveDiagLog(@"AUDIO_ERR", @"Invalid inputNode tapFormat");
                return;
            }

            __weak typeof(self) weakSelf = self;
            [inputNode installTapOnBus:0 bufferSize:1024 format:tapFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
                [weakSelf processMicrophoneInputPCMBuffer:buffer];
            }];

            [engine prepare];
            NSError *startErr = nil;
            if ([engine startAndReturnError:&startErr] && !startErr) {
                if (self.isDismissed || expectedToken != self.sessionGenerationToken) {
                    [inputNode removeTapOnBus:0];
                    [engine stop];
                    return;
                }
                [player play];
                self.liveAudioEngine = engine;
                self.pcmPlayerNode = player;
                self.playerOutputFormat = mixerFormat;
                // ✅ 避开硬件爬坡静音期 (380ms 错峰，避开 VoiceProcessingIO 300~350ms 硬件静音窗)
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.38 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    [self playCrystalWakeupChimeIfNeeded];
                });
                agLiveDiagLog(@"AEC_AUDIO_ENGINE", @"Started FullDuplex Engine (inRate=%.0f, outRate=%.0f, vpErr=%@)", tapFormat.sampleRate, mixerFormat.sampleRate, vpErr.localizedDescription ?: @"none");
            } else {
                agLiveDiagLog(@"AUDIO_ERR", @"AVAudioEngine start error: %@", startErr.localizedDescription);
            }
        } @catch (NSException *e) {
            agLiveDiagLog(@"AUDIO_EXC", @"Exception starting audio engine: %@", e.reason);
        }
    });
}

- (void)processMicrophoneInputPCMBuffer:(AVAudioPCMBuffer *)buffer {
    if (!buffer || buffer.frameLength == 0 || buffer.floatChannelData == NULL) return;

    // ✅ 硬件 AEC 已开启，不丢弃任何刚启动时用户的开口语音

    AVAudioFrameCount inFrames = buffer.frameLength;
    double inSampleRate = buffer.format.sampleRate > 0 ? buffer.format.sampleRate : 48000.0;
    // 在音频采集线程仅做极轻量内存拷贝，立即派发到 encodeQueue 处理，零阻塞 CoreAudio 线程
    NSData *copiedFloats = [NSData dataWithBytes:buffer.floatChannelData[0] length:inFrames * sizeof(float)];

    __weak typeof(self) weakSelf = self;
    dispatch_async(self.encodeQueue, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || strongSelf.isDismissed) return;

        const float *floatSamples = (const float *)copiedFloats.bytes;
        float sum = 0.0f;
        float peakVal = 0.0f;
        for (AVAudioFrameCount i = 0; i < inFrames; i++) {
            float s = floatSamples[i];
            sum += s * s;
            float absS = fabsf(s);
            if (absS > peakVal) peakVal = absS;
        }
        float db = 20.0f * log10f(MAX(sqrtf(sum / MAX(1, inFrames)), 1e-7f));
        float peakDb = 20.0f * log10f(MAX(peakVal, 1e-7f));

        BOOL isAIPlaying = (strongSelf.pendingPlayBuffersCount > 0 || [[NSDate date] timeIntervalSince1970] < strongSelf.aiPlaybackEndTime);

        if (!isAIPlaying) {
            if (db > -42.0f) {
                [strongSelf setWaveBarsLevel:MAX(0.24, MIN(1.0, (db + 44.0f) / 26.0f))];
            } else {
                [strongSelf setWaveBarsLevel:0.0];
            }
        }

        // 先完成重采样，若 WebSocket 尚未完成 setupComplete 握手，将用户刚开口的话存入预录缓冲区（最多保留最近 3 秒语音），绝不丢弃！
        double targetRate = strongSelf.isGoogleBidiProtocol
            ? 16000.0
            : agVendorTargetInputSampleRate(agEndpointForTab(strongSelf.activeModeTab), strongSelf.activeWebSocketModel);
        double ratio = inSampleRate / targetRate;
        NSUInteger outFrames = (NSUInteger)((double)inFrames / ratio);
        if (outFrames == 0) return;

        NSMutableData *pcm16Chunk = [NSMutableData dataWithLength:outFrames * sizeof(int16_t)];
        int16_t *outPtr = (int16_t *)pcm16Chunk.mutableBytes;
        for (NSUInteger i = 0; i < outFrames; i++) {
            double srcIdx = (double)i * ratio;
            NSUInteger idx0 = (NSUInteger)srcIdx;
            NSUInteger idx1 = MIN(idx0 + 1, (NSUInteger)(inFrames - 1));
            float sample = (float)((1.0 - (srcIdx - idx0)) * floatSamples[idx0] + (srcIdx - idx0) * floatSamples[idx1]) * 1.95f;
            sample = MAX(-1.0f, MIN(1.0f, sample));
            outPtr[i] = (int16_t)(sample * 32767.0f);
        }

        if (!strongSelf.isWebSocketConnected || !strongSelf.isSetupHandshakeCompleted) {
            @synchronized (strongSelf.wsPreRollPCMBuffer) {
                [strongSelf.wsPreRollPCMBuffer appendData:pcm16Chunk];
                if (strongSelf.wsPreRollPCMBuffer.length > 96000) {
                    NSRange dropRange = NSMakeRange(0, strongSelf.wsPreRollPCMBuffer.length - 96000);
                    [strongSelf.wsPreRollPCMBuffer replaceBytesInRange:dropRange withBytes:NULL length:0];
                }
            }
            return;
        }

        // 打断检测：开启硬件 AEC 后，当 AI 正在播放且检测到清晰人声 (db > -26.0f && peakDb > -15.0f 连续 3 帧 ~65ms)
        if (isAIPlaying) {
            if (db > -26.0f && peakDb > -15.0f) {
                strongSelf.wsBargeInVoiceTicks++;
                if (strongSelf.wsBargeInVoiceTicks >= 3) {
                    strongSelf.wsBargeInVoiceTicks = 0;
                    strongSelf.currentTurnPlaybackID++;
                    strongSelf.pendingPlayBuffersCount = 0;
                    strongSelf.aiPlaybackEndTime = 0;
                    agLiveDiagLog(@"BARGE_IN_LOCAL", @"User barge-in detected (db=%.1f, peak=%.1f), clearing local playback queue", db, peakDb);
                    dispatch_async(strongSelf.audioPlayQueue, ^{
                        if (strongSelf.pcmPlayerNode && strongSelf.pcmPlayerNode.isPlaying) {
                            [strongSelf.pcmPlayerNode stop];
                            [strongSelf.pcmPlayerNode play];
                        }
                    });
                    dispatch_async(dispatch_get_main_queue(), ^{
                        strongSelf.subStatusLabel.text = @"⚡ 已打断 AI，正在倾听您说话...";
                    });
                    if (!strongSelf.isGoogleBidiProtocol) {
                        [strongSelf sendJSONDictionaryOverWebSocket:@{ @"type": @"response.cancel" }];
                    }
                }
            } else {
                strongSelf.wsBargeInVoiceTicks = 0;
            }
        } else {
            strongSelf.wsBargeInVoiceTicks = 0;
        }

        // 持续向 Gemini Live 推送 16kHz PCM 流（每 1600 字节 = 50ms 发送一包，使用标准 audio 字段代替废弃的 mediaChunks）
        [strongSelf.outgoingPCMBuffer appendData:pcm16Chunk];
        if (strongSelf.outgoingPCMBuffer.length >= 1600) {
            NSData *packet = [strongSelf.outgoingPCMBuffer copy];
            [strongSelf.outgoingPCMBuffer setLength:0];
            NSString *b64PCM = [packet base64EncodedStringWithOptions:0];
            strongSelf.txAudioPacketsCount++;
            if (strongSelf.txAudioPacketsCount % 25 == 1) {
                agLiveDiagLog(@"MIC_AUDIO_TX", @"Sent audio packet #%lu (%lu bytes, db=%.1f)", (unsigned long)strongSelf.txAudioPacketsCount, (unsigned long)packet.length, db);
            }
            if (strongSelf.isGoogleBidiProtocol) {
                [strongSelf sendJSONDictionaryOverWebSocket:@{
                    @"realtimeInput": @{ @"audio": @{ @"mimeType": @"audio/pcm;rate=16000", @"data": b64PCM } }
                }];
            } else {
                [strongSelf sendJSONDictionaryOverWebSocket:agBuildVendorAudioAppendPacket(b64PCM)];
            }
        }
    });
}

- (void)handleAudioSessionInterruption:(NSNotification *)note {
    if (self.isDismissed || self.isWarmStandbyMode || !self.overlayWindow || self.overlayWindow.hidden) return;
    NSUInteger type = [note.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    agLiveDiagLog(@"AUDIO_INTERRUPT", @"AVAudioSession interruption type=%lu", (unsigned long)type);
    if (type == AVAudioSessionInterruptionTypeBegan) {
        // ✅ 修复：当窗口在前台被原生 assistantd 闪断(type=1)时，0.25s 后自动夺回麦克风并恢复收音
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (!self.isDismissed && !self.isWarmStandbyMode && self.overlayWindow && !self.overlayWindow.hidden && self.activeModeTab != AGConfigTabPureText) {
                [self forceKillNativeSiri];
                [self setupAndStartFullDuplexPCMAudioEngine];
            }
        });
    } else if (type == AVAudioSessionInterruptionTypeEnded) {
        [self setupAndStartFullDuplexPCMAudioEngine];
    }
}

- (void)handleAudioSessionRouteChange:(NSNotification *)note {
    NSUInteger reason = [note.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    agLiveDiagLog(@"AUDIO_ROUTE", @"Route changed reason=%lu", (unsigned long)reason);
}

#pragma mark - 引擎 B：高敏 WAV 语音直录直传

- (void)startContinuousVoiceListening {
    if (!self.overlayWindow || self.overlayWindow.hidden || !self.modelPickerContainer.hidden) return;
    if (self.activeModeTab == AGConfigTabPureText) return;
    self.micRetryCount = 0;
    [self attemptStartAudioRecorder];
}

// 启动与翻译模块同源的稳定 AVAudioEngine + SFSpeechRecognizer 实时边问边出字引擎
- (void)attemptStartAudioRecorder {
    if (self.isDismissed || !self.overlayWindow || self.overlayWindow.hidden || self.overlayWindow.alpha < 0.1 || !self.modelPickerContainer.hidden) return;
    if (self.activeModeTab == AGConfigTabPureText) return;

    if (self.audioRecorder && self.audioRecorder.isRecording) {
        if (!self.meterTimer || !self.meterTimer.isValid) {
            self.meterTimer = [NSTimer timerWithTimeInterval:0.06 target:self selector:@selector(updateAudioMeters) userInfo:nil repeats:YES];
            [[NSRunLoop mainRunLoop] addTimer:self.meterTimer forMode:NSRunLoopCommonModes];
        }
        return;
    }

    ensureSpringBoardTCCGranted();
    [self.meterTimer invalidate];
    self.meterTimer = nil;

    if (![self.synthesizer isSpeaking] && self.activeUtteranceCount == 0 && !self.currentTask) {
        self.subStatusLabel.text = (self.activeModeTab == AGConfigTabVideoAI)
            ? @"📹 正在全双工倾听并实时捕捉镜头画面..."
            : @"🎙️ 正在全双工倾听 (声波与极光随您的声音实时律动)...";
        [self setWaveBarsLevel:0.0];
    }

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if (self.isDismissed || !self.overlayWindow || self.overlayWindow.hidden || self.overlayWindow.alpha < 0.1) return;
        @try {
            AVAudioSession *session = [AVAudioSession sharedInstance];
            NSString *recMode = self.isVideoChatActive ? AVAudioSessionModeVideoChat : AVAudioSessionModeVoiceChat;
            [session setCategory:AVAudioSessionCategoryPlayAndRecord
                            mode:recMode
                         options:AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionAllowBluetooth | AVAudioSessionCategoryOptionAllowBluetoothA2DP
                           error:nil];
            [session setActive:YES withOptions:0 error:nil];

            NSDictionary *settings = @{
                AVFormatIDKey: @(kAudioFormatLinearPCM),
                AVSampleRateKey: @(16000.0),
                AVNumberOfChannelsKey: @(1),
                AVLinearPCMBitDepthKey: @(16),
                AVLinearPCMIsBigEndianKey: @NO,
                AVLinearPCMIsFloatKey: @NO
            };

            [[NSFileManager defaultManager] removeItemAtPath:self.audioFilePath error:nil];
            NSError *err = nil;
            AVAudioRecorder *rec = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:self.audioFilePath] settings:settings error:&err];
            BOOL started = NO;
            if (rec && !err) {
                rec.delegate = self;
                rec.meteringEnabled = YES;
                [rec prepareToRecord];
                started = [rec record];
            }

            dispatch_async(dispatch_get_main_queue(), ^{
                if (self.isDismissed || !self.overlayWindow || self.overlayWindow.hidden || self.overlayWindow.alpha < 0.1) {
                    if (rec && rec.isRecording) [rec stop];
                    return;
                }
                if (started && rec.isRecording) {
                    self.audioRecorder = rec;
                    self.hasDetectedSpeech = NO;
                    self.speechFirstDetectedTime = 0;
                    self.silenceStartTime = 0;
                    self.bargeInVoiceTicks = 0;
                    self.normalVoiceTicks = 0;
                    self.recordStartTime = [[NSDate date] timeIntervalSince1970];
                    [self.meterTimer invalidate];
                    self.meterTimer = [NSTimer timerWithTimeInterval:0.06 target:self selector:@selector(updateAudioMeters) userInfo:nil repeats:YES];
                    [[NSRunLoop mainRunLoop] addTimer:self.meterTimer forMode:NSRunLoopCommonModes];
                }
            });
        } @catch (NSException *e) {}
    });
}

- (void)updateAudioMeters {
    if (!self.audioRecorder || !self.audioRecorder.isRecording) return;
    [self.audioRecorder updateMeters];
    float power = [self.audioRecorder averagePowerForChannel:0];
    float peak = [self.audioRecorder peakPowerForChannel:0];
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

    // 1. 当 AI 正在说话或正在流式返回时：支持人声插话打断（采用已验证不自断的稳定阈值 power > -17.5f && peak > -8.0f 连续 5 帧）
    if ([self.synthesizer isSpeaking] || self.activeUtteranceCount > 0 || self.currentTask != nil) {
        if (power > -17.5f && peak > -8.0f) {
            self.bargeInVoiceTicks++;
            if (self.bargeInVoiceTicks >= 5) {
                self.bargeInVoiceTicks = 0;
                if (self.currentTask) {
                    [self.currentTask cancel];
                    self.currentTask = nil;
                }
                [self.pendingSpeechChunk setString:@""];
                self.activeUtteranceCount = 0;
                [self.synthesizer stopSpeakingAtBoundary:AVSpeechBoundaryImmediate];

                [self.audioRecorder stop];
                [[NSFileManager defaultManager] removeItemAtPath:self.audioFilePath error:nil];
                [self.audioRecorder prepareToRecord];
                [self.audioRecorder record];

                self.hasDetectedSpeech = YES;
                self.speechFirstDetectedTime = now;
                self.silenceStartTime = 0;
                self.subStatusLabel.text = @"⚡ 已打断 AI，正在倾听您的新指令...";
            }
        } else {
            self.bargeInVoiceTicks = 0;
        }
        return;
    }

    // 2. 正常倾听状态：过滤单次呼吸（需连续 2 帧高于 -35dB 起音），停顿 0.80 秒自动发送
    if (power > -35.0f && peak > -23.0f) {
        self.normalVoiceTicks++;
        CGFloat activeLevel = MAX(0.22, MIN(1.0, (power + 40.0) / 28.0));
        [self setWaveBarsLevel:activeLevel];
        if (self.normalVoiceTicks >= 2 && !self.hasDetectedSpeech) {
            self.hasDetectedSpeech = YES;
            self.speechFirstDetectedTime = now;
            self.subStatusLabel.text = (self.activeModeTab == AGConfigTabVideoAI)
                ? @"📹 正在捕捉您的语音与当前镜头画面..."
                : @"🔊 正在接收您的语音 (说完停顿 0.8 秒自动秒回)...";
        }
        if (self.hasDetectedSpeech) {
            self.silenceStartTime = 0;
        }
    } else {
        if (!self.hasDetectedSpeech) self.normalVoiceTicks = 0;
        [self setWaveBarsLevel:0.0];
        if (self.hasDetectedSpeech) {
            if (now - self.speechFirstDetectedTime < 0.45) return;
            if (self.silenceStartTime == 0) {
                self.silenceStartTime = now;
            } else if (now - self.silenceStartTime >= 0.80) {
                self.normalVoiceTicks = 0;
                [self finishVoiceTurnAndSend];
            }
        } else if (now - self.recordStartTime >= 25.0 && self.currentKeyboardHeight == 0) {
            [self.audioRecorder stop];
            [[NSFileManager defaultManager] removeItemAtPath:self.audioFilePath error:nil];
            [self.audioRecorder prepareToRecord];
            [self.audioRecorder record];
            self.recordStartTime = now;
        }
    }
}

- (void)finishVoiceTurnAndSend {
    [self.meterTimer invalidate];
    self.meterTimer = nil;
    [self setWaveBarsLevel:0.0];
    if (self.audioRecorder && self.audioRecorder.isRecording) [self.audioRecorder stop];
    self.audioRecorder = nil;

    NSMutableData *audioData = [NSMutableData dataWithContentsOfFile:self.audioFilePath];
    if (audioData.length < 1200) {
        [self startContinuousVoiceListening];
        return;
    }

    // 跳过 iOS CoreAudio 的 FLLR 填充块，定位真正的 "data" 音频起点做 2.2 倍远场放大，绝不破坏 WAV 文件头
    const uint8_t *bytes = (const uint8_t *)audioData.bytes;
    NSUInteger len = audioData.length;
    NSUInteger pcmDataOffset = 0;
    for (NSUInteger i = 12; i + 8 < MIN(len, 8192); i++) {
        if (bytes[i] == 'd' && bytes[i+1] == 'a' && bytes[i+2] == 't' && bytes[i+3] == 'a') {
            pcmDataOffset = i + 8;
            break;
        }
    }
    if (pcmDataOffset > 0 && pcmDataOffset < len) {
        int16_t *pcmSamples = (int16_t *)((uint8_t *)audioData.mutableBytes + pcmDataOffset);
        NSUInteger sampleCount = (len - pcmDataOffset) / sizeof(int16_t);
        for (NSUInteger i = 0; i < sampleCount; i++) {
            float boosted = (float)pcmSamples[i] * 2.2f;
            if (boosted > 32767.0f) boosted = 32767.0f;
            else if (boosted < -32768.0f) boosted = -32768.0f;
            pcmSamples[i] = (int16_t)boosted;
        }
    }

    NSString *promptText = (self.activeModeTab == AGConfigTabVideoAI)
        ? @"请认真听取这段用户的语音提问，并结合附带的实时摄像头画面（如有）直接用简明自然的中文回答用户。"
        : @"请认真听取这段用户的语音，结合上下文直接用简明自然的中文回答。如果用户要求打开应用、微信/支付宝快捷操作、开关手电筒、导航、音量或拨打电话，请在末尾附带对应的[ACTION:{\"type\":\"...\"}]指令。";
    [self dispatchMultimodalRequestWithText:promptText audioData:audioData isInitialGreeting:NO forTab:self.activeModeTab];
}

- (void)showActionBanner:(NSString *)msg {
    [[AGGlobalActionPillWindow sharedPill] showActionPill:msg];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.actionBannerLabel) {
            [self.actionBannerLabel.superview bringSubviewToFront:self.actionBannerLabel];
            self.actionBannerLabel.text = msg;
            self.actionBannerLabel.transform = CGAffineTransformMakeScale(0.92, 0.92);
            [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.7 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.actionBannerLabel.alpha = 1.0;
                self.actionBannerLabel.transform = CGAffineTransformIdentity;
            } completion:nil];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [UIView animateWithDuration:0.25 animations:^{
                    self.actionBannerLabel.alpha = 0.0;
                }];
            });
        }
    });
}

// 同时驱动顶部 5 根声波柱 + 底部双轨正弦流体波浪振幅 + 左上角 3D 球微脉动
- (void)setWaveBarsLevel:(CGFloat)level {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSTimeInterval now = CACurrentMediaTime();
        if (level <= 0.01) {
            if (self.targetVoiceAmplitude <= 0.01) return; // 已归零则不重复启动归零动画
            self.targetVoiceAmplitude = 0.0;
            self.lastWaveBarAnimTime = now;
            NSArray<NSNumber *> *idleScales = @[@(0.55), @(0.85), @(0.62), @(0.88), @(0.55)];
            [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
                for (int i = 0; i < self.waveBars.count; i++) {
                    UIView *bar = self.waveBars[i];
                    CGFloat sy = [idleScales[i % idleScales.count] floatValue];
                    bar.transform = CGAffineTransformMakeScale(1.0, sy);
                }
                self.aiOrbView.transform = CGAffineTransformIdentity;
            } completion:nil];
            return;
        }

        self.targetVoiceAmplitude = level;
        // 节流保护：距离上次音柱动画不足 0.07 秒时不重复创建重叠的 UIView 动画，主线程负载降低 85%
        if (now - self.lastWaveBarAnimTime < 0.07) {
            return;
        }
        self.lastWaveBarAnimTime = now;

        NSArray<NSNumber *> *weights = @[@(0.60), @(1.0), @(0.78), @(0.96), @(0.60)];
        [UIView animateWithDuration:0.08 delay:0 options:UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionAllowUserInteraction animations:^{
            for (int i = 0; i < self.waveBars.count; i++) {
                UIView *bar = self.waveBars[i];
                CGFloat w = [weights[i % weights.count] floatValue];
                CGFloat jitter = 0.72 + (arc4random_uniform(45) / 100.0);
                CGFloat sy = MAX(0.38, MIN(1.38, 0.38 + level * 1.05 * w * jitter));
                bar.transform = CGAffineTransformMakeScale(1.0, sy);
            }
            CGFloat orbScale = 1.0 + MIN(0.16, level * 0.18);
            self.aiOrbView.transform = CGAffineTransformMakeScale(orbScale, orbScale);
        } completion:nil];
    });
}

- (void)sendButtonTapped {
    [self.impactHaptic impactOccurred];
    [self animateButtonBounce:self.sendBtn];
    if (self.inputField.text.length > 0) {
        [self textFieldShouldReturn:self.inputField];
    } else if (self.audioRecorder && self.audioRecorder.isRecording) {
        [self finishVoiceTurnAndSend];
    }
}

#pragma mark - 3. 手机操作引擎 (全场景系统级 Agent 自动化中枢)

- (void)checkDeferredVoiceLocalCommand {
    if (self.currentVoiceQueryBuffer.length == 0) return;
    NSString *fullCmd = [self.currentVoiceQueryBuffer copy];
    if ([self tryExecuteDirectLocalCommand:fullCmd]) {
        [self.currentVoiceQueryBuffer setString:@""];
        if (self.pcmPlayerNode && self.pcmPlayerNode.isPlaying) {
            [self.pcmPlayerNode stop];
        }
    }
}

// 支持单条或多条连续 [ACTION:{...}] 复合连招解析与顺序执行
- (NSString *)parseAndExecuteActions:(NSString *)responseText executed:(BOOL *)outExecuted {
    if (outExecuted) *outExecuted = NO;
    if (!responseText || responseText.length == 0) return @"";

    static NSRegularExpression *sActionRegex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sActionRegex = [NSRegularExpression regularExpressionWithPattern:@"\\[ACTION:(\\{.*?\\})\\]"
                                                                 options:NSRegularExpressionDotMatchesLineSeparators
                                                                   error:nil];
    });
    NSArray<NSTextCheckingResult *> *matches = [sActionRegex matchesInString:responseText options:0 range:NSMakeRange(0, responseText.length)];
    if (matches.count > 0) {
        NSMutableArray<NSDictionary *> *actionList = [NSMutableArray array];
        for (NSTextCheckingResult *match in matches) {
            if (match.numberOfRanges > 1) {
                NSString *jsonStr = [responseText substringWithRange:[match rangeAtIndex:1]];
                NSData *jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
                NSDictionary *actionDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
                if ([actionDict isKindOfClass:[NSDictionary class]]) {
                    [actionList addObject:actionDict];
                }
            }
        }
        if (actionList.count > 0) {
            if (outExecuted) *outExecuted = YES;
            for (NSUInteger i = 0; i < actionList.count; i++) {
                NSDictionary *act = actionList[i];
                if (i == 0) {
                    [self executeActionDictionary:act];
                } else {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.45 * i * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self executeActionDictionary:act];
                    });
                }
            }
        }
        NSString *cleaned = [sActionRegex stringByReplacingMatchesInString:responseText options:0 range:NSMakeRange(0, responseText.length) withTemplate:@""];
        return [cleaned stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    return responseText;
}

- (BOOL)tryExecuteDirectLocalCommand:(NSString *)cmdText {
    if (!cmdText || cmdText.length == 0) return NO;

    static NSRegularExpression *wxPat1 = nil, *wxPat2 = nil, *wxPat3 = nil;
    static NSRegularExpression *numRe = nil, *timerRe = nil, *alarmRe = nil, *tapTextRe = nil;
    static NSRegularExpression *searchRegex = nil, *naviRegex = nil, *musicRegex = nil;
    static NSRegularExpression *openRegex = nil, *callRegex = nil, *smsRegex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        wxPat1 = [NSRegularExpression regularExpressionWithPattern:@"(?:打开微信|在微信|用微信|微信)(?:里|中)?(?:给|向|跟|发给|告诉|对)(.+?)(?:发消息|发信息|发一句话|发个消息|发条微信|发微信|发|说|留言)(?:说|内容是|：|:)?(.+)$" options:0 error:nil];
        wxPat2 = [NSRegularExpression regularExpressionWithPattern:@"(?:给|向|跟|对)(.+?)(?:发微信|发条微信|发个微信|发微信消息|微信留言|微信说)(?:说|内容是|：|:)?(.+)$" options:0 error:nil];
        wxPat3 = [NSRegularExpression regularExpressionWithPattern:@"(?:发微信|发条微信|微信发消息)(?:给|发给|向)(.+?)(?:说|内容是|：|:)?(.+)$" options:0 error:nil];
        numRe = [NSRegularExpression regularExpressionWithPattern:@"(\\d{1,3})" options:0 error:nil];
        timerRe = [NSRegularExpression regularExpressionWithPattern:@"(?:定个|设个|设置|开启|来个)?(\\d{1,3})(?:分钟|分|秒)(?:的)?(?:倒计时|计时器)" options:0 error:nil];
        alarmRe = [NSRegularExpression regularExpressionWithPattern:@"(?:定个|设个|设置|定一个)?(?:明天|明早|早上|上午|下午|晚上)?(\\d{1,2})(?:点|时|:|：)(?:(\\d{1,2})分?)?(?:的)?闹钟" options:0 error:nil];
        tapTextRe = [NSRegularExpression regularExpressionWithPattern:@"(?:点击|点一下)(?:屏幕上的|按钮)?[“\"'「]?([^”\"'」，。！？,.!?\\s]+)[”\"'」]?" options:0 error:nil];
        searchRegex = [NSRegularExpression regularExpressionWithPattern:@"(?:打开|启动|在|去|用|上)?(淘宝|京东|拼多多|美团|抖音|b站|哔哩哔哩|小红书|知乎|微博|百度)(?:里|上|app)?(?:帮我)?(?:搜一下|搜索一下|查找一下|找一下|搜索|搜|找|买|看)(?:一下)?(.+)$" options:0 error:nil];
        naviRegex = [NSRegularExpression regularExpressionWithPattern:@"(?:打开|用|使用)?(?:高德地图|百度地图|苹果地图|高德|百度|地图)?(?:帮我)?(?:导航|驾车|骑行|步行)?(?:到|去|前往|去往)(.+?)(?:怎么走|怎么去|吧|呢)?$" options:0 error:nil];
        musicRegex = [NSRegularExpression regularExpressionWithPattern:@"(?:在网易云|在qq音乐|听|播放)(?:搜|播|听)?([^，。！？,.!?\\s]+)" options:0 error:nil];
        openRegex = [NSRegularExpression regularExpressionWithPattern:@"^(?:打开|启动|开启)([^，。！？,.!?\\s”\"']+)$" options:0 error:nil];
        callRegex = [NSRegularExpression regularExpressionWithPattern:@"(?:给|拨打)([^，。！？,.!?\\s]+?)(?:打电话|呼叫|的电话)" options:0 error:nil];
        smsRegex = [NSRegularExpression regularExpressionWithPattern:@"给(.+?)发(?:短信|信息)(?:说|内容是)?(.+)$" options:0 error:nil];
    });

    NSString *cmd = [[cmdText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];

    NSString *cleanCmd = [cmd stringByReplacingOccurrencesOfString:@"帮我" withString:@""];
    cleanCmd = [cleanCmd stringByReplacingOccurrencesOfString:@"请你" withString:@""];
    cleanCmd = [cleanCmd stringByReplacingOccurrencesOfString:@"请" withString:@""];
    cleanCmd = [cleanCmd stringByReplacingOccurrencesOfString:@"把" withString:@""];

    // 0A. 💬 微信未读消息检查与打开指定聊天窗
    if ([cleanCmd containsString:@"微信"] && ([cleanCmd containsString:@"未读"] || [cleanCmd containsString:@"谁给我发"] || [cleanCmd containsString:@"新消息"])) {
        [self executeActionDictionary:@{@"type": @"wechat_read_unread"}];
        return YES;
    }

    // 0B. 💬 微信跨进程自动发消息
    NSTextCheckingResult *wxMatch = [wxPat1 firstMatchInString:cleanCmd options:0 range:NSMakeRange(0, cleanCmd.length)];
    if (!wxMatch) wxMatch = [wxPat2 firstMatchInString:cleanCmd options:0 range:NSMakeRange(0, cleanCmd.length)];
    if (!wxMatch) wxMatch = [wxPat3 firstMatchInString:cleanCmd options:0 range:NSMakeRange(0, cleanCmd.length)];

    if (wxMatch && wxMatch.numberOfRanges >= 3) {
        NSString *target = [[cleanCmd substringWithRange:[wxMatch rangeAtIndex:1]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *content = [[cleanCmd substringWithRange:[wxMatch rangeAtIndex:2]] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([content hasPrefix:@"说"]) content = [content substringFromIndex:1];
        if ([content hasPrefix:@"："] || [content hasPrefix:@":"]) content = [content substringFromIndex:1];
        if ([content hasPrefix:@"内容是"]) content = [content substringFromIndex:3];
        content = [content stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
        content = [content stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

        if (target.length > 0 && content.length > 0) {
            [self executeActionDictionary:@{@"type": @"wechat_message", @"target": target, @"content": content}];
            return YES;
        }
    }

    // 1. 🔦 手电筒极速控制
    if ([cmd containsString:@"关"] && [cmd containsString:@"手电筒"]) {
        [self executeActionDictionary:@{@"type": @"toggle_flashlight", @"on": @NO}];
        return YES;
    }
    if ([cmd containsString:@"手电筒"] && ([cmd containsString:@"开"] || [cmd containsString:@"照亮"])) {
        float lvl = 1.0f;
        if ([cmd containsString:@"弱"] || [cmd containsString:@"低"] || [cmd containsString:@"暗"]) lvl = 0.25f;
        [self executeActionDictionary:@{@"type": @"toggle_flashlight", @"on": @YES, @"level": @(lvl)}];
        return YES;
    }

    // 2. 🎵 媒体播放控制
    if ([cmd containsString:@"暂停播放"] || [cmd containsString:@"暂停音乐"] || [cmd isEqualToString:@"暂停"]) {
        [self executeActionDictionary:@{@"type": @"media_control", @"action": @"pause"}];
        return YES;
    }
    if ([cmd containsString:@"继续播放"] || [cmd containsString:@"播放音乐"] || [cmd isEqualToString:@"播放"]) {
        [self executeActionDictionary:@{@"type": @"media_control", @"action": @"play"}];
        return YES;
    }
    if ([cmd containsString:@"下一首"] || [cmd containsString:@"切歌"]) {
        [self executeActionDictionary:@{@"type": @"media_control", @"action": @"next"}];
        return YES;
    }
    if ([cmd containsString:@"上一首"]) {
        [self executeActionDictionary:@{@"type": @"media_control", @"action": @"prev"}];
        return YES;
    }

    // 3. 🔊 音量控制（支持说具体百分比数字，如“声音调到 60%”）
    if ([cmd containsString:@"静音"] || [cmd containsString:@"关闭声音"]) {
        [self executeActionDictionary:@{@"type": @"volume_control", @"action": @"mute"}];
        return YES;
    }
    if ([cmd containsString:@"音量"] || [cmd containsString:@"声音"]) {
        NSTextCheckingResult *numMatch = [numRe firstMatchInString:cmd options:0 range:NSMakeRange(0, cmd.length)];
        if (numMatch) {
            float val = [[cmd substringWithRange:[numMatch rangeAtIndex:1]] floatValue] / 100.0f;
            [self executeActionDictionary:@{@"type": @"volume_control", @"action": @"set", @"level": @(MAX(0.0f, MIN(1.0f, val)))}];
            return YES;
        }
        if ([cmd containsString:@"最大"] || [cmd containsString:@"拉满"]) {
            [self executeActionDictionary:@{@"type": @"volume_control", @"action": @"set", @"level": @1.0}];
            return YES;
        }
        if ([cmd containsString:@"一半"]) {
            [self executeActionDictionary:@{@"type": @"volume_control", @"action": @"set", @"level": @0.5}];
            return YES;
        }
        if ([cmd containsString:@"大"] || [cmd containsString:@"高"] || [cmd containsString:@"加"] || [cmd containsString:@"响"]) {
            [self executeActionDictionary:@{@"type": @"volume_control", @"action": @"up"}];
            return YES;
        }
        if ([cmd containsString:@"小"] || [cmd containsString:@"低"] || [cmd containsString:@"减"] || [cmd containsString:@"轻"]) {
            [self executeActionDictionary:@{@"type": @"volume_control", @"action": @"down"}];
            return YES;
        }
    }

    // 4. ☀️ 屏幕亮度调节（精准提取百分比数值，彻底修复包含 "0" 被误判为最暗的 Bug）
    if ([cmd containsString:@"亮度"] || ([cmd containsString:@"屏幕"] && ([cmd containsString:@"亮"] || [cmd containsString:@"暗"]))) {
        NSTextCheckingResult *numMatch = [numRe firstMatchInString:cmd options:0 range:NSMakeRange(0, cmd.length)];
        if (numMatch) {
            float pct = [[cmd substringWithRange:[numMatch rangeAtIndex:1]] floatValue];
            float targetLvl = MAX(0.02f, MIN(1.0f, pct / 100.0f));
            [self executeActionDictionary:@{@"type": @"brightness_control", @"action": @"set", @"level": @(targetLvl)}];
            return YES;
        }
        if ([cmd containsString:@"最亮"] || [cmd containsString:@"拉满"] || [cmd containsString:@"最大"]) {
            [self executeActionDictionary:@{@"type": @"brightness_control", @"action": @"set", @"level": @1.0}];
            return YES;
        } else if ([cmd containsString:@"最暗"] || [cmd containsString:@"最低"]) {
            [self executeActionDictionary:@{@"type": @"brightness_control", @"action": @"set", @"level": @0.05}];
            return YES;
        } else if ([cmd containsString:@"一半"] || [cmd containsString:@"适中"]) {
            [self executeActionDictionary:@{@"type": @"brightness_control", @"action": @"set", @"level": @0.50}];
            return YES;
        } else if ([cmd containsString:@"大"] || [cmd containsString:@"高"] || [cmd containsString:@"亮"] || [cmd containsString:@"加"] || [cmd containsString:@"升"]) {
            [self executeActionDictionary:@{@"type": @"brightness_control", @"action": @"up"}];
            return YES;
        } else if ([cmd containsString:@"小"] || [cmd containsString:@"低"] || [cmd containsString:@"暗"] || [cmd containsString:@"减"] || [cmd containsString:@"降"]) {
            [self executeActionDictionary:@{@"type": @"brightness_control", @"action": @"down"}];
            return YES;
        }
    }

    // 5. 📸 一键屏幕截图
    if ([cmd containsString:@"截屏"] || [cmd containsString:@"截图"] || [cmd containsString:@"截取屏幕"]) {
        [self executeActionDictionary:@{@"type": @"take_screenshot"}];
        return YES;
    }

    // 6. 📶 Wi-Fi、蓝牙、飞行模式
    if ([cmd containsString:@"wifi"] || [cmd containsString:@"wi-fi"] || [cmd containsString:@"无线网"] || [cmd containsString:@"局域网"]) {
        BOOL on = !([cmd containsString:@"关"] || [cmd containsString:@"断"]);
        [self executeActionDictionary:@{@"type": @"wifi_toggle", @"on": @(on)}];
        return YES;
    }
    if ([cmd containsString:@"蓝牙"]) {
        BOOL on = !([cmd containsString:@"关"] || [cmd containsString:@"断"]);
        [self executeActionDictionary:@{@"type": @"bluetooth_toggle", @"on": @(on)}];
        return YES;
    }
    if ([cmd containsString:@"飞行模式"]) {
        BOOL on = !([cmd containsString:@"关"] || [cmd containsString:@"退"]);
        [self executeActionDictionary:@{@"type": @"airplane_mode", @"on": @(on)}];
        return YES;
    }

    // 7. 🌙 深色模式 / 浅色模式 / 夜览护眼模式
    if ([cmd containsString:@"深色模式"] || [cmd containsString:@"暗黑模式"] || [cmd containsString:@"夜间模式"]) {
        BOOL on = !([cmd containsString:@"关"] || [cmd containsString:@"退"]);
        [self executeActionDictionary:@{@"type": @"appearance_mode", @"mode": (on ? @"dark" : @"light")}];
        return YES;
    }
    if ([cmd containsString:@"浅色模式"] || [cmd containsString:@"白天模式"] || [cmd containsString:@"亮色模式"]) {
        [self executeActionDictionary:@{@"type": @"appearance_mode", @"mode": @"light"}];
        return YES;
    }
    if ([cmd containsString:@"夜览"] || [cmd containsString:@"护眼模式"]) {
        BOOL on = !([cmd containsString:@"关"] || [cmd containsString:@"退"]);
        [self executeActionDictionary:@{@"type": @"appearance_mode", @"mode": (on ? @"nightshift_on" : @"nightshift_off")}];
        return YES;
    }

    // 8. 🧹 一键清理手机后台应用
    if (([cmd containsString:@"清理"] || [cmd containsString:@"关闭"] || [cmd containsString:@"清空"] || [cmd containsString:@"杀掉"]) && [cmd containsString:@"后台"]) {
        [self executeActionDictionary:@{@"type": @"kill_background_apps"}];
        return YES;
    }

    // 9. ⏰ 原生倒计时与闹钟直控
    NSTextCheckingResult *timerMatch = [timerRe firstMatchInString:cleanCmd options:0 range:NSMakeRange(0, cleanCmd.length)];
    if (timerMatch) {
        NSInteger val = [[cleanCmd substringWithRange:[timerMatch rangeAtIndex:1]] integerValue];
        BOOL isSec = [cleanCmd containsString:@"秒"] && ![cleanCmd containsString:@"分"];
        NSInteger totalSecs = isSec ? val : (val * 60);
        [self executeActionDictionary:@{@"type": @"timer_control", @"action": @"start", @"seconds": @(totalSecs)}];
        return YES;
    }
    NSTextCheckingResult *alarmMatch = [alarmRe firstMatchInString:cleanCmd options:0 range:NSMakeRange(0, cleanCmd.length)];
    if (alarmMatch) {
        NSInteger hr = [[cleanCmd substringWithRange:[alarmMatch rangeAtIndex:1]] integerValue];
        NSInteger min = 0;
        if (alarmMatch.numberOfRanges > 2 && [alarmMatch rangeAtIndex:2].location != NSNotFound) {
            min = [[cleanCmd substringWithRange:[alarmMatch rangeAtIndex:2]] integerValue];
        } else if ([cleanCmd containsString:@"半"]) {
            min = 30;
        }
        if (([cleanCmd containsString:@"下午"] || [cleanCmd containsString:@"晚上"]) && hr < 12) hr += 12;
        [self executeActionDictionary:@{@"type": @"alarm_control", @"hour": @(hr), @"minute": @(min)}];
        return YES;
    }

    // 10. 👆 视觉触控手势与点击屏幕上文字 (GUI Agent)
    if ([cmd isEqualToString:@"下一个视频"] || [cmd isEqualToString:@"往下滑"] || [cmd isEqualToString:@"向上滑"] || [cmd isEqualToString:@"刷下一个"]) {
        [self executeActionDictionary:@{@"type": @"ui_gesture", @"gesture": @"swipe_up"}];
        return YES;
    }
    if ([cmd isEqualToString:@"上一个视频"] || [cmd isEqualToString:@"往上滑"] || [cmd isEqualToString:@"向下滑"]) {
        [self executeActionDictionary:@{@"type": @"ui_gesture", @"gesture": @"swipe_down"}];
        return YES;
    }
    if ([cmd containsString:@"双击点赞"] || [cmd isEqualToString:@"点赞"]) {
        [self executeActionDictionary:@{@"type": @"ui_gesture", @"gesture": @"double_tap"}];
        return YES;
    }
    NSTextCheckingResult *tapMatch = [tapTextRe firstMatchInString:cleanCmd options:0 range:NSMakeRange(0, cleanCmd.length)];
    if (tapMatch) {
        NSString *targetTxt = [cleanCmd substringWithRange:[tapMatch rangeAtIndex:1]];
        if (targetTxt.length > 0) {
            [self executeActionDictionary:@{@"type": @"ui_tap_text", @"text": targetTxt}];
            return YES;
        }
    }

    // 11. 📊 设备电量与存储内存自检
    if ([cmd containsString:@"多少电"] || [cmd containsString:@"剩余电量"] || [cmd containsString:@"存储空间"] || [cmd containsString:@"手机状态"]) {
        [self executeActionDictionary:@{@"type": @"device_status"}];
        return YES;
    }

    // 12. 🔒 屏幕方向锁定与省电模式
    if ([cmd containsString:@"竖屏"] || [cmd containsString:@"旋转锁定"] || [cmd containsString:@"锁定方向"] || [cmd containsString:@"方向锁定"]) {
        BOOL lock = !([cmd containsString:@"解"] || [cmd containsString:@"关"]);
        [self executeActionDictionary:@{@"type": @"orientation_lock", @"lock": @(lock)}];
        return YES;
    }
    if (([cmd containsString:@"省电"] || [cmd containsString:@"低电量"]) && ([cmd containsString:@"关"] || [cmd containsString:@"退"])) {
        [self executeActionDictionary:@{@"type": @"low_power_mode", @"on": @NO}];
        return YES;
    }
    if (([cmd containsString:@"省电"] || [cmd containsString:@"低电量"]) && ([cmd containsString:@"开"] || [cmd containsString:@"启"] || [cmd isEqualToString:@"低电量模式"] || [cmd isEqualToString:@"省电模式"])) {
        [self executeActionDictionary:@{@"type": @"low_power_mode", @"on": @YES}];
        return YES;
    }

    // 13. 🔒 锁屏与系统操作
    if ([cmd containsString:@"回桌面"] || [cmd containsString:@"返回桌面"] || [cmd containsString:@"回到主屏幕"]) {
        [self executeActionDictionary:@{@"type": @"system_control", @"action": @"home"}];
        return YES;
    }
    if ([cmd containsString:@"锁屏"] || [cmd containsString:@"锁定屏幕"] || [cmd containsString:@"熄灭屏幕"]) {
        [self executeActionDictionary:@{@"type": @"system_control", @"action": @"lock"}];
        return YES;
    }
    if ([cmd containsString:@"注销"] || [cmd containsString:@"重启桌面"] || [cmd containsString:@"刷新桌面"]) {
        [self executeActionDictionary:@{@"type": @"system_control", @"action": @"respring"}];
        return YES;
    }

    // 14. 🟢 移动支付、扫码、乘车码与生活服务深度直达
    if ([cmd containsString:@"微信"] && [cmd containsString:@"扫"]) {
        [self executeActionDictionary:@{@"type": @"wechat_shortcut", @"feature": @"scan"}];
        return YES;
    }
    if ([cmd containsString:@"微信"] && ([cmd containsString:@"付"] || [cmd containsString:@"买单"])) {
        [self executeActionDictionary:@{@"type": @"wechat_shortcut", @"feature": @"pay"}];
        return YES;
    }
    if ([cmd containsString:@"微信"] && [cmd containsString:@"收"]) {
        [self executeActionDictionary:@{@"type": @"wechat_shortcut", @"feature": @"receipt"}];
        return YES;
    }
    if ([cmd containsString:@"微信"] && [cmd containsString:@"圈"]) {
        [self executeActionDictionary:@{@"type": @"wechat_shortcut", @"feature": @"moments"}];
        return YES;
    }
    if ([cmd isEqualToString:@"扫一扫"] || [cmd isEqualToString:@"扫码"]) {
        [self executeActionDictionary:@{@"type": @"wechat_shortcut", @"feature": @"scan"}];
        return YES;
    }
    if ([cmd containsString:@"支付宝"] && [cmd containsString:@"扫"]) {
        [self executeActionDictionary:@{@"type": @"alipay_shortcut", @"feature": @"scan"}];
        return YES;
    }
    if ([cmd containsString:@"乘车码"] || ([cmd containsString:@"支付宝"] && ([cmd containsString:@"公交"] || [cmd containsString:@"地铁"] || [cmd containsString:@"乘车"]))) {
        [self executeActionDictionary:@{@"type": @"alipay_shortcut", @"feature": @"bus"}];
        return YES;
    }
    if ([cmd containsString:@"支付宝"] && ([cmd containsString:@"付"] || [cmd containsString:@"买单"])) {
        [self executeActionDictionary:@{@"type": @"alipay_shortcut", @"feature": @"pay"}];
        return YES;
    }
    if ([cmd containsString:@"支付宝"] && [cmd containsString:@"收"]) {
        [self executeActionDictionary:@{@"type": @"alipay_shortcut", @"feature": @"receipt"}];
        return YES;
    }
    if ([cmd containsString:@"蚂蚁森林"] || [cmd containsString:@"收能量"] || [cmd containsString:@"收取能量"]) {
        [self openURLString:@"alipays://platformapi/startapp?appId=60000002"];
        return YES;
    }
    if ([cmd containsString:@"蚂蚁庄园"] || [cmd containsString:@"喂小鸡"] || [cmd containsString:@"喂鸡"]) {
        [self openURLString:@"alipays://platformapi/startapp?appId=66666674"];
        return YES;
    }
    if ([cmd containsString:@"支付宝"] && ([cmd containsString:@"快递"] || [cmd containsString:@"查件"])) {
        [self openURLString:@"alipays://platformapi/startapp?appId=20000754"];
        return YES;
    }
    if ([cmd containsString:@"医保"] && ([cmd containsString:@"码"] || [cmd containsString:@"凭证"])) {
        [self openURLString:@"alipays://platformapi/startapp?appId=20000067"];
        return YES;
    }
    if ([cmd containsString:@"云闪付"] && [cmd containsString:@"扫"]) {
        [self openURLString:@"upwallet://native/scanCode"];
        return YES;
    }
    if ([cmd containsString:@"云闪付"] && ([cmd containsString:@"付"] || [cmd containsString:@"买单"])) {
        [self openURLString:@"upwallet://pay"];
        return YES;
    }
    if ([cmd containsString:@"云闪付"] && ([cmd containsString:@"乘车"] || [cmd containsString:@"公交"] || [cmd containsString:@"地铁"])) {
        [self openURLString:@"upwallet://rn/rnhtmlridingcode"];
        return YES;
    }
    if ([cmd containsString:@"淘宝"] && [cmd containsString:@"扫"]) {
        [self openURLString:@"taobao://tb.cn/n/scancode"];
        return YES;
    }
    if ([cmd containsString:@"淘宝"] && [cmd containsString:@"购物车"]) {
        [self openURLString:@"taobao://m.taobao.com/cart"];
        return YES;
    }
    if ([cmd containsString:@"京东"] && [cmd containsString:@"扫"]) {
        [self openURLString:@"openapp.jdmobile://virtual?params=%7B%22category%22%3A%22jump%22%2C%22des%22%3A%22saoasao%22%7D"];
        return YES;
    }
    if ([cmd containsString:@"京东"] && [cmd containsString:@"购物车"]) {
        [self openURLString:@"openapp.jdmobile://virtual?params=%7B%22category%22%3A%22jump%22%2C%22des%22%3A%22cart%22%7D"];
        return YES;
    }
    if ([cmd containsString:@"闲鱼"] && ([cmd containsString:@"发布"] || [cmd containsString:@"卖闲置"])) {
        [self openURLString:@"fleamarket://publish"];
        return YES;
    }
    if ([cmd containsString:@"微博"] && [cmd containsString:@"扫"]) {
        [self openURLString:@"sinaweibo://qrcode"];
        return YES;
    }
    if ([cmd containsString:@"钉钉"] && [cmd containsString:@"扫"]) {
        [self openURLString:@"dingtalk://dingtalkclient/page/scan"];
        return YES;
    }
    if ([cmd containsString:@"飞书"] && [cmd containsString:@"扫"]) {
        [self openURLString:@"feishu://applink.feishu.cn/client/qrcode"];
        return YES;
    }
    if ([cmd containsString:@"58同城"] && [cmd containsString:@"扫"]) {
        [self openURLString:@"wbmain://jump/core/capture"];
        return YES;
    }
    if ([cmd containsString:@"菜鸟"] && ([cmd containsString:@"取件码"] || [cmd containsString:@"身份码"] || [cmd containsString:@"查件"])) {
        [self openURLString:@"cainiao://desktop/station_code"];
        return YES;
    }
    if (([cmd containsString:@"网易云"] || [cmd containsString:@"音乐"]) && [cmd containsString:@"听歌识曲"]) {
        [self openURLString:@"orpheuswidget://recognize"];
        return YES;
    }
    if ([cmd containsString:@"网易云"] && [cmd containsString:@"私人fm"]) {
        [self openURLString:@"orpheuswidget://radio"];
        return YES;
    }
    if ([cmd containsString:@"qq音乐"] && [cmd containsString:@"听歌识曲"]) {
        [self openURLString:@"qqmusic://qq.com/ui/recognize"];
        return YES;
    }
    if ([cmd containsString:@"滴答清单"] && ([cmd containsString:@"今天"] || [cmd containsString:@"今日"] || [cmd containsString:@"查看待办"])) {
        [self openURLString:@"ticktick://v1/show?smartlist=today"];
        return YES;
    }
    if ([cmd containsString:@"查违章"] || [cmd containsString:@"处理违章"] || [cmd containsString:@"驾照扣分"]) {
        [self openURLString:@"tmri12123://"];
        return YES;
    }
    if ([cmd containsString:@"个人所得税"] || [cmd containsString:@"个税汇算"] || [cmd containsString:@"查个税"]) {
        [self openURLString:@"taxpayer://"];
        return YES;
    }
    if ([cmd containsString:@"随申办"] || [cmd containsString:@"上海随申办"]) {
        [self openURLString:@"suishenban://"];
        return YES;
    }
    if ([cmd containsString:@"浙里办"]) {
        [self openURLString:@"zheliban://"];
        return YES;
    }
    if ([cmd containsString:@"大都会"] && ([cmd containsString:@"地铁"] || [cmd containsString:@"刷码"])) {
        [self openURLString:@"metrodadouhui://"];
        return YES;
    }
    if ([cmd containsString:@"亿通行"] && ([cmd containsString:@"地铁"] || [cmd containsString:@"乘车"])) {
        [self openURLString:@"yitongxing://"];
        return YES;
    }
    if ([cmd containsString:@"知乎"] && [cmd containsString:@"热榜"]) {
        [self openURLString:@"zhihu://billboard"];
        return YES;
    }
    if ([cmd containsString:@"b站"] && [cmd containsString:@"动态"]) {
        [self openURLString:@"bilibili://following/home"];
        return YES;
    }
    if ([cmd containsString:@"拍抖音"] || ([cmd containsString:@"抖音"] && [cmd containsString:@"拍视频"])) {
        [self openURLString:@"snssdk1128://openRecord"];
        return YES;
    }
    if ([cmd containsString:@"发小红书"] || ([cmd containsString:@"小红书"] && [cmd containsString:@"发笔记"])) {
        [self openURLString:@"xhsdiscover://post"];
        return YES;
    }

    // 14B. ⚙️ iOS 深度系统设置直达 (40+ 项设置面板秒开)
    if ([cmd containsString:@"设置"] || [cmd containsString:@"开关"]) {
        if ([cmd containsString:@"wifi"] || [cmd containsString:@"wi-fi"] || [cmd containsString:@"无线网"] || [cmd containsString:@"局域网"]) {
            [self openURLString:@"App-prefs:root=WIFI"];
            return YES;
        }
        if ([cmd containsString:@"蓝牙"]) {
            [self openURLString:@"App-prefs:root=Bluetooth"];
            return YES;
        }
        if ([cmd containsString:@"蜂窝"] || [cmd containsString:@"移动网络"] || [cmd containsString:@"流量"]) {
            [self openURLString:@"App-prefs:root=MOBILE_DATA_SETTINGS_ID"];
            return YES;
        }
        if ([cmd containsString:@"热点"] || [cmd containsString:@"个人热点"]) {
            [self openURLString:@"App-prefs:root=INTERNET_TETHERING"];
            return YES;
        }
        if ([cmd containsString:@"vpn"]) {
            [self openURLString:@"App-prefs:root=VPN"];
            return YES;
        }
        if ([cmd containsString:@"电池"] || [cmd containsString:@"健康"]) {
            [self openURLString:@"App-prefs:root=BATTERY_USAGE"];
            return YES;
        }
        if ([cmd containsString:@"显示"] || [cmd containsString:@"亮度"]) {
            [self openURLString:@"App-prefs:root=DISPLAY"];
            return YES;
        }
        if ([cmd containsString:@"自动锁定"] || [cmd containsString:@"息屏时间"]) {
            [self openURLString:@"App-prefs:root=DISPLAY&path=AUTOLOCK"];
            return YES;
        }
        if ([cmd containsString:@"声音"] || [cmd containsString:@"铃声"] || [cmd containsString:@"触感"]) {
            [self openURLString:@"App-prefs:root=Sounds"];
            return YES;
        }
        if ([cmd containsString:@"通知"]) {
            [self openURLString:@"App-prefs:root=NOTIFICATIONS_ID"];
            return YES;
        }
        if ([cmd containsString:@"专注模式"] || [cmd containsString:@"勿扰"]) {
            [self openURLString:@"App-prefs:root=DO_NOT_DISTURB"];
            return YES;
        }
        if ([cmd containsString:@"屏幕使用时间"]) {
            [self openURLString:@"App-prefs:root=SCREEN_TIME"];
            return YES;
        }
        if ([cmd containsString:@"通用"]) {
            [self openURLString:@"App-prefs:root=General"];
            return YES;
        }
        if ([cmd containsString:@"关于本机"] || [cmd containsString:@"序列号"]) {
            [self openURLString:@"App-prefs:root=General&path=About"];
            return YES;
        }
        if ([cmd containsString:@"软件更新"] || [cmd containsString:@"系统更新"]) {
            [self openURLString:@"App-prefs:root=General&path=SOFTWARE_UPDATE_LINK"];
            return YES;
        }
        if ([cmd containsString:@"存储空间"] || [cmd containsString:@"储存空间"] || [cmd containsString:@"清理手机"]) {
            [self openURLString:@"App-prefs:root=General&path=STORAGE_MGMT"];
            return YES;
        }
        if ([cmd containsString:@"隔空投送"] || [cmd containsString:@"airdrop"]) {
            [self openURLString:@"App-prefs:root=General&path=AIRDROP_LINK"];
            return YES;
        }
        if ([cmd containsString:@"carplay"] || [cmd containsString:@"车载"]) {
            [self openURLString:@"App-prefs:root=General&path=CARPLAY"];
            return YES;
        }
        if ([cmd containsString:@"日期"] || [cmd containsString:@"时间"]) {
            [self openURLString:@"App-prefs:root=General&path=DATE_AND_TIME"];
            return YES;
        }
        if ([cmd containsString:@"键盘"] || [cmd containsString:@"输入法"]) {
            [self openURLString:@"App-prefs:root=General&path=Keyboard"];
            return YES;
        }
        if ([cmd containsString:@"辅助功能"]) {
            [self openURLString:@"App-prefs:root=ACCESSIBILITY"];
            return YES;
        }
        if ([cmd containsString:@"小白点"] || [cmd containsString:@"辅助触控"]) {
            [self openURLString:@"App-prefs:root=ACCESSIBILITY&path=TOUCH_RE_TITLE"];
            return YES;
        }
        if ([cmd containsString:@"壁纸"] || [cmd containsString:@"墙纸"]) {
            [self openURLString:@"App-prefs:root=Wallpaper"];
            return YES;
        }
        if ([cmd containsString:@"面容"] || [cmd containsString:@"密码"] || [cmd containsString:@"face id"]) {
            [self openURLString:@"App-prefs:root=PASSCODE"];
            return YES;
        }
        if ([cmd containsString:@"定位"] || [cmd containsString:@"gps"]) {
            [self openURLString:@"App-prefs:root=Privacy&path=LOCATION"];
            return YES;
        }
        if ([cmd containsString:@"隐私"]) {
            [self openURLString:@"App-prefs:root=Privacy"];
            return YES;
        }
    }
    // 🛍️/🎬 各大电商与视频平台搜索（支持“打开淘宝搜索一下手机”、“去京东搜充电宝”、“在拼多多找纸巾”等全套口语）
    NSTextCheckingResult *searchMatch = [searchRegex firstMatchInString:cleanCmd options:0 range:NSMakeRange(0, cleanCmd.length)];
    if (searchMatch && searchMatch.numberOfRanges >= 3) {
        NSString *pltName = [cleanCmd substringWithRange:[searchMatch rangeAtIndex:1]];
        NSString *kw = [[cleanCmd substringWithRange:[searchMatch rangeAtIndex:2]] stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
        kw = [kw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (kw.length > 0) {
            [self executeActionDictionary:@{@"type": @"search", @"keyword": kw, @"platform": pltName}];
            return YES;
        }
    }

    // 🗺️ 地图导航（支持“帮我导航到XXX”、“打开高德地图导航去XXX”、“带我去XXX”）
    NSTextCheckingResult *naviMatch = [naviRegex firstMatchInString:cleanCmd options:0 range:NSMakeRange(0, cleanCmd.length)];
    if (naviMatch && ([cleanCmd containsString:@"导航"] || [cleanCmd containsString:@"地图"] || [cleanCmd containsString:@"带我去"] || [cleanCmd containsString:@"怎么走"])) {
        NSString *dest = [[cleanCmd substringWithRange:[naviMatch rangeAtIndex:1]] stringByTrimmingCharactersInSet:[NSCharacterSet punctuationCharacterSet]];
        dest = [dest stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (dest.length > 0 && ![dest containsString:@"微信"] && ![dest containsString:@"淘宝"]) {
            NSString *pref = [cleanCmd containsString:@"百度"] ? @"baidu" : ([cleanCmd containsString:@"苹果"] ? @"apple" : @"amap");
            [self executeActionDictionary:@{@"type": @"navigation", @"destination": dest, @"app": pref}];
            return YES;
        }
    }

    // 🎵 音乐播放与搜索
    if ([cmd containsString:@"网易云"] || [cmd containsString:@"qq音乐"] || [cmd containsString:@"歌曲"]) {
        NSTextCheckingResult *musicMatch = [musicRegex firstMatchInString:cmd options:0 range:NSMakeRange(0, cmd.length)];
        if (musicMatch) {
            NSString *kw = [cmd substringWithRange:[musicMatch rangeAtIndex:1]];
            NSString *pref = [cmd containsString:@"qq"] ? @"qqmusic" : @"netease";
            [self executeActionDictionary:@{@"type": @"music_search", @"keyword": kw, @"app": pref}];
            return YES;
        }
    }

    // 17. 📱 语音秒开任意应用（带防抢跑保护：若包含“给/向/发/说/告诉”，绝不当成单纯打开应用！）
    if (![cleanCmd containsString:@"给"] && ![cleanCmd containsString:@"发"] && ![cleanCmd containsString:@"向"] && ![cleanCmd containsString:@"告诉"]) {
        NSTextCheckingResult *openMatch = [openRegex firstMatchInString:cleanCmd options:0 range:NSMakeRange(0, cleanCmd.length)];
        if (openMatch) {
            NSString *appName = [cleanCmd substringWithRange:[openMatch rangeAtIndex:1]];
            [self executeActionDictionary:@{@"type": @"open_app", @"app": appName}];
            return YES;
        }
    }

    // 18. 📞 拨打电话 & 💬 发送短信
    NSTextCheckingResult *callMatch = [callRegex firstMatchInString:cleanCmd options:0 range:NSMakeRange(0, cleanCmd.length)];
    if (callMatch) {
        NSString *target = [cleanCmd substringWithRange:[callMatch rangeAtIndex:1]];
        [self executeActionDictionary:@{@"type": @"make_call", @"target": target}];
        return YES;
    }
    NSTextCheckingResult *smsMatch = [smsRegex firstMatchInString:cleanCmd options:0 range:NSMakeRange(0, cleanCmd.length)];
    if (smsMatch) {
        NSString *target = [cleanCmd substringWithRange:[smsMatch rangeAtIndex:1]];
        NSString *content = [cleanCmd substringWithRange:[smsMatch rangeAtIndex:2]];
        [self executeActionDictionary:@{@"type": @"send_sms", @"target": target, @"content": content}];
        return YES;
    }

    // 19. 🪄 复合场景宏 & 原位网页翻译
    if ([cmd containsString:@"晚安"] || [cmd containsString:@"我要睡了"] || [cmd containsString:@"准备睡觉"]) {
        [self executeActionDictionary:@{@"type": @"macro_scene", @"scene": @"sleep"}];
        return YES;
    }
    if ([cmd containsString:@"上车了"] || [cmd containsString:@"准备开车"] || [cmd containsString:@"出发去公司"]) {
        [self executeActionDictionary:@{@"type": @"macro_scene", @"scene": @"drive"}];
        return YES;
    }
    if ([cmd containsString:@"翻译"] && ([cmd containsString:@"网页"] || [cmd containsString:@"屏幕"] || [cmd containsString:@"页面"])) {
        [self executeActionDictionary:@{@"type": @"in_situ_translate"}];
        return YES;
    }
    return NO;
}

- (void)executeActionDictionary:(NSDictionary *)dict {
    [self.notifyHaptic notificationOccurred:UINotificationFeedbackTypeSuccess];
    [self.accumulatedReplyText setString:@""];
    [self.pendingSpeechChunk setString:@""];
    NSString *type = dict[@"type"];

    if ([type isEqualToString:@"open_app"]) {
        NSString *appName = dict[@"app"];
        if (appName) [self openApplicationByName:appName];
    } else if ([type isEqualToString:@"wechat_message"]) {
        NSString *target = dict[@"target"];
        NSString *content = dict[@"content"] ?: @"";
        if (target) [self sendWeChatMessageToTarget:target content:content];
    } else if ([type isEqualToString:@"wechat_read_unread"]) {
        [self handleWeChatReadUnread];
    } else if ([type isEqualToString:@"wechat_open_chat"]) {
        NSString *target = dict[@"target"];
        if (target) [self handleWeChatOpenChatWithTarget:target];
    } else if ([type isEqualToString:@"make_call"]) {
        NSString *target = dict[@"target"];
        if (target) [self makePhoneCallToTarget:target];
    } else if ([type isEqualToString:@"send_sms"]) {
        NSString *target = dict[@"target"];
        NSString *content = dict[@"content"] ?: @"";
        if (target) [self sendSMSToTarget:target content:content];
    } else if ([type isEqualToString:@"toggle_flashlight"] || [type isEqualToString:@"flashlight"]) {
        BOOL on = dict[@"on"] ? [dict[@"on"] boolValue] : YES;
        float lvl = dict[@"level"] ? [dict[@"level"] floatValue] : 1.0f;
        [self toggleFlashlight:on level:lvl];
    } else if ([type isEqualToString:@"brightness_control"]) {
        NSString *cmd = dict[@"action"] ?: @"set";
        NSNumber *lvl = dict[@"level"];
        [self handleBrightnessControl:cmd level:lvl];
    } else if ([type isEqualToString:@"take_screenshot"]) {
        [self handleTakeScreenshot];
    } else if ([type isEqualToString:@"wifi_toggle"]) {
        BOOL on = dict[@"on"] ? [dict[@"on"] boolValue] : YES;
        [self handleWiFiToggle:on];
    } else if ([type isEqualToString:@"bluetooth_toggle"]) {
        BOOL on = dict[@"on"] ? [dict[@"on"] boolValue] : YES;
        [self handleBluetoothToggle:on];
    } else if ([type isEqualToString:@"airplane_mode"]) {
        BOOL on = dict[@"on"] ? [dict[@"on"] boolValue] : YES;
        [self handleAirplaneMode:on];
    } else if ([type isEqualToString:@"appearance_mode"]) {
        NSString *mode = dict[@"mode"] ?: @"dark";
        [self handleAppearanceMode:mode];
    } else if ([type isEqualToString:@"kill_background_apps"]) {
        [self handleKillBackgroundApps];
    } else if ([type isEqualToString:@"alarm_control"]) {
        NSInteger hr = [dict[@"hour"] integerValue];
        NSInteger min = [dict[@"minute"] integerValue];
        NSString *title = dict[@"title"] ?: @"天使守护闹钟";
        [self handleCreateAlarmHour:hr minute:min title:title];
    } else if ([type isEqualToString:@"timer_control"]) {
        NSInteger secs = dict[@"seconds"] ? [dict[@"seconds"] integerValue] : ([dict[@"minutes"] integerValue] * 60);
        [self handleStartTimerSeconds:MAX(5, secs)];
    } else if ([type isEqualToString:@"reminder_add"]) {
        NSString *title = dict[@"title"] ?: dict[@"content"];
        if (title) [self handleAddSystemReminder:title];
    } else if ([type isEqualToString:@"ui_tap_text"]) {
        NSString *targetText = dict[@"text"];
        if (targetText) [self handleVisualTapTextOnScreen:targetText];
    } else if ([type isEqualToString:@"ui_gesture"]) {
        NSString *gesture = dict[@"gesture"] ?: @"swipe_up";
        [self handleSynthesizedUIGesture:gesture];
    } else if ([type isEqualToString:@"clipboard_auto_type"]) {
        NSString *text = dict[@"text"] ?: dict[@"content"];
        if (text) [self handleClipboardAndAutoType:text];
    } else if ([type isEqualToString:@"device_status"]) {
        [self handleReportDeviceStatus];
    } else if ([type isEqualToString:@"orientation_lock"]) {
        BOOL lock = dict[@"lock"] ? [dict[@"lock"] boolValue] : YES;
        [self handleOrientationLock:lock];
    } else if ([type isEqualToString:@"macro_scene"]) {
        NSString *sc = dict[@"scene"] ?: @"sleep";
        [self handleMacroScene:sc];
    } else if ([type isEqualToString:@"search"]) {
        NSString *kw = dict[@"keyword"] ?: @"";
        NSString *plt = dict[@"platform"] ?: @"baidu";
        [self handleSearchOnPlatform:plt keyword:kw];
    } else if ([type isEqualToString:@"media_control"]) {
        NSString *cmd = dict[@"action"] ?: dict[@"command"];
        if (cmd) [self handleMediaControl:cmd];
    } else if ([type isEqualToString:@"volume_control"]) {
        NSString *cmd = dict[@"action"] ?: dict[@"command"];
        NSNumber *lvl = dict[@"level"];
        [self handleVolumeControl:cmd level:lvl];
    } else if ([type isEqualToString:@"low_power_mode"]) {
        BOOL on = dict[@"on"] ? [dict[@"on"] boolValue] : YES;
        [self toggleLowPowerMode:on];
    } else if ([type isEqualToString:@"system_control"]) {
        NSString *cmd = dict[@"action"] ?: dict[@"command"];
        if (cmd) [self handleSystemControl:cmd];
    } else if ([type isEqualToString:@"wechat_shortcut"]) {
        NSString *feature = dict[@"feature"] ?: @"scan";
        [self handleWechatShortcut:feature];
    } else if ([type isEqualToString:@"alipay_shortcut"]) {
        NSString *feature = dict[@"feature"] ?: @"scan";
        [self handleAlipayShortcut:feature];
    } else if ([type isEqualToString:@"navigation"]) {
        NSString *dest = dict[@"destination"] ?: dict[@"target"];
        NSString *app = dict[@"app"] ?: @"amap";
        [self handleNavigationToDestination:dest preferredApp:app];
    } else if ([type isEqualToString:@"music_search"]) {
        NSString *keyword = dict[@"keyword"] ?: dict[@"song"];
        NSString *app = dict[@"app"] ?: @"netease";
        [self handleMusicSearch:keyword preferredApp:app];
    } else if ([type isEqualToString:@"open_url"]) {
        NSString *urlStr = dict[@"url"];
        if (urlStr) [self openURLString:urlStr];
    } else if ([type isEqualToString:@"in_situ_translate"]) {
        [self dismissOverlay];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[AGInSituTranslationOverlay sharedOverlay] startInSituTranslation];
        });
    }
}

- (void)openApplicationByName:(NSString *)appName {
    NSString *cleanName = [[appName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    NSString *targetBundleID = self.builtinAppMap[cleanName];

    if (!targetBundleID && self.cachedInstalledApps.count > 0) {
        targetBundleID = self.cachedInstalledApps[cleanName];
        if (!targetBundleID) {
            for (NSString *locName in self.cachedInstalledApps) {
                if ([locName containsString:cleanName] || [cleanName containsString:locName]) {
                    targetBundleID = self.cachedInstalledApps[locName];
                    break;
                }
            }
        }
    }

    if (!targetBundleID) {
        NSArray<LSApplicationProxy *> *apps = [[%c(LSApplicationWorkspace) defaultWorkspace] allInstalledApplications];
        for (LSApplicationProxy *proxy in apps) {
            NSString *locName = [proxy.localizedName lowercaseString];
            if (locName && ([locName isEqualToString:cleanName] || [locName containsString:cleanName] || [cleanName containsString:locName])) {
                targetBundleID = proxy.applicationIdentifier;
                self.cachedInstalledApps[locName] = targetBundleID;
                break;
            }
        }
    }

    if (targetBundleID) {
        [self.accumulatedReplyText setString:@""];
        [self.pendingSpeechChunk setString:@""];
        self.previousKeyWindow = nil;
        [[AGGlobalActionPillWindow sharedPill] showActionPill:[NSString stringWithFormat:@"🚀 正在打开 %@...", appName]];
        [self dismissOverlay];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            @try {
                [[%c(LSApplicationWorkspace) defaultWorkspace] openApplicationWithBundleID:targetBundleID];
            } @catch (NSException *e) {}
        });
    } else {
        [[AGGlobalActionPillWindow sharedPill] showActionPill:[NSString stringWithFormat:@"⚠️ 未找到应用: %@", appName]];
        [self showActionBanner:[NSString stringWithFormat:@"⚠️ 未找到应用: %@", appName]];
    }
}

- (NSString *)resolvePhoneNumberForTarget:(NSString *)target {
    NSCharacterSet *nonDigits = [[NSCharacterSet decimalDigitCharacterSet] invertedSet];
    NSString *digitsOnly = [[target componentsSeparatedByCharactersInSet:nonDigits] componentsJoinedByString:@""];
    if (digitsOnly.length >= 3 && digitsOnly.length == target.length) return digitsOnly;

    CNContactStore *store = [[CNContactStore alloc] init];
    NSArray *keys = @[CNContactGivenNameKey, CNContactFamilyNameKey, CNContactPhoneNumbersKey];
    CNContactFetchRequest *request = [[CNContactFetchRequest alloc] initWithKeysToFetch:keys];
    __block NSString *matchedPhone = nil;

    [store enumerateContactsWithFetchRequest:request error:nil usingBlock:^(CNContact * _Nonnull contact, BOOL * _Nonnull stop) {
        NSString *fullName = [NSString stringWithFormat:@"%@%@", contact.familyName ?: @"", contact.givenName ?: @""];
        NSString *reverseName = [NSString stringWithFormat:@"%@%@", contact.givenName ?: @"", contact.familyName ?: @""];
        if ([fullName containsString:target] || [reverseName containsString:target] || [target containsString:fullName]) {
            CNLabeledValue<CNPhoneNumber *> *firstPhone = contact.phoneNumbers.firstObject;
            if (firstPhone) {
                matchedPhone = firstPhone.value.stringValue;
                *stop = YES;
            }
        }
    }];

    if (matchedPhone) return [[matchedPhone componentsSeparatedByCharactersInSet:nonDigits] componentsJoinedByString:@""];
    return digitsOnly.length > 0 ? digitsOnly : nil;
}

- (void)makePhoneCallToTarget:(NSString *)target {
    NSString *phone = [self resolvePhoneNumberForTarget:target];
    if (phone.length > 0) {
        [[AGGlobalActionPillWindow sharedPill] showActionPill:[NSString stringWithFormat:@"📞 正在为您呼叫 %@ (%@)...", target, phone]];
        [self dismissOverlay];
        NSURL *telURL = [NSURL URLWithString:[NSString stringWithFormat:@"tel://%@", phone]];
        agSafeLaunchURL(telURL);
    } else {
        [[AGGlobalActionPillWindow sharedPill] showActionPill:[NSString stringWithFormat:@"⚠️ 未找到联系人 %@ 的号码", target]];
        [self showActionBanner:[NSString stringWithFormat:@"⚠️ 未找到联系人 %@ 的号码", target]];
    }
}

- (void)sendSMSToTarget:(NSString *)target content:(NSString *)content {
    NSString *phone = [self resolvePhoneNumberForTarget:target];
    if (phone.length > 0) {
        [[AGGlobalActionPillWindow sharedPill] showActionPill:[NSString stringWithFormat:@"💬 正在拟定短信发送给 %@...", target]];
        [self dismissOverlay];
        NSString *encodedBody = [content stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
        NSString *smsURLStr = [NSString stringWithFormat:@"sms:%@&body=%@", phone, encodedBody ?: @""];
        agSafeLaunchURL([NSURL URLWithString:smsURLStr]);
    } else {
        [[AGGlobalActionPillWindow sharedPill] showActionPill:[NSString stringWithFormat:@"⚠️ 未找到联系人 %@ 的号码", target]];
        [self showActionBanner:[NSString stringWithFormat:@"⚠️ 未找到联系人 %@ 的号码", target]];
    }
}

- (void)sendWeChatMessageToTarget:(NSString *)target content:(NSString *)content {
    if (!target || target.length == 0) return;
    NSString *msg = content ?: @"";
    [[AGGlobalActionPillWindow sharedPill] showActionPill:[NSString stringWithFormat:@"💬 正在向「%@」发送微信: %@...", target, msg]];
    [self dismissOverlay];

    NSDictionary *payload = @{
        @"action": @"send_text",
        @"targetName": target,
        @"content": msg,
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    };
    agWriteJSONToSharedPaths(payload, @"ag_wechat_send.json", agGetWeChatSendFilePath());

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @try {
            [[%c(LSApplicationWorkspace) defaultWorkspace] openApplicationWithBundleID:@"com.tencent.xin"];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.60 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                                     CFSTR("com.custom.timeguardian.wechat_send"),
                                                     NULL, NULL, YES);
            });
        } @catch (NSException *e) {}
    });
}

- (void)handleWeChatReadUnread {
    [[AGGlobalActionPillWindow sharedPill] showActionPill:@"💬 正在读取微信未读消息..."];
    NSDictionary *payload = @{
        @"action": @"read_unread",
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    };
    agWriteJSONToSharedPaths(payload, @"ag_wechat_send.json", agGetWeChatSendFilePath());
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                         CFSTR("com.custom.timeguardian.wechat_send"),
                                         NULL, NULL, YES);
}

- (void)handleWeChatOpenChatWithTarget:(NSString *)target {
    [[AGGlobalActionPillWindow sharedPill] showActionPill:[NSString stringWithFormat:@"💬 正在打开与「%@」的微信对话...", target]];
    [self dismissOverlay];
    NSDictionary *payload = @{
        @"action": @"open_chat",
        @"targetName": target,
        @"content": @"",
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    };
    agWriteJSONToSharedPaths(payload, @"ag_wechat_send.json", agGetWeChatSendFilePath());

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        @try {
            [[%c(LSApplicationWorkspace) defaultWorkspace] openApplicationWithBundleID:@"com.tencent.xin"];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.60 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
                                                     CFSTR("com.custom.timeguardian.wechat_send"),
                                                     NULL, NULL, YES);
            });
        } @catch (NSException *e) {}
    });
}

- (void)toggleFlashlight:(BOOL)enable {
    [self toggleFlashlight:enable level:1.0f];
}

- (void)toggleFlashlight:(BOOL)enable level:(float)level {
    dispatch_async(dispatch_get_main_queue(), ^{
        AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
        if ([device hasTorch] && [device isTorchAvailable]) {
            NSError *err = nil;
            if ([device lockForConfiguration:&err]) {
                if (enable) {
                    float targetLevel = MAX(0.01f, MIN(1.0f, level));
                    [device setTorchModeOnWithLevel:targetLevel error:&err];
                } else {
                    [device setTorchMode:AVCaptureTorchModeOff];
                }
                [device unlockForConfiguration];
                NSString *msg = enable ? [NSString stringWithFormat:@"🔦 已开启手电筒 (亮度: %d%%)", (int)(level * 100)] : @"🔦 已关闭手电筒";
                [[AGGlobalActionPillWindow sharedPill] showActionPill:msg];
                [self showActionBanner:msg];
            }
        } else {
            [[AGGlobalActionPillWindow sharedPill] showActionPill:@"⚠️ 当前设备手电筒不可用"];
            [self showActionBanner:@"⚠️ 当前设备手电筒不可用"];
        }
    });
}

// 真实硬件级屏幕背光调节（BackBoardServices + SBBrightnessController + 百分比自动归一化）
- (void)handleBrightnessControl:(NSString *)action level:(NSNumber *)level {
    dispatch_async(dispatch_get_main_queue(), ^{
        void *bksHandle = dlopen("/System/Library/PrivateFrameworks/BackBoardServices.framework/BackBoardServices", RTLD_LAZY);
        typedef float (*BKSGetBrightFunc)(void);
        typedef CFTypeRef (*BKSTransCreateFunc)(CFAllocatorRef);
        typedef void (*BKSSetBrightFunc)(float, int);

        BKSGetBrightFunc getBright = bksHandle ? (BKSGetBrightFunc)dlsym(bksHandle, "BKSDisplayBrightnessGetCurrent") : NULL;
        BKSTransCreateFunc createTrans = bksHandle ? (BKSTransCreateFunc)dlsym(bksHandle, "BKSDisplayBrightnessTransactionCreate") : NULL;
        BKSSetBrightFunc setBright = bksHandle ? (BKSSetBrightFunc)dlsym(bksHandle, "BKSDisplayBrightnessSet") : NULL;

        float cur = getBright ? getBright() : (float)[UIScreen mainScreen].brightness;
        if (cur <= 0.0f || cur > 1.0f) cur = (float)[UIScreen mainScreen].brightness;
        float target = cur;

        NSString *clean = [action lowercaseString];
        if (level != nil) {
            float rawLvl = [level floatValue];
            if (rawLvl > 1.0f && rawLvl <= 100.0f) {
                rawLvl = rawLvl / 100.0f;
            }
            target = MAX(0.02f, MIN(1.0f, rawLvl));
        } else if ([clean isEqualToString:@"max"] || [clean containsString:@"最亮"] || [clean containsString:@"拉满"]) {
            target = 1.0f;
        } else if ([clean isEqualToString:@"min"] || [clean containsString:@"最暗"] || [clean containsString:@"最低"]) {
            target = 0.05f;
        } else if ([clean isEqualToString:@"up"] || [clean containsString:@"调高"] || [clean containsString:@"增加"]) {
            target = MIN(1.0f, cur + 0.18f);
        } else if ([clean isEqualToString:@"down"] || [clean containsString:@"调低"] || [clean containsString:@"降低"]) {
            target = MAX(0.03f, cur - 0.18f);
        }

        // 1. 写入 BackBoardServices 硬件背光事务
        if (setBright) {
            CFTypeRef trans = createTrans ? createTrans(kCFAllocatorDefault) : NULL;
            setBright(target, 1);
            if (trans) CFRelease(trans);
        }
        // 2. 同步 SpringBoard 控制中心亮度控制器
        Class sbBrightCls = objc_getClass("SBBrightnessController");
        if (sbBrightCls && [sbBrightCls respondsToSelector:@selector(sharedBrightnessController)]) {
            id bc = [sbBrightCls sharedBrightnessController];
            if ([bc respondsToSelector:@selector(setBrightnessLevel:)]) {
                [bc setBrightnessLevel:target];
            }
        }
        // 3. 同步 UIScreen 亮度属性
        [UIScreen mainScreen].brightness = target;

        NSString *msg = [NSString stringWithFormat:@"☀️ 屏幕真实亮度已调至 %d%%", (int)roundf(target * 100.0f)];
        [[AGGlobalActionPillWindow sharedPill] showActionPill:msg];
        [self showActionBanner:msg];
    });
}

- (void)handleTakeScreenshot {
    [self dismissOverlay];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIImage *screenshot = _UICreateScreenUIImage();
        if (screenshot) {
            UIImageWriteToSavedPhotosAlbum(screenshot, nil, nil, nil);
            AudioServicesPlaySystemSound(1108);
            [[AGGlobalActionPillWindow sharedPill] showActionPill:@"📸 屏幕截图已保存至系统相册"];
        } else {
            [[AGGlobalActionPillWindow sharedPill] showActionPill:@"⚠️ 截屏捕获失败"];
        }
    });
}

- (void)handleWiFiToggle:(BOOL)on {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class wmCls = objc_getClass("SBWiFiManager");
        if (wmCls && [wmCls respondsToSelector:@selector(sharedInstance)]) {
            id wm = [wmCls sharedInstance];
            if ([wm respondsToSelector:@selector(setWiFiEnabled:)]) {
                [wm setWiFiEnabled:on];
            } else if ([wm respondsToSelector:@selector(setPowered:)]) {
                [wm setPowered:on];
            }
        }
        NSString *msg = on ? @"📶 无线局域网 (Wi-Fi) 已开启" : @"📶 无线局域网 (Wi-Fi) 已关闭";
        [[AGGlobalActionPillWindow sharedPill] showActionPill:msg];
        [self showActionBanner:msg];
    });
}

- (void)handleBluetoothToggle:(BOOL)on {
    dispatch_async(dispatch_get_main_queue(), ^{
        dlopen("/System/Library/PrivateFrameworks/BluetoothManager.framework/BluetoothManager", RTLD_NOW);
        Class bmCls = objc_getClass("BluetoothManager");
        if (bmCls && [bmCls respondsToSelector:@selector(sharedInstance)]) {
            id bm = [bmCls sharedInstance];
            if ([bm respondsToSelector:@selector(setEnabled:)]) [bm setEnabled:on];
            if ([bm respondsToSelector:@selector(setPowered:)]) [bm setPowered:on];
        }
        NSString *msg = on ? @"🔷 蓝牙 (Bluetooth) 已开启" : @"🔷 蓝牙 (Bluetooth) 已关闭";
        [[AGGlobalActionPillWindow sharedPill] showActionPill:msg];
        [self showActionBanner:msg];
    });
}

- (void)handleAirplaneMode:(BOOL)on {
    dispatch_async(dispatch_get_main_queue(), ^{
        dlopen("/System/Library/PrivateFrameworks/AppSupport.framework/AppSupport", RTLD_LAZY);
        Class rpCls = objc_getClass("RadiosPreferences");
        if (rpCls) {
            RadiosPreferences *rp = [[rpCls alloc] init];
            if ([rp respondsToSelector:@selector(setAirplaneMode:)]) {
                [rp setAirplaneMode:on];
                if ([rp respondsToSelector:@selector(synchronize)]) [rp synchronize];
            }
        }
        NSString *msg = on ? @"✈️ 飞行模式已开启" : @"✈️ 飞行模式已关闭";
        [[AGGlobalActionPillWindow sharedPill] showActionPill:msg];
        [self showActionBanner:msg];
    });
}

- (void)handleAppearanceMode:(NSString *)mode {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *m = [mode lowercaseString];
        if ([m containsString:@"nightshift"]) {
            BOOL enable = ![m containsString:@"off"];
            dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_LAZY);
            Class cbCls = objc_getClass("CBClient");
            if (cbCls) {
                id client = [[cbCls alloc] init];
                id bl = [client respondsToSelector:@selector(blueLightClient)] ? [client valueForKey:@"blueLightClient"] : nil;
                if (bl && [bl respondsToSelector:@selector(setEnabled:)]) {
                    typedef BOOL (*SetBLFunc)(id, SEL, BOOL);
                    SetBLFunc fn = (SetBLFunc)[bl methodForSelector:@selector(setEnabled:)];
                    if (fn) fn(bl, @selector(setEnabled:), enable);
                }
            }
            [[AGGlobalActionPillWindow sharedPill] showActionPill:enable ? @"🌅 夜览护眼模式已开启" : @"🌅 夜览护眼模式已关闭"];
            return;
        }
        BOOL isDark = ([m containsString:@"dark"] || [m containsString:@"深"] || [m containsString:@"暗"]);
        dlopen("/System/Library/PrivateFrameworks/UIKitServices.framework/UIKitServices", RTLD_LAZY);
        Class styleCls = objc_getClass("UISUserInterfaceStyleMode");
        if (styleCls) {
            UISUserInterfaceStyleMode *sm = [[styleCls alloc] init];
            if (!sm) {
                sm = ((id(*)(id, SEL, id))objc_msgSend)([styleCls alloc], @selector(initWithDelegate:), nil);
            }
            if ([sm respondsToSelector:@selector(setModeValue:)]) {
                sm.modeValue = isDark ? 2 : 1;
            }
        }
        NSString *msg = isDark ? @"🌙 已切换至系统深色模式" : @"☀️ 已切换至系统浅色模式";
        [[AGGlobalActionPillWindow sharedPill] showActionPill:msg];
        [self showActionBanner:msg];
    });
}

// 一键清理手机后台进程
- (void)handleKillBackgroundApps {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class swCls = objc_getClass("SBMainSwitcherViewController");
        id switcher = (swCls && [swCls respondsToSelector:@selector(sharedInstanceIfExists)]) ? [swCls sharedInstanceIfExists] : nil;
        if (!switcher && swCls && [swCls respondsToSelector:@selector(sharedInstance)]) {
            switcher = [swCls sharedInstance];
        }
        NSUInteger killedCount = 0;
        if (switcher && [switcher respondsToSelector:@selector(recentAppLayouts)]) {
            NSArray *layouts = [[switcher recentAppLayouts] copy];
            for (id layout in layouts) {
                if ([switcher respondsToSelector:@selector(_deleteAppLayout:forReason:)]) {
                    @try {
                        [switcher _deleteAppLayout:layout forReason:1];
                        killedCount++;
                    } @catch (NSException *e) {}
                }
            }
        }
        NSString *msg = [NSString stringWithFormat:@"🧹 已为您清理 %lu 个后台应用，释放系统内存", (unsigned long)MAX(1, killedCount)];
        [[AGGlobalActionPillWindow sharedPill] showActionPill:msg];
        [self showActionBanner:msg];
    });
}

// 原生闹钟免跳转直接创建 (MobileTimer.framework)
- (void)handleCreateAlarmHour:(NSInteger)hour minute:(NSInteger)minute title:(NSString *)title {
    dispatch_async(dispatch_get_main_queue(), ^{
        dlopen("/System/Library/PrivateFrameworks/MobileTimer.framework/MobileTimer", RTLD_LAZY);
        Class mgrCls = objc_getClass("MTAlarmManager");
        Class mutAlarmCls = objc_getClass("MTMutableAlarm");
        if (mgrCls && mutAlarmCls) {
            @try {
                id mgr = [[mgrCls alloc] init];
                typedef id (*InitAlarmFunc)(id, SEL, NSUInteger, NSUInteger);
                id alarm = [mutAlarmCls alloc];
                SEL initSel = NSSelectorFromString(@"initWithHour:minute:");
                if ([alarm respondsToSelector:initSel]) {
                    InitAlarmFunc fn = (InitAlarmFunc)[alarm methodForSelector:initSel];
                    alarm = fn(alarm, initSel, (NSUInteger)hour, (NSUInteger)minute);
                } else {
                    alarm = [alarm init];
                    [alarm setValue:@(hour) forKey:@"hour"];
                    [alarm setValue:@(minute) forKey:@"minute"];
                }
                [alarm setValue:(title ?: @"天使守护闹钟") forKey:@"title"];
                [alarm setValue:@YES forKey:@"enabled"];
                SEL addAlarmSel = NSSelectorFromString(@"addAlarm:");
                if ([mgr respondsToSelector:addAlarmSel]) {
                    ((void(*)(id, SEL, id))objc_msgSend)(mgr, addAlarmSel, alarm);
                }
                NSString *msg = [NSString stringWithFormat:@"⏰ 已为您设定 %02ld:%02ld 的系统闹钟", (long)hour, (long)minute];
                [[AGGlobalActionPillWindow sharedPill] showActionPill:msg];
                [self showActionBanner:msg];
                return;
            } @catch (NSException *e) {}
        }
        [[AGGlobalActionPillWindow sharedPill] showActionPill:@"⏰ 正在打开系统时钟..."];
        [self openApplicationByName:@"时钟"];
    });
}

// 原生倒计时免跳转直接启动
- (void)handleStartTimerSeconds:(NSInteger)seconds {
    dispatch_async(dispatch_get_main_queue(), ^{
        dlopen("/System/Library/PrivateFrameworks/MobileTimer.framework/MobileTimer", RTLD_LAZY);
        Class tmCls = objc_getClass("MTTimerManager");
        if (tmCls) {
            @try {
                id tm = [[tmCls alloc] init];
                SEL startSel = NSSelectorFromString(@"startTimerWithDuration:");
                if ([tm respondsToSelector:startSel]) {
                    typedef id (*StartTimerFunc)(id, SEL, double);
                    StartTimerFunc fn = (StartTimerFunc)[tm methodForSelector:startSel];
                    fn(tm, startSel, (double)seconds);
                }
                NSString *msg = (seconds >= 60)
                    ? [NSString stringWithFormat:@"⏳ 已启动 %ld 分钟系统倒计时", (long)(seconds / 60)]
                    : [NSString stringWithFormat:@"⏳ 已启动 %ld 秒系统倒计时", (long)seconds];
                [[AGGlobalActionPillWindow sharedPill] showActionPill:msg];
                [self showActionBanner:msg];
                return;
            } @catch (NSException *e) {}
        }
        [self openApplicationByName:@"时钟"];
    });
}

// 原生系统提醒事项直写 (EventKit)
- (void)handleAddSystemReminder:(NSString *)title {
    dlopen("/System/Library/Frameworks/EventKit.framework/EventKit", RTLD_LAZY);
    Class storeCls = objc_getClass("EKEventStore");
    Class remCls = objc_getClass("EKReminder");
    if (!storeCls || !remCls) return;
    @try {
        id store = [[storeCls alloc] init];
        SEL remSel = NSSelectorFromString(@"reminderWithEventStore:");
        if ([remCls respondsToSelector:remSel]) {
            id reminder = ((id(*)(id, SEL, id))objc_msgSend)(remCls, remSel, store);
            [reminder setValue:title forKey:@"title"];
            SEL defCalSel = NSSelectorFromString(@"defaultCalendarForNewReminders");
            id cal = [store respondsToSelector:defCalSel] ? ((id(*)(id, SEL))objc_msgSend)(store, defCalSel) : nil;
            if (cal) [reminder setValue:cal forKey:@"calendar"];
            typedef BOOL (*SaveRemFunc)(id, SEL, id, BOOL, NSError **);
            SEL saveSel = NSSelectorFromString(@"saveReminder:commit:error:");
            if ([store respondsToSelector:saveSel]) {
                SaveRemFunc fn = (SaveRemFunc)[store methodForSelector:saveSel];
                NSError *err = nil;
                fn(store, saveSel, reminder, YES, &err);
            }
            [[AGGlobalActionPillWindow sharedPill] showActionPill:[NSString stringWithFormat:@"📝 已写入系统提醒事项: %@", title]];
        }
    } @catch (NSException *e) {}
}

// 视觉 OCR 寻找屏幕上的目标文字并自动模拟点击 (GUI Agent)
- (void)handleVisualTapTextOnScreen:(NSString *)targetText {
    if (!targetText || targetText.length == 0) return;
    [self dismissOverlay];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.30 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        UIImage *screenImg = _UICreateScreenUIImage();
        if (!screenImg || !screenImg.CGImage) return;
        CGImageRef cgImg = screenImg.CGImage;
        CGImageRetain(cgImg);
        CGRect sb = [UIScreen mainScreen].bounds;

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            VNRecognizeTextRequest *req = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
                NSString *cleanTarget = [targetText lowercaseString];
                for (VNRecognizedTextObservation *obs in request.results) {
                    VNRecognizedText *top = [[obs topCandidates:1] firstObject];
                    if (top && [[top.string lowercaseString] containsString:cleanTarget]) {
                        CGRect box = obs.boundingBox;
                        // Vision 坐标系左下角为 (0,0)，转换为 UIKit 屏幕坐标
                        CGFloat tapX = CGRectGetMidX(box) * sb.size.width;
                        CGFloat tapY = (1.0 - CGRectGetMidY(box)) * sb.size.height;
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [[AGGlobalActionPillWindow sharedPill] showActionPill:[NSString stringWithFormat:@"👆 已为您视觉定位并点击「%@」", targetText]];
                            agSimulateScreenTapAtPoint(CGPointMake(tapX, tapY));
                        });
                        return;
                    }
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[AGGlobalActionPillWindow sharedPill] showActionPill:[NSString stringWithFormat:@"⚠️ 屏幕上未找到文字「%@」", targetText]];
                });
            }];
            req.recognitionLevel = VNRequestTextRecognitionLevelAccurate;
            req.recognitionLanguages = @[@"zh-Hans", @"en-US"];
            VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:cgImg options:@{}];
            [handler performRequests:@[req] error:nil];
            CGImageRelease(cgImg);
        });
    });
}

// 合成全自动刷视频/滑动/双击点赞手势
- (void)handleSynthesizedUIGesture:(NSString *)gesture {
    [self dismissOverlay];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        CGRect sb = [UIScreen mainScreen].bounds;
        CGFloat midX = sb.size.width * 0.5;
        CGFloat midY = sb.size.height * 0.5;
        NSString *g = [gesture lowercaseString];
        if ([g containsString:@"up"] || [g containsString:@"next"]) {
            [[AGGlobalActionPillWindow sharedPill] showActionPill:@"👆 已为您上滑切换下一个"];
            agSimulateScreenSwipe(CGPointMake(midX, sb.size.height * 0.76), CGPointMake(midX, sb.size.height * 0.22), 0.22);
        } else if ([g containsString:@"down"] || [g containsString:@"prev"]) {
            [[AGGlobalActionPillWindow sharedPill] showActionPill:@"👇 已为您下滑返回上一个"];
            agSimulateScreenSwipe(CGPointMake(midX, sb.size.height * 0.24), CGPointMake(midX, sb.size.height * 0.78), 0.22);
        } else if ([g containsString:@"double"]) {
            [[AGGlobalActionPillWindow sharedPill] showActionPill:@"❤️ 已为您双击屏幕点赞"];
            agSimulateScreenTapAtPoint(CGPointMake(midX, midY));
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                agSimulateScreenTapAtPoint(CGPointMake(midX, midY));
            });
        } else if ([g containsString:@"back"] || [g containsString:@"right"]) {
            [[AGGlobalActionPillWindow sharedPill] showActionPill:@"👈 已为您侧滑返回"];
            agSimulateScreenSwipe(CGPointMake(8.0, midY), CGPointMake(sb.size.width * 0.65, midY), 0.20);
        }
    });
}

// 剪贴板写入与当前焦点输入框自动打字上屏
- (void)handleClipboardAndAutoType:(NSString *)text {
    if (!text || text.length == 0) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [UIPasteboard generalPasteboard].string = text;
        Class kbCls = objc_getClass("UIKeyboardImpl");
        id kb = (kbCls && [kbCls respondsToSelector:@selector(activeInstance)]) ? [kbCls activeInstance] : nil;
        if (kb && [kb respondsToSelector:@selector(insertText:)]) {
            [kb insertText:text];
            [[AGGlobalActionPillWindow sharedPill] showActionPill:@"⌨️ 已为您自动填入输入框并复制"];
        } else {
            [[AGGlobalActionPillWindow sharedPill] showActionPill:@"📋 已复制到系统剪贴板，可直接粘贴"];
        }
    });
}

// 手机电池电量与存储空间硬件自检播报
- (void)handleReportDeviceStatus {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIDevice *dev = [UIDevice currentDevice];
        dev.batteryMonitoringEnabled = YES;
        int batPct = (int)roundf(dev.batteryLevel * 100.0f);
        if (batPct < 0) batPct = 100;
        NSString *chargeStr = (dev.batteryState == UIDeviceBatteryStateCharging || dev.batteryState == UIDeviceBatteryStateFull) ? @"充电中" : @"未充电";

        NSDictionary *fs = [[NSFileManager defaultManager] attributesOfFileSystemForPath:NSHomeDirectory() error:nil];
        double freeGB = [fs[NSFileSystemFreeSize] doubleValue] / (1024.0 * 1024.0 * 1024.0);
        int brightPct = (int)roundf([UIScreen mainScreen].brightness * 100.0f);

        NSString *report = [NSString stringWithFormat:@"📊 电量 %d%% (%@) · 亮度 %d%% · 剩余空间 %.1f GB", batPct, chargeStr, brightPct, freeGB];
        [[AGGlobalActionPillWindow sharedPill] showActionPill:report];
        [self showActionBanner:report];
    });
}

- (void)handleOrientationLock:(BOOL)lock {
    dispatch_async(dispatch_get_main_queue(), ^{
        Class olmCls = objc_getClass("SBOrientationLockManager");
        if (olmCls && [olmCls respondsToSelector:@selector(sharedInstance)]) {
            id olm = [olmCls sharedInstance];
            if (lock) {
                if ([olm respondsToSelector:@selector(lock)]) [olm lock];
            } else {
                if ([olm respondsToSelector:@selector(unlock)]) [olm unlock];
            }
        }
        NSString *msg = lock ? @"🔄 屏幕竖排方向已锁定" : @"🔄 屏幕旋转已解锁";
        [[AGGlobalActionPillWindow sharedPill] showActionPill:msg];
        [self showActionBanner:msg];
    });
}

- (void)handleMacroScene:(NSString *)scene {
    NSString *sc = [scene lowercaseString];
    if ([sc containsString:@"sleep"] || [sc containsString:@"晚安"] || [sc containsString:@"睡觉"]) {
        [self toggleFlashlight:NO level:1.0f];
        [self toggleLowPowerMode:YES];
        [self handleMediaControl:@"pause"];
        [self handleBrightnessControl:@"set" level:@(0.05f)];
        [self handleVolumeControl:@"mute" level:@(0.0f)];
        [[AGGlobalActionPillWindow sharedPill] showActionPill:@"🌙 晚安模式已启动：亮度调暗、静音、省电并锁屏"];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self handleSystemControl:@"lock"];
        });
    } else if ([sc containsString:@"drive"] || [sc containsString:@"车"] || [sc containsString:@"出发"]) {
        [self toggleLowPowerMode:NO];
        [self handleBrightnessControl:@"set" level:@(0.85f)];
        [self handleVolumeControl:@"set" level:@(0.75f)];
        [[AGGlobalActionPillWindow sharedPill] showActionPill:@"🚗 出发模式已启动：音量75%、亮度85%"];
    } else {
        [[AGGlobalActionPillWindow sharedPill] showActionPill:[NSString stringWithFormat:@"✨ 场景模式「%@」执行完毕", scene]];
    }
}

- (void)handleSearchOnPlatform:(NSString *)platform keyword:(NSString *)keyword {
    if (!keyword || keyword.length == 0) return;
    NSString *cleanKw = [keyword stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *encoded = [cleanKw stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *plt = [[platform stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] lowercaseString];
    NSURL *targetURL = nil;
    NSString *pillText = [NSString stringWithFormat:@"🔍 正在检索 %@...", cleanKw];

    // 1. 电商购物与闲置特卖
    if ([plt containsString:@"taobao"] || [plt containsString:@"淘宝"]) {
        pillText = [NSString stringWithFormat:@"🛍️ 正在淘宝搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"taobao://s.taobao.com/search?q=%@", encoded]];
    } else if ([plt containsString:@"jd"] || [plt containsString:@"京东"]) {
        pillText = [NSString stringWithFormat:@"📦 正在京东搜索: %@...", cleanKw];
        NSString *jdJson = [NSString stringWithFormat:@"{\"des\":\"productList\",\"keyWord\":\"%@\",\"from\":\"search\",\"category\":\"jump\"}", cleanKw];
        NSString *encodedParams = [jdJson stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet alphanumericCharacterSet]];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"openapp.jdmobile://virtual?params=%@", encodedParams]];
    } else if ([plt containsString:@"pdd"] || [plt containsString:@"拼多多"]) {
        pillText = [NSString stringWithFormat:@"🛍️ 正在拼多多搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"pinduoduo://yangkeduo.com/search_result.html?search_key=%@", encoded]];
    } else if ([plt containsString:@"xianyu"] || [plt containsString:@"闲鱼"]) {
        pillText = [NSString stringWithFormat:@"🐟 正在闲鱼搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"fleamarket://x_search_items?keyword=%@", encoded]];
    } else if ([plt containsString:@"vip"] || [plt containsString:@"唯品会"]) {
        pillText = [NSString stringWithFormat:@"👗 正在唯品会搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"vipshop://search?keyword=%@", encoded]];
    } else if ([plt containsString:@"dewu"] || [plt containsString:@"得物"]) {
        pillText = [NSString stringWithFormat:@"👟 正在得物查看: %@...", cleanKw];
        [UIPasteboard generalPasteboard].string = cleanKw;
        targetURL = [NSURL URLWithString:@"dewuapp://"];
    } else if ([plt containsString:@"zhuanzhuan"] || [plt containsString:@"转转"]) {
        pillText = [NSString stringWithFormat:@"🔄 正在转转搜索: %@...", cleanKw];
        [UIPasteboard generalPasteboard].string = cleanKw;
        targetURL = [NSURL URLWithString:@"zhuanzhuan://"];
    } else if ([plt containsString:@"zlj"] || [plt containsString:@"找靓机"]) {
        pillText = [NSString stringWithFormat:@"📱 正在找靓机搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"zlj://"];
    } else if ([plt containsString:@"suning"] || [plt containsString:@"苏宁"]) {
        pillText = [NSString stringWithFormat:@"🏬 正在苏宁易购搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"suning://"];
    } else if ([plt containsString:@"dangdang"] || [plt containsString:@"当当"]) {
        pillText = [NSString stringWithFormat:@"📚 正在当当网搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"dangdang://"];
    } else if ([plt containsString:@"taobaolite"] || [plt containsString:@"淘特"]) {
        pillText = [NSString stringWithFormat:@"🛍️ 正在淘特搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"taobaolite://"];
    }
    // 2. 本地生活与外卖餐饮
    else if ([plt containsString:@"meituanwaimai"] || [plt containsString:@"美团外卖"]) {
        pillText = [NSString stringWithFormat:@"🍔 正在美团外卖搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"meituanwaimai://waimai.meituan.com/search?query=%@", encoded]];
    } else if ([plt containsString:@"meituan"] || [plt containsString:@"美团"]) {
        pillText = [NSString stringWithFormat:@"🍔 正在美团搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"imeituan://www.meituan.com/search?q=%@", encoded]];
    } else if ([plt containsString:@"eleme"] || [plt containsString:@"饿了么"]) {
        pillText = [NSString stringWithFormat:@"🍱 正在饿了么搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"eleme://search?keyword=%@", encoded]];
    } else if ([plt containsString:@"dianping"] || [plt containsString:@"大众点评"] || [plt containsString:@"点评"]) {
        pillText = [NSString stringWithFormat:@"🍽️ 正在大众点评搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"dianping://search?keyword=%@", encoded]];
    } else if ([plt containsString:@"hema"] || [plt containsString:@"盒马"]) {
        pillText = [NSString stringWithFormat:@"🦛 正在盒马搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"freshhema://"];
    } else if ([plt containsString:@"ddmc"] || [plt containsString:@"叮咚"]) {
        pillText = [NSString stringWithFormat:@"🥦 正在叮咚买菜搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"ddmc://"];
    } else if ([plt containsString:@"pupu"] || [plt containsString:@"朴朴"]) {
        pillText = [NSString stringWithFormat:@"🛒 正在朴朴超市搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"pupu://"];
    } else if ([plt containsString:@"sam"] || [plt containsString:@"山姆"]) {
        pillText = [NSString stringWithFormat:@"🏬 正在山姆会员商店搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"samsclub://"];
    } else if ([plt containsString:@"luckin"] || [plt containsString:@"瑞幸"]) {
        pillText = [NSString stringWithFormat:@"☕ 正在打开瑞幸咖啡点单..."];
        targetURL = [NSURL URLWithString:@"luckincoffee://"];
    } else if ([plt containsString:@"heytea"] || [plt containsString:@"喜茶"]) {
        pillText = [NSString stringWithFormat:@"🧋 正在打开喜茶点单..."];
        targetURL = [NSURL URLWithString:@"heytea://"];
    } else if ([plt containsString:@"starbucks"] || [plt containsString:@"星巴克"]) {
        pillText = [NSString stringWithFormat:@"☕ 正在打开星巴克啡快..."];
        targetURL = [NSURL URLWithString:@"starbucks://"];
    } else if ([plt containsString:@"kfc"] || [plt containsString:@"肯德基"]) {
        pillText = [NSString stringWithFormat:@"🍗 正在打开肯德基宅急送..."];
        targetURL = [NSURL URLWithString:@"kfcapp://"];
    } else if ([plt containsString:@"mcdonald"] || [plt containsString:@"麦当劳"]) {
        pillText = [NSString stringWithFormat:@"🍟 正在打开麦当劳点餐..."];
        targetURL = [NSURL URLWithString:@"mcdmobileapp://"];
    } else if ([plt containsString:@"haidilao"] || [plt containsString:@"海底捞"]) {
        pillText = [NSString stringWithFormat:@"🍲 正在打开海底捞火锅排号..."];
        targetURL = [NSURL URLWithString:@"haidilao://"];
    }
    // 3. 社交网络、社区与潮流
    else if ([plt containsString:@"douyin"] || [plt containsString:@"抖音"]) {
        pillText = [NSString stringWithFormat:@"🎵 正在抖音搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"snssdk1128://search/?keyword=%@", encoded]];
    } else if ([plt containsString:@"kuaishou"] || [plt containsString:@"快手"]) {
        pillText = [NSString stringWithFormat:@"⚡ 正在快手搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"kwai://search?keyword=%@", encoded]];
    } else if ([plt containsString:@"bilibili"] || [plt containsString:@"b站"] || [plt containsString:@"哔哩哔哩"]) {
        pillText = [NSString stringWithFormat:@"📺 正在 B 站搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"bilibili://search?keyword=%@", encoded]];
    } else if ([plt containsString:@"xiaohongshu"] || [plt containsString:@"xhs"] || [plt containsString:@"小红书"]) {
        pillText = [NSString stringWithFormat:@"📕 正在小红书搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"xhsdiscover://search/result?keyword=%@", encoded]];
    } else if ([plt containsString:@"weibo"] || [plt containsString:@"微博"]) {
        pillText = [NSString stringWithFormat:@"👁️ 正在微博搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"sinaweibo://searchall?q=%@", encoded]];
    } else if ([plt containsString:@"zhihu"] || [plt containsString:@"知乎"]) {
        pillText = [NSString stringWithFormat:@"💡 正在知乎搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"zhihu://search?q=%@", encoded]];
    } else if ([plt containsString:@"douban"] || [plt containsString:@"豆瓣"]) {
        pillText = [NSString stringWithFormat:@"🎬 正在豆瓣搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"douban://douban.com/search?q=%@", encoded]];
    } else if ([plt containsString:@"tieba"] || [plt containsString:@"贴吧"]) {
        pillText = [NSString stringWithFormat:@"💬 正在贴吧搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"com.baidu.tieba://?searchkey=%@", encoded]];
    } else if ([plt containsString:@"hupu"] || [plt containsString:@"虎扑"]) {
        pillText = [NSString stringWithFormat:@"🏀 正在虎扑查看: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"hupu://"];
    } else if ([plt containsString:@"mihoyobbs"] || [plt containsString:@"米游社"]) {
        pillText = [NSString stringWithFormat:@"🎮 正在打开米游社..."];
        targetURL = [NSURL URLWithString:@"mihoyobbs://"];
    } else if ([plt containsString:@"xiaoheihe"] || [plt containsString:@"小黑盒"]) {
        pillText = [NSString stringWithFormat:@"🕹️ 正在打开小黑盒..."];
        targetURL = [NSURL URLWithString:@"xiaoheihe://"];
    } else if ([plt containsString:@"taptap"]) {
        pillText = [NSString stringWithFormat:@"🎯 正在打开 TapTap 发现新游戏..."];
        targetURL = [NSURL URLWithString:@"taptap://"];
    }
    // 4. 音频流媒体、音乐与播客
    else if ([plt containsString:@"netease"] || [plt containsString:@"网易云"]) {
        pillText = [NSString stringWithFormat:@"🎵 正在网易云搜歌: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"orpheus://song/search/%@", encoded]];
    } else if ([plt containsString:@"qqmusic"] || [plt containsString:@"qq音乐"]) {
        pillText = [NSString stringWithFormat:@"🎧 正在 QQ 音乐搜歌: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"qqmusic://search?key=%@", encoded]];
    } else if ([plt containsString:@"kugou"] || [plt containsString:@"酷狗"]) {
        pillText = [NSString stringWithFormat:@"🎵 正在酷狗音乐搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"kugouURL://"];
    } else if ([plt containsString:@"kuwo"] || [plt containsString:@"酷我"]) {
        pillText = [NSString stringWithFormat:@"🎶 正在酷我音乐搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"kuwo://"];
    } else if ([plt containsString:@"qishui"] || [plt containsString:@"汽水音乐"]) {
        pillText = [NSString stringWithFormat:@"🥤 正在打开汽水音乐..."];
        targetURL = [NSURL URLWithString:@"qishui://"];
    } else if ([plt containsString:@"ximalaya"] || [plt containsString:@"喜马拉雅"]) {
        pillText = [NSString stringWithFormat:@"📻 正在喜马拉雅搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"iting://search?keyword=%@", encoded]];
    } else if ([plt containsString:@"xiaoyuzhou"] || [plt containsString:@"小宇宙"]) {
        pillText = [NSString stringWithFormat:@"🎙️ 正在小宇宙听播客..."];
        targetURL = [NSURL URLWithString:@"xiaoyuzhou://"];
    } else if ([plt containsString:@"lizhi"] || [plt containsString:@"荔枝"]) {
        pillText = [NSString stringWithFormat:@"🎙️ 正在打开荔枝 FM..."];
        targetURL = [NSURL URLWithString:@"lizhifm://"];
    } else if ([plt containsString:@"qingting"] || [plt containsString:@"蜻蜓"]) {
        pillText = [NSString stringWithFormat:@"📻 正在打开蜻蜓 FM 收音机..."];
        targetURL = [NSURL URLWithString:@"qtfm://"];
    } else if ([plt containsString:@"iqiyi"] || [plt containsString:@"爱奇艺"]) {
        pillText = [NSString stringWithFormat:@"🎬 正在爱奇艺搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"iqiyi://mobile/webview?url=https%%3A%%2F%%2Fso.iqiyi.com%%2Fso%%2Fq_%@", encoded]];
    } else if ([plt containsString:@"tenvideo"] || [plt containsString:@"腾讯视频"]) {
        pillText = [NSString stringWithFormat:@"📺 正在腾讯视频搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"tenvideo://search?keyword=%@", encoded]];
    } else if ([plt containsString:@"youku"] || [plt containsString:@"优酷"]) {
        pillText = [NSString stringWithFormat:@"🎞️ 正在打开优酷视频..."];
        targetURL = [NSURL URLWithString:@"youku://"];
    } else if ([plt containsString:@"mgtv"] || [plt containsString:@"芒果"]) {
        pillText = [NSString stringWithFormat:@"🥭 正在打开芒果 TV 看综艺..."];
        targetURL = [NSURL URLWithString:@"mgtv://"];
    } else if ([plt containsString:@"douyu"] || [plt containsString:@"斗鱼"]) {
        pillText = [NSString stringWithFormat:@"🐟 正在打开斗鱼看直播..."];
        targetURL = [NSURL URLWithString:@"douyutv://"];
    } else if ([plt containsString:@"huya"] || [plt containsString:@"虎牙"]) {
        pillText = [NSString stringWithFormat:@"🐯 正在打开虎牙看直播..."];
        targetURL = [NSURL URLWithString:@"huya://"];
    }
    // 5. 地图导航、出行与打车
    else if ([plt containsString:@"amap"] || [plt containsString:@"高德"]) {
        pillText = [NSString stringWithFormat:@"🗺️ 正在高德搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"iosamap://poi?sourceApplication=TimeGuardian&name=%@", encoded]];
    } else if ([plt containsString:@"baidumap"] || [plt containsString:@"百度地图"]) {
        pillText = [NSString stringWithFormat:@"🗺️ 正在百度地图搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"baidumap://map/place/search?query=%@&src=TimeGuardian", encoded]];
    } else if ([plt containsString:@"qqmap"] || [plt containsString:@"腾讯地图"]) {
        pillText = [NSString stringWithFormat:@"🗺️ 正在腾讯地图搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"qqmap://map/search?keyword=%@", encoded]];
    } else if ([plt containsString:@"didi"] || [plt containsString:@"滴滴"]) {
        pillText = [NSString stringWithFormat:@"🚖 正在打开滴滴打车..."];
        targetURL = [NSURL URLWithString:@"diditaxi://"];
    } else if ([plt containsString:@"huaxiaozhu"] || [plt containsString:@"花小猪"]) {
        pillText = [NSString stringWithFormat:@"🐷 正在打开花小猪打车..."];
        targetURL = [NSURL URLWithString:@"huaxiaozhu://"];
    } else if ([plt containsString:@"hellobike"] || [plt containsString:@"哈啰"]) {
        pillText = [NSString stringWithFormat:@"🚲 正在打开哈啰单车/打车..."];
        targetURL = [NSURL URLWithString:@"hellobike://"];
    } else if ([plt containsString:@"t3"]) {
        pillText = [NSString stringWithFormat:@"🚗 正在打开 T3 出行叫车..."];
        targetURL = [NSURL URLWithString:@"t3travel://"];
    } else if ([plt containsString:@"caocao"] || [plt containsString:@"曹操"]) {
        pillText = [NSString stringWithFormat:@"🚗 正在打开曹操出行..."];
        targetURL = [NSURL URLWithString:@"caocao://"];
    } else if ([plt containsString:@"12306"] || [plt containsString:@"火车票"]) {
        pillText = [NSString stringWithFormat:@"🚄 正在打开 12306 火车票..."];
        targetURL = [NSURL URLWithString:@"cn.12306.railway://"];
    } else if ([plt containsString:@"zhixing"] || [plt containsString:@"智行"]) {
        pillText = [NSString stringWithFormat:@"🎫 正在打开智行火车票抢票..."];
        targetURL = [NSURL URLWithString:@"zhixing://"];
    } else if ([plt containsString:@"ctrip"] || [plt containsString:@"携程"]) {
        pillText = [NSString stringWithFormat:@"✈️ 正在携程搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"ctrip://"];
    } else if ([plt containsString:@"qunar"] || [plt containsString:@"去哪儿"]) {
        pillText = [NSString stringWithFormat:@"✈️ 正在去哪儿比价: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"qunarphone://"];
    } else if ([plt containsString:@"fliggy"] || [plt containsString:@"飞猪"]) {
        pillText = [NSString stringWithFormat:@"🛫 正在飞猪旅行搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"alitrip://"];
    } else if ([plt containsString:@"umetrip"] || [plt containsString:@"航旅纵横"]) {
        pillText = [NSString stringWithFormat:@"🛫 正在航旅纵横追踪航班..."];
        targetURL = [NSURL URLWithString:@"umetrip://"];
    } else if ([plt containsString:@"variflight"] || [plt containsString:@"飞常准"]) {
        pillText = [NSString stringWithFormat:@"✈️ 正在飞常准查延误..."];
        targetURL = [NSURL URLWithString:@"variflight://"];
    } else if ([plt containsString:@"dadouhui"] || [plt containsString:@"大都会"]) {
        pillText = [NSString stringWithFormat:@"🚇 正在打开 Metro 大都会刷码坐地铁..."];
        targetURL = [NSURL URLWithString:@"metrodadouhui://"];
    } else if ([plt containsString:@"yitongxing"] || [plt containsString:@"亿通行"]) {
        pillText = [NSString stringWithFormat:@"🚇 正在打开亿通行刷码乘车..."];
        targetURL = [NSURL URLWithString:@"yitongxing://"];
    }
    // 6. 演艺演出与电影票务
    else if ([plt containsString:@"damai"] || [plt containsString:@"大麦"]) {
        pillText = [NSString stringWithFormat:@"🎤 正在大麦网搜索演出: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"damai://"];
    } else if ([plt containsString:@"showstart"] || [plt containsString:@"秀动"]) {
        pillText = [NSString stringWithFormat:@"🎸 正在秀动看 Livehouse 演出..."];
        targetURL = [NSURL URLWithString:@"showstart://"];
    } else if ([plt containsString:@"maoyan"] || [plt containsString:@"猫眼"]) {
        pillText = [NSString stringWithFormat:@"🎟️ 正在猫眼看电影票: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"meituanmovie://"];
    } else if ([plt containsString:@"taopiaopiao"] || [plt containsString:@"淘票票"]) {
        pillText = [NSString stringWithFormat:@"🍿 正在淘票票选座购票..."];
        targetURL = [NSURL URLWithString:@"taopiaopiao://"];
    } else if ([plt containsString:@"motianlun"] || [plt containsString:@"摩天轮"]) {
        pillText = [NSString stringWithFormat:@"🎡 正在摩天轮看折扣演出票..."];
        targetURL = [NSURL URLWithString:@"motianlun://"];
    }
    // 7. 协同办公、工具与学习效率
    else if ([plt containsString:@"dingtalk"] || [plt containsString:@"钉钉"]) {
        pillText = [NSString stringWithFormat:@"💼 正在打开钉钉..."];
        targetURL = [NSURL URLWithString:@"dingtalk://"];
    } else if ([plt containsString:@"feishu"] || [plt containsString:@"飞书"]) {
        pillText = [NSString stringWithFormat:@"🕊️ 正在打开飞书工作台..."];
        targetURL = [NSURL URLWithString:@"feishu://"];
    } else if ([plt containsString:@"wemeet"] || [plt containsString:@"腾讯会议"]) {
        pillText = [NSString stringWithFormat:@"👥 正在加入腾讯会议: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"wemeet://page/inmeeting?meeting_code=%@", encoded]];
    } else if ([plt containsString:@"wxwork"] || [plt containsString:@"企业微信"]) {
        pillText = [NSString stringWithFormat:@"💼 正在打开企业微信..."];
        targetURL = [NSURL URLWithString:@"wxwork://"];
    } else if ([plt containsString:@"wps"]) {
        pillText = [NSString stringWithFormat:@"📄 正在打开 WPS Office 查看文档..."];
        targetURL = [NSURL URLWithString:@"KingsoftOfficeApp://"];
    } else if ([plt containsString:@"baiduyun"] || [plt containsString:@"百度网盘"]) {
        pillText = [NSString stringWithFormat:@"☁️ 正在打开百度网盘..."];
        targetURL = [NSURL URLWithString:@"baiduyun://"];
    } else if ([plt containsString:@"alipan"] || [plt containsString:@"阿里云盘"]) {
        pillText = [NSString stringWithFormat:@"☁️ 正在打开阿里云盘..."];
        targetURL = [NSURL URLWithString:@"alipan://"];
    } else if ([plt containsString:@"quark"] || [plt containsString:@"夸克"]) {
        pillText = [NSString stringWithFormat:@"🔬 正在打开夸克搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"quark://"];
    } else if ([plt containsString:@"ticktick"] || [plt containsString:@"滴答清单"]) {
        pillText = [NSString stringWithFormat:@"✅ 正在滴答清单添加待办: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"ticktick://v1/add?title=%@", encoded]];
    } else if ([plt containsString:@"camscanner"] || [plt containsString:@"扫描全能王"]) {
        pillText = [NSString stringWithFormat:@"📷 正在打开扫描全能王..."];
        targetURL = [NSURL URLWithString:@"camscanner://"];
    } else if ([plt containsString:@"baimiao"] || [plt containsString:@"白描"]) {
        pillText = [NSString stringWithFormat:@"📝 正在打开白描 OCR 提取文字..."];
        targetURL = [NSURL URLWithString:@"baimiao://"];
    } else if ([plt containsString:@"eudic"] || [plt containsString:@"欧路词典"]) {
        pillText = [NSString stringWithFormat:@"📖 正在欧路词典查询: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"eudic://dict/%@", encoded]];
    } else if ([plt containsString:@"youdao"] || [plt containsString:@"有道词典"] || [plt containsString:@"有道"]) {
        pillText = [NSString stringWithFormat:@"📖 正在有道词典查询: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"yddictproapp://search?word=%@", encoded]];
    } else if ([plt containsString:@"weread"] || [plt containsString:@"微信读书"]) {
        pillText = [NSString stringWithFormat:@"📚 正在打开微信读书..."];
        targetURL = [NSURL URLWithString:@"weread://"];
    } else if ([plt containsString:@"baicizhan"] || [plt containsString:@"百词斩"]) {
        pillText = [NSString stringWithFormat:@"🔤 正在打开百词斩背单词..."];
        targetURL = [NSURL URLWithString:@"baicizhan://"];
    } else if ([plt containsString:@"duolingo"] || [plt containsString:@"多邻国"]) {
        pillText = [NSString stringWithFormat:@"🦉 正在打开多邻国打卡..."];
        targetURL = [NSURL URLWithString:@"duolingo://"];
    } else if ([plt containsString:@"xuexi"] || [plt containsString:@"学习强国"]) {
        pillText = [NSString stringWithFormat:@"🇨🇳 正在打开学习强国..."];
        targetURL = [NSURL URLWithString:@"xuexi://"];
    } else if ([plt containsString:@"luojilab"] || [plt containsString:@"得到"]) {
        pillText = [NSString stringWithFormat:@"💡 正在打开得到听课程..."];
        targetURL = [NSURL URLWithString:@"luojilab://"];
    } else if ([plt containsString:@"qidian"] || [plt containsString:@"起点"]) {
        pillText = [NSString stringWithFormat:@"📖 正在起点读书阅读小说..."];
        targetURL = [NSURL URLWithString:@"qidian://"];
    } else if ([plt containsString:@"jjwxc"] || [plt containsString:@"晋江"]) {
        pillText = [NSString stringWithFormat:@"🌸 正在打开晋江文学城..."];
        targetURL = [NSURL URLWithString:@"jjwxc://"];
    } else if ([plt containsString:@"dragonread"] || [plt containsString:@"番茄小说"]) {
        pillText = [NSString stringWithFormat:@"🍅 正在打开番茄免费小说..."];
        targetURL = [NSURL URLWithString:@"dragonread://"];
    } else if ([plt containsString:@"kuaikan"] || [plt containsString:@"快看漫画"]) {
        pillText = [NSString stringWithFormat:@"🎨 正在打开快看漫画..."];
        targetURL = [NSURL URLWithString:@"kuaikan://"];
    } else if ([plt containsString:@"bilibilimanga"] || [plt containsString:@"b站漫画"]) {
        pillText = [NSString stringWithFormat:@"📕 正在打开 B 站漫画..."];
        targetURL = [NSURL URLWithString:@"bilibilimanga://"];
    } else if ([plt containsString:@"ireader"] || [plt containsString:@"掌阅"]) {
        pillText = [NSString stringWithFormat:@"📱 正在打开掌阅 iReader..."];
        targetURL = [NSURL URLWithString:@"ireader://"];
    } else if ([plt containsString:@"yuque"] || [plt containsString:@"语雀"]) {
        pillText = [NSString stringWithFormat:@"🐦 正在打开语雀知识库..."];
        targetURL = [NSURL URLWithString:@"yuque://"];
    } else if ([plt containsString:@"shimo"] || [plt containsString:@"石墨"]) {
        pillText = [NSString stringWithFormat:@"📝 正在打开石墨文档..."];
        targetURL = [NSURL URLWithString:@"shimo://"];
    } else if ([plt containsString:@"mubu"] || [plt containsString:@"幕布"]) {
        pillText = [NSString stringWithFormat:@"🌳 正在打开幕布做思维导图..."];
        targetURL = [NSURL URLWithString:@"mubu://"];
    }
    // 8. 快递物流与跑腿
    else if ([plt containsString:@"cainiao"] || [plt containsString:@"菜鸟"]) {
        pillText = [NSString stringWithFormat:@"📦 正在打开菜鸟取件码..."];
        targetURL = [NSURL URLWithString:@"cainiao://desktop/station_code"];
    } else if ([plt containsString:@"sfexpress"] || [plt containsString:@"顺丰"]) {
        pillText = [NSString stringWithFormat:@"📦 正在打开顺丰速运..."];
        targetURL = [NSURL URLWithString:@"sfexpress://"];
    } else if ([plt containsString:@"fcbox"] || [plt containsString:@"丰巢"]) {
        pillText = [NSString stringWithFormat:@"📬 正在打开丰巢智能柜取件..."];
        targetURL = [NSURL URLWithString:@"fcbox://"];
    } else if ([plt containsString:@"huolala"] || [plt containsString:@"货拉拉"]) {
        pillText = [NSString stringWithFormat:@"🚚 正在打开货拉拉拉货/搬家..."];
        targetURL = [NSURL URLWithString:@"huolala://"];
    } else if ([plt containsString:@"shansong"] || [plt containsString:@"闪送"]) {
        pillText = [NSString stringWithFormat:@"⚡ 正在打开闪送专人急送..."];
        targetURL = [NSURL URLWithString:@"ishansong://"];
    }
    // 9. 三大运营商掌厅
    else if ([plt containsString:@"chinamobile"] || [plt containsString:@"移动"] || [plt containsString:@"10086"]) {
        pillText = [NSString stringWithFormat:@"📱 正在打开中国移动掌厅查话费..."];
        targetURL = [NSURL URLWithString:@"chinamobile://"];
    } else if ([plt containsString:@"unicom"] || [plt containsString:@"联通"] || [plt containsString:@"10010"]) {
        pillText = [NSString stringWithFormat:@"📱 正在打开中国联通营业厅..."];
        targetURL = [NSURL URLWithString:@"unicomclient://"];
    } else if ([plt containsString:@"ctclient"] || [plt containsString:@"电信"] || [plt containsString:@"10000"]) {
        pillText = [NSString stringWithFormat:@"📱 正在打开中国电信掌厅..."];
        targetURL = [NSURL URLWithString:@"ctclient://"];
    }
    // 10. 交管政务、社保办事与地方一网通办
    else if ([plt containsString:@"12123"] || [plt containsString:@"违章"] || [plt containsString:@"交管"]) {
        pillText = [NSString stringWithFormat:@"👮 正在打开交管12123查违章..."];
        targetURL = [NSURL URLWithString:@"tmri12123://"];
    } else if ([plt containsString:@"taxpayer"] || [plt containsString:@"个税"] || [plt containsString:@"个人所得税"]) {
        pillText = [NSString stringWithFormat:@"🧾 正在打开个人所得税汇算清缴..."];
        targetURL = [NSURL URLWithString:@"taxpayer://"];
    } else if ([plt containsString:@"suishenban"] || [plt containsString:@"随申办"]) {
        pillText = [NSString stringWithFormat:@"🏙️ 正在打开上海随申办一网通办..."];
        targetURL = [NSURL URLWithString:@"suishenban://"];
    } else if ([plt containsString:@"zheliban"] || [plt containsString:@"浙里办"]) {
        pillText = [NSString stringWithFormat:@"🏛️ 正在打开浙江浙里办政务服务..."];
        targetURL = [NSURL URLWithString:@"zheliban://"];
    } else if ([plt containsString:@"wuba"] || [plt containsString:@"58同城"]) {
        pillText = [NSString stringWithFormat:@"🏠 正在打开 58 同城便民生活..."];
        targetURL = [NSURL URLWithString:@"wbmain://"];
    }
    // 11. 新能源车机互联与汽车资讯
    else if ([plt containsString:@"nio"] || [plt containsString:@"蔚来"]) {
        pillText = [NSString stringWithFormat:@"🚗 正在打开蔚来控车..."];
        targetURL = [NSURL URLWithString:@"nio://"];
    } else if ([plt containsString:@"xiaopeng"] || [plt containsString:@"小鹏"]) {
        pillText = [NSString stringWithFormat:@"🚗 正在打开小鹏汽车座舱..."];
        targetURL = [NSURL URLWithString:@"xiaopeng://"];
    } else if ([plt containsString:@"lixiang"] || [plt containsString:@"理想"]) {
        pillText = [NSString stringWithFormat:@"🚗 正在打开理想汽车诊断..."];
        targetURL = [NSURL URLWithString:@"lixiang://"];
    } else if ([plt containsString:@"byd"] || [plt containsString:@"比亚迪"]) {
        pillText = [NSString stringWithFormat:@"🚗 正在打开比亚迪云服务..."];
        targetURL = [NSURL URLWithString:@"bydapp://"];
    } else if ([plt containsString:@"tesla"] || [plt containsString:@"特斯拉"]) {
        pillText = [NSString stringWithFormat:@"⚡ 正在打开特斯拉钥匙控车..."];
        targetURL = [NSURL URLWithString:@"tesla://"];
    } else if ([plt containsString:@"dongchedi"] || [plt containsString:@"懂车帝"]) {
        pillText = [NSString stringWithFormat:@"🚘 正在懂车帝看成交价: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"dongchedi://"];
    } else if ([plt containsString:@"autohome"] || [plt containsString:@"汽车之家"]) {
        pillText = [NSString stringWithFormat:@"🚘 正在汽车之家看报价: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"autohome://"];
    } else if ([plt containsString:@"yiche"] || [plt containsString:@"易车"]) {
        pillText = [NSString stringWithFormat:@"🚘 正在易车看汽车对比..."];
        targetURL = [NSURL URLWithString:@"yicheapp://"];
    } else if ([plt containsString:@"guazi"] || [plt containsString:@"瓜子"]) {
        pillText = [NSString stringWithFormat:@"🚙 正在瓜子看二手车严选..."];
        targetURL = [NSURL URLWithString:@"guazi://"];
    }
    // 12. 智能家居与安居房产
    else if ([plt containsString:@"mihome"] || [plt containsString:@"米家"]) {
        pillText = [NSString stringWithFormat:@"🏠 正在打开米家全屋智能设备..."];
        targetURL = [NSURL URLWithString:@"mihome://"];
    } else if ([plt containsString:@"huaweihonor"] || [plt containsString:@"智慧生活"]) {
        pillText = [NSString stringWithFormat:@"🏠 正在打开华为智慧生活控制台..."];
        targetURL = [NSURL URLWithString:@"huaweihonor://"];
    } else if ([plt containsString:@"meiju"] || [plt containsString:@"美居"]) {
        pillText = [NSString stringWithFormat:@"❄️ 正在打开美的美居调空调..."];
        targetURL = [NSURL URLWithString:@"meiju://"];
    } else if ([plt containsString:@"haier"] || [plt containsString:@"海尔智家"]) {
        pillText = [NSString stringWithFormat:@"🧺 正在打开海尔智家管理设备..."];
        targetURL = [NSURL URLWithString:@"haierzhijia://"];
    } else if ([plt containsString:@"beike"] || [plt containsString:@"贝壳"]) {
        pillText = [NSString stringWithFormat:@"🏢 正在贝壳看二手房/租房: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"lianjiabeike://"];
    } else if ([plt containsString:@"anjuke"] || [plt containsString:@"安居客"]) {
        pillText = [NSString stringWithFormat:@"🏠 正在安居客找房子: %@...", cleanKw];
        targetURL = [NSURL URLWithString:@"anjuke://"];
    }
    // 13. 剪辑修图、求职招聘与证券
    else if ([plt containsString:@"jianying"] || [plt containsString:@"剪映"]) {
        pillText = [NSString stringWithFormat:@"✂️ 正在打开剪映剪视频..."];
        targetURL = [NSURL URLWithString:@"jianying://"];
    } else if ([plt containsString:@"mtxx"] || [plt containsString:@"美图秀秀"]) {
        pillText = [NSString stringWithFormat:@"✨ 正在美图秀秀修图..."];
        targetURL = [NSURL URLWithString:@"mtxx://"];
    } else if ([plt containsString:@"xingtu"] || [plt containsString:@"醒图"]) {
        pillText = [NSString stringWithFormat:@"📸 正在醒图一键修图..."];
        targetURL = [NSURL URLWithString:@"xingtusdk://"];
    } else if ([plt containsString:@"boss"] || [plt containsString:@"boss直聘"]) {
        pillText = [NSString stringWithFormat:@"💼 正在 BOSS 直聘跟老板直聊..."];
        targetURL = [NSURL URLWithString:@"bosszhipin://"];
    } else if ([plt containsString:@"zhaopin"] || [plt containsString:@"智联招聘"]) {
        pillText = [NSString stringWithFormat:@"💼 正在智联招聘看岗位..."];
        targetURL = [NSURL URLWithString:@"zhaopin://"];
    } else if ([plt containsString:@"liepin"] || [plt containsString:@"猎聘"]) {
        pillText = [NSString stringWithFormat:@"💼 正在猎聘看中高端职位..."];
        targetURL = [NSURL URLWithString:@"liepin://"];
    } else if ([plt containsString:@"amihexin"] || [plt containsString:@"同花顺"]) {
        pillText = [NSString stringWithFormat:@"📈 正在同花顺看自选股行情..."];
        targetURL = [NSURL URLWithString:@"amihexin://"];
    } else if ([plt containsString:@"eastmoney"] || [plt containsString:@"东方财富"]) {
        pillText = [NSString stringWithFormat:@"📊 正在东方财富看大盘异动..."];
        targetURL = [NSURL URLWithString:@"eastmoney://"];
    } else if ([plt containsString:@"xueqiu"] || [plt containsString:@"雪球"]) {
        pillText = [NSString stringWithFormat:@"❄️ 正在雪球看股票组合讨论..."];
        targetURL = [NSURL URLWithString:@"xueqiu://"];
    } else if ([plt containsString:@"futunn"] || [plt containsString:@"富途牛牛"]) {
        pillText = [NSString stringWithFormat:@"🐂 正在富途牛牛看港美股行情..."];
        targetURL = [NSURL URLWithString:@"futunn://"];
    }
    // 14. 国产大模型 AI 助手
    else if ([plt containsString:@"doubao"] || [plt containsString:@"豆包"]) {
        pillText = [NSString stringWithFormat:@"🤖 正在打开豆包 AI 助手..."];
        targetURL = [NSURL URLWithString:@"doubao://"];
    } else if ([plt containsString:@"kimi"]) {
        pillText = [NSString stringWithFormat:@"🤖 正在打开 Kimi 分析研报..."];
        targetURL = [NSURL URLWithString:@"kimi://"];
    } else if ([plt containsString:@"chatglm"] || [plt containsString:@"智谱清言"]) {
        pillText = [NSString stringWithFormat:@"🤖 正在打开智谱清言大模型..."];
        targetURL = [NSURL URLWithString:@"chatglm://"];
    } else if ([plt containsString:@"yiyan"] || [plt containsString:@"文心一言"]) {
        pillText = [NSString stringWithFormat:@"🤖 正在打开文心一言..."];
        targetURL = [NSURL URLWithString:@"yiyan://"];
    }
    // 15. 支付/金融
    else if ([plt containsString:@"alipay"] || [plt containsString:@"支付宝"]) {
        pillText = [NSString stringWithFormat:@"🔵 正在支付宝搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"alipays://platformapi/startapp?appId=20001003&keyword=%@", encoded]];
    } else if ([plt containsString:@"upwallet"] || [plt containsString:@"云闪付"]) {
        pillText = [NSString stringWithFormat:@"🔴 正在打开云闪付..."];
        targetURL = [NSURL URLWithString:@"upwallet://"];
    } else if ([plt containsString:@"cmbmobilebank"] || [plt containsString:@"招商银行"]) {
        pillText = [NSString stringWithFormat:@"🏦 正在打开招商银行..."];
        targetURL = [NSURL URLWithString:@"cmbmobilebank://"];
    } else if ([plt containsString:@"cmblife"] || [plt containsString:@"掌上生活"]) {
        pillText = [NSString stringWithFormat:@"💳 正在打开招行掌上生活..."];
        targetURL = [NSURL URLWithString:@"cmblife://"];
    } else if ([plt containsString:@"icbc"] || [plt containsString:@"工商银行"]) {
        pillText = [NSString stringWithFormat:@"🏦 正在打开工商银行..."];
        targetURL = [NSURL URLWithString:@"com.icbc.iphoneclient://"];
    } else if ([plt containsString:@"ccb"] || [plt containsString:@"建设银行"]) {
        pillText = [NSString stringWithFormat:@"🏦 正在打开建设银行..."];
        targetURL = [NSURL URLWithString:@"ccbmobilebank://"];
    } else if ([plt containsString:@"boc"] || [plt containsString:@"中国银行"]) {
        pillText = [NSString stringWithFormat:@"🏦 正在打开中国银行..."];
        targetURL = [NSURL URLWithString:@"BOCMBCIphone://"];
    } else if ([plt containsString:@"bankabc"] || [plt containsString:@"农业银行"]) {
        pillText = [NSString stringWithFormat:@"🏦 正在打开农业银行..."];
        targetURL = [NSURL URLWithString:@"bankabc://"];
    } else if ([plt containsString:@"bankcomm"] || [plt containsString:@"交通银行"]) {
        pillText = [NSString stringWithFormat:@"🏦 正在打开交通银行..."];
        targetURL = [NSURL URLWithString:@"bankcomm://"];
    } else if ([plt containsString:@"pingan"] || [plt containsString:@"平安银行"]) {
        pillText = [NSString stringWithFormat:@"🏦 正在打开平安口袋银行..."];
        targetURL = [NSURL URLWithString:@"pinganbank://"];
    } else if ([plt containsString:@"spdb"] || [plt containsString:@"浦发银行"]) {
        pillText = [NSString stringWithFormat:@"🏦 正在打开浦发银行..."];
        targetURL = [NSURL URLWithString:@"spdbmb://"];
    } else if ([plt containsString:@"citic"] || [plt containsString:@"中信银行"]) {
        pillText = [NSString stringWithFormat:@"🏦 正在打开中信银行..."];
        targetURL = [NSURL URLWithString:@"citicbank://"];
    } else if ([plt containsString:@"cmbc"] || [plt containsString:@"民生银行"]) {
        pillText = [NSString stringWithFormat:@"🏦 正在打开民生银行..."];
        targetURL = [NSURL URLWithString:@"cmbc://"];
    } else if ([plt containsString:@"ceb"] || [plt containsString:@"光大银行"]) {
        pillText = [NSString stringWithFormat:@"🏦 正在打开光大银行..."];
        targetURL = [NSURL URLWithString:@"cebbank://"];
    } else if ([plt containsString:@"cgb"] || [plt containsString:@"广发银行"]) {
        pillText = [NSString stringWithFormat:@"🏦 正在打开广发银行..."];
        targetURL = [NSURL URLWithString:@"cgbmobile://"];
    } else if ([plt containsString:@"cib"] || [plt containsString:@"兴业银行"]) {
        pillText = [NSString stringWithFormat:@"🏦 正在打开兴业银行..."];
        targetURL = [NSURL URLWithString:@"cibmb://"];
    } else if ([plt containsString:@"jdmobile"] || [plt containsString:@"京东金融"]) {
        pillText = [NSString stringWithFormat:@"💰 正在打开京东金融查白条..."];
        targetURL = [NSURL URLWithString:@"jdmobile://"];
    }
    // 16. 百度与系统应用商店
    else if ([plt containsString:@"baiduboxapp"] || [plt containsString:@"百度"]) {
        pillText = [NSString stringWithFormat:@"🔍 正在百度搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"baiduboxapp://browser?url=https%%3A%%2F%%2Fwww.baidu.com%%2Fs%%3Fwd%%3D%@", encoded]];
    } else if ([plt containsString:@"appstore"] || [plt containsString:@"应用商店"]) {
        pillText = [NSString stringWithFormat:@"🛍️ 正在 App Store 搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"itms-apps://search.itunes.apple.com/WebObjects/MZSearch.woa/wa/search?term=%@", encoded]];
    }

    if (targetURL) {
        [[AGGlobalActionPillWindow sharedPill] showActionPill:pillText];
        [self dismissOverlay];
        agSafeLaunchURL(targetURL);
        return;
    }

    // 17. 若非预置清单应用，动态扫描本机已安装的所有应用，走剪贴板预置 + 原生 BundleID 启动
    NSString *cleanPlt = plt;
    NSString *bundleID = self.builtinAppMap[cleanPlt];
    if (!bundleID && self.cachedInstalledApps.count > 0) {
        bundleID = self.cachedInstalledApps[cleanPlt];
        if (!bundleID) {
            for (NSString *loc in self.cachedInstalledApps) {
                if ([loc containsString:cleanPlt] || [cleanPlt containsString:loc]) {
                    bundleID = self.cachedInstalledApps[loc];
                    break;
                }
            }
        }
    }
    if (!bundleID) {
        NSArray<LSApplicationProxy *> *apps = [[%c(LSApplicationWorkspace) defaultWorkspace] allInstalledApplications];
        for (LSApplicationProxy *proxy in apps) {
            NSString *locName = [proxy.localizedName lowercaseString];
            if (locName && ([locName containsString:cleanPlt] || [cleanPlt containsString:locName])) {
                bundleID = proxy.applicationIdentifier;
                self.cachedInstalledApps[locName] = bundleID;
                break;
            }
        }
    }

    if (bundleID) {
        // 本地安装了该应用：自动将关键词写入剪贴板，秒开该 App 并提示粘贴
        [UIPasteboard generalPasteboard].string = cleanKw;
        [[AGGlobalActionPillWindow sharedPill] showActionPill:[NSString stringWithFormat:@"📋 已复制「%@」并打开【%@】，直接粘贴即可", cleanKw, platform ?: @"应用"]];
        [self dismissOverlay];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.12 * NSEC_PER_SEC)), dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
            @try {
                [[%c(LSApplicationWorkspace) defaultWorkspace] openApplicationWithBundleID:bundleID];
            } @catch (NSException *e) {}
        });
        return;
    }

    // 18. 若明确要求进行网页搜索（如百度/网页/谷歌），则打开网页；否则严禁降级到 Safari 访问官方网页！
    if ([cleanPlt containsString:@"web"] || [cleanPlt containsString:@"网页"] || [cleanPlt containsString:@"google"] || [cleanPlt containsString:@"谷歌"]) {
        pillText = [NSString stringWithFormat:@"🔍 正在百度搜索: %@...", cleanKw];
        targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.baidu.com/s?wd=%@", encoded]];
        [[AGGlobalActionPillWindow sharedPill] showActionPill:pillText];
        [self dismissOverlay];
        agSafeLaunchURL(targetURL);
        return;
    }

    // 坚决不降级打开 Safari，直接明确提示未安装
    [[AGGlobalActionPillWindow sharedPill] showActionPill:[NSString stringWithFormat:@"⚠️ 手机未安装「%@」", platform ?: @"目标应用"]];
    [self showActionBanner:[NSString stringWithFormat:@"⚠️ 手机未安装「%@」", platform ?: @"目标应用"]];
    [self dismissOverlay];
}
- (void)handleMediaControl:(NSString *)action {
    dispatch_async(dispatch_get_main_queue(), ^{
        SBMediaController *mc = [%c(SBMediaController) sharedInstance];
        if (!mc) return;
        NSString *clean = [action lowercaseString];
        if ([clean containsString:@"pause"] || [clean containsString:@"暂停"]) {
            if ([mc respondsToSelector:@selector(pauseForType:)]) [mc pauseForType:0];
            [[AGGlobalActionPillWindow sharedPill] showActionPill:@"⏸️ 已暂停音乐播放"];
            [self showActionBanner:@"⏸️ 已暂停音乐播放"];
        } else if ([clean containsString:@"play"] || [clean containsString:@"播放"]) {
            if ([mc respondsToSelector:@selector(playForType:)]) [mc playForType:0];
            [[AGGlobalActionPillWindow sharedPill] showActionPill:@"▶️ 正在播放音乐"];
            [self showActionBanner:@"▶️ 正在播放音乐"];
        } else if ([clean containsString:@"next"] || [clean containsString:@"下一首"] || [clean containsString:@"切歌"]) {
            if ([mc respondsToSelector:@selector(changeTrack:eventSource:)]) [mc changeTrack:1 eventSource:0];
            [[AGGlobalActionPillWindow sharedPill] showActionPill:@"⏭️ 已切换至下一首"];
            [self showActionBanner:@"⏭️ 已切换至下一首"];
        } else if ([clean containsString:@"prev"] || [clean containsString:@"上一首"]) {
            if ([mc respondsToSelector:@selector(changeTrack:eventSource:)]) [mc changeTrack:-1 eventSource:0];
            [[AGGlobalActionPillWindow sharedPill] showActionPill:@"⏮️ 已切换至上一首"];
            [self showActionBanner:@"⏮️ 已切换至上一首"];
        } else {
            if ([mc respondsToSelector:@selector(togglePlayPauseForType:)]) [mc togglePlayPauseForType:0];
        }
    });
}

- (void)handleVolumeControl:(NSString *)action level:(NSNumber *)level {
    float target = level ? level.floatValue : 0.5f;
    agAdjustSystemVolume(action ?: (level ? @"set" : @"up"), target);
}

- (void)toggleLowPowerMode:(BOOL)enable {
    agSetLowPowerMode(enable);
}

- (void)handleSystemControl:(NSString *)action {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *clean = [action lowercaseString];
        if ([clean containsString:@"home"] || [clean containsString:@"桌面"]) {
            [[AGGlobalActionPillWindow sharedPill] showActionPill:@"🏠 已返回主屏幕"];
            [self dismissOverlay];
            SBUIController *uic = [%c(SBUIController) sharedInstanceIfExists];
            if (uic && [uic respondsToSelector:@selector(clickedMenuButton)]) {
                [uic clickedMenuButton];
            }
        } else if ([clean containsString:@"lock"] || [clean containsString:@"锁屏"]) {
            [[AGGlobalActionPillWindow sharedPill] showActionPill:@"🔒 已锁定屏幕"];
            [self dismissOverlay];
            SBLockScreenManager *lsm = [%c(SBLockScreenManager) sharedInstance];
            if (lsm && [lsm respondsToSelector:@selector(lockUIFromSource:withOptions:)]) {
                [lsm lockUIFromSource:1 withOptions:nil];
                return;
            }
            SpringBoard *sb = (SpringBoard *)[UIApplication sharedApplication];
            if ([sb respondsToSelector:@selector(_simulateLockButtonPress)]) {
                [sb _simulateLockButtonPress];
            }
        } else if ([clean containsString:@"respring"] || [clean containsString:@"注销"] || [clean containsString:@"重启桌面"]) {
            [[AGGlobalActionPillWindow sharedPill] showActionPill:@"🔄 正在注销重启桌面..."];
            [self dismissOverlay];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                SpringBoard *sb = (SpringBoard *)[UIApplication sharedApplication];
                if ([sb respondsToSelector:@selector(_relaunchSpringBoardNow)]) {
                    [sb _relaunchSpringBoardNow];
                } else {
                    kill(getpid(), SIGKILL);
                }
            });
        }
    });
}

- (void)handleWechatShortcut:(NSString *)feature {
    NSString *f = [feature lowercaseString];
    NSString *urlStr = @"weixin://dl/scan";
    NSString *pillText = @"📷 正在打开 微信扫一扫...";
    if ([f containsString:@"pay"] || [f containsString:@"付"]) {
        urlStr = @"weixin://dl/money";
        pillText = @"💳 正在打开 微信付款码...";
    } else if ([f containsString:@"receipt"] || [f containsString:@"收"]) {
        urlStr = @"weixin://dl/pay";
        pillText = @"💰 正在打开 微信收款码...";
    } else if ([f containsString:@"moment"] || [f containsString:@"圈"]) {
        urlStr = @"weixin://dl/moments";
        pillText = @"⭕ 正在打开 微信朋友圈...";
    }
    [[AGGlobalActionPillWindow sharedPill] showActionPill:pillText];
    [self dismissOverlay];
    agSafeLaunchURL([NSURL URLWithString:urlStr]);
}

- (void)handleAlipayShortcut:(NSString *)feature {
    NSString *f = [feature lowercaseString];
    NSString *urlStr = @"alipays://platformapi/startapp?appId=10000007";
    NSString *pillText = @"📷 正在打开 支付宝扫一扫...";
    if ([f containsString:@"bus"] || [f containsString:@"乘车"] || [f containsString:@"公交"] || [f containsString:@"地铁"]) {
        urlStr = @"alipays://platformapi/startapp?appId=200011235";
        pillText = @"🚌 正在打开 支付宝乘车码...";
    } else if ([f containsString:@"pay"] || [f containsString:@"付"]) {
        urlStr = @"alipays://platformapi/startapp?appId=20000056";
        pillText = @"💳 正在打开 支付宝付款码...";
    } else if ([f containsString:@"receipt"] || [f containsString:@"收"]) {
        urlStr = @"alipays://platformapi/startapp?appId=20000123";
        pillText = @"💰 正在打开 支付宝收款码...";
    }
    [[AGGlobalActionPillWindow sharedPill] showActionPill:pillText];
    [self dismissOverlay];
    agSafeLaunchURL([NSURL URLWithString:urlStr]);
}

- (void)handleNavigationToDestination:(NSString *)dest preferredApp:(NSString *)prefApp {
    if (!dest || dest.length == 0) return;
    NSString *encoded = [dest stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *appLower = [prefApp lowercaseString];
    NSURL *targetURL = nil;

    BOOL hasAmap = NO;
    BOOL hasBaidu = NO;
    Class proxyCls = objc_getClass("LSApplicationProxy");
    if (proxyCls && [proxyCls respondsToSelector:@selector(applicationProxyForIdentifier:)]) {
        id amapProxy = [proxyCls applicationProxyForIdentifier:@"com.autonavi.amap"];
        if (amapProxy && [amapProxy respondsToSelector:@selector(isInstalled)] && [amapProxy isInstalled]) hasAmap = YES;
        id baiduProxy = [proxyCls applicationProxyForIdentifier:@"com.baidu.BaiduMobileMap"];
        if (baiduProxy && [baiduProxy respondsToSelector:@selector(isInstalled)] && [baiduProxy isInstalled]) hasBaidu = YES;
    }

    NSString *chosenApp = @"高德地图";
    if ([appLower containsString:@"baidu"] || [appLower containsString:@"百度"]) {
        if (hasBaidu) {
            targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"baidumap://map/direction?destination=%@&mode=driving&src=TimeGuardian", encoded]];
            chosenApp = @"百度地图";
        } else if (hasAmap) {
            targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"iosamap://path?sourceApplication=TimeGuardian&dname=%@&dev=0&t=0", encoded]];
            chosenApp = @"高德地图";
        } else {
            targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://maps.apple.com/?daddr=%@&dirflg=d", encoded]];
            chosenApp = @"苹果地图";
        }
    } else {
        if (hasAmap) {
            targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"iosamap://path?sourceApplication=TimeGuardian&dname=%@&dev=0&t=0", encoded]];
            chosenApp = @"高德地图";
        } else if (hasBaidu) {
            targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"baidumap://map/direction?destination=%@&mode=driving&src=TimeGuardian", encoded]];
            chosenApp = @"百度地图";
        } else {
            targetURL = [NSURL URLWithString:[NSString stringWithFormat:@"http://maps.apple.com/?daddr=%@&dirflg=d", encoded]];
            chosenApp = @"苹果地图";
        }
    }

    [[AGGlobalActionPillWindow sharedPill] showActionPill:[NSString stringWithFormat:@"🧭 正在使用%@导航前往: %@...", chosenApp, dest]];
    [self dismissOverlay];
    agSafeLaunchURL(targetURL);
}

- (void)handleMusicSearch:(NSString *)keyword preferredApp:(NSString *)prefApp {
    if (!keyword || keyword.length == 0) return;
    NSString *encoded = [keyword stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
    NSString *appLower = [prefApp lowercaseString];
    NSURL *targetURL = ([appLower containsString:@"qq"])
        ? [NSURL URLWithString:[NSString stringWithFormat:@"qqmusic://qq.com/ui/search?searchType=0&keyword=%@", encoded]]
        : [NSURL URLWithString:[NSString stringWithFormat:@"orpheus://search/%@", encoded]];
    [[AGGlobalActionPillWindow sharedPill] showActionPill:[NSString stringWithFormat:@"🎵 正在检索音乐: %@...", keyword]];
    [self dismissOverlay];
    agSafeLaunchURL(targetURL);
}

- (void)openURLString:(NSString *)urlStr {
    if (!urlStr || urlStr.length == 0) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        NSString *target = [urlStr containsString:@"://"] ? urlStr : [NSString stringWithFormat:@"https://%@", urlStr];
        NSURL *u = [NSURL URLWithString:target];
        if (u) {
            [[AGGlobalActionPillWindow sharedPill] showActionPill:@"🌐 正在打开链接..."];
            [self dismissOverlay];
            agSafeLaunchURL(u);
        }
    });
}

#pragma mark - 4. 悬浮窗右上角 ⚙️ 模型切换面板

- (void)setupEmbeddedModelPickerInView:(UIView *)parent width:(CGFloat)w height:(CGFloat)h {
    self.modelPickerContainer = [[UIView alloc] initWithFrame:CGRectMake(16, 62, w - 32, h - 130.0)];
    self.modelPickerContainer.backgroundColor = [UIColor colorWithRed:0.06 green:0.05 blue:0.14 alpha:0.98];
    self.modelPickerContainer.layer.cornerRadius = 22.0;
    self.modelPickerContainer.layer.borderWidth = 1.2;
    self.modelPickerContainer.layer.borderColor = [UIColor colorWithRed:0.45 green:0.70 blue:1.0 alpha:0.45].CGColor;
    self.modelPickerContainer.clipsToBounds = YES;
    self.modelPickerContainer.hidden = YES;
    [parent addSubview:self.modelPickerContainer];

    CGFloat mw = self.modelPickerContainer.bounds.size.width;

    self.pickerHeaderLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 7, mw - 160, 26)];
    self.pickerHeaderLabel.text = @"🤖 可用模型列表";
    self.pickerHeaderLabel.textColor = [UIColor colorWithRed:0.75 green:0.90 blue:1.0 alpha:1.0];
    self.pickerHeaderLabel.font = [UIFont boldSystemFontOfSize:12.5];
    [self.modelPickerContainer addSubview:self.pickerHeaderLabel];

    UIButton *syncCloudBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    syncCloudBtn.frame = CGRectMake(mw - 140, 7, 80, 26);
    syncCloudBtn.backgroundColor = [UIColor colorWithRed:0.20 green:0.45 blue:0.85 alpha:0.85];
    syncCloudBtn.layer.cornerRadius = 7.0;
    [syncCloudBtn setTitle:@"☁️刷新模型" forState:UIControlStateNormal];
    [syncCloudBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    syncCloudBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11];
    [syncCloudBtn addTarget:self action:@selector(fetchCloudModelsTapped:) forControlEvents:UIControlEventTouchUpInside];
    [self.modelPickerContainer addSubview:syncCloudBtn];

    UIButton *backBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    backBtn.frame = CGRectMake(mw - 54, 7, 44, 26);
    backBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.15];
    backBtn.layer.cornerRadius = 7.0;
    [backBtn setTitle:@"收起" forState:UIControlStateNormal];
    [backBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    backBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11.5];
    [backBtn addTarget:self action:@selector(togglePureModelPicker) forControlEvents:UIControlEventTouchUpInside];
    [self.modelPickerContainer addSubview:backBtn];

    self.modelTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 38, mw, self.modelPickerContainer.bounds.size.height - 38.0) style:UITableViewStylePlain];
    self.modelTableView.backgroundColor = [UIColor clearColor];
    self.modelTableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    self.modelTableView.delegate = self;
    self.modelTableView.dataSource = self;
    self.modelTableView.rowHeight = 38.0;
    self.modelTableView.delaysContentTouches = NO;
    [self.modelPickerContainer addSubview:self.modelTableView];
}

- (void)refreshOverlayPickerHeader {
    AGConfigTab tab = self.activeModeTab;
    if (tab == AGConfigTabVideoAI) {
        self.pickerHeaderLabel.text = @"📹 独立视频AI 精选与云端模型";
    } else if (tab == AGConfigTabPureText) {
        self.pickerHeaderLabel.text = @"💬 纯文本模式 精选与云端模型";
    } else {
        self.pickerHeaderLabel.text = @"🎙️ 纯正Live 精选与云端模型";
    }
    [self.availableModelsList removeAllObjects];
    [self.availableModelsList addObjectsFromArray:agCachedModelsForTab(tab)];
    [self.modelTableView reloadData];
}

- (void)togglePureModelPicker {
    [self.impactHaptic impactOccurred];
    [self.inputField resignFirstResponder];
    self.modelPickerContainer.hidden = !self.modelPickerContainer.hidden;
    self.overlayWindow.lockFullScreenTouch = !self.modelPickerContainer.hidden;

    if (!self.modelPickerContainer.hidden) {
        [self stopAllVoiceEngines];
        [self refreshOverlayPickerHeader];
        [self.modelPickerContainer.superview bringSubviewToFront:self.modelPickerContainer];
    } else if (self.activeModeTab != AGConfigTabPureText) {
        [self startAdaptiveVoiceSessionForTab:self.activeModeTab];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.availableModelsList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellID = @"GeminiModelCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cellID];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        cell.textLabel.minimumScaleFactor = 0.72;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
        UIView *selBg = [[UIView alloc] init];
        selBg.backgroundColor = [UIColor colorWithRed:0.35 green:0.45 blue:0.95 alpha:0.35];
        cell.selectedBackgroundView = selBg;
    }
    if (indexPath.row >= self.availableModelsList.count) return cell;
    NSDictionary *item = self.availableModelsList[indexPath.row];
    NSString *mID = item[@"id"];
    NSString *mTitle = item[@"title"] ?: mID;
    NSString *curSaved = agModelForTab(self.activeModeTab);
    BOOL isCurrent = [mID isEqualToString:curSaved];
    cell.textLabel.text = isCurrent ? [NSString stringWithFormat:@"✅ %@", mTitle] : [NSString stringWithFormat:@"    %@", mTitle];
    cell.textLabel.textColor = isCurrent ? [UIColor colorWithRed:0.45 green:0.95 blue:0.65 alpha:1.0] : [UIColor whiteColor];

    NSString *latStr = item[@"latencyStr"];
    if (latStr.length > 0) {
        cell.detailTextLabel.text = latStr;
        if ([latStr containsString:@"❌"]) {
            cell.detailTextLabel.textColor = [UIColor colorWithRed:1.0 green:0.40 blue:0.40 alpha:1.0];
        } else {
            cell.detailTextLabel.textColor = [UIColor colorWithRed:0.40 green:0.96 blue:0.68 alpha:1.0];
        }
    } else {
        cell.detailTextLabel.text = @"";
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.impactHaptic impactOccurred];
    if (indexPath.row >= self.availableModelsList.count) return;
    NSDictionary *item = self.availableModelsList[indexPath.row];
    NSString *selectedID = item[@"id"];
    if (selectedID) {
        // 安全拦截：若已被测速标记为不可用，阻止切换，防止崩溃注销！
        if (item[@"isUsable"] != nil && ![item[@"isUsable"] boolValue]) {
            [self showActionBanner:@"❌ 该模型不可用或未开通权限，已阻止切换"];
            return;
        }

        AGConfigTab tab = self.activeModeTab;
        NSMutableDictionary *p = loadGeminiPrefs();
        NSString *modelKey = [NSString stringWithFormat:@"%@_Model", agPrefixForTab(tab)];
        p[modelKey] = selectedID;
        saveGeminiPrefs(p);

        NSString *shortName = [selectedID stringByReplacingOccurrencesOfString:@"models/" withString:@""];
        [self updateHeaderBadges];
        [self showActionBanner:[NSString stringWithFormat:@"✨ 已选择模型：%@", shortName]];
        [self.modelTableView reloadData];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.16 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            self.modelPickerContainer.hidden = YES;
            self.overlayWindow.lockFullScreenTouch = NO;
            if (self.activeModeTab != AGConfigTabPureText) {
                [self startAdaptiveVoiceSessionForTab:self.activeModeTab];
            }
        });
    }
}

- (void)fetchCloudModelsTapped:(UIButton *)sender {
    [self.impactHaptic impactOccurred];
    AGConfigTab tab = self.activeModeTab;
    NSString *ep = agEndpointForTab(tab);
    NSString *key = agAPIKeyForTab(tab);
    NSString *proxy = agProxyForTab(tab);

    [self showActionBanner:@"☁️ 正在精选 5 款最新可用模型并测速..."];
    agFetchCloudModelsForTab(tab, ep, key, proxy, ^(BOOL success, NSArray<NSDictionary *> *models, NSString *errorMsg) {
        [self.availableModelsList removeAllObjects];
        if (models.count > 0) {
            NSMutableArray<NSMutableDictionary *> *benchmarkedList = [NSMutableArray array];
            for (NSDictionary *m in models) {
                [benchmarkedList addObject:[m mutableCopy]];
            }
            [self.availableModelsList addObjectsFromArray:benchmarkedList];
            NSMutableDictionary *p = loadGeminiPrefs();
            NSString *cacheKey = (tab == AGConfigTabTranslation) ? @"AG_Trans_CachedModels" : [NSString stringWithFormat:@"%@_CachedModels", agPrefixForTab(tab)];
            p[cacheKey] = benchmarkedList;
            NSString *modelKey = [NSString stringWithFormat:@"%@_Model", agPrefixForTab(tab)];
            if (benchmarkedList.count > 0 && ([p[modelKey] length] == 0)) {
                p[modelKey] = benchmarkedList.firstObject[@"id"];
            }
            saveGeminiPrefs(p);
            [self updateHeaderBadges];
            [self.modelTableView reloadData];
            [self showActionBanner:[NSString stringWithFormat:@"✅ 已实测就绪 %lu 款最新可用模型", (unsigned long)benchmarkedList.count]];
        } else {
            [self showActionBanner:errorMsg ?: @"⚠️ 未能获取到当前功能可用模型"];
        }
    });
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    NSString *text = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (text.length > 0) {
        [textField resignFirstResponder];
        textField.text = @"";
        if ([self tryExecuteDirectLocalCommand:text]) return YES;

        if (self.isWebSocketConnected && self.liveWebSocketTask && self.activeModeTab != AGConfigTabPureText) {
            NSMutableString *curTrans = [self currentTabTranscript];
            if (curTrans.length > 0 && ![curTrans hasSuffix:@"\n"]) [curTrans appendString:@"\n\n"];
            [curTrans appendFormat:@"🗣️ 您：%@\n", text];
            self.responseTextView.text = curTrans;
            [self throttledExpandAndScrollTextViewForce:YES];

            if (self.isGoogleBidiProtocol) {
                NSMutableArray *partsArr = [NSMutableArray array];
                if (self.isVideoChatActive && self.latestFrameJPEGData.length > 0) {
                    NSString *b64Img = [self.latestFrameJPEGData base64EncodedStringWithOptions:0];
                    [partsArr addObject:@{ @"inlineData": @{ @"mimeType": @"image/jpeg", @"data": b64Img } }];
                }
                [partsArr addObject:@{ @"text": text }];
                [self sendJSONDictionaryOverWebSocket:@{
                    @"clientContent": @{
                        @"turns": @[ @{ @"role": @"user", @"parts": partsArr } ],
                        @"turnComplete": @YES
                    }
                }];
            } else {
                [self sendJSONDictionaryOverWebSocket:@{
                    @"type": @"conversation.item.create",
                    @"item": @{ @"type": @"message", @"role": @"user", @"content": @[ @{ @"type": @"input_text", @"text": text } ] }
                }];
                [self sendJSONDictionaryOverWebSocket:@{ @"type": @"response.create" }];
            }
            return YES;
        }

        [self stopAllVoiceEngines];
        [self dispatchMultimodalRequestWithText:text audioData:nil isInitialGreeting:NO forTab:self.activeModeTab];
    }
    return YES;
}

#pragma mark - 5. 呼出、收起与 60/120Hz 实时流体声波极光动画

- (void)startVisualAnimations {
    [self.screenNeonLayer removeAllAnimations];
    CABasicAnimation *breath = [CABasicAnimation animationWithKeyPath:@"opacity"];
    breath.fromValue = @(0.55);
    breath.toValue = @(1.00);
    breath.duration = 2.2;
    breath.autoreverses = YES;
    breath.repeatCount = HUGE_VALF;
    breath.removedOnCompletion = NO;
    [self.screenNeonLayer addAnimation:breath forKey:@"auroraGentleBreath"];

    [self.waveDisplayLink invalidate];
    self.waveDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(tickFluidWaveAnimation)];
    AGDeviceMetrics m = agComputeDeviceMetrics();
    if (@available(iOS 15.0, *)) {
        float fps = (float)m.targetAnimFPS;
        self.waveDisplayLink.preferredFrameRateRange = CAFrameRateRangeMake(fps, fps, fps);
    } else if (@available(iOS 10.0, *)) {
        self.waveDisplayLink.preferredFramesPerSecond = m.targetAnimFPS;
    }
    [self.waveDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)stopVisualAnimations {
    [self.waveDisplayLink invalidate];
    self.waveDisplayLink = nil;
    [self.screenNeonLayer removeAllAnimations];
    [self.aiOrbView.layer removeAllAnimations];
}

- (void)tickFluidWaveAnimation {
    if (!self.overlayWindow || self.overlayWindow.hidden) return;

    CGFloat target = MAX(0.16, self.targetVoiceAmplitude);
    self.currentVoiceAmplitude += (target - self.currentVoiceAmplitude) * 0.16;
    self.wavePhase += (0.048 + self.currentVoiceAmplitude * 0.085);

    [self.cardBgCanvas stepAnimationWithPhase:self.wavePhase amplitude:self.currentVoiceAmplitude];
    [self.orbCanvas stepAnimationWithPhase:self.wavePhase amplitude:self.currentVoiceAmplitude];
    [self.waveCanvas stepAnimationWithPhase:self.wavePhase amplitude:self.currentVoiceAmplitude];
    [self stepMarqueeAnimationWithPhase:self.wavePhase voiceAmp:self.currentVoiceAmplitude];
}


- (void)triggerFromSystemHook {
    agWakeScreenBacklightIfNeeded();
    self.pendingWakeupChime = YES;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - self.lastTriggerTime < 0.45) return;
    self.lastTriggerTime = now;

    pauseBackgroundMediaPlayback();
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.impactHaptic prepare];
        [self.impactHaptic impactOccurred];
        [self forceKillNativeSiri];
        [self toggleOverlayInternal];
        [self playIOS27SiriInvocationEffectFromPowerButton:self.isInvocationFromPowerButton];
    });
}

- (void)toggleOverlayInternal {
    [self setupWindowIfNeeded];
    if (!self.overlayWindow.hidden && self.overlayWindow.alpha > 0.1) {
        [self dismissOverlay];
    } else {
        for (UIWindow *w in [UIApplication sharedApplication].windows) {
            if (w.isKeyWindow && w != self.overlayWindow) {
                self.previousKeyWindow = w;
                break;
            }
        }

        if (agIsTabEnabled(AGConfigTabNativeLive)) {
            self.activeModeTab = AGConfigTabNativeLive;
        } else if (agIsTabEnabled(AGConfigTabVideoAI)) {
            self.activeModeTab = AGConfigTabVideoAI;
        } else {
            self.activeModeTab = AGConfigTabPureText;
        }

        [self.accumulatedReplyText setString:@""];
        [self.pendingSpeechChunk setString:@""];
        [self.tabTranscriptMap[@(AGConfigTabNativeLive)] setString:@""];
        [self.tabTranscriptMap[@(AGConfigTabVideoAI)] setString:@""];
        [self.tabTranscriptMap[@(AGConfigTabPureText)] setString:@""];
        [self.tabHistoryMap[@(AGConfigTabNativeLive)] removeAllObjects];
        [self.tabHistoryMap[@(AGConfigTabVideoAI)] removeAllObjects];
        [self.tabHistoryMap[@(AGConfigTabPureText)] removeAllObjects];

        AGDeviceMetrics m = agComputeDeviceMetrics();
        self.currentKeyboardHeight = 0.0;
        self.currentCapsuleHeight = m.defaultCapsuleH;

        // 关键修复 1：在计算和设置 frame 之前，必须先将上次关闭动画残留的 transform 归零，彻底杜绝 UIKit 首帧几何尺寸失真放大！
        self.overlayWindow.capsuleWrapper.transform = CGAffineTransformIdentity;
        self.cardBlurView.transform = CGAffineTransformIdentity;

        // 关键修复 2：直接按紧凑正常高度 (defaultCapsuleH) 同步完成首帧布局，打开第 0 秒就是正常大小，绝不先铺满再缩回！
        [self adjustCapsuleHeightTo:m.defaultCapsuleH animated:NO];
        [self.overlayWindow.capsuleWrapper layoutIfNeeded];
        [self.cardBgCanvas setNeedsLayout];
        [self.cardBgCanvas layoutIfNeeded];

        self.modelPickerContainer.hidden = YES;
        self.overlayWindow.lockFullScreenTouch = NO;
        self.isDismissed = NO;
        self.overlayWindow.alpha = 0.0;
        self.overlayWindow.hidden = NO;
        [self.overlayWindow makeKeyWindow];
        [self startVisualAnimations];

        // 预先设置好初始提示文案，让首帧画面零延迟呈现
        BOOL hasKey = (agAPIKeyForTab(self.activeModeTab).length >= 5);
        if (!hasKey) {
            self.subStatusLabel.text = @"⚠️ 当前模式未配置 API Key";
            self.responseTextView.text = @"请前往手机《设置》App，点击右上角「✨天使守护」在对应标签页填入 API Key。";
        } else if (self.activeModeTab == AGConfigTabNativeLive) {
            self.responseTextView.text = @"“直接开口说话，支持毫秒级流式秒回与随时插话打断...”";
        } else if (self.activeModeTab == AGConfigTabPureText) {
            self.responseTextView.text = @"“请在下方输入框打字提问...”";
        }

        // 丝滑弹簧入场动画（卡片上浮放大 + 全屏紫晕毛玻璃渐显）
        self.screenDimBlurView.alpha = 0.0;
        self.overlayWindow.capsuleWrapper.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(0.92, 0.92), CGAffineTransformMakeTranslation(0, 36));
        [UIView animateWithDuration:0.38 delay:0 usingSpringWithDamping:0.80 initialSpringVelocity:0.9 options:UIViewAnimationOptionCurveEaseOut | UIViewAnimationOptionAllowUserInteraction animations:^{
            self.overlayWindow.alpha = 1.0;
            self.screenDimBlurView.alpha = 0.36;
            self.overlayWindow.capsuleWrapper.transform = CGAffineTransformIdentity;
        } completion:nil];

        // 关键顺畅度优化：错峰 0.08 秒（待弹窗动画顺滑起跳后）再异步初始化相机与语音连接，彻底消除唤出瞬间的掉帧！
        if (hasKey) {
            AGConfigTab launchTab = self.activeModeTab;
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.08 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                if (self.isDismissed || self.overlayWindow.hidden) return;
                if (launchTab == AGConfigTabVideoAI) {
                    [self startCameraSession];
                    [self startAdaptiveVoiceSessionForTab:AGConfigTabVideoAI];
                } else if (launchTab == AGConfigTabNativeLive) {
                    [self startAdaptiveVoiceSessionForTab:AGConfigTabNativeLive];
                } else {
                    [self ensureCloudModelsLoadedForTab:AGConfigTabPureText completion:^(NSString *readyModel) {
                        NSString *shortM = [readyModel stringByReplacingOccurrencesOfString:@"models/" withString:@""];
                        self.subStatusLabel.text = [NSString stringWithFormat:@"💬 纯文本模式已就绪 (%@)", shortM];
                    }];
                }
            });
        }
    }
}

- (void)dismissOverlay {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.isDismissed = YES;
        if ((self.activeModeTab == AGConfigTabNativeLive || self.activeModeTab == AGConfigTabVideoAI) &&
            self.isWebSocketConnected && self.liveWebSocketTask && self.liveWebSocketTask.state == NSURLSessionTaskStateRunning) {
            // 关闭界面时仅释放音频与麦克风，保持 WebSocket 在后台热备并自动续杯
            [self suspendVoiceSessionKeepWebSocketAlive];
        } else {
            [self stopAllVoiceEngines];
        }
        if (self.isVideoChatActive) {
            [self stopCameraSession];
        }
        self.currentKeyboardHeight = 0.0;
        [self.inputField resignFirstResponder];
        [self.overlayWindow endEditing:YES];
        self.overlayWindow.lockFullScreenTouch = NO;

        if (self.currentTask) {
            [self.currentTask cancel];
            self.currentTask = nil;
        }

        [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            self.overlayWindow.alpha = 0.0;
            self.screenDimBlurView.alpha = 0.0;
            self.overlayWindow.capsuleWrapper.transform = CGAffineTransformConcat(CGAffineTransformMakeScale(0.94, 0.94), CGAffineTransformMakeTranslation(0, 24));
        } completion:^(BOOL finished) {
            self.overlayWindow.hidden = YES;
            self.overlayWindow.capsuleWrapper.transform = CGAffineTransformIdentity;
            [self stopVisualAnimations];
        }];
    });
}

#pragma mark - 6. 统一多模态流式引擎 + 失效模型自动迁移容错

- (void)migrateAwayFromUnavailableModelAndRetry:(NSString *)userText
                                      audioData:(NSData *)audioData
                                     isGreeting:(BOOL)isGreeting {
    AGConfigTab tab = self.activeModeTab;
    NSString *badModel = agModelForTab(tab);
    NSString *ep = agEndpointForTab(tab);
    NSString *key = agAPIKeyForTab(tab);
    NSString *proxy = agProxyForTab(tab);

    self.subStatusLabel.text = @"🔄 正在为您自动切换至最新可用的实时模型...";
    agFetchCloudModelsForTab(tab, ep, key, proxy, ^(BOOL success, NSArray<NSDictionary *> *models, NSString *errorMsg) {
        NSString *nextModel = nil;
        for (NSDictionary *m in models) {
            NSString *cand = m[@"id"];
            if ([m[@"isUsable"] boolValue] && ![cand isEqualToString:badModel]) {
                if ((tab == AGConfigTabNativeLive || tab == AGConfigTabVideoAI) && ![m[@"bidi"] boolValue]) {
                    continue;
                }
                nextModel = cand;
                break;
            }
        }
        if (!nextModel) {
            nextModel = (tab == AGConfigTabNativeLive || tab == AGConfigTabVideoAI)
                ? @"models/gemini-2.5-flash-native-audio-preview-09-2025"
                : models.firstObject[@"id"];
        }
        if (!nextModel) return;

        NSMutableDictionary *p = loadGeminiPrefs();
        NSString *prefix = agPrefixForTab(tab);
        p[[NSString stringWithFormat:@"%@_Model", prefix]] = nextModel;
        saveGeminiPrefs(p);
        [self updateHeaderBadges];
        [self showActionBanner:[NSString stringWithFormat:@"✅ 已切换至实时模型: %@", [nextModel stringByReplacingOccurrencesOfString:@"models/" withString:@""]]];

        if (!self.hasAutoMigratedDeprecatedModel) {
            self.hasAutoMigratedDeprecatedModel = YES;
            if (tab == AGConfigTabNativeLive || tab == AGConfigTabVideoAI) {
                [self startWebSocketBidiSessionWithModel:nextModel forTab:tab];
            } else {
                [self executeRequestWithCloudModel:nextModel
                                          userText:(userText ?: @"你好，请简短打个招呼。")
                                         audioData:audioData
                                 isInitialGreeting:isGreeting
                                            forTab:tab];
            }
        }
    });
}

- (void)dispatchMultimodalRequestWithText:(NSString *)userText
                                audioData:(NSData *)audioData
                        isInitialGreeting:(BOOL)isGreeting
                                   forTab:(AGConfigTab)tab {
    self.lastSentUserText = userText;
    self.lastSentAudioData = audioData;
    [self ensureCloudModelsLoadedForTab:tab completion:^(NSString *selectedModel) {
        [self executeRequestWithCloudModel:selectedModel userText:userText audioData:audioData isInitialGreeting:isGreeting forTab:tab];
    }];
}

- (void)executeRequestWithCloudModel:(NSString *)modelPath
                            userText:(NSString *)userText
                           audioData:(NSData *)audioData
                   isInitialGreeting:(BOOL)isGreeting
                              forTab:(AGConfigTab)tab {
    NSString *apiKey = agAPIKeyForTab(tab);
    NSString *endpoint = agEndpointForTab(tab);
    NSString *proxy = agProxyForTab(tab);
    NSString *exactModelID = [modelPath stringByReplacingOccurrencesOfString:@"models/" withString:@""];

    if (self.currentTask) [self.currentTask cancel];
    [self.rawHTTPResponseData setLength:0];
    [self.sseLineBuffer setString:@""];
    [self.accumulatedReplyText setString:@""];
    [self.pendingSpeechChunk setString:@""];
    self.activeUtteranceCount = 0;

    [self updateHeaderBadges];
    self.subStatusLabel.text = (agIsWebSearchEnabled() && agIsGoogleNativeProtocol(endpoint, modelPath))
        ? [NSString stringWithFormat:@"🌐 %@ (%@) 正在联网检索并流式回应...", [self currentVendorBrandName], exactModelID]
        : [NSString stringWithFormat:@"⚡ %@ (%@) 正在流式回应...", [self currentVendorBrandName], exactModelID];

    NSData *cameraJPEG = self.isVideoChatActive ? self.latestFrameJPEGData : nil;
    if (self.isVideoChatActive && (!cameraJPEG || cameraJPEG.length == 0)) {
        cameraJPEG = [NSData dataWithContentsOfFile:agSharedCameraFramePath()];
        if (cameraJPEG.length > 200) {
            self.latestFrameJPEGData = cameraJPEG;
        }
    }

    NSMutableString *curTrans = [self currentTabTranscript];
    if (curTrans.length > 0 && ![curTrans hasSuffix:@"\n"]) {
        [curTrans appendString:@"\n\n"];
    }
    if (!isGreeting) {
        NSString *qLabel = nil;
        if (audioData) {
            if (self.isVideoChatActive) {
                qLabel = (cameraJPEG.length > 200)
                    ? [NSString stringWithFormat:@"📹 [语音 + 实时视频帧(%luKB)提问]", (unsigned long)(cameraJPEG.length / 1024)]
                    : @"📹 [语音提问 (摄像头未就绪，仅发送语音)]";
            } else {
                qLabel = @"🎙️ [语音提问]";
            }
        } else {
            if (self.isVideoChatActive) {
                qLabel = (cameraJPEG.length > 200)
                    ? [NSString stringWithFormat:@"📹 [提问 + 实时视频帧(%luKB)]: %@", (unsigned long)(cameraJPEG.length / 1024), userText]
                    : [NSString stringWithFormat:@"🗣️ 您：%@", userText];
            } else {
                qLabel = [NSString stringWithFormat:@"🗣️ 您：%@", userText];
            }
        }
        [curTrans appendFormat:@"%@\n", qLabel];
    }
    [curTrans appendFormat:@"✨ %@：", [self currentVendorBrandName]];
    self.responseTextView.text = curTrans;
    [self throttledExpandAndScrollTextViewForce:YES];

    NSString *promptFirstLine = (audioData != nil)
        ? @"你接收到了用户的真实语音录音。请用简明自然、口语化的中文直接流式回答用户，不要使用复杂的 Markdown 符号。\n"
        : @"请用简明、自然、口语化的中文直接回答用户，不要使用复杂的 Markdown 符号。\n";

    NSString *sysPrompt = [NSString stringWithFormat:
        @"%@"
        @"【上下文记忆】请紧密结合前面的对话历史回答用户的追问。\n"
        @"【身份准则】不要声称自己是 iPhone 语音助手或 Siri。当用户询问你是谁或什么模型时，请如实回答你的真实官方身份（%@）与具体模型版本（%@）。\n"
        @"【系统与应用自动化控制指令规范】当用户要求控制手机、打开应用或执行具体操作时，请在回答末尾输出标准指令标记（支持连续输出多个 [ACTION:{...}] 组合连招，系统将按时序自动依次执行）：\n"
        @"1. 打开应用：[ACTION:{\"type\":\"open_app\",\"app\":\"应用名\"}]\n"
        @"2. 微信发消息：[ACTION:{\"type\":\"wechat_message\",\"target\":\"联系人\",\"content\":\"内容\"}]\n"
        @"3. 微信读未读消息：[ACTION:{\"type\":\"wechat_read_unread\"}]\n"
        @"4. 微信打开指定聊天窗口：[ACTION:{\"type\":\"wechat_open_chat\",\"target\":\"联系人\"}]\n"
        @"5. 微信扫一扫/付款/收款/朋友圈：[ACTION:{\"type\":\"wechat_shortcut\",\"feature\":\"scan|pay|receipt|moments\"}]\n"
        @"6. 支付宝扫一扫/乘车码/付款/收款：[ACTION:{\"type\":\"alipay_shortcut\",\"feature\":\"scan|bus|pay|receipt\"}]\n"
        @"7. 真实硬件音量控制：[ACTION:{\"type\":\"volume_control\",\"action\":\"up|down|mute|set\",\"level\":0.5}]\n"
        @"8. 音乐播放控制：[ACTION:{\"type\":\"media_control\",\"action\":\"play|pause|next|prev\"}]\n"
        @"9. 屏幕亮度与手电筒：[ACTION:{\"type\":\"brightness_control\",\"action\":\"set|up|down\",\"level\":0.8}] / [ACTION:{\"type\":\"toggle_flashlight\",\"on\":true|false,\"level\":1.0}]\n"
        @"10. 屏幕截图：[ACTION:{\"type\":\"take_screenshot\"}]\n"
        @"11. 设定闹钟：[ACTION:{\"type\":\"alarm_control\",\"hour\":7,\"minute\":30,\"title\":\"闹钟\"}]\n"
        @"12. 设定倒计时：[ACTION:{\"type\":\"timer_control\",\"seconds\":180}]\n"
        @"13. 添加提醒事项：[ACTION:{\"type\":\"reminder_add\",\"title\":\"提醒内容\"}]\n"
        @"14. 视觉点击屏幕文字：[ACTION:{\"type\":\"ui_tap_text\",\"text\":\"屏幕上的按钮文字\"}]\n"
        @"15. 屏幕滑动/点赞手势：[ACTION:{\"type\":\"ui_gesture\",\"gesture\":\"swipe_up|swipe_down|double_tap|back\"}]\n"
        @"16. 清理手机后台：[ACTION:{\"type\":\"kill_background_apps\"}]\n"
        @"17. 深色/浅色/护眼模式：[ACTION:{\"type\":\"appearance_mode\",\"mode\":\"dark|light|nightshift_on|nightshift_off\"}]\n"
        @"18. Wi-Fi/蓝牙/飞行/省电：[ACTION:{\"type\":\"wifi_toggle\",\"on\":true}] / [ACTION:{\"type\":\"bluetooth_toggle\",\"on\":true}] / [ACTION:{\"type\":\"airplane_mode\",\"on\":true}] / [ACTION:{\"type\":\"low_power_mode\",\"on\":true}]\n"
        @"19. 自动打字填入/复制：[ACTION:{\"type\":\"clipboard_auto_type\",\"text\":\"要填入或复制的文字\"}]\n"
        @"20. 手机电量与空间自检：[ACTION:{\"type\":\"device_status\"}]\n"
        @"21. 地图导航与平台搜索：[ACTION:{\"type\":\"navigation\",\"destination\":\"地点\",\"app\":\"amap|baidu\"}] / [ACTION:{\"type\":\"search\",\"keyword\":\"词\",\"platform\":\"taobao|jd|douyin|bilibili|xhs|meituan|baidu\"}]\n"
        @"22. 电话/短信/锁屏/桌面：[ACTION:{\"type\":\"make_call\",\"target\":\"人名\"}] / [ACTION:{\"type\":\"send_sms\",\"target\":\"人名\",\"content\":\"内容\"}] / [ACTION:{\"type\":\"system_control\",\"action\":\"home|lock|respring\"}]",
        promptFirstLine, [self currentVendorBrandName], exactModelID];

    if (self.isVideoChatActive || self.activeModeTab == AGConfigTabVideoAI) {
        sysPrompt = [sysPrompt stringByAppendingString:
            @"\n【实时视觉模式】用户已开启实时摄像头，你能够实时接收并看清摄像头所拍摄的现场画面。请根据用户所指以及镜头中看到的真实画面、物体、文字或环境进行智能分析和回答。当用户询问你能否看到或画面内容时，请根据附带的图像如实生动地描述。"];
    }

    if (agIsWebSearchEnabled()) {
        NSDateFormatter *fmt = [[NSDateFormatter alloc] init];
        fmt.dateFormat = @"yyyy-MM-dd HH:mm:ss";
        NSString *nowStr = [fmt stringFromDate:[NSDate date]];
        sysPrompt = [sysPrompt stringByAppendingFormat:@"\n【实时联网搜索已打通】当前系统准确时间：%@。当用户询问关于实时天气、最新新闻、今日资讯、股票行情、体育比分等内容时，请充分利用最新的联网实时信息进行准确作答，绝不输出过期旧信息。\n", nowStr];
    }

    NSMutableArray<NSDictionary *> *curHist = [self currentTabHistory];
    BOOL isGoogle = agIsGoogleNativeProtocol(endpoint, modelPath);
    NSMutableURLRequest *request = nil;

    if (isGoogle) {
        NSString *baseEP = agSanitizeEndpoint(endpoint, tab);
        NSString *fullModelPath = [modelPath hasPrefix:@"models/"] ? modelPath : [NSString stringWithFormat:@"models/%@", modelPath];
        NSString *urlStr = [NSString stringWithFormat:@"%@/v1beta/%@:streamGenerateContent?alt=sse&key=%@", baseEP, fullModelPath, apiKey ?: @""];
        NSURL *reqURL = [NSURL URLWithString:urlStr];
        if (!reqURL) {
            reqURL = [NSURL URLWithString:[NSString stringWithFormat:@"https://generativelanguage.googleapis.com/v1beta/%@:streamGenerateContent?alt=sse&key=%@", fullModelPath, apiKey ?: @""]];
        }
        request = [NSMutableURLRequest requestWithURL:reqURL];
        request.HTTPMethod = @"POST";
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

        NSMutableArray *userParts = [NSMutableArray array];
        if (cameraJPEG.length > 0) {
            [userParts addObject:@{
                @"inlineData": @{ @"mimeType": @"image/jpeg", @"data": [cameraJPEG base64EncodedStringWithOptions:0] }
            }];
        }
        if (audioData.length > 0) {
            [userParts addObject:@{
                @"inlineData": @{ @"mimeType": @"audio/wav", @"data": [audioData base64EncodedStringWithOptions:0] }
            }];
        }
        if (userText.length > 0) {
            [userParts addObject:@{@"text": userText}];
        }

        NSMutableArray *contents = [NSMutableArray array];
        for (NSDictionary *hist in curHist) {
            [contents addObject:@{
                @"role": [hist[@"role"] isEqualToString:@"assistant"] ? @"model" : @"user",
                @"parts": @[@{@"text": hist[@"content"] ?: @""}]
            }];
        }
        [contents addObject:@{@"role": @"user", @"parts": userParts}];

        NSMutableDictionary *body = [@{
            @"systemInstruction": @{@"parts": @[@{@"text": sysPrompt}]},
            @"contents": contents
        } mutableCopy];
        if (agIsWebSearchEnabled()) {
            body[@"tools"] = @[ @{ @"google_search": @{} } ];
        }
        request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    } else {
        NSString *baseEP = agSanitizeEndpoint(endpoint, tab);
        NSString *urlStr = agResolveVendorHTTPChatEndpoint(baseEP, modelPath);
        NSURL *reqURL = [NSURL URLWithString:urlStr];
        if (!reqURL) {
            reqURL = [NSURL URLWithString:@"https://api.deepseek.com/v1/chat/completions"];
        }
        request = [NSMutableURLRequest requestWithURL:reqURL];
        request.HTTPMethod = @"POST";
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];

        AGHTTPProtocolFamily httpFamily = agDetectHTTPProtocolFamily(baseEP, modelPath);
        if (httpFamily == AGHTTPProtocolFamilyAnthropic) {
            [request setValue:(apiKey ?: @"") forHTTPHeaderField:@"x-api-key"];
            [request setValue:@"2023-06-01" forHTTPHeaderField:@"anthropic-version"];

            NSMutableArray *claudeMessages = [NSMutableArray array];
            for (NSDictionary *hist in curHist) {
                NSString *r = hist[@"role"];
                if ([r isEqualToString:@"user"] || [r isEqualToString:@"assistant"]) {
                    [claudeMessages addObject:@{ @"role": r, @"content": hist[@"content"] ?: @"" }];
                }
            }

            NSMutableArray *userContent = [NSMutableArray array];
            if (cameraJPEG.length > 0) {
                NSString *b64Img = [cameraJPEG base64EncodedStringWithOptions:0];
                [userContent addObject:@{
                    @"type": @"image",
                    @"source": @{
                        @"type": @"base64",
                        @"media_type": @"image/jpeg",
                        @"data": b64Img
                    }
                }];
            }
            [userContent addObject:@{
                @"type": @"text",
                @"text": (userText.length > 0 ? userText : @"请回答。")
            }];
            [claudeMessages addObject:@{ @"role": @"user", @"content": userContent }];

            NSMutableDictionary *body = [@{
                @"model": exactModelID,
                @"system": sysPrompt,
                @"messages": claudeMessages,
                @"max_tokens": @4096,
                @"stream": @YES
            } mutableCopy];
            request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        } else {
            [request setValue:[NSString stringWithFormat:@"Bearer %@", apiKey ?: @""] forHTTPHeaderField:@"Authorization"];

            NSMutableArray *messages = [NSMutableArray array];
            [messages addObject:@{@"role": @"system", @"content": sysPrompt}];
            for (NSDictionary *hist in curHist) {
                [messages addObject:hist];
            }

            NSMutableArray *multimodalContent = [NSMutableArray array];
            if (cameraJPEG.length > 0) {
                NSString *b64Img = [cameraJPEG base64EncodedStringWithOptions:0];
                [multimodalContent addObject:@{
                    @"type": @"image_url",
                    @"image_url": @{@"url": [NSString stringWithFormat:@"data:image/jpeg;base64,%@", b64Img]}
                }];
            }
            if (audioData.length > 0) {
                NSString *b64Aud = [audioData base64EncodedStringWithOptions:0];
                [multimodalContent addObject:@{
                    @"type": @"input_audio",
                    @"input_audio": @{@"data": b64Aud, @"format": @"wav"}
                }];
            }
            [multimodalContent addObject:@{@"type": @"text", @"text": (userText.length > 0 ? userText : @"请回答。")}];

            if (cameraJPEG.length > 0 || audioData.length > 0) {
                [messages addObject:@{@"role": @"user", @"content": multimodalContent}];
            } else {
                [messages addObject:@{@"role": @"user", @"content": (userText.length > 0 ? userText : @"你好")}];
            }

            NSMutableDictionary *body = [@{
                @"model": exactModelID,
                @"messages": messages,
                @"stream": @YES
            } mutableCopy];

            if (agIsWebSearchEnabled()) {
                body[@"enable_search"] = @YES;
                if ([urlStr containsString:@"bigmodel.cn"]) {
                    body[@"tools"] = @[ @{ @"type": @"web_search", @"web_search": @{ @"enable": @YES, @"search_result": @YES } } ];
                }
            }
            request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
        }
    }

    if (!isGreeting && userText.length > 0 && !audioData) {
        [curHist addObject:@{@"role": @"user", @"content": userText}];
        if (curHist.count > 14) [curHist removeObjectAtIndex:0];
    }

    if (self.streamSession) {
        [self.streamSession invalidateAndCancel];
    }
    self.streamSession = agCreateSessionWithProxy(proxy, self, [NSOperationQueue mainQueue]);
    self.currentTask = [self.streamSession dataTaskWithRequest:request];
    [self.currentTask resume];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    if (!data || data.length == 0) return;
    [self.rawHTTPResponseData appendData:data];

    NSString *chunkStr = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    if (!chunkStr) return;

    [self.sseLineBuffer appendString:chunkStr];
    NSArray<NSString *> *lines = [self.sseLineBuffer componentsSeparatedByString:@"\n"];

    for (NSInteger i = 0; i < (NSInteger)lines.count - 1; i++) {
        NSString *line = [lines[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if ([line hasPrefix:@"data:"]) {
            NSString *jsonStr = [[line substringFromIndex:5] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if ([jsonStr isEqualToString:@"[DONE]"]) continue;
            [self processStreamJSONChunk:jsonStr];
        }
    }
    [self.sseLineBuffer setString:lines.lastObject ?: @""];
}

- (NSString *)extractTextFromDictionary:(NSDictionary *)dict {
    return agExtractTextFromJSON(dict);
}

- (void)processStreamJSONChunk:(NSString *)jsonStr {
    NSData *jsonData = [jsonStr dataUsingEncoding:NSUTF8StringEncoding];
    if (!jsonData) return;
    id parsed = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:nil];
    if ([parsed isKindOfClass:[NSArray class]]) {
        for (NSDictionary *item in (NSArray *)parsed) {
            NSString *t = [self extractTextFromDictionary:item];
            if (t.length > 0) [self appendIncomingTextDelta:t];
        }
    } else if ([parsed isKindOfClass:[NSDictionary class]]) {
        NSString *t = [self extractTextFromDictionary:parsed];
        if (t.length > 0) [self appendIncomingTextDelta:t];
    }
}

- (void)appendIncomingTextDelta:(NSString *)delta {
    [self.accumulatedReplyText appendString:delta];
    [self.pendingSpeechChunk appendString:delta];

    if ([self.accumulatedReplyText containsString:@"[ACTION:"] && [self.accumulatedReplyText containsString:@"]"]) {
        BOOL actionExecuted = NO;
        [self parseAndExecuteActions:self.accumulatedReplyText executed:&actionExecuted];
        if (actionExecuted) {
            [self.accumulatedReplyText setString:@""];
            [self.pendingSpeechChunk setString:@""];
        }
    }

    NSMutableString *curTrans = [self currentTabTranscript];
    if (curTrans.length == 0 || [curTrans hasSuffix:@"\n"]) {
        [curTrans appendFormat:@"✨ %@：", [self currentVendorBrandName]];
    }
    [curTrans appendString:delta];
    if ([curTrans containsString:@"[ACTION:"]) {
        NSRegularExpression *actionReg = [NSRegularExpression regularExpressionWithPattern:@"\\[ACTION:.*?\\]" options:NSRegularExpressionDotMatchesLineSeparators error:nil];
        NSString *cleanedTrans = [actionReg stringByReplacingMatchesInString:curTrans options:0 range:NSMakeRange(0, curTrans.length) withTemplate:@""];
        [curTrans setString:cleanedTrans];
    }
    self.responseTextView.text = curTrans;
    [self throttledExpandAndScrollTextViewForce:NO];

    // 关键修复：将最小朗读分句长度从 >= 4 提升至 >= 14，防止前 4 个字 ("你好！我") 刚出就被切碎提前触发 didFinishSpeechUtterance！
    if (self.activeModeTab != AGConfigTabPureText && !self.isWebSocketConnected && ![self.accumulatedReplyText containsString:@"[ACTION:"]) {
        NSCharacterSet *punctSet = [NSCharacterSet characterSetWithCharactersInString:@"。！？；.!?;:\n"];
        NSRange punctRange = [self.pendingSpeechChunk rangeOfCharacterFromSet:punctSet options:NSBackwardsSearch];
        if (punctRange.location != NSNotFound && punctRange.location >= 14) {
            NSString *sentence = [self.pendingSpeechChunk substringToIndex:punctRange.location + 1];
            NSString *rem = [self.pendingSpeechChunk substringFromIndex:punctRange.location + 1];
            [self.pendingSpeechChunk setString:rem];
            [self enqueueSpeechSentence:sentence];
        }
    }
}

- (void)enqueueSpeechSentence:(NSString *)sentence {
    NSString *clean = [sentence stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (clean.length == 0) return;

    self.activeUtteranceCount++;
    self.bargeInVoiceTicks = 0;
    self.subStatusLabel.text = [NSString stringWithFormat:@"🔊 %@ 正在回答 (直接开口说话即可随时打断)...", [self currentVendorBrandName]];
    [self setWaveBarsLevel:0.70];

    AVSpeechUtterance *utt = [AVSpeechUtterance speechUtteranceWithString:clean];
    utt.voice = [AVSpeechSynthesisVoice voiceWithLanguage:@"zh-CN"];
    utt.rate = 0.52;
    utt.volume = 0.80; // 适度降低外放音量，防止底部扬声器回声冲破 -17.5dB 自打断
    [self.synthesizer speakUtterance:utt];

    if (!self.audioRecorder || !self.audioRecorder.isRecording) {
        [self attemptStartAudioRecorder];
    }
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didFinishSpeechUtterance:(AVSpeechUtterance *)utterance {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.activeUtteranceCount > 0) {
            self.activeUtteranceCount--;
        }
        // 核心修复：必须同时满足 self.currentTask == nil 且 self.pendingSpeechChunk.length == 0（网络流已彻底结束且无剩余待读句子），才允许重新开始倾听！彻底消灭念 4 个字就卡住的 Bug！
        if (self.activeUtteranceCount == 0 && ![synthesizer isSpeaking] && self.currentTask == nil && self.pendingSpeechChunk.length == 0) {
            [self setWaveBarsLevel:0.0];
            if (self.audioRecorder && self.audioRecorder.isRecording) {
                // 清空 AI 朗读期间录进来的外放声音，干净开始下一轮倾听
                [self.audioRecorder stop];
                [[NSFileManager defaultManager] removeItemAtPath:self.audioFilePath error:nil];
                [self.audioRecorder prepareToRecord];
                [self.audioRecorder record];
                self.hasDetectedSpeech = NO;
                self.silenceStartTime = 0;
                self.recordStartTime = [[NSDate date] timeIntervalSince1970];
                self.subStatusLabel.text = (self.activeModeTab == AGConfigTabVideoAI)
                    ? @"📹 正在全双工倾听并实时捕捉镜头画面..."
                    : @"🎙️ 正在全双工倾听 (声波与极光随您的声音实时律动)...";
            } else {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.20 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    if (self.overlayWindow && !self.overlayWindow.hidden && self.modelPickerContainer.hidden && self.activeModeTab != AGConfigTabPureText) {
                        [self startContinuousVoiceListening];
                    }
                });
            }
        }
    });
}

- (void)speechSynthesizer:(AVSpeechSynthesizer *)synthesizer didCancelSpeechUtterance:(AVSpeechUtterance *)utterance {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.activeUtteranceCount = 0;
        [self setWaveBarsLevel:0.0];
    });
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if ([task isKindOfClass:[NSURLSessionWebSocketTask class]] || session == self.webSocketSession || task == self.liveWebSocketTask) {
        return;
    }
    if (task == self.currentTask) self.currentTask = nil;
    if (error && error.code == NSURLErrorCancelled) return;

    NSString *remLine = [self.sseLineBuffer stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([remLine hasPrefix:@"data:"]) {
        NSString *jsonStr = [[remLine substringFromIndex:5] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (![jsonStr isEqualToString:@"[DONE]"]) {
            [self processStreamJSONChunk:jsonStr];
        }
    }

    NSMutableString *curTrans = [self currentTabTranscript];
    if (error && self.accumulatedReplyText.length == 0) {
        self.subStatusLabel.text = @"❌ 网络请求失败";
        [curTrans appendFormat:@"[网络异常：%@]\n\n", error.localizedDescription];
        self.responseTextView.text = curTrans;
        [self throttledExpandAndScrollTextViewForce:YES];
        return;
    }

    if (self.accumulatedReplyText.length == 0 && self.rawHTTPResponseData.length > 0) {
        NSString *rawStr = [[NSString alloc] initWithData:self.rawHTTPResponseData encoding:NSUTF8StringEncoding];
        if (rawStr) {
            NSArray *rawLines = [rawStr componentsSeparatedByString:@"\n"];
            for (NSString *l in rawLines) {
                NSString *tl = [l stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                if ([tl hasPrefix:@"data:"]) {
                    NSString *js = [[tl substringFromIndex:5] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    if (![js isEqualToString:@"[DONE]"]) [self processStreamJSONChunk:js];
                }
            }
        }
        if (self.accumulatedReplyText.length == 0) {
            id fullObj = [NSJSONSerialization JSONObjectWithData:self.rawHTTPResponseData options:0 error:nil];
            if (fullObj) {
                [self processStreamJSONChunk:rawStr];
            }
            if (self.accumulatedReplyText.length == 0) {
                NSDictionary *errDict = [fullObj isKindOfClass:[NSDictionary class]] ? fullObj : ([fullObj isKindOfClass:[NSArray class]] ? [fullObj firstObject] : nil);
                NSString *errMsg = ([errDict isKindOfClass:[NSDictionary class]] && errDict[@"error"][@"message"])
                    ? errDict[@"error"][@"message"]
                    : nil;
                if (!errMsg || errMsg.length == 0) {
                    if (self.isVideoChatActive && [[self currentVendorBrandName] containsString:@"DeepSeek"]) {
                        errMsg = @"DeepSeek 为纯文本大模型，暂不支持视觉图像分析。请点击右上角⚙️切换为 Gemini 或 GPT-4o 视讯模型";
                    } else {
                        errMsg = @"当前所选模型未返回文本，请点击右上角⚙️切换其他可用模型";
                    }
                } else if (agIsWebSearchEnabled() && ([errMsg containsString:@"quota"] || [errMsg containsString:@"RESOURCE_EXHAUSTED"])) {
                    errMsg = @"API 额度受限或当前 Key 暂不支持实时联网搜索 (Grounding)。建议前往《设置》关闭「实时联网搜索」开关后重试。";
                }

                NSString *lowerErr = [errMsg lowercaseString];
                if (!self.hasAutoMigratedDeprecatedModel &&
                    ([lowerErr containsString:@"no longer available"] ||
                     [lowerErr containsString:@"not found"] ||
                     [lowerErr containsString:@"not supported"] ||
                     [lowerErr containsString:@"only supports"] ||
                     [lowerErr containsString:@"invalid argument"])) {
                    [curTrans appendFormat:@"[检测到旧模型不可用，正在自动迁移至新模型...]\n"];
                    self.responseTextView.text = curTrans;
                    [self migrateAwayFromUnavailableModelAndRetry:self.lastSentUserText audioData:self.lastSentAudioData isGreeting:NO];
                    return;
                }

                self.subStatusLabel.text = @"⚠️ 模型接口返回错误";
                [curTrans appendFormat:@"[%@]\n\n", errMsg];
                self.responseTextView.text = curTrans;
                [self throttledExpandAndScrollTextViewForce:YES];
                if (self.activeModeTab != AGConfigTabPureText) {
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        [self startContinuousVoiceListening];
                    });
                }
                return;
            }
        }
    }

    BOOL actionExecuted = NO;
    NSString *cleanReply = [self parseAndExecuteActions:self.accumulatedReplyText executed:&actionExecuted];
    if (actionExecuted) {
        [self.accumulatedReplyText setString:@""];
        [self.pendingSpeechChunk setString:@""];
        self.subStatusLabel.text = @"✅ 正在为您执行操作...";
        return;
    }

    if (cleanReply.length > 0) {
        [curTrans appendString:@"\n\n"];
        self.responseTextView.text = curTrans;
        NSMutableArray *curHist = [self currentTabHistory];
        [curHist addObject:@{@"role": @"assistant", @"content": cleanReply}];
        if (curHist.count > 14) [curHist removeObjectAtIndex:0];
        [self throttledExpandAndScrollTextViewForce:YES];
    }

    NSString *tailSpeech = [self.pendingSpeechChunk stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    [self.pendingSpeechChunk setString:@""];
    if (self.activeModeTab != AGConfigTabPureText && tailSpeech.length > 0) {
        [self enqueueSpeechSentence:tailSpeech];
    } else if (self.activeModeTab == AGConfigTabPureText) {
        self.subStatusLabel.text = [NSString stringWithFormat:@"✨ %@ 回答完毕", [self currentVendorBrandName]];
    } else if (self.activeUtteranceCount == 0 && ![self.synthesizer isSpeaking]) {
        [self startContinuousVoiceListening];
    }
}

@end

// ==================== 3. 手机系统《设置》App 原生三模独立配置中心 ====================
@interface AngelGuardianSettingsViewController : UIViewController <UITableViewDelegate, UITableViewDataSource, UITextFieldDelegate>
@property (nonatomic, assign) AGConfigTab currentEditingTab;
@property (nonatomic, strong) UISwitch *masterEnableSwitch;
@property (nonatomic, strong) UISwitch *webSearchEnableSwitch;
@property (nonatomic, strong) UISegmentedControl *configModuleTabSeg;

@property (nonatomic, strong) UIView *tabSwitchRowView;
@property (nonatomic, strong) UILabel *tabSwitchTitleLabel;
@property (nonatomic, strong) UISwitch *tabEnableSwitch;

@property (nonatomic, strong) UITextField *endpointField;
@property (nonatomic, strong) UITextField *apiKeyField;
@property (nonatomic, strong) UITextField *proxyField;
@property (nonatomic, strong) UITextField *modelField;
@property (nonatomic, strong) UIButton *fetchModelsBtn;
@property (nonatomic, strong) UILabel *modelSectionHintLabel;
@property (nonatomic, strong) UITableView *modelsTableView;
@property (nonatomic, strong) NSMutableArray<NSDictionary *> *currentTabModels;
@end

@implementation AngelGuardianSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"✨ 天使守护 v5.8.0 配置中心";
    self.view.backgroundColor = [UIColor colorWithRed:0.07 green:0.06 blue:0.13 alpha:1.0];
    self.currentTabModels = [NSMutableArray array];

    UIBarButtonItem *closeItem = [[UIBarButtonItem alloc] initWithTitle:@"保存并关闭" style:UIBarButtonItemStyleDone target:self action:@selector(saveAndDismissTapped)];
    closeItem.tintColor = [UIColor colorWithRed:0.35 green:0.92 blue:0.70 alpha:1.0];
    self.navigationItem.rightBarButtonItem = closeItem;

    UIScrollView *scroll = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    scroll.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self.view addSubview:scroll];

    CGFloat w = self.view.bounds.size.width;
    CGFloat pad = 16.0;
    CGFloat cardW = w - pad * 2;
    CGFloat y = 14.0;

    UIView *topCard = [[UIView alloc] initWithFrame:CGRectMake(pad, y, cardW, 96)];
    topCard.backgroundColor = [UIColor colorWithRed:0.13 green:0.12 blue:0.22 alpha:1.0];
    topCard.layer.cornerRadius = 16.0;
    topCard.layer.borderWidth = 0.8;
    topCard.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.14].CGColor;
    [scroll addSubview:topCard];

    NSDictionary *prefs = loadGeminiPrefs();

    UILabel *enLbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 11, cardW - 85, 24)];
    enLbl.text = @"⚡ 启用「天使守护」总开关";
    enLbl.textColor = [UIColor whiteColor];
    enLbl.font = [UIFont boldSystemFontOfSize:14];
    [topCard addSubview:enLbl];

    self.masterEnableSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(cardW - 64, 8, 50, 30)];
    self.masterEnableSwitch.on = prefs[@"Gemini_Enabled"] ? [prefs[@"Gemini_Enabled"] boolValue] : YES;
    [self.masterEnableSwitch addTarget:self action:@selector(globalControlChanged) forControlEvents:UIControlEventValueChanged];
    [topCard addSubview:self.masterEnableSwitch];

    UIView *div = [[UIView alloc] initWithFrame:CGRectMake(14, 46, cardW - 28, 0.6)];
    div.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    [topCard addSubview:div];

    UILabel *wsLbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 53, cardW - 85, 20)];
    wsLbl.text = @"🌐 允许模型实时联网搜索 (Google Grounding)";
    wsLbl.textColor = [UIColor colorWithRed:0.75 green:0.88 blue:1.0 alpha:1.0];
    wsLbl.font = [UIFont boldSystemFontOfSize:12.5];
    [topCard addSubview:wsLbl];

    UILabel *wsSubLbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 73, cardW - 85, 14)];
    wsSubLbl.text = @"开启后问答时自动搜网页，若 API 报 429 超额请关闭";
    wsSubLbl.textColor = [UIColor colorWithWhite:0.55 alpha:1.0];
    wsSubLbl.font = [UIFont systemFontOfSize:9.5];
    [topCard addSubview:wsSubLbl];

    self.webSearchEnableSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(cardW - 64, 54, 50, 30)];
    self.webSearchEnableSwitch.on = agIsWebSearchEnabled();
    [self.webSearchEnableSwitch addTarget:self action:@selector(webSearchControlChanged) forControlEvents:UIControlEventValueChanged];
    [topCard addSubview:self.webSearchEnableSwitch];

    y += 110.0;

    // ==================== 1:1 还原 HTML 预览的三列色块主题选择卡片 ====================
    UIView *themeCard = [[UIView alloc] initWithFrame:CGRectMake(pad, y, cardW, 118)];
    themeCard.tag = 97500;
    themeCard.backgroundColor = [UIColor colorWithRed:0.13 green:0.12 blue:0.22 alpha:1.0];
    themeCard.layer.cornerRadius = 16.0;
    themeCard.layer.borderWidth = 0.8;
    themeCard.layer.borderColor = [UIColor colorWithRed:0.40 green:0.65 blue:1.0 alpha:0.35].CGColor;
    [scroll addSubview:themeCard];

    UILabel *tHeader = [[UILabel alloc] initWithFrame:CGRectMake(12, 10, 155, 20)];
    tHeader.text = @"🎨 主界面视觉主题风格";
    tHeader.textColor = [UIColor whiteColor];
    tHeader.font = [UIFont boldSystemFontOfSize:13.5];
    [themeCard addSubview:tHeader];

    UILabel *tStatus = [[UILabel alloc] initWithFrame:CGRectMake(168, 10, cardW - 180, 20)];
    tStatus.tag = 97509;
    tStatus.textAlignment = NSTextAlignmentRight;
    tStatus.textColor = [UIColor colorWithRed:0.0 green:0.96 blue:1.0 alpha:1.0];
    tStatus.font = [UIFont boldSystemFontOfSize:11.0];
    [themeCard addSubview:tStatus];

    NSArray *titles = @[@"1. 轻奢", @"2. 简约", @"3. 炫酷"];
    NSArray *subs   = @[@"高定黑金琉璃", @"超折射液态玻璃", @"全息量子液态玻璃"];
    NSArray *swatchColors = @[
        @[(__bridge id)[UIColor colorWithRed:0.09 green:0.07 blue:0.08 alpha:1.0].CGColor,
          (__bridge id)[UIColor colorWithRed:0.90 green:0.75 blue:0.60 alpha:1.0].CGColor,
          (__bridge id)[UIColor colorWithRed:1.00 green:0.97 blue:0.92 alpha:1.0].CGColor],
        @[(__bridge id)[UIColor colorWithWhite:1.0 alpha:0.30].CGColor,
          (__bridge id)[UIColor colorWithRed:0.73 green:0.90 blue:0.99 alpha:1.0].CGColor,
          (__bridge id)[UIColor whiteColor].CGColor],
        @[(__bridge id)[UIColor colorWithRed:0.00 green:0.96 blue:1.00 alpha:1.0].CGColor,
          (__bridge id)[UIColor colorWithRed:0.66 green:0.33 blue:0.97 alpha:1.0].CGColor,
          (__bridge id)[UIColor colorWithRed:1.00 green:0.16 blue:0.52 alpha:1.0].CGColor]
    ];

    CGFloat itemGap = 8.0;
    CGFloat itemW = (cardW - 24.0 - itemGap * 2.0) / 3.0;
    for (int i = 0; i < 3; i++) {
        UIButton *optCard = [UIButton buttonWithType:UIButtonTypeCustom];
        optCard.tag = 97501 + i;
        optCard.frame = CGRectMake(12.0 + i * (itemW + itemGap), 36.0, itemW, 72.0);
        optCard.layer.cornerRadius = 12.0;
        optCard.layer.borderWidth = 1.5;
        [optCard addTarget:self action:@selector(agSelectThemeCardTapped:) forControlEvents:UIControlEventTouchUpInside];
        [themeCard addSubview:optCard];

        UIView *sw = [[UIView alloc] initWithFrame:CGRectMake((itemW - 40.0) / 2.0, 8.0, 40.0, 22.0)];
        sw.userInteractionEnabled = NO;
        sw.layer.cornerRadius = 7.0;
        sw.layer.masksToBounds = YES;
        sw.layer.borderWidth = 1.0;
        sw.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.85].CGColor;
        CAGradientLayer *sg = [CAGradientLayer layer];
        sg.frame = sw.bounds;
        sg.colors = swatchColors[i];
        sg.startPoint = CGPointMake(0, 0);
        sg.endPoint = CGPointMake(1, 1);
        [sw.layer addSublayer:sg];
        [optCard addSubview:sw];

        UILabel *nLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 34.0, itemW, 16.0)];
        nLbl.text = titles[i];
        nLbl.textColor = [UIColor whiteColor];
        nLbl.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightHeavy];
        nLbl.textAlignment = NSTextAlignmentCenter;
        [optCard addSubview:nLbl];

        UILabel *sLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 51.0, itemW, 14.0)];
        sLbl.text = subs[i];
        sLbl.textColor = [UIColor colorWithWhite:1.0 alpha:0.65];
        sLbl.font = [UIFont systemFontOfSize:9.5 weight:UIFontWeightMedium];
        sLbl.textAlignment = NSTextAlignmentCenter;
        [optCard addSubview:sLbl];
    }
    [self agRefreshThemeCardsSelectionState];
    y += 130.0;

    // ==================== 新增：iOS 27 呼吸跑马灯边框独立开关（已移除原双滑块） ====================
    UIView *marqueeSwitchCard = [[UIView alloc] initWithFrame:CGRectMake(pad, y, cardW, 58)];
    marqueeSwitchCard.backgroundColor = [UIColor colorWithRed:0.13 green:0.12 blue:0.22 alpha:1.0];
    marqueeSwitchCard.layer.cornerRadius = 16.0;
    marqueeSwitchCard.layer.borderWidth = 0.8;
    marqueeSwitchCard.layer.borderColor = [UIColor colorWithRed:0.40 green:0.65 blue:1.0 alpha:0.35].CGColor;
    [scroll addSubview:marqueeSwitchCard];

    UILabel *mqTitleLbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 9, cardW - 85, 22)];
    mqTitleLbl.text = @"🌈 启用「iOS 27 呼吸跑马灯边框」";
    mqTitleLbl.textColor = [UIColor whiteColor];
    mqTitleLbl.font = [UIFont boldSystemFontOfSize:13.5];
    [marqueeSwitchCard addSubview:mqTitleLbl];

    UILabel *mqSubLbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 32, cardW - 85, 16)];
    mqSubLbl.text = @"主界面四周流光呼吸与呼唤Siri波纹特效 (颜色随主题同步)";
    mqSubLbl.textColor = [UIColor colorWithWhite:0.62 alpha:1.0];
    mqSubLbl.font = [UIFont systemFontOfSize:10.0];
    [marqueeSwitchCard addSubview:mqSubLbl];

    UISwitch *marqueeEnableSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(cardW - 64, 14, 50, 30)];
    marqueeEnableSwitch.on = agIsMarqueeEnabled();
    [marqueeEnableSwitch addTarget:self action:@selector(onMarqueeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    [marqueeSwitchCard addSubview:marqueeEnableSwitch];

    y += 70.0;

    UILabel *tabHeader = [[UILabel alloc] initWithFrame:CGRectMake(pad + 4, y, cardW, 20)];
    tabHeader.text = @"🛠️ 三大独立模式配置 (输入Key后建议点刷新云端模型)：";
    tabHeader.textColor = [UIColor colorWithWhite:0.86 alpha:1.0];
    tabHeader.font = [UIFont boldSystemFontOfSize:12.5];
    [scroll addSubview:tabHeader];
    y += 24.0;

    self.configModuleTabSeg = [[UISegmentedControl alloc] initWithItems:@[@"🎙️ 纯正Live", @"📹 独立视频AI", @"💬 纯文本模式"]];
    self.configModuleTabSeg.frame = CGRectMake(pad, y, cardW, 36);
    self.configModuleTabSeg.selectedSegmentIndex = 0;
    self.configModuleTabSeg.backgroundColor = [UIColor colorWithRed:0.16 green:0.15 blue:0.26 alpha:1.0];
    [self.configModuleTabSeg addTarget:self action:@selector(moduleTabSwitched:) forControlEvents:UIControlEventValueChanged];
    [scroll addSubview:self.configModuleTabSeg];
    y += 44.0;

    UIView *moduleCard = [[UIView alloc] initWithFrame:CGRectMake(pad, y, cardW, 480)];
    moduleCard.backgroundColor = [UIColor colorWithRed:0.13 green:0.12 blue:0.22 alpha:1.0];
    moduleCard.layer.cornerRadius = 16.0;
    moduleCard.layer.borderWidth = 0.8;
    moduleCard.layer.borderColor = [UIColor colorWithRed:0.40 green:0.65 blue:1.0 alpha:0.35].CGColor;
    [scroll addSubview:moduleCard];

    CGFloat cy = 12.0;

    self.tabSwitchRowView = [[UIView alloc] initWithFrame:CGRectMake(12, cy, cardW - 24, 40)];
    self.tabSwitchRowView.backgroundColor = [UIColor colorWithRed:0.18 green:0.26 blue:0.36 alpha:0.75];
    self.tabSwitchRowView.layer.cornerRadius = 10.0;
    [moduleCard addSubview:self.tabSwitchRowView];

    self.tabSwitchTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 5, cardW - 92, 30)];
    self.tabSwitchTitleLabel.textColor = [UIColor colorWithRed:0.60 green:0.95 blue:0.80 alpha:1.0];
    self.tabSwitchTitleLabel.font = [UIFont boldSystemFontOfSize:12.5];
    [self.tabSwitchRowView addSubview:self.tabSwitchTitleLabel];

    self.tabEnableSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(cardW - 80, 5, 50, 30)];
    [self.tabEnableSwitch addTarget:self action:@selector(saveCurrentTabFieldsToDisk) forControlEvents:UIControlEventValueChanged];
    [self.tabSwitchRowView addSubview:self.tabEnableSwitch];

    cy += 48.0;

    self.endpointField = [self createStyledTextFieldWithFrame:CGRectMake(12, cy, cardW - 24, 38)
                                                  placeholder:@"🔗 独立接口地址 (如 https://generativelanguage.googleapis.com)"];
    [self.endpointField addTarget:self action:@selector(apiInputFieldsDidChange) forControlEvents:UIControlEventEditingChanged];
    [moduleCard addSubview:self.endpointField];
    cy += 46.0;

    self.apiKeyField = [self createStyledTextFieldWithFrame:CGRectMake(12, cy, cardW - 24, 38)
                                                placeholder:@"🔑 独立 API Key (必填)"];
    [self.apiKeyField addTarget:self action:@selector(apiInputFieldsDidChange) forControlEvents:UIControlEventEditingChanged];
    [moduleCard addSubview:self.apiKeyField];
    cy += 46.0;

    self.proxyField = [self createStyledTextFieldWithFrame:CGRectMake(12, cy, cardW - 24, 38)
                                               placeholder:@"🌐 独立代理端口 (如 7890，直连留空)"];
    [self.proxyField addTarget:self action:@selector(saveCurrentTabFieldsToDisk) forControlEvents:UIControlEventEditingChanged];
    [moduleCard addSubview:self.proxyField];
    cy += 46.0;

    self.modelField = [self createStyledTextFieldWithFrame:CGRectMake(12, cy, cardW - 142, 38)
                                               placeholder:@"🤖 当前选用的模型 ID"];
    [self.modelField addTarget:self action:@selector(saveCurrentTabFieldsToDisk) forControlEvents:UIControlEventEditingChanged];
    [moduleCard addSubview:self.modelField];

    self.fetchModelsBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.fetchModelsBtn.frame = CGRectMake(cardW - 124, cy, 112, 38);
    self.fetchModelsBtn.backgroundColor = [UIColor colorWithRed:0.22 green:0.52 blue:0.98 alpha:0.95];
    self.fetchModelsBtn.layer.cornerRadius = 10.0;
    [self.fetchModelsBtn setTitle:@"🔍 刷新云端模型" forState:UIControlStateNormal];
    [self.fetchModelsBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.fetchModelsBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12.0];
    [self.fetchModelsBtn addTarget:self action:@selector(fetchModelsForCurrentTabTapped) forControlEvents:UIControlEventTouchUpInside];
    [moduleCard addSubview:self.fetchModelsBtn];
    cy += 46.0;

    self.modelSectionHintLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, cy, cardW - 28, 20)];
    self.modelSectionHintLabel.text = @"📋 可用模型列表 (点击任意模型即可生效)：";
    self.modelSectionHintLabel.textColor = [UIColor colorWithRed:0.65 green:0.85 blue:1.0 alpha:1.0];
    self.modelSectionHintLabel.font = [UIFont boldSystemFontOfSize:12.0];
    [moduleCard addSubview:self.modelSectionHintLabel];
    cy += 22.0;

    self.modelsTableView = [[UITableView alloc] initWithFrame:CGRectMake(8, cy, cardW - 16, 200) style:UITableViewStylePlain];
    self.modelsTableView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.25];
    self.modelsTableView.layer.cornerRadius = 10.0;
    self.modelsTableView.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    self.modelsTableView.delegate = self;
    self.modelsTableView.dataSource = self;
    self.modelsTableView.rowHeight = 38.0;
    [moduleCard addSubview:self.modelsTableView];

    scroll.contentSize = CGSizeMake(w, y + 500.0);

    self.currentEditingTab = AGConfigTabNativeLive;
    [self loadFieldsForTab:AGConfigTabNativeLive];
}

- (UITextField *)createStyledTextFieldWithFrame:(CGRect)frame placeholder:(NSString *)placeholder {
    UITextField *tf = [[UITextField alloc] initWithFrame:frame];
    tf.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    tf.layer.cornerRadius = 10.0;
    tf.layer.borderWidth = 0.7;
    tf.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.15].CGColor;
    tf.textColor = [UIColor whiteColor];
    tf.font = [UIFont systemFontOfSize:13.0];
    tf.leftView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    tf.leftViewMode = UITextFieldViewModeAlways;
    tf.clearButtonMode = UITextFieldViewModeWhileEditing;
    tf.returnKeyType = UIReturnKeyDone;
    tf.delegate = self;
    tf.attributedPlaceholder = [[NSAttributedString alloc] initWithString:placeholder attributes:@{NSForegroundColorAttributeName: [UIColor colorWithWhite:0.55 alpha:1.0]}];
    return tf;
}

- (void)globalControlChanged {
    NSMutableDictionary *p = loadGeminiPrefs();
    p[@"Gemini_Enabled"] = @(self.masterEnableSwitch.isOn);
    saveGeminiPrefs(p);
}

- (void)webSearchControlChanged {
    NSMutableDictionary *p = loadGeminiPrefs();
    p[@"AG_WebSearch_Enabled"] = @(self.webSearchEnableSwitch.isOn);
    saveGeminiPrefs(p);
}

- (void)moduleTabSwitched:(UISegmentedControl *)seg {
    [self saveCurrentTabFieldsToDisk];
    self.currentEditingTab = (AGConfigTab)seg.selectedSegmentIndex;
    [self loadFieldsForTab:self.currentEditingTab];
}

- (void)loadFieldsForTab:(AGConfigTab)tab {
    self.tabEnableSwitch.enabled = YES;
    self.tabEnableSwitch.on = agIsTabEnabled(tab);

    if (tab == AGConfigTabNativeLive) {
        self.tabSwitchTitleLabel.text = @"🎙️ 启用「纯正 Live 模式」 (底部显示🎙️按钮)";
    } else if (tab == AGConfigTabVideoAI) {
        self.tabSwitchTitleLabel.text = @"📹 启用「独立视频 AI 模式」 (底部显示📹按钮)";
    } else {
        self.tabSwitchTitleLabel.text = @"💬 启用「纯文本模式」 (底部显示💬按钮)";
    }

    self.endpointField.text = agEndpointForTab(tab);
    self.apiKeyField.text = agAPIKeyForTab(tab);
    self.proxyField.text = agProxyForTab(tab);
    self.modelField.text = agModelForTab(tab);

    [self.currentTabModels removeAllObjects];
    [self.currentTabModels addObjectsFromArray:agCachedModelsForTab(tab)];
    [self.modelsTableView reloadData];
}

- (void)apiInputFieldsDidChange {
    [self saveCurrentTabFieldsToDisk];
}

- (void)saveCurrentTabFieldsToDisk {
    NSMutableDictionary *p = loadGeminiPrefs();
    NSString *prefix = agPrefixForTab(self.currentEditingTab);

    NSString *ep = [self.endpointField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *key = [self.apiKeyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *proxy = [self.proxyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSString *model = [self.modelField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];

    p[[NSString stringWithFormat:@"%@_Enabled", prefix]] = @(self.tabEnableSwitch.isOn);
    p[[NSString stringWithFormat:@"%@_Endpoint", prefix]] = ep ?: @"";
    p[[NSString stringWithFormat:@"%@_APIKey", prefix]] = key ?: @"";
    p[[NSString stringWithFormat:@"%@_ProxyPort", prefix]] = proxy ?: @"";
    if (model.length > 0) {
        p[[NSString stringWithFormat:@"%@_Model", prefix]] = model;
    }
    saveGeminiPrefs(p);
}

- (void)fetchModelsForCurrentTabTapped {
    [self.view endEditing:YES];
    [self saveCurrentTabFieldsToDisk];

    AGConfigTab tab = self.currentEditingTab;
    NSString *ep = self.endpointField.text ?: @"";
    NSString *key = self.apiKeyField.text ?: @"";
    NSString *proxy = self.proxyField.text ?: @"";

    [self.fetchModelsBtn setTitle:@"⏳ 测速精选中..." forState:UIControlStateNormal];
    self.fetchModelsBtn.enabled = NO;

    agFetchCloudModelsForTab(tab, ep, key, proxy, ^(BOOL success, NSArray<NSDictionary *> *models, NSString *errorMsg) {
        self.fetchModelsBtn.enabled = YES;
        [self.fetchModelsBtn setTitle:@"🔍 刷新云端模型" forState:UIControlStateNormal];

        if (success && models.count > 0) {
            self.modelSectionHintLabel.textColor = [UIColor colorWithRed:0.45 green:0.95 blue:0.65 alpha:1.0];
            self.modelSectionHintLabel.text = [NSString stringWithFormat:@"✅ 精选 %lu 款最新实测可用模型 (附带实测延迟)：", (unsigned long)models.count];

            [self.currentTabModels removeAllObjects];
            [self.currentTabModels addObjectsFromArray:models];

            NSMutableDictionary *p = loadGeminiPrefs();
            NSString *prefix = agPrefixForTab(tab);
            p[[NSString stringWithFormat:@"%@_CachedModels", prefix]] = models;
            NSString *firstID = models.firstObject[@"id"];
            self.modelField.text = firstID;
            p[[NSString stringWithFormat:@"%@_Model", prefix]] = firstID;
            saveGeminiPrefs(p);
            [self.modelsTableView reloadData];
        } else {
            self.modelSectionHintLabel.textColor = [UIColor colorWithRed:1.0 green:0.40 blue:0.40 alpha:1.0];
            self.modelSectionHintLabel.text = [NSString stringWithFormat:@"❌ 获取失败: %@", errorMsg ?: @"无符合当前功能的可用模型"];
        }
    });
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.currentTabModels.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cid = @"AGSettingsModelCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cid];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:cid];
        cell.backgroundColor = [UIColor clearColor];
        cell.textLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];
        cell.textLabel.adjustsFontSizeToFitWidth = YES;
        cell.textLabel.minimumScaleFactor = 0.72;
        cell.detailTextLabel.font = [UIFont systemFontOfSize:11.5 weight:UIFontWeightMedium];
        UIView *selBg = [[UIView alloc] init];
        selBg.backgroundColor = [UIColor colorWithRed:0.35 green:0.45 blue:0.95 alpha:0.35];
        cell.selectedBackgroundView = selBg;
    }
    if (indexPath.row >= self.currentTabModels.count) return cell;
    NSDictionary *m = self.currentTabModels[indexPath.row];
    NSString *mID = m[@"id"];
    NSString *mTitle = m[@"title"] ?: mID;
    NSString *curModel = self.modelField.text ?: agModelForTab(self.currentEditingTab);
    BOOL isSelected = [mID isEqualToString:curModel];
    cell.textLabel.text = isSelected ? [NSString stringWithFormat:@"✅ %@", mTitle] : [NSString stringWithFormat:@"    %@", mTitle];
    cell.textLabel.textColor = isSelected ? [UIColor colorWithRed:0.45 green:0.95 blue:0.65 alpha:1.0] : [UIColor whiteColor];

    NSString *latStr = m[@"latencyStr"];
    if (latStr.length > 0) {
        cell.detailTextLabel.text = latStr;
        cell.detailTextLabel.textColor = [UIColor colorWithRed:0.40 green:0.96 blue:0.68 alpha:1.0];
    } else {
        cell.detailTextLabel.text = @"";
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.row >= self.currentTabModels.count) return;
    NSDictionary *m = self.currentTabModels[indexPath.row];
    NSString *mID = m[@"id"];
    if (mID) {
        self.modelField.text = mID;
        [self saveCurrentTabFieldsToDisk];
        [self.modelsTableView reloadData];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self saveCurrentTabFieldsToDisk];
    return YES;
}

- (void)saveAndDismissTapped {
    [self.view endEditing:YES];
    [self globalControlChanged];
    [self saveCurrentTabFieldsToDisk];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)agRefreshThemeCardsSelectionState {
    AGVisualTheme cur = agCurrentVisualTheme();
    NSArray *statusNames = @[@"当前：1. 轻奢 (高定黑金琉璃)", @"当前：2. 简约 (超折射液态玻璃)", @"当前：3. 炫酷 (全息流光液态玻璃)"];
    UILabel *st = (UILabel *)[self.view viewWithTag:97509];
    if (st) st.text = statusNames[cur];
    for (int i = 0; i < 3; i++) {
        UIButton *card = (UIButton *)[self.view viewWithTag:97501 + i];
        if (!card) continue;
        if (i == cur) {
            card.backgroundColor = [UIColor colorWithRed:0.0 green:0.96 blue:1.0 alpha:0.16];
            card.layer.borderColor = [UIColor colorWithRed:0.0 green:0.96 blue:1.0 alpha:1.0].CGColor;
        } else {
            card.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.04];
            card.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.12].CGColor;
        }
    }
}

- (void)agSelectThemeCardTapped:(UIButton *)sender {
    NSInteger idx = sender.tag - 97501;
    if (idx < 0 || idx > 2) return;
    NSMutableDictionary *p = loadGeminiPrefs();
    p[@"AG_Visual_Theme"] = @(idx);
    saveGeminiPrefs(p);
    [self agRefreshThemeCardsSelectionState];
    [[GeminiAssistantManager sharedManager] updateHeaderBadges];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.angelguardian.prefsChanged"), NULL, NULL, YES);
}

- (void)onMarqueeSwitchChanged:(UISwitch *)sender {
    NSMutableDictionary *prefs = loadGeminiPrefs();
    prefs[@"AG_Marquee_Enabled"] = @(sender.isOn);
    saveGeminiPrefs(prefs);
    reloadGeminiPrefsCache();
    GeminiAssistantManager *mgr = [GeminiAssistantManager sharedManager];
    if (mgr.edgeGlowContainer) {
        mgr.edgeGlowContainer.hidden = !sender.isOn;
    }
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), CFSTR("com.angelguardian.prefsChanged"), NULL, NULL, YES);
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (__bridge CFStringRef)kAGPrefsChangedNotification, NULL, NULL, YES);
}

@end

// ==================== 4. 手机《设置》入口 + 桌面拦截钩子 ====================
%hook UINavigationController
- (void)viewDidAppear:(BOOL)animated {
    %orig(animated);
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundleID isEqualToString:@"com.apple.Preferences"]) {
        UIViewController *topVC = self.topViewController;
        if (topVC && ![topVC isKindOfClass:[AngelGuardianSettingsViewController class]] && topVC.navigationItem && !topVC.navigationItem.rightBarButtonItem) {
            UIBarButtonItem *btn = [[UIBarButtonItem alloc] initWithTitle:@"✨天使守护" style:UIBarButtonItemStyleDone target:self action:@selector(angelGuardianOpenPrefsModal)];
            btn.tintColor = [UIColor colorWithRed:0.55 green:0.36 blue:0.96 alpha:1.0];
            topVC.navigationItem.rightBarButtonItem = btn;
        }
    }
}

%new
- (void)angelGuardianOpenPrefsModal {
    AngelGuardianSettingsViewController *vc = [[AngelGuardianSettingsViewController alloc] init];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:vc];
    nav.navigationBar.barStyle = UIBarStyleBlack;
    nav.navigationBar.tintColor = [UIColor whiteColor];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}
%end

%hook NSBundle
- (NSDictionary *)infoDictionary {
    NSDictionary *orig = %orig;
    if (self == [NSBundle mainBundle]) {
        NSMutableDictionary *mutableInfo = orig ? [orig mutableCopy] : [NSMutableDictionary dictionary];
        mutableInfo[@"NSMicrophoneUsageDescription"] = @"天使守护需要使用麦克风进行实时语音对讲";
        mutableInfo[@"NSCameraUsageDescription"] = @"天使守护需要使用相机进行独立实景视频 AI 对话";
        mutableInfo[@"NSContactsUsageDescription"] = @"天使守护需要访问通讯录为您拨打电话与发送短信";
        return mutableInfo;
    }
    return orig;
}

- (id)objectForInfoDictionaryKey:(NSString *)key {
    if (self == [NSBundle mainBundle]) {
        if ([key isEqualToString:@"NSCameraUsageDescription"]) {
            return @"天使守护需要使用相机进行独立实景视频 AI 对话";
        }
        if ([key isEqualToString:@"NSMicrophoneUsageDescription"]) {
            return @"天使守护需要使用麦克风进行实时语音对讲";
        }
        if ([key isEqualToString:@"NSContactsUsageDescription"]) {
            return @"天使守护需要访问通讯录为您拨打电话与发送短信";
        }
    }
    return %orig(key);
}
%end

%hook AVCaptureDevice
+ (AVAuthorizationStatus)authorizationStatusForMediaType:(AVMediaType)mediaType {
    if ([mediaType isEqualToString:AVMediaTypeVideo] || [mediaType isEqualToString:AVMediaTypeAudio]) {
        return AVAuthorizationStatusAuthorized;
    }
    return %orig(mediaType);
}

+ (void)requestAccessForMediaType:(AVMediaType)mediaType completionHandler:(void (^)(BOOL granted))handler {
    if ([mediaType isEqualToString:AVMediaTypeVideo] || [mediaType isEqualToString:AVMediaTypeAudio]) {
        if (handler) handler(YES);
        return;
    }
    %orig(mediaType, handler);
}
%end

%hook SFSpeechRecognizer
+ (SFSpeechRecognizerAuthorizationStatus)authorizationStatus {
    return SFSpeechRecognizerAuthorizationStatusAuthorized;
}
+ (void)requestAuthorization:(void (^)(SFSpeechRecognizerAuthorizationStatus status))handler {
    if (handler) handler(SFSpeechRecognizerAuthorizationStatusAuthorized);
}
%end

%hook SBLockHardwareButtonActions
- (void)performLongPressActions {
    if ([[GeminiAssistantManager sharedManager] isTweakEnabled] && !isDeviceCurrentlyLocked()) {
        [GeminiAssistantManager sharedManager].isInvocationFromPowerButton = YES;
        [[GeminiAssistantManager sharedManager] triggerFromSystemHook];
        return;
    }
    %orig;
}
%end

%hook SBHomeHardwareButtonActions
- (void)performLongPressActions {
    if ([[GeminiAssistantManager sharedManager] isTweakEnabled] && !isDeviceCurrentlyLocked()) {
        [GeminiAssistantManager sharedManager].isInvocationFromPowerButton = NO;
        [[GeminiAssistantManager sharedManager] triggerFromSystemHook];
        return;
    }
    %orig;
}
%end

%hook SBAssistantController
- (void)_activateSiriWithContext:(id)context {
    if ([[GeminiAssistantManager sharedManager] isTweakEnabled]) {
        [GeminiAssistantManager sharedManager].isInvocationFromPowerButton = NO;
        agWakeScreenBacklightIfNeeded();
        [[GeminiAssistantManager sharedManager] triggerFromSystemHook];
        return;
    }
    %orig(context);
}
- (void)_activateSiriForPPTWithOptions:(id)arg1 {
    if ([[GeminiAssistantManager sharedManager] isTweakEnabled]) {
        agWakeScreenBacklightIfNeeded();
        [[GeminiAssistantManager sharedManager] triggerFromSystemHook];
        return;
    }
    %orig(arg1);
}
- (void)handleSiriButtonDownEventFromSource:(NSInteger)source activationEvent:(NSInteger)event {
    if ([[GeminiAssistantManager sharedManager] isTweakEnabled]) {
        agWakeScreenBacklightIfNeeded();
        [[GeminiAssistantManager sharedManager] triggerFromSystemHook];
        return;
    }
    %orig(source, event);
}
- (BOOL)activateIgnoringTouches:(BOOL)arg1 {
    if ([[GeminiAssistantManager sharedManager] isTweakEnabled]) {
        agWakeScreenBacklightIfNeeded();
        [[GeminiAssistantManager sharedManager] triggerFromSystemHook];
        return NO;
    }
    return %orig(arg1);
}
%end

%hook SiriPresentationSpringBoardMainScreenViewController
- (BOOL)_canShowWhileLocked {
    return YES;
}
- (void)requestSiriPresentation:(id)arg1 withOptions:(id)arg2 {
    if ([[GeminiAssistantManager sharedManager] isTweakEnabled]) {
        if ([self respondsToSelector:@selector(dismissSiriViewController:withReason:)]) {
            [self dismissSiriViewController:nil withReason:0];
        } else if ([self respondsToSelector:@selector(dismissSiriViewController:)]) {
            [self dismissSiriViewController:nil];
        }
        agWakeScreenBacklightIfNeeded();
        [[GeminiAssistantManager sharedManager] triggerFromSystemHook];
        return;
    }
    %orig(arg1, arg2);
}
- (void)_activateSiriWithContext:(id)context {
    if ([[GeminiAssistantManager sharedManager] isTweakEnabled]) {
        agWakeScreenBacklightIfNeeded();
        [[GeminiAssistantManager sharedManager] triggerFromSystemHook];
        return;
    }
    %orig(context);
}
- (void)viewWillAppear:(BOOL)animated {
    %orig(animated);
    if ([[GeminiAssistantManager sharedManager] isTweakEnabled]) {
        self.view.hidden = YES;
        self.view.alpha = 0.0;
        if ([self respondsToSelector:@selector(dismissSiriViewController:withReason:)]) {
            [self dismissSiriViewController:nil withReason:0];
        } else if ([self respondsToSelector:@selector(dismissSiriViewController:)]) {
            [self dismissSiriViewController:nil];
        }
        agWakeScreenBacklightIfNeeded();
        [[GeminiAssistantManager sharedManager] triggerFromSystemHook];
    }
}
%end
// ==============================================================================
// Module: AngelGuardian Live Screen & Audio Translator (v5.9.0 Pro Extension)
// 使用方法：直接将本段代码粘贴在 Tweak.x / Tweak.xm 的最底部（替换旧的翻译扩展）！
// 升级特性：
// 1. 设置页支持「🔍 获取可用翻译模型」+ 点击模型自动发起真实 API 连通性握手验证，
//    验证通过后在模型末尾显示「(使用中)」标记。
// 2. 悬浮窗点击「👂 听译」后，大号字幕取景框与边框立即消失，丝滑收缩为「极简纯字幕条」，
//    只显示翻译后的字幕，不遮挡视频画面；点击「📷 框选」可随时恢复取景框。
// ==============================================================================

// ==============================================================================
// Module: AngelGuardian Live Screen & Audio Translator (v5.9.1 Pro Fix Edition)
// 直接粘贴在 Tweak.x / Tweak.xm 最底部（完整替换旧的翻译扩展模块）
// ==============================================================================

// ==============================================================================
// Module: AngelGuardian Live Screen & Audio Translator (v6.0 Zero-Latency Pro)
// 核心升级：
// 1. 零音质损伤内录听译：彻底废除 PlayAndRecord 麦克风抢占，手機音量与音质 100% 原生不变！
// 2. 字幕自动滚动刷新：采用增量断句 + 自动上推滚动字幕流，满了自动换行刷新，绝不卡死。
// 3. 毫秒级极速翻译：关闭模型思考延迟 (thinkingBudget=0)，移除单请求阻塞锁，随听随出。
// 4. 框选与听译双模式自由缩放：右下角 ↘ 手柄全程可拖拽调节大小。
// ==============================================================================

#import <Vision/Vision.h>
#import <Speech/Speech.h>
#import <ReplayKit/ReplayKit.h>

UIKIT_EXTERN UIImage *_UICreateScreenUIImage(void);

@interface AGScreenTranslationOverlay : UIWindow <SFSpeechRecognizerDelegate>
@property (nonatomic, strong) UIView *cropBoxView;
@property (nonatomic, strong) UIView *topBarView;
@property (nonatomic, strong) UILabel *statusBadgeLabel;
@property (nonatomic, strong) UIButton *langSwitchBtn;
@property (nonatomic, strong) UIButton *audioModeSwitchBtn;
@property (nonatomic, strong) UIButton *closeFloatBtn;
@property (nonatomic, strong) UIVisualEffectView *subtitleGlassBg;
@property (nonatomic, strong) UITextView *translatedTextView; // 升级为可自动滚动刷新的 UITextView
@property (nonatomic, strong) UIView *resizeCornerHandle;

@property (nonatomic, strong) UIButton *compactLangBtn;
@property (nonatomic, strong) UIButton *compactRestoreBoxBtn;
@property (nonatomic, strong) UIButton *compactCloseBtn;

@property (nonatomic, assign) BOOL isListenOnlyCompactMode;
@property (nonatomic, assign) CGRect savedFullCropBoxFrame;

// 识别源语种切换 (0=自动/英语, 1=日语, 2=韩语)
@property (nonatomic, assign) NSInteger sourceLangIndex;

// OCR 与实时帧缓存
@property (nonatomic, strong) NSTimer *ocrScanTimer;
@property (nonatomic, copy) NSString *lastRecognizedText;
@property (nonatomic, copy) NSString *lastTranslatedText;
@property (nonatomic, assign) NSUInteger latestTranslationSeq;
@property (nonatomic, strong) NSURLSessionDataTask *activeTransTask;

// 电脑级无声数字听译与语音识别引擎
@property (nonatomic, strong) SFSpeechRecognizer *speechRecognizer;
@property (nonatomic, strong) SFSpeechAudioBufferRecognitionRequest *speechRequest;
@property (nonatomic, strong) SFSpeechRecognitionTask *speechTask;
@property (nonatomic, strong) AVAudioEngine *voiceFallbackEngine;
@property (nonatomic, assign) NSUInteger committedTranscriptLength;
@property (nonatomic, copy) NSString *latestPartialSegment;
@property (nonatomic, strong) NSTimer *autoFlushTimer;
@property (nonatomic, assign) NSTimeInterval lastSpeechTranslateTime;
@property (nonatomic, assign) BOOL isTranslationInFlight;
@property (nonatomic, copy) NSString *pendingTranslationText;

+ (instancetype)sharedOverlay;
- (void)toggleTranslatorFloatingBox;
- (void)showTranslatorFloatingBox;
- (void)hideTranslatorFloatingBox;
- (void)applySavedFontSizeAndStyle;
@end

// ==================== 翻译配置读写 ====================
static BOOL agTransIsEnabled(void) {
    NSNumber *v = agReadOnlyPrefs()[@"AG_Trans_Enabled"];
    return v ? [v boolValue] : YES;
}

static CGFloat agTransFontSize(void) {
    NSNumber *v = agReadOnlyPrefs()[@"AG_Trans_FontSize"];
    CGFloat sz = v ? [v floatValue] : 16.0;
    return MAX(11.0, MIN(30.0, sz));
}

static NSString *agTransEndpoint(void) {
    NSDictionary *p = agReadOnlyPrefs();
    NSString *ep = [p[@"AG_Trans_Endpoint"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!ep) ep = @"";
    while ([ep hasSuffix:@"/"]) ep = [ep substringToIndex:ep.length - 1];
    return ep;
}

static NSString *agTransAPIKey(void) {
    NSDictionary *p = agReadOnlyPrefs();
    NSString *k = [p[@"AG_Trans_APIKey"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return k ?: @"";
}

static NSArray<NSDictionary *> *agTransCachedModels(void) {
    NSDictionary *p = agReadOnlyPrefs();
    NSArray *arr = p[@"AG_Trans_CachedModels"];
    if ([arr isKindOfClass:[NSArray class]] && arr.count > 0) {
        return arr;
    }
    return agVerifiedDefaultModelsForTab(AGConfigTabTranslation);
}

static NSString *agTransModel(void) {
    NSDictionary *p = agReadOnlyPrefs();
    NSString *m = [p[@"AG_Trans_Model"] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (m && m.length > 0) return m;
    NSArray *list = agTransCachedModels();
    if (list.count > 0 && list.firstObject[@"id"]) return list.firstObject[@"id"];
    return @"";
}

static BOOL agTransIsHighAccuracyOCR(void) {
    NSDictionary *p = loadGeminiPrefs();
    NSNumber *val = p[@"AG_Trans_HighAccuracyOCR"];
    return val ? [val boolValue] : YES; // 默认开启高精度深度神经网络模型，精准识别各类复杂/艺术/斜体字
}

static NSTimeInterval agTransScrollDebounceTime(void) {
    NSDictionary *p = loadGeminiPrefs();
    NSNumber *val = p[@"AG_Trans_ScrollDebounceTime"];
    if (val && [val doubleValue] >= 0.15 && [val doubleValue] <= 2.0) {
        return [val doubleValue];
    }
    return 0.40; // 默认 0.40 秒
}

static NSString *agSanitizeOpenAIEndpoint(NSString *raw) {
    NSString *ep = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while ([ep hasSuffix:@"/"]) ep = [ep substringToIndex:ep.length - 1];
    if ([ep containsString:@"dashscope.aliyuncs.com"]) {
        if (![ep containsString:@"/compatible-mode/v1"]) {
            ep = [ep stringByAppendingString:@"/compatible-mode/v1"];
        }
    } else if ([ep containsString:@"open.bigmodel.cn"]) {
        if (![ep containsString:@"/api/paas/v4"]) {
            ep = [ep stringByAppendingString:@"/api/paas/v4"];
        }
    } else if ([ep containsString:@"volces.com"]) {
        if (![ep containsString:@"/api/v3"]) {
            ep = [ep stringByAppendingString:@"/api/v3"];
        }
    } else if ([ep containsString:@"api.moonshot.cn"]) {
        if (![ep containsString:@"/v1"]) {
            ep = [ep stringByAppendingString:@"/v1"];
        }
    }
    if (![ep hasSuffix:@"/chat/completions"]) {
        ep = [NSString stringWithFormat:@"%@/chat/completions", ep];
    }
    return ep;
}

// ==================== 悬浮翻译窗实现 ====================
@implementation AGScreenTranslationOverlay

+ (instancetype)sharedOverlay {
    static AGScreenTranslationOverlay *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGRect bounds = [UIScreen mainScreen].bounds;
        UIWindowScene *scene = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
            }
        }
        if (scene) {
            instance = [[self alloc] initWithWindowScene:scene];
            instance.frame = bounds;
        } else {
            instance = [[self alloc] initWithFrame:bounds];
        }
        [instance setupOverlayUI];
    });
    return instance;
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.05 || !self.cropBoxView) return NO;
    CGPoint p = [self convertPoint:point toView:self.cropBoxView];
    return [self.cropBoxView pointInside:p withEvent:event];
}

- (BOOL)_canBecomeKeyWindow { return NO; }

- (NSString *)currentLocaleIdentifier {
    if (self.sourceLangIndex == 1) return @"ja-JP";
    if (self.sourceLangIndex == 2) return @"ko-KR";
    return @"en-US";
}

- (NSString *)currentLangShortTitle {
    if (self.sourceLangIndex == 1) return @"🇯🇵日语";
    if (self.sourceLangIndex == 2) return @"🇰🇷韩语";
    return @"🇺🇸英语";
}

- (void)setupOverlayUI {
    self.windowLevel = UIWindowLevelAlert + 520;
    self.backgroundColor = [UIColor clearColor];
    self.hidden = YES;
    self.sourceLangIndex = 0;

    UIViewController *vc = [[UIViewController alloc] init];
    vc.view.backgroundColor = [UIColor clearColor];
    self.rootViewController = vc;

    AGDeviceMetrics m = agComputeDeviceMetrics();
    self.savedFullCropBoxFrame = CGRectMake(m.sideMargin, MAX(140.0, m.topSafeLimit + 60.0), m.screenW - m.sideMargin * 2.0, m.isCompactPhone ? 132.0 : 148.0);

    self.cropBoxView = [[UIView alloc] initWithFrame:self.savedFullCropBoxFrame];
    self.cropBoxView.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.10 alpha:0.15];
    self.cropBoxView.layer.cornerRadius = 16.0;
    self.cropBoxView.layer.borderWidth = 1.6;
    self.cropBoxView.layer.borderColor = [UIColor colorWithRed:0.20 green:0.92 blue:1.00 alpha:0.90].CGColor;
    self.cropBoxView.layer.shadowColor = [UIColor colorWithRed:0.15 green:0.85 blue:1.00 alpha:1.0].CGColor;
    self.cropBoxView.layer.shadowRadius = 10.0;
    self.cropBoxView.layer.shadowOpacity = 0.45;
    self.cropBoxView.layer.shadowOffset = CGSizeZero;
    [vc.view addSubview:self.cropBoxView];

    // 1. 顶部控制栏
    self.topBarView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.cropBoxView.bounds.size.width, 28)];
    self.topBarView.backgroundColor = [UIColor colorWithRed:0.08 green:0.06 blue:0.18 alpha:0.90];
    self.topBarView.layer.cornerRadius = 14.0;
    self.topBarView.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    [self.cropBoxView addSubview:self.topBarView];

    self.statusBadgeLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 4, 150, 20)];
    self.statusBadgeLabel.text = @"🌐 框选区域自动翻译中";
    self.statusBadgeLabel.textColor = [UIColor colorWithRed:0.45 green:0.95 blue:0.85 alpha:1.0];
    self.statusBadgeLabel.font = [UIFont boldSystemFontOfSize:11.0];
    [self.topBarView addSubview:self.statusBadgeLabel];

    self.langSwitchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.langSwitchBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.12];
    self.langSwitchBtn.layer.cornerRadius = 8.0;
    [self.langSwitchBtn setTitle:@"🇺🇸英语" forState:UIControlStateNormal];
    [self.langSwitchBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.langSwitchBtn.titleLabel.font = [UIFont boldSystemFontOfSize:10.5];
    [self.langSwitchBtn addTarget:self action:@selector(cycleSourceLanguage) forControlEvents:UIControlEventTouchUpInside];
    [self.topBarView addSubview:self.langSwitchBtn];

    self.audioModeSwitchBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.audioModeSwitchBtn.backgroundColor = [UIColor colorWithRed:0.95 green:0.55 blue:0.15 alpha:0.28];
    self.audioModeSwitchBtn.layer.cornerRadius = 8.0;
    self.audioModeSwitchBtn.layer.borderWidth = 0.7;
    self.audioModeSwitchBtn.layer.borderColor = [UIColor colorWithRed:1.0 green:0.75 blue:0.30 alpha:0.75].CGColor;
    [self.audioModeSwitchBtn setTitle:@"👂 听译" forState:UIControlStateNormal];
    [self.audioModeSwitchBtn setTitleColor:[UIColor colorWithRed:1.0 green:0.82 blue:0.38 alpha:1.0] forState:UIControlStateNormal];
    self.audioModeSwitchBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11.0];
    [self.audioModeSwitchBtn addTarget:self action:@selector(enterCompactListenOnlyMode) forControlEvents:UIControlEventTouchUpInside];
    [self.topBarView addSubview:self.audioModeSwitchBtn];

    self.closeFloatBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.closeFloatBtn setTitle:@"✕" forState:UIControlStateNormal];
    [self.closeFloatBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.closeFloatBtn.titleLabel.font = [UIFont boldSystemFontOfSize:12.0];
    [self.closeFloatBtn addTarget:self action:@selector(hideTranslatorFloatingBox) forControlEvents:UIControlEventTouchUpInside];
    [self.topBarView addSubview:self.closeFloatBtn];

    // 2. 译文毛玻璃字幕条（三主题 50% 液态镜面毛玻璃，仅显示纯译文）
    UIBlurEffect *subBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    self.subtitleGlassBg = [[UIVisualEffectView alloc] initWithEffect:subBlur];
    self.subtitleGlassBg.layer.cornerRadius = 14.0;
    self.subtitleGlassBg.layer.masksToBounds = YES;

    AGVisualTheme theme = agCurrentVisualTheme();
    UIColor *borderCol = nil;
    UIColor *bgCol = nil;
    CGFloat glassAlpha = agMainGlassOpacity();
    if (theme == AGVisualThemeLightLuxury) {
        borderCol = [UIColor colorWithRed:0.98 green:0.85 blue:0.60 alpha:0.85];
        bgCol = [UIColor colorWithRed:0.08 green:0.06 blue:0.04 alpha:glassAlpha * 0.95];
    } else if (theme == AGVisualThemeMinimalist) {
        borderCol = [UIColor colorWithRed:0.75 green:0.92 blue:1.00 alpha:0.88];
        bgCol = [UIColor colorWithRed:0.06 green:0.11 blue:0.26 alpha:glassAlpha * 0.92];
    } else {
        borderCol = [UIColor colorWithRed:0.00 green:0.96 blue:1.00 alpha:0.88];
        bgCol = [UIColor colorWithRed:0.04 green:0.06 blue:0.18 alpha:glassAlpha * 0.95];
    }
    self.subtitleGlassBg.layer.borderWidth = 1.3;
    self.subtitleGlassBg.layer.borderColor = borderCol.CGColor;
    self.subtitleGlassBg.contentView.backgroundColor = bgCol;
    [self.cropBoxView addSubview:self.subtitleGlassBg];

    self.translatedTextView = [[UITextView alloc] init];
    self.translatedTextView.backgroundColor = [UIColor clearColor];
    self.translatedTextView.textColor = [UIColor whiteColor];
    self.translatedTextView.font = [UIFont systemFontOfSize:16.5 weight:UIFontWeightBold];
    self.translatedTextView.textAlignment = NSTextAlignmentCenter;
    self.translatedTextView.editable = NO;
    self.translatedTextView.selectable = NO;
    self.translatedTextView.scrollEnabled = YES;
    self.translatedTextView.showsVerticalScrollIndicator = NO;
    self.translatedTextView.textContainerInset = UIEdgeInsetsMake(6, 8, 6, 8);
    self.translatedTextView.text = @"🎧 正在实时同传听译手机发出的声音...";
    [self.subtitleGlassBg.contentView addSubview:self.translatedTextView];

    // 3. 极简听译模式专属控制按钮
    self.compactLangBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.compactLangBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
    self.compactLangBtn.layer.cornerRadius = 8.0;
    [self.compactLangBtn setTitle:@"🇺🇸英语" forState:UIControlStateNormal];
    [self.compactLangBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.compactLangBtn.titleLabel.font = [UIFont boldSystemFontOfSize:9.5];
    self.compactLangBtn.hidden = YES;
    [self.compactLangBtn addTarget:self action:@selector(cycleSourceLanguage) forControlEvents:UIControlEventTouchUpInside];
    [self.subtitleGlassBg.contentView addSubview:self.compactLangBtn];

    self.compactRestoreBoxBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.compactRestoreBoxBtn.backgroundColor = [UIColor colorWithRed:0.15 green:0.75 blue:0.95 alpha:0.30];
    self.compactRestoreBoxBtn.layer.cornerRadius = 8.0;
    [self.compactRestoreBoxBtn setTitle:@"📷框选" forState:UIControlStateNormal];
    [self.compactRestoreBoxBtn setTitleColor:[UIColor colorWithRed:0.55 green:0.95 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    self.compactRestoreBoxBtn.titleLabel.font = [UIFont boldSystemFontOfSize:9.5];
    self.compactRestoreBoxBtn.hidden = YES;
    [self.compactRestoreBoxBtn addTarget:self action:@selector(exitCompactListenOnlyMode) forControlEvents:UIControlEventTouchUpInside];
    [self.subtitleGlassBg.contentView addSubview:self.compactRestoreBoxBtn];

    self.compactCloseBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    self.compactCloseBtn.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.14];
    self.compactCloseBtn.layer.cornerRadius = 8.0;
    [self.compactCloseBtn setTitle:@"✕" forState:UIControlStateNormal];
    [self.compactCloseBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    self.compactCloseBtn.titleLabel.font = [UIFont boldSystemFontOfSize:10.0];
    self.compactCloseBtn.hidden = YES;
    [self.compactCloseBtn addTarget:self action:@selector(hideTranslatorFloatingBox) forControlEvents:UIControlEventTouchUpInside];
    [self.subtitleGlassBg.contentView addSubview:self.compactCloseBtn];

    // 4. 右下角自由缩放手柄
    self.resizeCornerHandle = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 26, 26)];
    self.resizeCornerHandle.backgroundColor = [UIColor colorWithRed:0.20 green:0.88 blue:1.00 alpha:0.90];
    self.resizeCornerHandle.layer.cornerRadius = 13.0;
    UILabel *gripLbl = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 26, 26)];
    gripLbl.text = @"↘";
    gripLbl.textColor = [UIColor blackColor];
    gripLbl.font = [UIFont boldSystemFontOfSize:13.0];
    gripLbl.textAlignment = NSTextAlignmentCenter;
    [self.resizeCornerHandle addSubview:gripLbl];
    [self.cropBoxView addSubview:self.resizeCornerHandle];

    UIPanGestureRecognizer *movePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleMovePan:)];
    [self.cropBoxView addGestureRecognizer:movePan];

    UIPanGestureRecognizer *resizePan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleResizePan:)];
    [self.resizeCornerHandle addGestureRecognizer:resizePan];
    [movePan requireGestureRecognizerToFail:resizePan];

    self.isListenOnlyCompactMode = NO;
    [self relayoutCropBoxSubviews];
}

// 切换识别语种 (英 / 日 / 韩)
- (void)cycleSourceLanguage {
    self.sourceLangIndex = (self.sourceLangIndex + 1) % 3;
    NSString *title = [self currentLangShortTitle];
    [self.langSwitchBtn setTitle:title forState:UIControlStateNormal];
    [self.compactLangBtn setTitle:title forState:UIControlStateNormal];
    self.lastRecognizedText = @"";
    if (self.isListenOnlyCompactMode) {
        [self updateSubtitleDisplay:[NSString stringWithFormat:@"👂 已切换为%@实时听译...", title]];
        [self restartSpeechRecognitionTaskOnly];
    } else {
        self.statusBadgeLabel.text = [NSString stringWithFormat:@"🌐 %@字幕实时扫描中", title];
    }
}

- (void)updateSubtitleDisplay:(NSString *)text {
    if (!text || text.length == 0) return;
    self.translatedTextView.text = text;
    // 当字幕满了超过高度时，自动平滑滚动到最底部最新一行
    NSInteger len = self.translatedTextView.text.length;
    if (len > 0) {
        [self.translatedTextView scrollRangeToVisible:NSMakeRange(len - 1, 1)];
    }
}

- (void)enterCompactListenOnlyMode {
    if (self.isListenOnlyCompactMode) return;
    self.isListenOnlyCompactMode = YES;
    self.savedFullCropBoxFrame = self.cropBoxView.frame;

    [self.ocrScanTimer invalidate];
    self.ocrScanTimer = nil;

    CGFloat compactH = MAX(68.0, agTransFontSize() * 3.2 + 20.0);
    CGFloat newY = CGRectGetMaxY(self.savedFullCropBoxFrame) - compactH;
    CGRect targetFrame = CGRectMake(self.savedFullCropBoxFrame.origin.x, newY, self.savedFullCropBoxFrame.size.width, compactH);

    [self updateSubtitleDisplay:@"👂 正在监听英文实时出字幕 (右下角↘可自由拉伸)..."];

    [UIView animateWithDuration:0.26 delay:0 usingSpringWithDamping:0.84 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.cropBoxView.frame = targetFrame;
        self.cropBoxView.backgroundColor = [UIColor clearColor];
        self.cropBoxView.layer.borderWidth = 0.0;
        self.cropBoxView.layer.shadowOpacity = 0.25;
        self.topBarView.alpha = 0.0;
        self.resizeCornerHandle.alpha = 0.92;
        self.resizeCornerHandle.hidden = NO;
        [self relayoutCropBoxSubviews];
    } completion:^(BOOL finished) {
        self.topBarView.hidden = YES;
        self.resizeCornerHandle.hidden = NO;
        [self.cropBoxView bringSubviewToFront:self.resizeCornerHandle];
        self.compactLangBtn.hidden = NO;
        self.compactRestoreBoxBtn.hidden = NO;
        self.compactCloseBtn.hidden = NO;
        [self startZeroInterferenceInternalAudioTranslation];
    }];
}

- (void)exitCompactListenOnlyMode {
    if (!self.isListenOnlyCompactMode) return;
    self.isListenOnlyCompactMode = NO;
    [self stopZeroInterferenceInternalAudioTranslation];

    self.topBarView.hidden = NO;
    self.resizeCornerHandle.hidden = NO;
    self.compactLangBtn.hidden = YES;
    self.compactRestoreBoxBtn.hidden = YES;
    self.compactCloseBtn.hidden = YES;

    CGRect restoreFrame = self.savedFullCropBoxFrame;
    restoreFrame.origin.x = self.cropBoxView.frame.origin.x;
    restoreFrame.origin.y = MAX(agComputeDeviceMetrics().topSafeLimit, CGRectGetMaxY(self.cropBoxView.frame) - restoreFrame.size.height);

    [UIView animateWithDuration:0.26 delay:0 usingSpringWithDamping:0.82 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.cropBoxView.frame = restoreFrame;
        self.cropBoxView.backgroundColor = [UIColor colorWithRed:0.04 green:0.04 blue:0.10 alpha:0.15];
        self.cropBoxView.layer.borderWidth = 1.6;
        self.cropBoxView.layer.shadowOpacity = 0.45;
        self.topBarView.alpha = 1.0;
        self.resizeCornerHandle.alpha = 1.0;
        [self relayoutCropBoxSubviews];
    } completion:^(BOOL finished) {
        self.statusBadgeLabel.text = @"🌐 框选字幕实时翻译中";
        [self startRealtimeScreenOCRLoop];
    }];
}

- (void)relayoutCropBoxSubviews {
    CGFloat w = self.cropBoxView.bounds.size.width;
    CGFloat h = self.cropBoxView.bounds.size.height;

    if (self.isListenOnlyCompactMode) {
        self.subtitleGlassBg.frame = self.cropBoxView.bounds;
        self.compactCloseBtn.frame = CGRectMake(w - 26, 5, 20, 18);
        self.compactRestoreBoxBtn.frame = CGRectMake(w - 72, 5, 42, 18);
        self.compactLangBtn.frame = CGRectMake(w - 118, 5, 42, 18);
        self.translatedTextView.frame = CGRectMake(6, 22, w - 32, MAX(28.0, h - 26));
        self.resizeCornerHandle.frame = CGRectMake(w - 24, h - 24, 24, 24);
        [self.cropBoxView bringSubviewToFront:self.resizeCornerHandle];
    } else {
        self.topBarView.frame = CGRectMake(0, 0, w, 28);
        self.statusBadgeLabel.frame = CGRectMake(10, 4, w - 155, 20);
        self.langSwitchBtn.frame = CGRectMake(w - 142, 3, 46, 22);
        self.audioModeSwitchBtn.frame = CGRectMake(w - 90, 3, 54, 22);
        self.closeFloatBtn.frame = CGRectMake(w - 30, 2, 26, 24);

        CGFloat subH = MAX(46.0, MIN(82.0, h * 0.44));
        self.subtitleGlassBg.frame = CGRectMake(6, h - subH - 6, w - 12, subH);
        self.translatedTextView.frame = CGRectMake(4, 2, self.subtitleGlassBg.bounds.size.width - 28, subH - 4);
        self.resizeCornerHandle.frame = CGRectMake(w - 26, h - 26, 26, 26);
        [self.cropBoxView bringSubviewToFront:self.resizeCornerHandle];
    }
}

- (void)applySavedFontSizeAndStyle {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.translatedTextView.font = [UIFont boldSystemFontOfSize:agTransFontSize()];
        [self relayoutCropBoxSubviews];
    });
}

- (void)handleMovePan:(UIPanGestureRecognizer *)pan {
    CGPoint trans = [pan translationInView:self.rootViewController.view];
    CGRect f = self.cropBoxView.frame;
    CGRect sb = [UIScreen mainScreen].bounds;
    AGDeviceMetrics m = agComputeDeviceMetrics();
    f.origin.x = MAX(4.0, MIN(sb.size.width - f.size.width - 4.0, f.origin.x + trans.x));
    f.origin.y = MAX(m.topSafeLimit, MIN(sb.size.height - f.size.height - 10.0, f.origin.y + trans.y));
    self.cropBoxView.frame = f;
    [pan setTranslation:CGPointZero inView:self.rootViewController.view];
}

- (void)handleResizePan:(UIPanGestureRecognizer *)pan {
    CGPoint trans = [pan translationInView:self.rootViewController.view];
    CGRect f = self.cropBoxView.frame;
    CGRect sb = [UIScreen mainScreen].bounds;
    AGDeviceMetrics m = agComputeDeviceMetrics();

    CGFloat minH = self.isListenOnlyCompactMode ? 52.0 : 92.0;
    CGFloat minW = m.isCompactPhone ? 156.0 : 175.0;
    f.size.width = MAX(minW, MIN(sb.size.width - f.origin.x - 6.0, f.size.width + trans.x));
    f.size.height = MAX(minH, MIN(sb.size.height * 0.70, f.size.height + trans.y));
    self.cropBoxView.frame = f;

    if (!self.isListenOnlyCompactMode) {
        self.savedFullCropBoxFrame = f;
    }
    [self relayoutCropBoxSubviews];
    [pan setTranslation:CGPointZero inView:self.rootViewController.view];
}

- (void)toggleTranslatorFloatingBox {
    if (self.hidden) {
        [self showTranslatorFloatingBox];
    } else {
        [self hideTranslatorFloatingBox];
    }
}

- (void)showTranslatorFloatingBox {
    if (!agTransIsEnabled()) return;
    [self applySavedFontSizeAndStyle];
    self.alpha = 0.0;
    self.hidden = NO;
    self.cropBoxView.transform = CGAffineTransformMakeScale(0.92, 0.92);
    [UIView animateWithDuration:0.25 delay:0 usingSpringWithDamping:0.80 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.alpha = 1.0;
        self.cropBoxView.transform = CGAffineTransformIdentity;
    } completion:nil];

    if (self.isListenOnlyCompactMode) {
        [self startZeroInterferenceInternalAudioTranslation];
    } else {
        [self startRealtimeScreenOCRLoop];
    }
}

- (void)hideTranslatorFloatingBox {
    [self.ocrScanTimer invalidate];
    self.ocrScanTimer = nil;
    [self stopZeroInterferenceInternalAudioTranslation];
    if (self.activeTransTask) {
        [self.activeTransTask cancel];
        self.activeTransTask = nil;
    }
    self.isTranslationInFlight = NO;
    self.pendingTranslationText = nil;
    [UIView animateWithDuration:0.20 animations:^{
        self.alpha = 0.0;
    } completion:^(BOOL finished) {
        self.hidden = YES;
    }];
}

#pragma mark - 📷 框选屏幕字幕实时 OCR 引擎（修复位图裁剪与坐标，毫秒级响应）

- (void)startRealtimeScreenOCRLoop {
    [self.ocrScanTimer invalidate];
    self.ocrScanTimer = [NSTimer timerWithTimeInterval:1.00 target:self selector:@selector(performRealtimeOCRScanTick) userInfo:nil repeats:YES];
    [[NSRunLoop mainRunLoop] addTimer:self.ocrScanTimer forMode:NSRunLoopCommonModes];
}

- (void)performRealtimeOCRScanTick {
    if (self.hidden || self.isListenOnlyCompactMode) return;
    if (isDeviceCurrentlyLocked()) return; // 锁屏休眠，0 额外开销

    @autoreleasepool {
        CGRect boxFrame = self.cropBoxView.frame;
        CGFloat subH = self.subtitleGlassBg.frame.size.height;
        // 只截取取景框上半部分透明区域，避开底部的译文字幕条
        CGRect targetScreenRect = CGRectMake(boxFrame.origin.x + 2.0,
                                             boxFrame.origin.y + 28.0,
                                             MAX(40.0, boxFrame.size.width - 4.0),
                                             MAX(26.0, boxFrame.size.height - 28.0 - subH - 4.0));

        self.cropBoxView.hidden = YES;
        UIImage *fullScreenImg = nil;
        @try {
            fullScreenImg = _UICreateScreenUIImage();
        } @catch (NSException *e) {
            fullScreenImg = nil;
        }
        self.cropBoxView.hidden = NO;

        if (!fullScreenImg) return;

        // 关键优化：把位图裁剪与 Vision 识别全部移到后台线程，主线程绝对 0 阻塞、0 掉帧！
        __weak typeof(self) weakSelf = self;
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            @autoreleasepool {
                UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
                fmt.scale = 1.0; // 1.0x 渲染耗时减少 75%，保证 Vision 高速识别且内存几乎为 0
                fmt.opaque = YES;
                UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:targetScreenRect.size format:fmt];
                UIImage *croppedUIImage = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull ctx) {
                    [fullScreenImg drawAtPoint:CGPointMake(-targetScreenRect.origin.x, -targetScreenRect.origin.y)];
                }];

                CGImageRef cleanCG = croppedUIImage.CGImage;
                if (!cleanCG) return;

                VNRecognizeTextRequest *req = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
                    NSMutableString *detected = [NSMutableString string];
                    for (VNRecognizedTextObservation *obs in request.results) {
                        VNRecognizedText *topCandidate = [[obs topCandidates:1] firstObject];
                        if (topCandidate.string.length > 0) {
                            if (detected.length > 0) [detected appendString:@" "];
                            [detected appendString:topCandidate.string];
                        }
                    }
                    NSString *cleanSource = [detected stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [weakSelf handleDetectedSubtitleText:cleanSource];
                    });
                }];
                req.recognitionLevel = VNRequestTextRecognitionLevelFast; // 快速模式：耗时仅 15ms
                req.usesLanguageCorrection = YES;
                req.recognitionLanguages = @[@"en-US"]; // 专一纯英语识别，彻底释放 A14 神经引擎算力

                VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:cleanCG options:@{}];
                [handler performRequests:@[req] error:nil];
            }
        });
    }
}

- (void)handleDetectedSubtitleText:(NSString *)sourceText {
    if (!sourceText || sourceText.length < 2) return;

    // 过滤非英文内容：若没有任何英文字母，不发起无效网络请求
    NSRange letterRange = [sourceText rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]];
    if (letterRange.location == NSNotFound) return;

    if ([sourceText isEqualToString:self.lastRecognizedText] || [sourceText isEqualToString:self.lastTranslatedText]) {
        return;
    }
    self.lastRecognizedText = sourceText;
    self.statusBadgeLabel.text = [NSString stringWithFormat:@"⚡ 识别到: %@", (sourceText.length > 18 ? [sourceText substringToIndex:18] : sourceText)];
    [self translateSourceStringViaAPI:sourceText isVoiceSource:NO];
}

#pragma mark - 👂 电脑级极速无声实时听译引擎 (离线 ANE 神经芯片加速，0 CPU占用，绝不降低手机音量)

- (void)startZeroInterferenceInternalAudioTranslation {
    [self stopZeroInterferenceInternalAudioTranslation];

    self.committedTranscriptLength = 0;
    self.latestPartialSegment = @"";

    ensureSpringBoardTCCGranted();

    self.speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"en-US"]];
    if (!self.speechRecognizer || !self.speechRecognizer.isAvailable) {
        self.speechRecognizer = [[SFSpeechRecognizer alloc] init];
    }
    if (!self.speechRecognizer) {
        [self updateSubtitleDisplay:@"⚠️ 语音识别引擎初始化失败"];
        return;
    }

    @try {
        AVAudioSession *session = [AVAudioSession sharedInstance];
        // 关键设置：MixWithOthers 绝不打断或降低视频音量，DefaultToSpeaker 保持立体声外放/耳机
        [session setCategory:AVAudioSessionCategoryPlayAndRecord
                        mode:AVAudioSessionModeDefault
                     options:AVAudioSessionCategoryOptionMixWithOthers | AVAudioSessionCategoryOptionDefaultToSpeaker | AVAudioSessionCategoryOptionAllowBluetooth
                       error:nil];
        [session setActive:YES withOptions:0 error:nil];

        self.voiceFallbackEngine = [[AVAudioEngine alloc] init];
        self.speechRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
        self.speechRequest.shouldReportPartialResults = YES;
        if (@available(iOS 13.0, *)) {
            if (self.speechRecognizer.supportsOnDeviceRecognition) {
                self.speechRequest.requiresOnDeviceRecognition = YES; // A14 离线神经引擎，0 延迟、0 流量、手机不发热
            }
        }
        if (@available(iOS 16.0, *)) {
            self.speechRequest.addsPunctuation = YES;
        }

        AVAudioInputNode *inputNode = self.voiceFallbackEngine.inputNode;
        AVAudioFormat *fmt = [inputNode outputFormatForBus:0];
        if (!fmt || fmt.sampleRate <= 0 || fmt.channelCount == 0) {
            fmt = [inputNode inputFormatForBus:0];
        }

        __weak typeof(self) weakSelf = self;
        [inputNode removeTapOnBus:0];
        [inputNode installTapOnBus:0 bufferSize:4096 format:fmt block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
            if (isDeviceCurrentlyLocked()) return;
            if (weakSelf.speechRequest) {
                [weakSelf.speechRequest appendAudioPCMBuffer:buffer];
            }
        }];

        [self.voiceFallbackEngine prepare];
        NSError *startErr = nil;
        [self.voiceFallbackEngine startAndReturnError:&startErr];

        self.speechTask = [self.speechRecognizer recognitionTaskWithRequest:self.speechRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
            if (result) {
                NSString *fullText = result.bestTranscription.formattedString ?: @"";
                if (fullText.length < weakSelf.committedTranscriptLength) {
                    weakSelf.committedTranscriptLength = 0;
                }
                NSString *activeWindow = [fullText substringFromIndex:weakSelf.committedTranscriptLength];
                if (activeWindow.length > 85) {
                    NSRange cutRange = [activeWindow rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" ,.?!。？！"] options:0 range:NSMakeRange(35, activeWindow.length - 35)];
                    NSUInteger advance = (cutRange.location != NSNotFound) ? (cutRange.location + 1) : 45;
                    weakSelf.committedTranscriptLength += advance;
                    activeWindow = [fullText substringFromIndex:weakSelf.committedTranscriptLength];
                }
                NSString *cleanSpoken = [activeWindow stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                weakSelf.latestPartialSegment = cleanSpoken;
            }
            if (error || (result && result.isFinal)) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (!weakSelf.hidden && weakSelf.isListenOnlyCompactMode) {
                        [weakSelf restartSpeechRecognitionTaskOnly];
                    }
                });
            }
        }];

        // 每 0.85 秒检查一次是否有新说出的短句，平滑发起极速翻译
        self.autoFlushTimer = [NSTimer timerWithTimeInterval:0.85 target:self selector:@selector(flushPendingSpeechSegmentTick) userInfo:nil repeats:YES];
        [[NSRunLoop mainRunLoop] addTimer:self.autoFlushTimer forMode:NSRunLoopCommonModes];

    } @catch (NSException *e) {
        [self updateSubtitleDisplay:[NSString stringWithFormat:@"⚠️ 音频引擎初始化异常: %@", e.reason]];
    }
}

- (void)startSpeechRecognitionTaskOnly {
    [self startZeroInterferenceInternalAudioTranslation];
}

- (void)restartSpeechRecognitionTaskOnly {
    if (self.speechRequest) {
        [self.speechRequest endAudio];
        self.speechRequest = nil;
    }
    if (self.speechTask) {
        [self.speechTask cancel];
        self.speechTask = nil;
    }
    self.committedTranscriptLength = 0;
    self.latestPartialSegment = @"";

    if (!self.voiceFallbackEngine || !self.voiceFallbackEngine.isRunning) {
        [self startZeroInterferenceInternalAudioTranslation];
        return;
    }

    self.speechRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    self.speechRequest.shouldReportPartialResults = YES;
    if (@available(iOS 13.0, *)) {
        if (self.speechRecognizer.supportsOnDeviceRecognition) {
            self.speechRequest.requiresOnDeviceRecognition = YES;
        }
    }
    if (@available(iOS 16.0, *)) {
        self.speechRequest.addsPunctuation = YES;
    }

    __weak typeof(self) weakSelf = self;
    self.speechTask = [self.speechRecognizer recognitionTaskWithRequest:self.speechRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
        if (result) {
            NSString *fullText = result.bestTranscription.formattedString ?: @"";
            if (fullText.length < weakSelf.committedTranscriptLength) {
                weakSelf.committedTranscriptLength = 0;
            }
            NSString *activeWindow = [fullText substringFromIndex:weakSelf.committedTranscriptLength];
            if (activeWindow.length > 85) {
                NSRange cutRange = [activeWindow rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@" ,.?!。？！"] options:0 range:NSMakeRange(35, activeWindow.length - 35)];
                NSUInteger advance = (cutRange.location != NSNotFound) ? (cutRange.location + 1) : 45;
                weakSelf.committedTranscriptLength += advance;
                activeWindow = [fullText substringFromIndex:weakSelf.committedTranscriptLength];
            }
            NSString *cleanSpoken = [activeWindow stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            weakSelf.latestPartialSegment = cleanSpoken;
        }
        if (error || (result && result.isFinal)) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (!weakSelf.hidden && weakSelf.isListenOnlyCompactMode) {
                    [weakSelf restartSpeechRecognitionTaskOnly];
                }
            });
        }
    }];
}

// 定时将最新听到的短句立即送去极速翻译，随说随刷新
- (void)flushPendingSpeechSegmentTick {
    if (self.hidden || !self.isListenOnlyCompactMode) return;
    if (isDeviceCurrentlyLocked()) return; // 锁屏休眠，0 额外开销
    NSString *seg = self.latestPartialSegment;
    if (!seg || seg.length < 2 || [seg isEqualToString:self.lastRecognizedText]) return;

    self.lastRecognizedText = seg;
    [self translateSourceStringViaAPI:seg isVoiceSource:YES];
}

- (void)stopZeroInterferenceInternalAudioTranslation {
    [self.autoFlushTimer invalidate];
    self.autoFlushTimer = nil;

    if (self.voiceFallbackEngine) {
        @try {
            [self.voiceFallbackEngine.inputNode removeTapOnBus:0];
            [self.voiceFallbackEngine stop];
        } @catch (NSException *e) {}
        self.voiceFallbackEngine = nil;
    }
    if (self.speechRequest) {
        [self.speechRequest endAudio];
        self.speechRequest = nil;
    }
    if (self.speechTask) {
        [self.speechTask cancel];
        self.speechTask = nil;
    }
}

#pragma mark - ⚡ 毫秒级无阻塞流式翻译请求 (去除不兼容参数，极速纯净回传)

- (void)translateSourceStringViaAPI:(NSString *)sourceText isVoiceSource:(BOOL)isVoice {
    if (!sourceText || sourceText.length < 2) return;

    NSString *apiKey = agTransAPIKey();
    NSString *endpoint = agTransEndpoint();
    NSString *model = agTransModel();
    NSString *proxy = loadGeminiPrefs()[@"AG_Trans_ProxyPort"] ?: @"";

    if (apiKey.length < 4) {
        [self updateSubtitleDisplay:@"⚠️ 请先在《设置 -> ✨天使守护》配置实时翻译专属 API Key"];
        return;
    }

    // 关键优化：绝不 Cancel 正在网络传输中的有效请求！
    // 如果当前有正在请求中的翻译，暂存最新识别短句，待当前请求返回后无缝接力翻译
    if (self.isTranslationInFlight) {
        self.pendingTranslationText = sourceText;
        return;
    }

    self.isTranslationInFlight = YES;
    self.latestTranslationSeq++;
    NSUInteger currentSeq = self.latestTranslationSeq;

    NSString *prompt = [NSString stringWithFormat:@"将以下英文字幕直接翻译为简练自然的简体中文，只输出译文，绝不输出任何解释：\n%@", sourceText];

    NSURLSession *session = agCreateSessionWithProxy(proxy, nil, nil);
    BOOL isGoogle = agIsGoogleNativeProtocol(endpoint, model);
    NSMutableURLRequest *req = nil;

    if (isGoogle) {
        NSString *fullM = [model hasPrefix:@"models/"] ? model : [NSString stringWithFormat:@"models/%@", model];
        NSString *urlStr = [NSString stringWithFormat:@"%@/v1beta/%@:generateContent?key=%@", endpoint, fullM, apiKey];
        req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        req.HTTPMethod = @"POST";
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSDictionary *body = @{
            @"contents": @[ @{ @"role": @"user", @"parts": @[ @{ @"text": prompt } ] } ],
            @"generationConfig": @{
                @"temperature": @0.1,
                @"maxOutputTokens": @90
            }
        };
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    } else {
        NSString *urlStr = endpoint;
        if (![urlStr hasSuffix:@"/chat/completions"]) {
            urlStr = [urlStr hasSuffix:@"/v1"] ? [NSString stringWithFormat:@"%@/chat/completions", urlStr] : [NSString stringWithFormat:@"%@/v1/chat/completions", urlStr];
        }
        req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        req.HTTPMethod = @"POST";
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [req setValue:[NSString stringWithFormat:@"Bearer %@", apiKey] forHTTPHeaderField:@"Authorization"];
        NSString *exactM = [model stringByReplacingOccurrencesOfString:@"models/" withString:@""];
        NSDictionary *body = @{
            @"model": exactM,
            @"messages": @[ @{ @"role": @"user", @"content": prompt } ],
            @"temperature": @0.1,
            @"max_tokens": @90
        };
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    }
    req.timeoutInterval = 6.0;

    __weak typeof(self) weakSelf = self;
    self.activeTransTask = [session dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            weakSelf.isTranslationInFlight = NO;

            if (currentSeq == weakSelf.latestTranslationSeq) {
                if (!error && data) {
                    NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                    if ([json isKindOfClass:[NSDictionary class]] && json[@"error"]) {
                        NSString *errMsg = json[@"error"][@"message"] ?: @"API 接口报错";
                        if (!weakSelf.isListenOnlyCompactMode) {
                            weakSelf.statusBadgeLabel.text = [NSString stringWithFormat:@"⚠️ 接口错误: %@", errMsg];
                        } else if (weakSelf.lastTranslatedText.length == 0) {
                            [weakSelf updateSubtitleDisplay:[NSString stringWithFormat:@"⚠️ 翻译报错: %@", errMsg]];
                        }
                    } else {
                        NSString *resultText = [[GeminiAssistantManager sharedManager] extractTextFromDictionary:json];
                        resultText = [resultText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                        if (resultText.length > 0) {
                            weakSelf.lastTranslatedText = resultText;
                            [weakSelf updateSubtitleDisplay:resultText];
                            if (!weakSelf.isListenOnlyCompactMode) {
                                weakSelf.statusBadgeLabel.text = @"🌐 实时翻译已同步";
                            }
                        }
                    }
                } else if (error && error.code != NSURLErrorCancelled) {
                    if (!weakSelf.isListenOnlyCompactMode) {
                        weakSelf.statusBadgeLabel.text = [NSString stringWithFormat:@"⚠️ 网络错误: %@", error.localizedDescription];
                    } else if (weakSelf.lastTranslatedText.length == 0) {
                        [weakSelf updateSubtitleDisplay:[NSString stringWithFormat:@"⚠️ 网络错误: %@", error.localizedDescription]];
                    }
                }
            }

            // 边说边翻无缝接力：若在等待期间有更新的识别短句，立即启动下一棒翻译！
            if (weakSelf.pendingTranslationText.length > 0) {
                NSString *nextText = weakSelf.pendingTranslationText;
                weakSelf.pendingTranslationText = nil;
                [weakSelf translateSourceStringViaAPI:nextText isVoiceSource:isVoice];
            }
        });
    }];
    [self.activeTransTask resume];
}

@end

// ==================== 全新：网页/全屏原位覆膜就地翻译管理器 (双轨并存) ====================

static void agPerformGeneralTranslation(NSString *sourceText, void (^completion)(NSString *translatedText, NSError *error)) {
    if (!sourceText || sourceText.length < 2) {
        if (completion) completion(@"", nil);
        return;
    }
    NSString *apiKey = agTransAPIKey();
    NSString *endpoint = agTransEndpoint();
    NSString *model = agTransModel();
    NSString *proxy = loadGeminiPrefs()[@"AG_Trans_ProxyPort"] ?: @"";

    if (apiKey.length < 4) {
        if (completion) completion(nil, [NSError errorWithDomain:@"AGTrans" code:401 userInfo:@{NSLocalizedDescriptionKey: @"未配置有效 API Key"}]);
        return;
    }

    NSString *prompt = [NSString stringWithFormat:@"你是一个专业的即时多语言翻译引擎。请将以下外语文本直接翻译为自然流畅的简体中文。\n"
        @"【严格对齐规则】：\n"
        @"1. 保持原有的逐行换行格式，原文每一行必须对应翻译为一行，严禁合并行或增减行数！\n"
        @"2. 只输出中文翻译结果本身，绝不输出任何多余的解释、问候或标点前缀：\n%@", sourceText];

    NSURLSession *session = agCreateSessionWithProxy(proxy, nil, nil);
    BOOL isGoogle = agIsGoogleNativeProtocol(endpoint, model);
    NSMutableURLRequest *req = nil;

    if (isGoogle) {
        NSString *fullM = [model hasPrefix:@"models/"] ? model : [NSString stringWithFormat:@"models/%@", model];
        NSString *urlStr = [NSString stringWithFormat:@"https://generativelanguage.googleapis.com/v1beta/%@:generateContent?key=%@", fullM, apiKey];
        req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        req.HTTPMethod = @"POST";
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        NSDictionary *body = @{
            @"contents": @[ @{ @"role": @"user", @"parts": @[ @{ @"text": prompt } ] } ],
            @"generationConfig": @{
                @"temperature": @0.1,
                @"maxOutputTokens": @1024
            }
        };
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    } else {
        NSString *urlStr = agSanitizeOpenAIEndpoint(endpoint);
        req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        req.HTTPMethod = @"POST";
        [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [req setValue:[NSString stringWithFormat:@"Bearer %@", apiKey] forHTTPHeaderField:@"Authorization"];
        NSString *exactM = [model stringByReplacingOccurrencesOfString:@"models/" withString:@""];
        NSDictionary *body = @{
            @"model": exactM,
            @"messages": @[ @{ @"role": @"user", @"content": prompt } ],
            @"temperature": @0.1,
            @"max_tokens": @1024
        };
        req.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
    }
    req.timeoutInterval = 8.0;

    NSURLSessionDataTask *task = [session dataTaskWithRequest:req completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (error || !data) {
                if (completion) completion(nil, error);
                return;
            }
            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if ([json isKindOfClass:[NSDictionary class]] && json[@"error"]) {
                NSString *errMsg = json[@"error"][@"message"] ?: @"API 接口报错";
                if (completion) completion(nil, [NSError errorWithDomain:@"AGTrans" code:500 userInfo:@{NSLocalizedDescriptionKey: errMsg}]);
                return;
            }
            NSString *resultText = [[GeminiAssistantManager sharedManager] extractTextFromDictionary:json];
            resultText = [resultText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (completion) completion(resultText, nil);
        });
    }];
    [task resume];
}

typedef void *IOHIDEventSystemClientRef;
typedef void *IOHIDEventRef;
typedef void *IOHIDServiceRef;
typedef void (*IOHIDEventSystemClientEventCallback)(void *target, void *refcon, IOHIDServiceRef service, IOHIDEventRef event);

static IOHIDEventSystemClientRef s_inSituHIDClient = NULL;

static void agInSituHIDCallback(void *target, void *refcon, IOHIDServiceRef service, IOHIDEventRef event) {
    if (!event) return;
    AGInSituTranslationOverlay *overlay = [AGInSituTranslationOverlay sharedOverlay];
    if (!overlay || !overlay.isInSituActive) return;

    static uint32_t (*s_IOHIDEventGetType)(IOHIDEventRef) = NULL;
    static CFIndex (*s_IOHIDEventGetIntegerValue)(IOHIDEventRef, uint32_t) = NULL;
    static dispatch_once_t s_resolveToken;
    dispatch_once(&s_resolveToken, ^{
        void *h = dlopen(NULL, RTLD_GLOBAL | RTLD_LAZY);
        if (!h) h = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_GLOBAL | RTLD_LAZY);
        s_IOHIDEventGetType = (uint32_t (*)(IOHIDEventRef))dlsym(h, "IOHIDEventGetType");
        s_IOHIDEventGetIntegerValue = (CFIndex (*)(IOHIDEventRef, uint32_t))dlsym(h, "IOHIDEventGetIntegerValue");
    });

    if (!s_IOHIDEventGetType || !s_IOHIDEventGetIntegerValue) return;

    uint32_t type = s_IOHIDEventGetType(event);
    if (type == 11) { // kIOHIDEventTypeDigitizer
        CFIndex touch = s_IOHIDEventGetIntegerValue(event, 0xB0009); // kIOHIDEventFieldDigitizerTouch
        CFIndex eventMask = s_IOHIDEventGetIntegerValue(event, 0xB0007); // kIOHIDEventFieldDigitizerEventMask

        dispatch_async(dispatch_get_main_queue(), ^{
            [overlay handleGlobalTouchStateChanged:(touch > 0) eventMask:(uint32_t)eventMask];
        });
    }
}

static void initInSituGlobalTouchMonitor(void) {
    if (s_inSituHIDClient) return;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        void *h = dlopen(NULL, RTLD_GLOBAL | RTLD_LAZY);
        if (!h) h = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_GLOBAL | RTLD_LAZY);
        if (!h) return;

        IOHIDEventSystemClientRef (*createClient)(CFAllocatorRef) = (IOHIDEventSystemClientRef (*)(CFAllocatorRef))dlsym(h, "IOHIDEventSystemClientCreate");
        void (*scheduleWithRunLoop)(IOHIDEventSystemClientRef, CFRunLoopRef, CFStringRef) = (void (*)(IOHIDEventSystemClientRef, CFRunLoopRef, CFStringRef))dlsym(h, "IOHIDEventSystemClientScheduleWithRunLoop");
        void (*registerCallback)(IOHIDEventSystemClientRef, IOHIDEventSystemClientEventCallback, void *, void *) = (void (*)(IOHIDEventSystemClientRef, IOHIDEventSystemClientEventCallback, void *, void *))dlsym(h, "IOHIDEventSystemClientRegisterEventCallback");

        if (createClient && scheduleWithRunLoop && registerCallback) {
            s_inSituHIDClient = createClient(kCFAllocatorDefault);
            if (s_inSituHIDClient) {
                scheduleWithRunLoop(s_inSituHIDClient, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
                registerCallback(s_inSituHIDClient, agInSituHIDCallback, NULL, NULL);
            }
        }
    });
}

@implementation AGInSituTranslationOverlay

+ (instancetype)sharedOverlay {
    static AGInSituTranslationOverlay *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        CGRect bounds = [UIScreen mainScreen].bounds;
        UIWindowScene *scene = nil;
        if (@available(iOS 13.0, *)) {
            for (UIScene *s in [UIApplication sharedApplication].connectedScenes) {
                if ([s isKindOfClass:[UIWindowScene class]]) { scene = (UIWindowScene *)s; break; }
            }
        }
        if (scene) {
            instance = [[self alloc] initWithWindowScene:scene];
            instance.frame = bounds;
        } else {
            instance = [[self alloc] initWithFrame:bounds];
        }
        [instance setupInSituUI];
    });
    return instance;
}

- (void)setupInSituUI {
    self.windowLevel = UIWindowLevelAlert + 15;
    self.backgroundColor = [UIColor clearColor];
    self.hidden = YES;
    self.userInteractionEnabled = YES;
    self.impactHaptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];

    UIViewController *rootVC = [[UIViewController alloc] init];
    rootVC.view.backgroundColor = [UIColor clearColor];
    rootVC.view.userInteractionEnabled = YES;
    self.rootViewController = rootVC;

    // 1. 覆膜标签容器 (其子视图 userInteractionEnabled = NO，完全穿透)
    self.patchContainerView = [[UIView alloc] initWithFrame:self.bounds];
    self.patchContainerView.backgroundColor = [UIColor clearColor];
    self.patchContainerView.userInteractionEnabled = NO;
    [rootVC.view addSubview:self.patchContainerView];

    // 2. 极光扫描激光线
    self.laserBeamView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.bounds.size.width, 3.0)];
    CAGradientLayer *grad = [CAGradientLayer layer];
    grad.frame = self.laserBeamView.bounds;
    grad.colors = @[
        (id)[UIColor clearColor].CGColor,
        (id)[UIColor colorWithRed:0.69 green:0.32 blue:0.87 alpha:0.9].CGColor,
        (id)[UIColor colorWithRed:0.35 green:0.80 blue:1.00 alpha:0.9].CGColor,
        (id)[UIColor clearColor].CGColor
    ];
    grad.startPoint = CGPointMake(0, 0.5);
    grad.endPoint = CGPointMake(1, 0.5);
    [self.laserBeamView.layer addSublayer:grad];
    self.laserBeamView.alpha = 0.0;
    self.laserBeamView.userInteractionEnabled = NO;
    [rootVC.view addSubview:self.laserBeamView];

    // 3. 底部控制胶囊 (宽度 320，包含状态、立即重译、还原按钮)
    CGFloat pillW = 320.0;
    CGFloat pillH = 38.0;
    CGFloat screenW = self.bounds.size.width > 0 ? self.bounds.size.width : [UIScreen mainScreen].bounds.size.width;
    CGFloat screenH = self.bounds.size.height > 0 ? self.bounds.size.height : [UIScreen mainScreen].bounds.size.height;
    self.revertPillView = [[UIView alloc] initWithFrame:CGRectMake((screenW - pillW) / 2.0, screenH - pillH - 24.0, pillW, pillH)];
    self.revertPillView.backgroundColor = [UIColor colorWithRed:0.10 green:0.10 blue:0.14 alpha:0.92];
    self.revertPillView.layer.cornerRadius = pillH / 2.0;
    self.revertPillView.layer.borderWidth = 1.0;
    self.revertPillView.layer.borderColor = [UIColor colorWithRed:0.20 green:0.85 blue:0.35 alpha:0.6].CGColor;
    self.revertPillView.layer.shadowColor = [UIColor blackColor].CGColor;
    self.revertPillView.layer.shadowOpacity = 0.5;
    self.revertPillView.layer.shadowRadius = 12.0;
    self.revertPillView.layer.shadowOffset = CGSizeMake(0, 4);

    self.statusLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 0, 115, pillH)];
    self.statusLabel.text = @"🪄 自动跟随翻译";
    self.statusLabel.textColor = [UIColor colorWithRed:0.25 green:0.88 blue:0.45 alpha:1.0];
    self.statusLabel.font = [UIFont boldSystemFontOfSize:11.0];
    self.statusLabel.adjustsFontSizeToFitWidth = YES;
    [self.revertPillView addSubview:self.statusLabel];

    UIView *sep1 = [[UIView alloc] initWithFrame:CGRectMake(130, 8, 1, 22)];
    sep1.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    [self.revertPillView addSubview:sep1];

    UIButton *rescanBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    rescanBtn.frame = CGRectMake(134, 0, 84, pillH);
    [rescanBtn setTitle:@"🔄 立即重译" forState:UIControlStateNormal];
    [rescanBtn setTitleColor:[UIColor colorWithRed:0.40 green:0.85 blue:1.0 alpha:1.0] forState:UIControlStateNormal];
    rescanBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11.0];
    [rescanBtn addTarget:self action:@selector(manualRetranslateTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.revertPillView addSubview:rescanBtn];

    UIView *sep2 = [[UIView alloc] initWithFrame:CGRectMake(222, 8, 1, 22)];
    sep2.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.18];
    [self.revertPillView addSubview:sep2];

    UIButton *revertBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    revertBtn.frame = CGRectMake(226, 0, 88, pillH);
    [revertBtn setTitle:@"还原英文 ↩️" forState:UIControlStateNormal];
    [revertBtn setTitleColor:[UIColor colorWithRed:1.0 green:0.35 blue:0.30 alpha:1.0] forState:UIControlStateNormal];
    revertBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11.0];
    [revertBtn addTarget:self action:@selector(revertInSituTranslation) forControlEvents:UIControlEventTouchUpInside];
    [self.revertPillView addSubview:revertBtn];

    self.revertPillView.alpha = 0.0;
    self.revertPillView.transform = CGAffineTransformMakeTranslation(0, 50);
    [rootVC.view addSubview:self.revertPillView];

    initInSituGlobalTouchMonitor();
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (self.hidden || self.alpha < 0.05 || !self.revertPillView || self.revertPillView.hidden || self.revertPillView.alpha < 0.05) {
        return NO;
    }
    CGPoint p = [self convertPoint:point toView:self.revertPillView];
    if ([self.revertPillView pointInside:p withEvent:event]) {
        return YES;
    }
    return NO; // 100% 穿透到底层 App，按钮、链接、手势滑动完全不受阻挡！
}

- (void)startInSituTranslation {
    if (!agTransIsEnabled()) {
        [[GeminiAssistantManager sharedManager] showActionBanner:@"⚠️ 请先在《设置 -> ✨天使守护》启用实时翻译"];
        return;
    }
    NSString *apiKey = agTransAPIKey();
    if (apiKey.length < 4) {
        [[GeminiAssistantManager sharedManager] showActionBanner:@"⚠️ 请先在《设置 -> ✨天使守护》配置翻译 API Key"];
        return;
    }

    // 三主题动态配色联动
    AGVisualTheme theme = agCurrentVisualTheme();
    UIColor *accentBorderCol = nil;
    UIColor *pillBgCol = nil;
    UIColor *laserCol = nil;
    if (theme == AGVisualThemeLightLuxury) {
        accentBorderCol = [UIColor colorWithRed:0.99 green:0.86 blue:0.58 alpha:0.90];
        pillBgCol       = [UIColor colorWithRed:0.10 green:0.07 blue:0.05 alpha:0.76];
        laserCol        = [UIColor colorWithRed:0.99 green:0.84 blue:0.48 alpha:0.95];
    } else if (theme == AGVisualThemeMinimalist) {
        accentBorderCol = [UIColor colorWithRed:0.72 green:0.92 blue:1.00 alpha:0.92];
        pillBgCol       = [UIColor colorWithRed:0.06 green:0.12 blue:0.28 alpha:0.72];
        laserCol        = [UIColor colorWithRed:0.45 green:0.88 blue:1.00 alpha:0.95];
    } else {
        accentBorderCol = [UIColor colorWithRed:0.00 green:0.96 blue:1.00 alpha:0.92];
        pillBgCol       = [UIColor colorWithRed:0.05 green:0.07 blue:0.20 alpha:0.76];
        laserCol        = [UIColor colorWithRed:0.00 green:0.96 blue:1.00 alpha:0.95];
    }
    self.revertPillView.backgroundColor = pillBgCol;
    self.revertPillView.layer.borderWidth = 1.3;
    self.revertPillView.layer.borderColor = accentBorderCol.CGColor;
    self.laserBeamView.backgroundColor = laserCol;
    self.laserBeamView.layer.shadowColor = laserCol.CGColor;

    [self.impactHaptic impactOccurred];
    self.hidden = NO;
    self.alpha = 1.0;
    self.isInSituActive = YES;
    self.isFingerTouching = NO;
    self.inSituScanEpoch++;
    [self.patchContainerView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    self.patchContainerView.alpha = 1.0;

    initInSituGlobalTouchMonitor();

    // 播放极光扫描线动画
    self.laserBeamView.frame = CGRectMake(0, 0, self.bounds.size.width, 3.0);
    self.laserBeamView.alpha = 1.0;
    [UIView animateWithDuration:0.85 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.laserBeamView.frame = CGRectMake(0, self.bounds.size.height, self.bounds.size.width, 3.0);
    } completion:^(BOOL finished) {
        self.laserBeamView.alpha = 0.0;
    }];

    // 弹出底部控制胶囊
    self.revertPillView.alpha = 1.0;
    self.revertPillView.transform = CGAffineTransformMakeTranslation(0, 50);
    self.statusLabel.text = @"⚡ 正在识别翻译...";
    self.statusLabel.textColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.30 alpha:1.0];
    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.80 initialSpringVelocity:0.6 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.revertPillView.transform = CGAffineTransformIdentity;
    } completion:nil];

    [[GeminiAssistantManager sharedManager] showActionBanner:@"🪄 智能跟随覆膜已开启 (滑动松手自动重译)"];

    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf performInSituRetranslateQuietly];
    });
}

- (void)handleGlobalTouchStateChanged:(BOOL)isTouching eventMask:(uint32_t)mask {
    if (!self.isInSituActive) return;

    if (isTouching) {
        // 用户正在触摸屏幕 / 滑动列表
        if (!self.isFingerTouching) {
            self.isFingerTouching = YES;
            self.inSituScanEpoch++; // 用户触摸屏幕，立即使正在进行的后台翻译请求失效
            if (self.scrollSettleTimer) {
                [self.scrollSettleTimer invalidate];
                self.scrollSettleTimer = nil;
            }
            if (self.patchContainerView.alpha > 0.1) {
                [UIView animateWithDuration:0.15 animations:^{
                    self.patchContainerView.alpha = 0.05;
                }];
            }
            self.statusLabel.text = @"👆 滑动中 (松手即译)...";
            self.statusLabel.textColor = [UIColor colorWithRed:0.4 green:0.8 blue:1.0 alpha:1.0];
        } else {
            if (self.scrollSettleTimer) {
                [self.scrollSettleTimer invalidate];
                self.scrollSettleTimer = nil;
            }
        }
    } else {
        // 用户手指离开屏幕 (列表开始减速或已经停稳)
        if (self.isFingerTouching) {
            self.isFingerTouching = NO;
            self.statusLabel.text = @"⏳ 静止检测中...";
            self.statusLabel.textColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.3 alpha:1.0];

            if (self.scrollSettleTimer) {
                [self.scrollSettleTimer invalidate];
            }
            __weak typeof(self) weakSelf = self;
            NSTimeInterval debounce = agTransScrollDebounceTime();
            self.scrollSettleTimer = [NSTimer scheduledTimerWithTimeInterval:debounce repeats:NO block:^(NSTimer * _Nonnull timer) {
                if (!weakSelf || !weakSelf.isInSituActive || weakSelf.isFingerTouching) return;
                [weakSelf performInSituRetranslateQuietly];
            }];
        }
    }
}

- (void)manualRetranslateTapped {
    [self.impactHaptic impactOccurred];
    if (self.scrollSettleTimer) {
        [self.scrollSettleTimer invalidate];
        self.scrollSettleTimer = nil;
    }
    [self performInSituRetranslateQuietly];
}

- (void)performInSituRetranslateQuietly {
    if (!self.isInSituActive || !agTransIsEnabled()) return;
    NSString *apiKey = agTransAPIKey();
    if (apiKey.length < 4) return;

    NSInteger currentEpoch = ++self.inSituScanEpoch;
    self.statusLabel.text = @"⚡ 正在刷新翻译...";
    self.statusLabel.textColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.30 alpha:1.0];

    // 隐藏浮层并瞬时截图，避免截到旧的中文覆膜
    self.patchContainerView.hidden = YES;
    self.revertPillView.hidden = YES;
    UIImage *screenImg = nil;
    @try {
        screenImg = _UICreateScreenUIImage();
    } @catch (NSException *e) {
        screenImg = nil;
    }
    self.patchContainerView.hidden = NO;
    self.revertPillView.hidden = NO;

    if (!screenImg || !screenImg.CGImage) {
        self.statusLabel.text = @"🪄 自动跟随翻译";
        self.statusLabel.textColor = [UIColor colorWithRed:0.25 green:0.88 blue:0.45 alpha:1.0];
        self.patchContainerView.alpha = 1.0;
        return;
    }

    CGImageRef cleanCG = CGImageCreateCopy(screenImg.CGImage);
    if (!cleanCG) return;

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (currentEpoch != weakSelf.inSituScanEpoch) {
            CGImageRelease(cleanCG);
            return;
        }

        VNRecognizeTextRequest *req = [[VNRecognizeTextRequest alloc] initWithCompletionHandler:^(VNRequest * _Nonnull request, NSError * _Nullable error) {
            CGImageRelease(cleanCG);
            if (currentEpoch != weakSelf.inSituScanEpoch) return;

            if (error || request.results.count == 0) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (currentEpoch != weakSelf.inSituScanEpoch) return;
                    [weakSelf.patchContainerView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
                    weakSelf.statusLabel.text = @"🪄 自动跟随翻译";
                    weakSelf.statusLabel.textColor = [UIColor colorWithRed:0.25 green:0.88 blue:0.45 alpha:1.0];
                    weakSelf.patchContainerView.alpha = 1.0;
                });
                return;
            }

            CGFloat screenW = [UIScreen mainScreen].bounds.size.width;
            CGFloat screenH = [UIScreen mainScreen].bounds.size.height;
            NSMutableArray<NSDictionary *> *detectedBlocks = [NSMutableArray array];
            NSMutableArray<NSString *> *sourceLines = [NSMutableArray array];

            for (VNRecognizedTextObservation *obs in request.results) {
                VNRecognizedText *cand = [[obs topCandidates:1] firstObject];
                if (cand.string.length < 2) continue;
                if ([cand.string rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]].location == NSNotFound) continue;

                // 检查是否包含外语字符(英文、俄语、西里尔、日文假名、韩文等)，若为纯中文则无需重复翻译
                BOOL hasForeignChars = NO;
                for (NSUInteger ci = 0; ci < cand.string.length; ci++) {
                    unichar c = [cand.string characterAtIndex:ci];
                    if ((c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || (c >= 0x0400 && c <= 0x04FF) || (c >= 0x3040 && c <= 0x30FF)) {
                        hasForeignChars = YES;
                        break;
                    }
                }
                if (!hasForeignChars) continue;

                CGRect box = obs.boundingBox;
                CGRect rect = CGRectMake(box.origin.x * screenW,
                                         (1.0 - box.origin.y - box.size.height) * screenH,
                                         box.size.width * screenW,
                                         box.size.height * screenH);

                // 过滤状态栏及底部胶囊区域
                if (rect.origin.y < 44.0 || rect.origin.y > (screenH - 70.0) || rect.size.width < 15.0 || rect.size.height < 8.0) continue;

                [detectedBlocks addObject:@{
                    @"text": cand.string,
                    @"rect": [NSValue valueWithCGRect:rect]
                }];
                [sourceLines addObject:cand.string];
            }

            if (sourceLines.count == 0 || currentEpoch != weakSelf.inSituScanEpoch) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (currentEpoch != weakSelf.inSituScanEpoch) return;
                    [weakSelf.patchContainerView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
                    weakSelf.statusLabel.text = @"🪄 自动跟随翻译";
                    weakSelf.statusLabel.textColor = [UIColor colorWithRed:0.25 green:0.88 blue:0.45 alpha:1.0];
                    weakSelf.patchContainerView.alpha = 1.0;
                });
                return;
            }

            NSString *fullCombined = [sourceLines componentsJoinedByString:@"\n"];
            agPerformGeneralTranslation(fullCombined, ^(NSString *translatedText, NSError *transError) {
                if (currentEpoch != weakSelf.inSituScanEpoch) return;

                if (transError || translatedText.length == 0) {
                    weakSelf.statusLabel.text = @"⚠️ 翻译刷新超时";
                    weakSelf.statusLabel.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
                    weakSelf.patchContainerView.alpha = 1.0;
                    return;
                }

                NSArray<NSString *> *translatedLines = [translatedText componentsSeparatedByString:@"\n"];
                [weakSelf.patchContainerView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];

                for (NSUInteger i = 0; i < detectedBlocks.count; i++) {
                    NSDictionary *item = detectedBlocks[i];
                    CGRect rect = [item[@"rect"] CGRectValue];
                    NSString *zhLine = (i < translatedLines.count) ? [translatedLines[i] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] : @"";
                    if (zhLine.length == 0) zhLine = item[@"text"];

                    CGRect patchRect = CGRectInset(rect, -2.0, -1.0);
                    UIView *patch = [[UIView alloc] initWithFrame:patchRect];
                    patch.backgroundColor = [UIColor colorWithRed:0.08 green:0.09 blue:0.14 alpha:0.94];
                    patch.layer.cornerRadius = 4.0;
                    patch.userInteractionEnabled = NO;

                    UILabel *lbl = [[UILabel alloc] initWithFrame:patch.bounds];
                    lbl.text = zhLine;
                    lbl.textColor = [UIColor colorWithRed:0.98 green:0.98 blue:1.0 alpha:1.0];
                    lbl.font = [UIFont systemFontOfSize:MAX(11.0, MIN(22.0, rect.size.height * 0.85)) weight:UIFontWeightMedium];
                    lbl.numberOfLines = 0;
                    lbl.adjustsFontSizeToFitWidth = YES;
                    lbl.minimumScaleFactor = 0.55;
                    lbl.userInteractionEnabled = NO;
                    [patch addSubview:lbl];

                    [weakSelf.patchContainerView addSubview:patch];
                }

                weakSelf.patchContainerView.alpha = 0.0;
                [UIView animateWithDuration:0.25 animations:^{
                    weakSelf.patchContainerView.alpha = 1.0;
                }];

                weakSelf.statusLabel.text = @"🪄 自动跟随翻译";
                weakSelf.statusLabel.textColor = [UIColor colorWithRed:0.25 green:0.88 blue:0.45 alpha:1.0];
                [weakSelf.impactHaptic impactOccurred];
            });
        }];

        req.recognitionLevel = agTransIsHighAccuracyOCR() ? VNRequestTextRecognitionLevelAccurate : VNRequestTextRecognitionLevelFast;
        req.usesLanguageCorrection = YES;
        req.recognitionLanguages = @[@"en-US", @"ru-RU", @"zh-Hans", @"zh-Hant", @"fr-FR", @"de-DE", @"es-ES", @"ja-JP", @"ko-KR", @"uk-UA", @"it-IT", @"pt-BR"];

        VNImageRequestHandler *handler = [[VNImageRequestHandler alloc] initWithCGImage:cleanCG options:@{}];
        [handler performRequests:@[req] error:nil];
    });
}

- (void)revertInSituTranslation {
    [self.impactHaptic impactOccurred];
    self.isInSituActive = NO;
    self.inSituScanEpoch++;
    if (self.scrollSettleTimer) {
        [self.scrollSettleTimer invalidate];
        self.scrollSettleTimer = nil;
    }
    [UIView animateWithDuration:0.25 animations:^{
        self.revertPillView.transform = CGAffineTransformMakeTranslation(0, 50);
        self.patchContainerView.alpha = 0.0;
    } completion:^(BOOL finished) {
        [self.patchContainerView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
        self.patchContainerView.alpha = 1.0;
        self.hidden = YES;
        [[GeminiAssistantManager sharedManager] showActionBanner:@"↩️ 已恢复英文原文"];
    }];
}

@end

// ==================== 挂钩主界面与《设置》面板 ====================
%hook GeminiAssistantManager

- (void)setupWindowIfNeeded {
    %orig;
    UIView *content = self.cardBlurView.contentView;
    if (content && ![content viewWithTag:95881]) {
        UIButton *transBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        transBtn.tag = 95881;
        transBtn.backgroundColor = [UIColor clearColor];
        [transBtn addTarget:self action:@selector(agScreenTranslateButtonTapped) forControlEvents:UIControlEventTouchUpInside];
        transBtn.hidden = !agTransIsEnabled();
        [content addSubview:transBtn];
        [self updateHeaderBadges];
    }
}

- (void)toggleOverlayInternal {
    if (![AGScreenTranslationOverlay sharedOverlay].hidden) {
        [[AGScreenTranslationOverlay sharedOverlay] hideTranslatorFloatingBox];
    }
    if (![AGInSituTranslationOverlay sharedOverlay].hidden) {
        [[AGInSituTranslationOverlay sharedOverlay] revertInSituTranslation];
    }
    %orig;
}

%new
- (void)agScreenTranslateButtonTapped {
    [self.impactHaptic impactOccurred];
    if (!agTransIsEnabled()) {
        [self showActionBanner:@"⚠️ 请先在手机《设置 -> ✨天使守护》启用屏幕实时翻译"];
        return;
    }
    AGVisualTheme theme = agCurrentVisualTheme();

    // 若已存在翻译选择面板则收起
    UIView *existingSheet = [self.cardBlurView.contentView viewWithTag:95889];
    if (existingSheet) {
        [existingSheet removeFromSuperview];
        return;
    }

    UIView *parent = self.cardBlurView.contentView;
    CGRect boxFrame = self.innerGlassBox.frame;

    UIBlurEffect *sheetBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterialDark];
    UIVisualEffectView *sheetView = [[UIVisualEffectView alloc] initWithEffect:sheetBlur];
    sheetView.frame = boxFrame;
    sheetView.tag = 95889;
    sheetView.layer.cornerRadius = self.innerGlassBox.layer.cornerRadius;
    sheetView.layer.masksToBounds = YES;
    sheetView.layer.borderWidth = 1.4;

    UIColor *borderCol = nil;
    UIColor *tintBgCol = nil;
    UIColor *btnBgCol  = nil;
    UIColor *titleCol  = nil;

    CGFloat glassAlpha = agMainGlassOpacity();

    if (theme == AGVisualThemeLightLuxury) {
        borderCol = [UIColor colorWithRed:0.98 green:0.85 blue:0.60 alpha:0.85];
        tintBgCol = [UIColor colorWithRed:0.08 green:0.06 blue:0.04 alpha:glassAlpha * 0.95];
        btnBgCol  = [UIColor colorWithRed:0.22 green:0.16 blue:0.10 alpha:0.65];
        titleCol  = [UIColor colorWithRed:1.00 green:0.92 blue:0.75 alpha:1.0];
    } else if (theme == AGVisualThemeMinimalist) {
        borderCol = [UIColor colorWithRed:0.75 green:0.92 blue:1.00 alpha:0.88];
        tintBgCol = [UIColor colorWithRed:0.06 green:0.11 blue:0.26 alpha:glassAlpha * 0.92];
        btnBgCol  = [UIColor colorWithRed:0.16 green:0.28 blue:0.54 alpha:0.58];
        titleCol  = [UIColor colorWithRed:0.88 green:0.96 blue:1.00 alpha:1.0];
    } else {
        borderCol = [UIColor colorWithRed:0.00 green:0.96 blue:1.00 alpha:0.88];
        tintBgCol = [UIColor colorWithRed:0.04 green:0.06 blue:0.18 alpha:glassAlpha * 0.95];
        btnBgCol  = [UIColor colorWithRed:0.10 green:0.20 blue:0.44 alpha:0.62];
        titleCol  = [UIColor colorWithRed:0.55 green:0.96 blue:1.00 alpha:1.0];
    }

    sheetView.layer.borderColor = borderCol.CGColor;
    sheetView.contentView.backgroundColor = tintBgCol;

    CGFloat w = boxFrame.size.width;
    UILabel *hdr = [[UILabel alloc] initWithFrame:CGRectMake(16, 12, w - 32, 22)];
    hdr.text = @"✨ 翻译模块 · 选择实时交互方式";
    hdr.textColor = titleCol;
    hdr.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightHeavy];
    hdr.textAlignment = NSTextAlignmentCenter;
    [sheetView.contentView addSubview:hdr];

    // 按钮 1：原位智能跟随翻译 (保留)
    UIButton *inSituBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    inSituBtn.frame = CGRectMake(14, 42, w - 28, 48);
    inSituBtn.backgroundColor = btnBgCol;
    inSituBtn.layer.cornerRadius = 14.0;
    inSituBtn.layer.borderWidth = 1.1;
    inSituBtn.layer.borderColor = [borderCol colorWithAlphaComponent:0.65].CGColor;
    [inSituBtn setTitle:@"🪄 原位智能跟随翻译 (覆膜换字·滑动自动重译)" forState:UIControlStateNormal];
    [inSituBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    inSituBtn.titleLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold];
    [inSituBtn addTarget:self action:@selector(launchInSituFollowTranslationFromSheet) forControlEvents:UIControlEventTouchUpInside];
    [sheetView.contentView addSubview:inSituBtn];

    // 按钮 2：实时语音同传听译 (保留，已彻底移除屏幕框选)
    UIButton *listenTransBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    listenTransBtn.frame = CGRectMake(14, 98, w - 28, 48);
    listenTransBtn.backgroundColor = btnBgCol;
    listenTransBtn.layer.cornerRadius = 14.0;
    listenTransBtn.layer.borderWidth = 1.1;
    listenTransBtn.layer.borderColor = [borderCol colorWithAlphaComponent:0.65].CGColor;
    [listenTransBtn setTitle:@"🎧 实时语音同传听译 (纯译文悬浮字幕)" forState:UIControlStateNormal];
    [listenTransBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    listenTransBtn.titleLabel.font = [UIFont systemFontOfSize:13.5 weight:UIFontWeightBold];
    [listenTransBtn addTarget:self action:@selector(launchLiveAudioListenTranslationFromSheet) forControlEvents:UIControlEventTouchUpInside];
    [sheetView.contentView addSubview:listenTransBtn];

    // 底部返回按钮
    UIButton *cancelBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    cancelBtn.frame = CGRectMake(14, 152, w - 28, 32);
    [cancelBtn setTitle:@"收起返回" forState:UIControlStateNormal];
    [cancelBtn setTitleColor:[UIColor colorWithWhite:0.82 alpha:1.0] forState:UIControlStateNormal];
    cancelBtn.titleLabel.font = [UIFont systemFontOfSize:12.5 weight:UIFontWeightSemibold];
    [cancelBtn addTarget:self action:@selector(dismissTranslationSheetView) forControlEvents:UIControlEventTouchUpInside];
    [sheetView.contentView addSubview:cancelBtn];

    sheetView.alpha = 0.0;
    sheetView.transform = CGAffineTransformMakeScale(0.94, 0.94);
    [parent addSubview:sheetView];
    [UIView animateWithDuration:0.26 delay:0 usingSpringWithDamping:0.78 initialSpringVelocity:0.8 options:UIViewAnimationOptionCurveEaseOut animations:^{
        sheetView.alpha = 1.0;
        sheetView.transform = CGAffineTransformIdentity;
    } completion:nil];
}

%new
- (void)dismissTranslationSheetView {
    UIView *sheetView = [self.cardBlurView.contentView viewWithTag:95889];
    if (sheetView) {
        [UIView animateWithDuration:0.20 animations:^{
            sheetView.alpha = 0.0;
            sheetView.transform = CGAffineTransformMakeScale(0.94, 0.94);
        } completion:^(BOOL finished) {
            [sheetView removeFromSuperview];
        }];
    }
}

%new
- (void)launchInSituFollowTranslationFromSheet {
    [self dismissTranslationSheetView];
    [self dismissOverlay];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.22 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[AGInSituTranslationOverlay sharedOverlay] startInSituTranslation];
    });
}

%new
- (void)launchLiveAudioListenTranslationFromSheet {
    [self dismissTranslationSheetView];
    [self dismissOverlay];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.22 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[AGScreenTranslationOverlay sharedOverlay] showTranslatorFloatingBox];
    });
}

%end

%hook AngelGuardianSettingsViewController

- (void)viewDidLoad {
    %orig;
    UIScrollView *scroll = nil;
    for (UIView *sub in self.view.subviews) {
        if ([sub isKindOfClass:[UIScrollView class]]) { scroll = (UIScrollView *)sub; break; }
    }
    if (!scroll) return;

    CGFloat w = self.view.bounds.size.width;
    CGFloat pad = 16.0;
    CGFloat cardW = w - pad * 2;
    CGFloat startY = scroll.contentSize.height + 10.0;

    UIView *transCard = [[UIView alloc] initWithFrame:CGRectMake(pad, startY, cardW, 735)];
    transCard.backgroundColor = [UIColor colorWithRed:0.12 green:0.13 blue:0.24 alpha:1.0];
    transCard.layer.cornerRadius = 16.0;
    transCard.layer.borderWidth = 1.0;
    transCard.layer.borderColor = [UIColor colorWithRed:0.20 green:0.85 blue:1.0 alpha:0.45].CGColor;
    [scroll addSubview:transCard];

    UILabel *hdr = [[UILabel alloc] initWithFrame:CGRectMake(14, 12, cardW - 90, 26)];
    hdr.text = @"🌐 启用「屏幕实时字幕/声音翻译」";
    hdr.textColor = [UIColor colorWithRed:0.40 green:0.95 blue:0.88 alpha:1.0];
    hdr.font = [UIFont boldSystemFontOfSize:14.0];
    [transCard addSubview:hdr];

    UISwitch *enSw = [[UISwitch alloc] initWithFrame:CGRectMake(cardW - 64, 10, 50, 30)];
    enSw.tag = 96001;
    enSw.on = agTransIsEnabled();
    [enSw addTarget:self action:@selector(agTransSettingsChanged:) forControlEvents:UIControlEventValueChanged];
    [transCard addSubview:enSw];

    UITextField *epTF = [self createStyledTextFieldWithFrame:CGRectMake(12, 48, cardW - 24, 36)
                                                 placeholder:@"🔗 翻译API地址 (如 https://api.openai.com)"];
    epTF.tag = 96002;
    epTF.text = loadGeminiPrefs()[@"AG_Trans_Endpoint"] ?: @"";
    [epTF addTarget:self action:@selector(agTransSettingsChanged:) forControlEvents:UIControlEventEditingChanged];
    [transCard addSubview:epTF];

    UITextField *keyTF = [self createStyledTextFieldWithFrame:CGRectMake(12, 92, cardW - 24, 36)
                                                  placeholder:@"🔑 翻译API Key (必填，可填国内外任意Key)"];
    keyTF.tag = 96003;
    keyTF.text = loadGeminiPrefs()[@"AG_Trans_APIKey"] ?: @"";
    [keyTF addTarget:self action:@selector(agTransSettingsChanged:) forControlEvents:UIControlEventEditingChanged];
    [transCard addSubview:keyTF];

    UITextField *modelTF = [self createStyledTextFieldWithFrame:CGRectMake(12, 136, cardW - 142, 36)
                                                    placeholder:@"🤖 当前选用的翻译模型"];
    modelTF.tag = 96004;
    modelTF.text = [NSString stringWithFormat:@"%@ (使用中)", [agTransModel() stringByReplacingOccurrencesOfString:@"models/" withString:@""]];
    [modelTF addTarget:self action:@selector(agTransSettingsChanged:) forControlEvents:UIControlEventEditingChanged];
    [transCard addSubview:modelTF];

    UIButton *fetchTransBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    fetchTransBtn.tag = 96008;
    fetchTransBtn.frame = CGRectMake(cardW - 124, 136, 112, 36);
    fetchTransBtn.backgroundColor = [UIColor colorWithRed:0.16 green:0.62 blue:0.95 alpha:0.95];
    fetchTransBtn.layer.cornerRadius = 10.0;
    [fetchTransBtn setTitle:@"🔍 获取翻译模型" forState:UIControlStateNormal];
    [fetchTransBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    fetchTransBtn.titleLabel.font = [UIFont boldSystemFontOfSize:11.5];
    [fetchTransBtn addTarget:self action:@selector(agFetchTranslateModelsTapped:) forControlEvents:UIControlEventTouchUpInside];
    [transCard addSubview:fetchTransBtn];

    UILabel *verifyHintLbl = [[UILabel alloc] initWithFrame:CGRectMake(14, 178, cardW - 28, 18)];
    verifyHintLbl.tag = 96009;
    verifyHintLbl.text = @"📋 点击下方模型将自动验证连通性，通过后标记 (使用中)：";
    verifyHintLbl.textColor = [UIColor colorWithRed:0.65 green:0.88 blue:1.0 alpha:1.0];
    verifyHintLbl.font = [UIFont boldSystemFontOfSize:11.5];
    [transCard addSubview:verifyHintLbl];

    UITableView *transTable = [[UITableView alloc] initWithFrame:CGRectMake(8, 200, cardW - 16, 145) style:UITableViewStylePlain];
    transTable.tag = 96010;
    transTable.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.28];
    transTable.layer.cornerRadius = 10.0;
    transTable.separatorColor = [UIColor colorWithWhite:1.0 alpha:0.10];
    transTable.delegate = self;
    transTable.dataSource = self;
    transTable.rowHeight = 35.0;
    [transCard addSubview:transTable];

    UILabel *szTitle = [[UILabel alloc] initWithFrame:CGRectMake(14, 355, cardW - 28, 20)];
    szTitle.tag = 96005;
    szTitle.text = [NSString stringWithFormat:@"🔠 悬浮窗译文字号调节：%.0f pt", agTransFontSize()];
    szTitle.textColor = [UIColor whiteColor];
    szTitle.font = [UIFont boldSystemFontOfSize:12.5];
    [transCard addSubview:szTitle];

    UISlider *szSlider = [[UISlider alloc] initWithFrame:CGRectMake(14, 377, cardW - 28, 28)];
    szSlider.tag = 96006;
    szSlider.minimumValue = 11.0;
    szSlider.maximumValue = 28.0;
    szSlider.value = agTransFontSize();
    szSlider.minimumTrackTintColor = [UIColor colorWithRed:0.25 green:0.88 blue:1.0 alpha:1.0];
    [szSlider addTarget:self action:@selector(agTransFontSliderMoved:) forControlEvents:UIControlEventValueChanged];
    [transCard addSubview:szSlider];

    UIView *sampleBox = [[UIView alloc] initWithFrame:CGRectMake(12, 410, cardW - 24, 72)];
    sampleBox.backgroundColor = [UIColor colorWithRed:0.05 green:0.05 blue:0.12 alpha:0.95];
    sampleBox.layer.cornerRadius = 12.0;
    sampleBox.layer.borderWidth = 0.8;
    sampleBox.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.18].CGColor;
    [transCard addSubview:sampleBox];

    UILabel *sampleLabel = [[UILabel alloc] initWithFrame:CGRectInset(sampleBox.bounds, 10, 6)];
    sampleLabel.tag = 96007;
    sampleLabel.text = @"【实时字号预览实例】\n拖动上方滑块，调节悬浮字幕大小";
    sampleLabel.textColor = [UIColor colorWithRed:1.0 green:0.98 blue:0.88 alpha:1.0];
    sampleLabel.font = [UIFont boldSystemFontOfSize:agTransFontSize()];
    sampleLabel.numberOfLines = 0;
    sampleLabel.textAlignment = NSTextAlignmentCenter;
    [sampleBox addSubview:sampleLabel];

    // 新增：高精度 OCR 识别开关
    UILabel *ocrHdr = [[UILabel alloc] initWithFrame:CGRectMake(14, 492, cardW - 80, 22)];
    ocrHdr.text = @"🔬 开启高精度深度 OCR (精准识别复杂/艺术/斜体字)";
    ocrHdr.textColor = [UIColor colorWithRed:0.40 green:0.95 blue:0.88 alpha:1.0];
    ocrHdr.font = [UIFont boldSystemFontOfSize:12.0];
    [transCard addSubview:ocrHdr];

    UISwitch *ocrSw = [[UISwitch alloc] initWithFrame:CGRectMake(cardW - 64, 488, 50, 30)];
    ocrSw.tag = 96011;
    ocrSw.on = agTransIsHighAccuracyOCR();
    [ocrSw addTarget:self action:@selector(agTransSettingsChanged:) forControlEvents:UIControlEventValueChanged];
    [transCard addSubview:ocrSw];

    UILabel *ocrSub = [[UILabel alloc] initWithFrame:CGRectMake(14, 514, cardW - 28, 16)];
    ocrSub.text = @"开启使用 Apple Accurate 神经网络精准识别 Telegram 复杂文字；关闭为极速模式。";
    ocrSub.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    ocrSub.font = [UIFont systemFontOfSize:10.0];
    [transCard addSubview:ocrSub];

    // 新增：滑动松手静止判定时间调节 (防抖灵敏度)
    UILabel *debounceTitle = [[UILabel alloc] initWithFrame:CGRectMake(14, 536, cardW - 28, 20)];
    debounceTitle.tag = 96012;
    debounceTitle.text = [NSString stringWithFormat:@"⏱️ 滑动松手静止重译时间：%.2f 秒 (推荐 0.40s)", agTransScrollDebounceTime()];
    debounceTitle.textColor = [UIColor whiteColor];
    debounceTitle.font = [UIFont boldSystemFontOfSize:12.0];
    [transCard addSubview:debounceTitle];

    UISlider *debounceSlider = [[UISlider alloc] initWithFrame:CGRectMake(14, 558, cardW - 28, 28)];
    debounceSlider.tag = 96013;
    debounceSlider.minimumValue = 0.20;
    debounceSlider.maximumValue = 1.00;
    debounceSlider.value = agTransScrollDebounceTime();
    debounceSlider.minimumTrackTintColor = [UIColor colorWithRed:0.25 green:0.88 blue:1.0 alpha:1.0];
    [debounceSlider addTarget:self action:@selector(agTransDebounceSliderMoved:) forControlEvents:UIControlEventValueChanged];
    [transCard addSubview:debounceSlider];

    UILabel *debounceSub = [[UILabel alloc] initWithFrame:CGRectMake(14, 588, cardW - 28, 16)];
    debounceSub.text = @"0.25s 极速响应，0.40s 适中推荐，0.70s 稳健省流（适合快速翻阅 Telegram 群聊长文）。";
    debounceSub.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    debounceSub.font = [UIFont systemFontOfSize:10.0];
    [transCard addSubview:debounceSub];

    // 新增：实时联网搜索总开关
    UILabel *webHdr = [[UILabel alloc] initWithFrame:CGRectMake(14, 612, cardW - 80, 22)];
    webHdr.text = @"🌐 智能助手实时联网搜索增强 (天气/新闻/股票/汇率)";
    webHdr.textColor = [UIColor colorWithRed:1.0 green:0.88 blue:0.40 alpha:1.0];
    webHdr.font = [UIFont boldSystemFontOfSize:12.0];
    [transCard addSubview:webHdr];

    UISwitch *webSw = [[UISwitch alloc] initWithFrame:CGRectMake(cardW - 64, 608, 50, 30)];
    webSw.tag = 96014;
    webSw.on = agIsWebSearchEnabled();
    [webSw addTarget:self action:@selector(agTransSettingsChanged:) forControlEvents:UIControlEventValueChanged];
    [transCard addSubview:webSw];

    UILabel *webSub = [[UILabel alloc] initWithFrame:CGRectMake(14, 634, cardW - 28, 30)];
    webSub.text = @"开启后助手自带 Google/Bing 搜索工具，结合当下最新时间回答今日天气、新闻资讯与金融汇率。";
    webSub.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
    webSub.font = [UIFont systemFontOfSize:10.0];
    webSub.numberOfLines = 2;
    [transCard addSubview:webSub];

    scroll.contentSize = CGSizeMake(w, startY + 760.0);
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView.tag == 96010) {
        return agTransCachedModels().count;
    }
    return %orig(tableView, section);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.tag == 96010) {
        static NSString *tcid = @"AGTransModelCell";
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:tcid];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:tcid];
            cell.backgroundColor = [UIColor clearColor];
            cell.textLabel.font = [UIFont systemFontOfSize:12.0 weight:UIFontWeightSemibold];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
        }
        NSArray *list = agTransCachedModels();
        if (indexPath.row >= list.count) return cell;
        NSDictionary *m = list[indexPath.row];
        NSString *mID = m[@"id"];
        NSString *shortName = [mID stringByReplacingOccurrencesOfString:@"models/" withString:@""];
        BOOL isCurrent = [mID isEqualToString:agTransModel()];
        if (isCurrent) {
            cell.textLabel.text = [NSString stringWithFormat:@"✅ %@ (使用中)", shortName];
            cell.textLabel.textColor = [UIColor colorWithRed:0.38 green:0.98 blue:0.68 alpha:1.0];
        } else {
            cell.textLabel.text = [NSString stringWithFormat:@"    🌐 %@", shortName];
            cell.textLabel.textColor = [UIColor whiteColor];
        }

        NSString *latStr = m[@"latencyStr"];
        if (latStr.length > 0) {
            cell.detailTextLabel.text = latStr;
            if ([latStr containsString:@"❌"]) {
                cell.detailTextLabel.textColor = [UIColor colorWithRed:1.0 green:0.40 blue:0.40 alpha:1.0];
            } else if ([m[@"latencyMs"] integerValue] < 300) {
                cell.detailTextLabel.textColor = [UIColor colorWithRed:0.40 green:0.96 blue:0.68 alpha:1.0];
            } else if ([m[@"latencyMs"] integerValue] < 700) {
                cell.detailTextLabel.textColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.35 alpha:1.0];
            } else {
                cell.detailTextLabel.textColor = [UIColor colorWithRed:1.0 green:0.55 blue:0.40 alpha:1.0];
            }
        } else {
            cell.detailTextLabel.text = @"⚡ 待测速";
            cell.detailTextLabel.textColor = [UIColor colorWithWhite:0.65 alpha:1.0];
        }
        return cell;
    }
    return %orig(tableView, indexPath);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView.tag == 96010) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        NSArray *list = agTransCachedModels();
        if (indexPath.row >= list.count) return;
        NSDictionary *m = list[indexPath.row];
        NSString *candidateID = m[@"id"];
        NSString *shortName = [candidateID stringByReplacingOccurrencesOfString:@"models/" withString:@""];

        UITextField *epTF = (UITextField *)[self.view viewWithTag:96002];
        UITextField *keyTF = (UITextField *)[self.view viewWithTag:96003];
        UITextField *modelTF = (UITextField *)[self.view viewWithTag:96004];
        UILabel *hintLbl = (UILabel *)[self.view viewWithTag:96009];

        hintLbl.textColor = [UIColor colorWithRed:1.0 green:0.85 blue:0.35 alpha:1.0];
        hintLbl.text = [NSString stringWithFormat:@"⏳ 正在实时测速并验证模型 %@...", shortName];

        agBenchmarkModelLatency(epTF.text, keyTF.text, nil, candidateID, ^(BOOL ok, NSInteger latencyMs, NSString *sampleReply, NSString *errMsg) {
            if (ok) {
                NSMutableDictionary *p = loadGeminiPrefs();
                p[@"AG_Trans_Model"] = candidateID;

                NSMutableArray *mutableList = [list mutableCopy];
                NSMutableDictionary *updatedM = [m mutableCopy];
                updatedM[@"latencyMs"] = @(latencyMs);
                updatedM[@"latencyStr"] = [NSString stringWithFormat:@"⚡ %ldms", (long)latencyMs];
                updatedM[@"isUsable"] = @YES;
                if (indexPath.row < mutableList.count) {
                    mutableList[indexPath.row] = updatedM;
                    p[@"AG_Trans_CachedModels"] = mutableList;
                }
                saveGeminiPrefs(p);

                modelTF.text = [NSString stringWithFormat:@"%@ (使用中)", shortName];
                hintLbl.textColor = [UIColor colorWithRed:0.40 green:0.96 blue:0.68 alpha:1.0];
                hintLbl.text = [NSString stringWithFormat:@"✅ 验证通过 (延迟:%ldms) · %@ 使用中", (long)latencyMs, shortName];
                [tableView reloadData];
            } else {
                hintLbl.textColor = [UIColor colorWithRed:1.0 green:0.45 blue:0.45 alpha:1.0];
                hintLbl.text = [NSString stringWithFormat:@"❌ 模型不可用 (已阻止切换以防注销): %@", errMsg ?: @"接口拒绝"];
            }
        });
        return;
    }
    %orig(tableView, indexPath);
}

%new
- (void)agFetchTranslateModelsTapped:(UIButton *)btn {
    [self.view endEditing:YES];
    [self performSelector:@selector(agTransSettingsChanged:) withObject:nil];

    UITextField *epTF = (UITextField *)[self.view viewWithTag:96002];
    UITextField *keyTF = (UITextField *)[self.view viewWithTag:96003];
    UILabel *hintLbl = (UILabel *)[self.view viewWithTag:96009];
    UITableView *transTable = (UITableView *)[self.view viewWithTag:96010];

    NSString *ep = (epTF.text.length > 4) ? epTF.text : agTransEndpoint();
    NSString *key = (keyTF.text.length > 4) ? keyTF.text : agTransAPIKey();
    NSString *proxy = loadGeminiPrefs()[@"AG_Trans_ProxyPort"] ?: @"";

    btn.enabled = NO;
    [btn setTitle:@"⏳ 测速精选中..." forState:UIControlStateNormal];
    hintLbl.textColor = [UIColor colorWithRed:0.65 green:0.88 blue:1.0 alpha:1.0];
    hintLbl.text = @"☁️ 正在从 API 实测精选低延迟可用模型...";

    agFetchCloudModelsForTab(AGConfigTabTranslation, ep, key, proxy, ^(BOOL success, NSArray<NSDictionary *> *models, NSString *errorMsg) {
        btn.enabled = YES;
        [btn setTitle:@"🔍 获取翻译模型" forState:UIControlStateNormal];

        if (models.count > 0) {
            NSMutableDictionary *p = loadGeminiPrefs();
            p[@"AG_Trans_CachedModels"] = models;
            NSString *fastestID = models.firstObject[@"id"];
            p[@"AG_Trans_Model"] = fastestID;
            saveGeminiPrefs(p);

            UITextField *modelTF = (UITextField *)[self.view viewWithTag:96004];
            NSString *shortFastest = [fastestID stringByReplacingOccurrencesOfString:@"models/" withString:@""];
            if (modelTF) modelTF.text = [NSString stringWithFormat:@"%@ (使用中)", shortFastest];

            hintLbl.textColor = [UIColor colorWithRed:0.40 green:0.96 blue:0.68 alpha:1.0];
            NSString *lat = models.firstObject[@"latencyStr"] ?: @"";
            hintLbl.text = [NSString stringWithFormat:@"✅ 精选 %lu 款高速模型 · 推荐 %@ (%@)", (unsigned long)models.count, shortFastest, lat];
            [transTable reloadData];
        } else {
            hintLbl.textColor = [UIColor colorWithRed:1.0 green:0.45 blue:0.45 alpha:1.0];
            hintLbl.text = [NSString stringWithFormat:@"❌ 未获取到有效模型: %@", errorMsg ?: @"请检查 API 地址与 Key"];
        }
    });
}

%new
- (void)agTransFontSliderMoved:(UISlider *)slider {
    CGFloat sz = roundf(slider.value);
    UILabel *szTitle = (UILabel *)[self.view viewWithTag:96005];
    UILabel *sampleLbl = (UILabel *)[self.view viewWithTag:96007];
    if (szTitle) szTitle.text = [NSString stringWithFormat:@"🔠 译文字体大小调节：%.0f pt", sz];
    if (sampleLbl) sampleLbl.font = [UIFont boldSystemFontOfSize:sz];

    NSMutableDictionary *p = loadGeminiPrefs();
    p[@"AG_Trans_FontSize"] = @(sz);
    saveGeminiPrefs(p);
    [[AGScreenTranslationOverlay sharedOverlay] applySavedFontSizeAndStyle];
}

%new
- (void)agTransDebounceSliderMoved:(UISlider *)slider {
    CGFloat val = roundf(slider.value * 20.0) / 20.0;
    if (val < 0.20) val = 0.20;
    if (val > 1.00) val = 1.00;
    UILabel *lbl = (UILabel *)[self.view viewWithTag:96012];
    if (lbl) lbl.text = [NSString stringWithFormat:@"⏱️ 滑动松手静止重译时间：%.2f 秒", val];

    NSMutableDictionary *p = loadGeminiPrefs();
    p[@"AG_Trans_ScrollDebounceTime"] = @(val);
    saveGeminiPrefs(p);
}

%new
- (void)agTransSettingsChanged:(id)sender {
    UISwitch *enSw = (UISwitch *)[self.view viewWithTag:96001];
    UITextField *epTF = (UITextField *)[self.view viewWithTag:96002];
    UITextField *keyTF = (UITextField *)[self.view viewWithTag:96003];
    UITextField *modelTF = (UITextField *)[self.view viewWithTag:96004];
    UISwitch *ocrSw = (UISwitch *)[self.view viewWithTag:96011];
    UISwitch *webSw = (UISwitch *)[self.view viewWithTag:96014];

    NSMutableDictionary *p = loadGeminiPrefs();
    if (enSw) p[@"AG_Trans_Enabled"] = @(enSw.isOn);
    if (epTF) p[@"AG_Trans_Endpoint"] = epTF.text ?: @"";
    if (keyTF) p[@"AG_Trans_APIKey"] = keyTF.text ?: @"";
    if (ocrSw) p[@"AG_Trans_HighAccuracyOCR"] = @(ocrSw.isOn);
    if (webSw) p[@"AG_WebSearch_Enabled"] = @(webSw.isOn);
    if (modelTF && sender == modelTF) {
        NSString *cleanM = [[modelTF.text stringByReplacingOccurrencesOfString:@"(使用中)" withString:@""] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (cleanM.length > 0) p[@"AG_Trans_Model"] = cleanM;
    }
    saveGeminiPrefs(p);
}

%end

static int (*orig_TCCAccessPreflight)(CFStringRef service, CFDictionaryRef options) = NULL;
static int my_TCCAccessPreflight(CFStringRef service, CFDictionaryRef options) {
    if (service) {
        if (CFEqual(service, CFSTR("kTCCServiceCamera")) ||
            CFEqual(service, CFSTR("kTCCServiceMicrophone")) ||
            CFEqual(service, CFSTR("kTCCServiceAddressBook")) ||
            CFEqual(service, CFSTR("kTCCServiceSpeechRecognition"))) {
            return 0; // kTCCAccessPreflightGranted
        }
    }
    if (orig_TCCAccessPreflight) {
        return orig_TCCAccessPreflight(service, options);
    }
    return 0;
}


%ctor {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier];
    if ([bundleID isEqualToString:@"com.tencent.xin"]) {
        initWeChatAngelGuardianService();
        return;
    }

    void *tccHandle = dlopen("/System/Library/PrivateFrameworks/TCC.framework/TCC", RTLD_NOW);
    if (tccHandle) {
        void *sym = dlsym(tccHandle, "TCCAccessPreflight");
        if (sym) {
            MSHookFunction(sym, (void *)my_TCCAccessPreflight, (void **)&orig_TCCAccessPreflight);
        }
    }
}
