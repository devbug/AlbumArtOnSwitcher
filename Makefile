SDKVERSION=5.0

include theos/makefiles/common.mk

TWEAK_NAME = AlbumArtOnSwitcher
AlbumArtOnSwitcher_FILES = Tweak.xm
AlbumArtOnSwitcher_FRAMEWORKS = UIKit Foundation MediaPlayer CoreGraphics
AlbumArtOnSwitcher_PRIVATE_FRAMEWORKS = MobileIcons

include $(THEOS_MAKE_PATH)/tweak.mk
