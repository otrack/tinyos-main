#include "VSA.h"			// An important header file containing all program constants
#include <math.h>			// Mathematics library
#include <Timer.h>			// Tossim defined timer scheme

configuration VSAC {
  provides interface GVSA;
}
implementation{
  components MainC, VSAM;
  components new TimerMilliC() as clock;
  components LocalTimeMilliC as LocalTime;
  components LedsC;

  components new ABroadcastP(CompleteMessage_t,BCAST_PERIOD) as ABroadcast;
  components new QueueC(CompleteMessage_t, BCAST_MSG_QUEUE_SIZE) as Queue;
  components new PaxosC(CompleteMessage_t,500,10) as Paxos;
  components new TimerMilliC() as TimerMilli1;
  components new TimerMilliC() as TimerMilli2;

  components new AMSenderC(AM_BROADCAST) as AMSender;
  components new AMReceiverC(AM_BROADCAST) as AMReceiver;
  components ActiveMessageC as AM;
	
  GVSA = VSAM;
  VSAM.clock -> clock;
  VSAM.Broadcast -> ABroadcast;
  VSAM.Leds -> LedsC;

  ABroadcast.LocalTime -> LocalTime;
  ABroadcast.Timer0 -> TimerMilli1;
  ABroadcast.Queue -> Queue;
  ABroadcast.Paxos -> Paxos;
  ABroadcast.AMControl -> AM;

  Paxos.Boot -> MainC.Boot;
  Paxos.Timer0 -> TimerMilli2;
  Paxos.Packet -> AM;
  Paxos.AMPacket -> AM;
  Paxos.AMControl -> AM;
  Paxos.Receive -> AMReceiver;
  Paxos.AMSend -> AMSender;
}

