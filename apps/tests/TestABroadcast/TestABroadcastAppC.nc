configuration TestABroadcastAppC {}
implementation {
  components MainC, LedsC;
  components new TestABroadcastApp(100) as App;
  components new ABroadcastP(uint16_t,100) as ABroadcast;
  components new TimerMilliC() as TimerMilli0;
  components new TimerMilliC() as TimerMilli1;
  components new TimerMilliC() as TimerMilli2;
  components LocalTimeMilliC as LocalTime;
  components new QueueC(uint16_t,10) as Queue;
  components new PaxosC(uint16_t,500,10) as Paxos;
  components new AMSenderC(0x08) as AMSender;
  components new AMReceiverC(0x08) as AMReceiver;
  components ActiveMessageC as AM;
  components PrintfC, SerialStartC;
    
  App.Boot -> MainC.Boot;
  App.ABroadcast -> ABroadcast;
  App.Timer0 -> TimerMilli0;
  App.Leds -> LedsC;

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
