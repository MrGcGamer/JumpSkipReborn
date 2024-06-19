TARGET := iphone:clang:14.4:14.0
INSTALL_TARGET_PROCESSES = SpringBoard
ARCHS = arm64e
THEOS_PACKAGE_SCHEME = rootless

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = JumpSkipReborn


JumpSkipReborn_FILES = Tweak.mm
JumpSkipReborn_CFLAGS = -fobjc-arc
JumpSkipReborn_LIBRARIES += substrate

include $(THEOS_MAKE_PATH)/tweak.mk
