#include "VSA.h"			// An important header file containing all program constants
#include <math.h>			// Mathematics library
#include <Timer.h>			// Tossim defined timer scheme

configuration VSAC {
     provides interface GVSA;
}
implementation{
        components VSAM;
	components MACC;
	components new TimerMilliC() as clock;
	components LedsC;
	
	GVSA = VSAM;
	VSAM.clock -> clock;
        VSAM.Broadcast -> MACC;
	VSAM.Leds -> LedsC;
}

