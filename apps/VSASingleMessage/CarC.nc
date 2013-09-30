configuration CarC {
      provides interface Car;
      
}
implementation
{      
	enum {
	      AM_SERIAL_MSG = 0x89
	};
	components CarP;
	components SerialActiveMessageC as AM;
	//components new AMSenderC(AM_SERIAL_MSG);

	Car = CarP;
	CarP.Control -> AM;
	CarP.Receive -> AM.Receive[AM_SERIAL_MSG];
	CarP.Packet -> AM;
	//CarP.AMSend -> AMSenderC;
	
}

