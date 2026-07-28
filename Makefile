export TARGET = iphone:clang:16.5:15.0
export ARCHS = arm64 arm64e
export THEOS_PACKAGE_SCHEME = roothide

include $(THEOS)/makefiles/common.mk

SUBPROJECTS += Tweak Prefs

include $(THEOS_MAKE_PATH)/aggregate.mk

internal-all::
	@echo "Syncing version from control to Prefs.plist"
	@VERSION=$$(awk '/^Version:/ {print $$2}' $(THEOS_PROJECT_DIR)/control); \
	sed -i '' -E "s/<string>PanCake( v[0-9\.]+)?<\/string>/<string>PanCake v$$VERSION<\/string>/g" $(THEOS_PROJECT_DIR)/Prefs/Resources/Prefs.plist

after-install::
	install.exec "killall -9 SpringBoard"
	install.exec "killall -9 Preferences"
