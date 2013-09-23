configuration MACC {
      provides interface Broadcast;
}
implementation
{      
  components MACP;	
  components ActiveMessageC;
  components new AMSenderC(AM_BROADCAST);
  components new AMReceiverC(AM_BROADCAST);
	
  Broadcast = MACP;
  MACP.Control -> ActiveMessageC;	
  MACP.Receive -> AMReceiverC;
  MACP.AMSend -> AMSenderC;
  MACP.Packet -> AMSenderC;
  //  MACP.PacketLink -> ActiveMessageC;
}

