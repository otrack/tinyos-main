#include "VSA.h"			// An important header file containing all program constants
#include <math.h>			// Mathematics library
#include <Timer.h>			// Tossim defined timer scheme

configuration VSAC {
  provides interface GVSA;
}
implementation{
  components VSAM;
  components new TimerMilliC() as clock;
  components LocalTimeMilliC as LocalTime;
  components LedsC;

  components new BroadcastP(CompleteMessage_t,BCAST_PERIOD) as Broadcast;
  components new QueueC(CompleteMessage_t, BCAST_MSG_QUEUE_SIZE) as Queue;
  components new TimerMilliC() as Timer0;
  components new AMSenderC(AM_BROADCAST);
  components new AMReceiverC(AM_BROADCAST);
  components ActiveMessageC as ActiveMessageC;
	
  GVSA = VSAM;
  VSAM.clock -> clock;
  VSAM.Broadcast -> Broadcast;
  VSAM.Leds -> LedsC;

  Broadcast.Receive -> AMReceiverC;
  Broadcast.AMSend -> AMSenderC;
  Broadcast.AMControl -> ActiveMessageC;
  Broadcast.Packet -> AMSenderC;
  Broadcast.Timer0 -> Timer0;
  Broadcast.Acks -> AMSenderC;
  Broadcast.Queue -> Queue;
  Broadcast.LocalTime -> LocalTime;

}

