generic module BroadcastP(typedef T, int PERIOD){
  provides interface Broadcast<T>;	
  uses{
    interface Timer<TMilli> as Timer0;
    interface Receive;
    interface AMSend;
    interface SplitControl as AMControl;
    interface Packet;    
    interface PacketAcknowledgements as Acks;
    interface Queue<T> as Queue;
  }
}
implementation {

  message_t packet;
  bool locked = FALSE;
    
  command void Broadcast.init() {
    call AMControl.start();
  }
     
  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      call Timer0.startPeriodic(PERIOD);
    }
    else {
      call AMControl.start();
    }
  }
 
  event void AMControl.stopDone(error_t err) {
    // do nothing
  }
     
  event void Timer0.fired()
  {
    T toSend;	      
    if( locked ) {
      return;	      
    }else {	
      if (!call Queue.empty()) {
	message_t *msg =  (message_t*)(call Packet.getPayload(&packet, sizeof(T)));
	if (msg == NULL) {
	  dbg("BCAST","Error invalid payload size %u \n", sizeof(T));	      
	  return;
	}
	call Acks.requestAck(msg);
	toSend = call Queue.head();
	memcpy(msg,&toSend, sizeof(T));	  	
	if( call AMSend.send( AM_BROADCAST_ADDR, &packet, sizeof( T ) ) == SUCCESS ) {
	  locked = TRUE;
	}
      }
    }
  }
	
  command void Broadcast.bcast(T m)
  {
    dbg("BCAST","Info %lu Broadcast.bcast \n", TOS_NODE_ID);	      
    if (call Queue.size() < call Queue.maxSize())
      call Queue.enqueue(m);
  }
   
  event void AMSend.sendDone(message_t* bufPtr, error_t err) {
    T toSend;
    if (&packet == bufPtr) {
      toSend = call Queue.head();
      signal Broadcast.brcv(&toSend);  
      call Queue.dequeue();
      locked = FALSE;
      dbg("BCAST","Info %lu Broadcast.sendDone \n", TOS_NODE_ID);	      
    }
  }
              
  event message_t* Receive.receive(message_t* bufPtr, void* payload, uint8_t len) {
    if (len == sizeof(T)) {		  
      T* m = (T*)payload;		  
      dbg("BCAST","Info %lu  Broadcast.receive msg %lu \n", TOS_NODE_ID);	      
      signal  Broadcast.brcv(m);
    }	    
    return bufPtr;
  }
}
