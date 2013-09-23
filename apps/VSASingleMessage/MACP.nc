#include "VSA.h"
#include "broadcast.h"

module MACP {
  provides interface Broadcast;	
  uses{
    interface Packet;
    //    interface PacketLink;
    interface AMSend;
    interface Receive;
    interface SplitControl as Control;
  }
}
implementation {
  message_t pkt;
     
  command void Broadcast.init() {
    call Control.start();
  }
    
  event void Control.startDone(error_t err) {
    if (err != SUCCESS) {
      call Control.start();
    }	
  }

  event void Control.stopDone(error_t err) {
  }       
	
  command void Broadcast.bcast(CompleteMessage_t m)
  {
    message_t *msg =  (message_t*)(call Packet.getPayload(&pkt, sizeof(CompleteMessage_t)));
    if (msg == NULL) {
      return;
    }
    memcpy(msg, &m, sizeof(CompleteMessage_t));
    //    call PacketLink.setRetries(msg, MAX_RETRIES);
    //    call PacketLink.setRelay(msg, RETRY_DELAY);
    if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(CompleteMessage_t)) != FAIL)
      {
    	// call Leds.led1On();
    	signal  Broadcast.brcv(&m);  // Receiving my own message
    	dbg("MAC","Broadcast.sent msg= %lu\n", m.msg);
      }
  }
  
  event void AMSend.sendDone(message_t* msg, error_t err) {
  }
        
       

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
  {	 
    dbg("MAC","Broadcast.receive receive=%lu\n", len);
    if (len == sizeof(CompleteMessage_t)) {
      CompleteMessage_t* m = (CompleteMessage_t*)payload;
      //call Leds.led0Toggle();
      signal  Broadcast.brcv(m);
    }
    return msg;
  }
}
