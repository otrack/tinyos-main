#include <Timer.h>

/**
 *
 * non-idempotent atomic broadcast primitive
 *  
 * The implementation is based on an underlying Paxos primitive.
 * The amount of ongoing messages is limited by the size of the queue.
 * This primitive is stubborn in the sense that it keeps resending the first message in the queue until 
 * it becomes decided by Paxos.
 * 
 * @author = P. Sutra
 *
 **/
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
    if (locked == TRUE) {
      call Paxos.propose(&toSend);
    } else if (!call Queue.empty()) {
      toSend = call Queue.head();
      locked = TRUE;
      call Paxos.propose(&toSend);
    }
  }
	
  command T* ABroadcast.bcast(T* m)
  {
    dbg("ABCAST","abcast(%u) \n",*m);
    if (call Queue.size() < call Queue.maxSize()) {
      call Queue.enqueue(*m);
      return m;
    }
    return NULL;
  }
   
  event void Paxos.learn(T* v){
    dbg("ABCAST","abrcv(%u) \n",*v);
    if (memcmp(v,&toSend,sizeof(T))==0) {
      call Queue.dequeue();
      locked=FALSE;
    }
    signal ABroadcast.brcv(v);
  }

}
