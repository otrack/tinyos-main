#include "car.h"

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
    if (STATUS == m.msg)
      dbg("CAR","STATUS %lu,%lu\n", TOS_NODE_ID, m.param1);

    if (STARTPLATOON == m.msg)
      dbg("CAR", "SetPlatoon %lu,%lu\n", TOS_NODE_ID, m.param1);

    if (STOPPLATOON == m.msg)
      dbg("CAR", "SetCruiseControl %lu\n", TOS_NODE_ID);

    if (SETSPEED == m.msg)
      //{
      dbg("CAR", "SetSpeed %lu,%lu\n", TOS_NODE_ID, m.param1);
    // dbg("LEDS", "Info %lu set speed to %lu\n", TOS_NODE_ID, m.param1);
    //}

    if (SETLANECHANGE == m.msg)
      dbg("CAR", "setChangeLane %lu\n", TOS_NODE_ID);

    if (SETSAFETYDISTANCE == m.msg)
      dbg("CAR", "setSafetyDistance %lu,%lu\n", TOS_NODE_ID, m.param1);
	  	  
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
