export THEOS_DEVICE_IP=10.1.1.2
SDKVERSION = 5.1
include theos/makefiles/common.mk

TWEAK_NAME = RemoteLockscreenControls
RemoteLockscreenControls_FILES = Tweak.xm
RemoteLockscreenControls_FRAMEWORKS = UIKit AVFoundation MediaPlayer

include $(THEOS_MAKE_PATH)/tweak.mk
