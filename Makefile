SDKVERSION=5.0

include theos/makefiles/common.mk

TWEAK_NAME = AlbumArtOnSwitcher
AlbumArtOnSwitcher_FILES = Tweak.xm
AlbumArtOnSwitcher_FRAMEWORKS = UIKit Foundation MediaPlayer

include $(THEOS_MAKE_PATH)/tweak.mk
