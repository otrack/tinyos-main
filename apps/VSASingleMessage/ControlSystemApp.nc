#include "VSA.h"			// An important header file containing all program constants
#include <math.h>			// Mathematics library
#include <Timer.h>			// Tossim defined timer scheme

configuration ControlSystemApp{}
implementation{
	components ControlSystemP;
	components MainC, VSAC, CarC;
	components LedsC;

	ControlSystemP -> MainC.Boot;
	ControlSystemP.GVSA -> VSAC;
	ControlSystemP.Car -> CarC;
	ControlSystemP.Leds -> LedsC;  
}

