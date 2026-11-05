export TARGET = iphone:clang:16.5:15.0
export ARCHS = arm64 arm64e
BUNDLE_NAME = PanCakePrefs
$(BUNDLE_NAME)_FILES = PCRootListController.m
$(BUNDLE_NAME)_INSTALL_PATH = /Library/PreferenceBundles
$(BUNDLE_NAME)_FRAMEWORKS = UIKit
$(BUNDLE_NAME)_PRIVATE_FRAMEWORKS = Preferences
$(BUNDLE_NAME)_CFLAGS = -fobjc-arc -Wno-deprecated-declarations -O3

# Version shown on the settings page, taken from control
PC_VERSION := $(shell sed -n 's/^Version: //p' $(THEOS_PROJECT_DIR)/control)
ifeq ($(PC_VERSION),)
$(error no Version line in $(THEOS_PROJECT_DIR)/control)
endif
$(BUNDLE_NAME)_CFLAGS += -DPACKAGE_VERSION='"$(PC_VERSION)"' 
include $(THEOS)/makefiles/common.mk
include $(THEOS_MAKE_PATH)/bundle.mk

before-all::
	chmod 644 ./Resources/*.png

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/$(BUNDLE_NAME).plist$(ECHO_END)
