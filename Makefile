TARGET := iphone:clang:16.5:15.0
ARCHS = arm64 arm64e
THEOS_PACKAGE_SCHEME = rootless
INSTALL_TARGET_PROCESSES = SpringBoard Preferences

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = GeminiSiriOverlay
GeminiSiriOverlay_FILES = Tweak.x
GeminiSiriOverlay_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-variable -Wno-unguarded-availability-new -Wno-incomplete-implementation -Wno-unused-function -Wno-arc-performSelector-leaks -Wno-nonnull
GeminiSiriOverlay_FRAMEWORKS = UIKit Foundation AVFoundation Contacts QuartzCore CoreGraphics CoreMedia CoreVideo CoreImage VideoToolbox ImageIO Speech AudioToolbox Vision ReplayKit

TOOL_NAME = AngelCameraHelper
AngelCameraHelper_ARCHS = arm64 arm64e
AngelCameraHelper_FILES = AngelCameraHelper.m
AngelCameraHelper_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -Wno-unused-function -Wno-incompatible-pointer-types-discards-qualifiers -Wno-unguarded-availability-new
AngelCameraHelper_LDFLAGS = -Wl,-sectcreate,__TEXT,__info_plist,HelperInfo.plist
AngelCameraHelper_FRAMEWORKS = UIKit QuartzCore AVFoundation CoreMedia CoreVideo CoreImage Foundation ImageIO VideoToolbox
AngelCameraHelper_CODESIGN_FLAGS = -Scam_ent.xml
AngelCameraHelper_INSTALL_PATH = /usr/bin

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/tool.mk
