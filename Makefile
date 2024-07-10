INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64 arm64e
FINALPACKAGE = 1

ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
	TARGET = iphone:14.4:14.0
else
	TARGET = iphone:14.4:13.0
endif

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = JumpSkipReborn

JumpSkipReborn_FILES = Tweak.mm
JumpSkipReborn_CFLAGS = -fobjc-arc -std=c++11
JumpSkipReborn_LIBRARIES += substrate

include $(THEOS_MAKE_PATH)/tweak.mk
