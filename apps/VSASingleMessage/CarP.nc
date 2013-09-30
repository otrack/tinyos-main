
module CarP {
	provides interface Car;	
	uses{
	    interface SplitControl as Control;
	    interface Receive;
	    interface Packet;
	    interface AMSend;
	}
}
implementation {
    message_t packet;
    uint8_t busy;
    message_t pkt;
     
     command void Car.init() {
	call Control.start();
     }
    
    event void Control.startDone(error_t err) {
	if (err != SUCCESS) {
	  call Control.start();
	}	
    }
    
    event void Control.stopDone(error_t err) {
    }
       

    event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
    {	      
	signal  Car.receive(msg, payload, len);
	return msg;
    }
	
	
    event void AMSend.sendDone(message_t* msg, error_t err) 
    {
    }		
    
    command void Car.SendCommand(CarCommands_t m)
    {
	//message_t *msg =  (CarCommands_t*)(call Packet.getPayload(&pkt, sizeof(CarCommands_t)));
	if (STARTPLATOON == m.msg)
	  dbg("LEDS", "SetPlatoon %lu,%lu\n", TOS_NODE_ID, m.param1);
	if (STOPPLATOON == m.msg)
	  dbg("LEDS", "SetCruiseControl %lu\n", TOS_NODE_ID);
	if (SETSPEED == m.msg)
	//{
	  dbg("LEDS", "SetSpeed %lu,%lu\n", TOS_NODE_ID, m.param1);
	 // dbg("LEDS", "Info %lu set speed to %lu\n", TOS_NODE_ID, m.param1);
	//}
	if (SETLANECHANGE == m.msg)
	  dbg("LEDS", "setChangeLane %lu\n", TOS_NODE_ID);
	if (SETSAFETYDISTANCE == m.msg)
	  dbg("LEDS", "setSafetyDistance %lu,%lu\n", TOS_NODE_ID, m.param1);
	  	  
// 	if (msg == NULL) {
// 	    return;
// 	}
	
	/*memcpy(msg, &m, sizeof(CarCommands_t));
	 
	if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(CarCommands_t)) != FAIL) 
	{	    
	    dbg("LEDS", "Info Send over serial port \n");
	    // call Leds.led1On();
	}	  	*/ 	
		      
    }
    
}