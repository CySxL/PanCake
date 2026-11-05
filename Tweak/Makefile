export TARGET = iphone:clang:16.5:15.0
export ARCHS = arm64 arm64e
TWEAK_NAME = PanCake
$(TWEAK_NAME)_FILES = Tweak.x
ADDITIONAL_OBJCFLAGS = -fobjc-arc -Wno-deprecated-declarations -O3
include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/tweak.mk
