COMPONENT=ControlSystemApp
BUILD_EXTRA_DEPS = Location.py 
MIB520 ?= /dev/ttyUSB0
PFLAGS = -DCC2420_DEF_CHANNEL=12
CFLAGS += -I$(TOSDIR)/lib/printf
CFLAGS += -DTOSH_DATA_LENGTH=127
CFLAGS = -DPACKET_LINK


Location.py: ControlSystem.h
	mig python -target=$(PLATFORM) $(CFLAGS) -python-classname=Location ControlSystem.h Location -o $@


include $(MAKERULES)