#include <Timer.h>
#include "printf.h"

generic module ABroadcastP(typedef T, int PERIOD){
  provides interface ABroadcast<T>;	
  uses{
    interface LocalTime<TMilli> as LocalTime;
    interface Timer<TMilli> as Timer0;
    interface SplitControl as AMControl;
    interface Queue<T> as Queue;
    interface Paxos<T>;
    interface Packet;
  }
}
implementation {

  message_t packet;
  bool locked = FALSE;
  T toSend;
    
  command void ABroadcast.init() {
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
    atomic{
      if (!locked) {
	if (!call Queue.empty()) {
	  toSend = call Queue.head();
	  locked = TRUE;
	}
      }
    }
    call Paxos.propose(&toSend);
  }
	
  command T* ABroadcast.bcast(T* m)
  {
    printf("ABCAST bcast (%u) \n",*m);
    printfflush();
    atomic{
      if (call Queue.size() < call Queue.maxSize()) {
	call Queue.enqueue(*m);
	return m;
      }
    }
    return NULL;
  }
   
  event void Paxos.learn(T* v){
    printf("ABCAST rcv (%u) \n",*v);
    printfflush();
    atomic{
      if (memcmp(v,&toSend,sizeof(T))==0) {
	call Queue.dequeue();
	locked=FALSE;
      }
    }

    signal ABroadcast.brcv(v);
  }

}
