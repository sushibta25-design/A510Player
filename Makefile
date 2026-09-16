ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:15.0

include $(THEOS)/makefiles/common.mk

TOOL_NAME = a510probe
a510probe_FILES = main.m
a510probe_CFLAGS = -fobjc-arc
a510probe_FRAMEWORKS = Foundation
a510probe_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/tool.mk
