ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = A510Player
A510Player_FILES = main.m AppDelegate.m PlayerViewController.m
A510Player_CFLAGS = -fobjc-arc
A510Player_FRAMEWORKS = UIKit Foundation AVFoundation VideoToolbox CoreMedia CoreVideo QuartzCore
A510Player_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
