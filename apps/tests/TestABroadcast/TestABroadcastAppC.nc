configuration TestABroadcastAppC {}
implementation {
  components MainC, LedsC;
  components new TestABroadcastApp(100) as App;
  components new ABroadcastP(uint16_t,100) as ABroadcast;
  components new MembershipC(10,1000) as Membership;
  components new TimerMilliC() as TimerMilli0;
  components new TimerMilliC() as TimerMilli1;
  components new TimerMilliC() as TimerMilli2;
  components new TimerMilliC() as TimerMilli3;
  components LocalTimeMilliC as LocalTime;
  components new QueueC(uint16_t,10) as Queue;
  components new PaxosC(uint16_t,500,10) as Paxos;
  components new AMSenderC(0x08) as AMSenderMemebership;
  components new AMSenderC(0x08) as AMSenderLeader;
  components new AMSenderC(0x08) as AMSenderAcceptor;
  components new AMReceiverC(0x08) as AMReceiver;
  components ActiveMessageC as AM;
  components SerialStartC;
    
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
  Paxos.TimerLeader -> TimerMilli2;
  Paxos.Packet -> AM;
  Paxos.AMPacket -> AM;
  Paxos.AMControl -> AM;
  Paxos.Receive -> AMReceiver;
  Paxos.AMSendLeader -> AMSenderLeader;
  Paxos.AMSendAcceptor -> AMSenderAcceptor;
  Paxos.Membership -> Membership;

  Membership.Timer0 -> TimerMilli3;
  Membership.Packet -> AM;
  Membership.AMControl -> AM;
  Membership.Receive -> AMReceiver;
  Membership.AMSend -> AMSenderMemebership;

}
