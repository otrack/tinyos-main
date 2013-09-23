#include <Timer.h>
#include "Paxos.h"
#include "printf.h"

// TODO add stdcontrol to start/stop this module.
// TODO use SendQueue
// signal  Broadcast.brcv(&m);  // Receiving my own message

module PaxosC {
  provides interface Paxos;
  uses interface Boot;
  uses interface Timer<TMilli> as Timer0;
  uses interface Timer<TMilli> as Timer1;
  uses interface Packet;
  uses interface AMPacket;
  uses interface AMSend;
  uses interface SplitControl as AMControl;
  uses interface Receive;
}
implementation {

  instance_t instances[CONCURRENT_INSTANCES];
  instance_t instance;
  message_t pkt;

  // INSTANCE MANAGEMENT

  void initInstance(int i){
    instance = instances[i%CONCURRENT_INSTANCES-1];
    instance.id = i;
    instance.phase = PHASE_1A;

    instance.leader.ballot = 0;
    instance.leader.toPropose = NULL;
    instance.leader.nmsgs = 0;
    instance.leader.hbal = 0;
    instance.leader.hval = NULL;

    instance.acceptor.cbal = 0;
    instance.acceptor.lbal = 0;
    instance.acceptor.lval = NULL;

    instance.learner.ballot = 0;
    instance.learner.nmsgs = 0;
    instance.learner.decision = NULL;

    printf("Starting %u\n",instance.id);
    printfflush();

  }
   
  // INIT

  event void Boot.booted() {
    call AMControl.start();
    initInstance(1);
  }
 
  // RADIO

  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      call Timer0.startPeriodic(LEADER_PERIOD_MILLI);
      call Timer1.startPeriodic(LEADER_TIMEOUT_MILLI);
    }else{
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
  }
 
  event void AMSend.sendDone(message_t* msg, error_t error) {
  }

  // PAXOS PHASES 

  command void Paxos.propose(value_t* v){
    propose_msg_t* msg_propose;
    atomic{
      if(instance.leader.toPropose!=NULL) return;
      instance.leader.toPropose = v;
      msg_propose = (propose_msg_t*)(call Packet.getPayload(&pkt, sizeof (propose_msg_t)));
      memcpy(&(msg_propose->value),v,sizeof(value_t));
      call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(propose_msg_t));
    }
    /* printf("Proposing %u\n",v->data[0]); */
    /* printfflush(); */
  }

  void phase1a(){
    phase1a_msg_t* msg_1a;
    msg_1a = (phase1a_msg_t*)(call Packet.getPayload(&pkt, sizeof (phase1a_msg_t)));
    msg_1a->nodeid = TOS_NODE_ID;
    msg_1a->instance = instance.id;
    msg_1a->ballot = instance.leader.ballot;
    if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(phase1a_msg_t)) == SUCCESS) {
      instance.phase = PHASE_1B;
      instance.leader.nmsgs = 0;
    }
    /* printf("phase 1A (%u) \n",msg_1a->ballot); */
    /* printfflush(); */
  }

  void phase1b(phase1a_msg_t* msg_1a){
    phase1b_msg_t* msg_1b;
    instance.acceptor.cbal = msg_1a->ballot;
    msg_1b = (phase1b_msg_t*)(call Packet.getPayload(&pkt, sizeof (phase1b_msg_t)));
    msg_1b->nodeid = TOS_NODE_ID;
    msg_1b->leaderid = msg_1a->nodeid;
    msg_1b->instance = instance.id;
    msg_1b->ballot = instance.acceptor.cbal;
    msg_1b->lbal = instance.acceptor.lbal;
    memcpy(&(msg_1b->lval),instance.acceptor.lval,sizeof(value_t));
    call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(phase1b_msg_t));
    /* printf("phase 1B (%u,%u) \n",instance.acceptor.cbal, msg_1a->nodeid); */
    /* printfflush(); */
  }

  void phase2a(){
    // assert instance.leader.toPropose := NULL
    phase2a_msg_t* msg_2a;
    msg_2a = (phase2a_msg_t*)(call Packet.getPayload(&pkt, sizeof (phase2a_msg_t)));
    msg_2a->nodeid = TOS_NODE_ID;
    msg_2a->instance = instance.id;
    msg_2a->ballot = instance.leader.ballot;
    if(instance.leader.hval != NULL)
      memcpy(&(msg_2a->value),instance.leader.hval,sizeof(value_t));
    else
      memcpy(&(msg_2a->value),instance.leader.toPropose,sizeof(value_t));
    if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(phase2a_msg_t)) == SUCCESS) {
      instance.phase = PHASE_2B;
    }
  }

  void phase2b(phase2a_msg_t* msg_2a){
    phase2b_msg_t* msg_2b;
    instance.acceptor.cbal = msg_2a->ballot;
    instance.acceptor.lbal = msg_2a->ballot;
    memcpy(instance.acceptor.lval,&(msg_2a->value),sizeof(value_t));
    msg_2b = (phase2b_msg_t*)(call Packet.getPayload(&pkt, sizeof (phase2b_msg_t)));
    msg_2b->nodeid = TOS_NODE_ID;
    msg_2b->instance = instance.id;
    msg_2b->ballot = instance.acceptor.lbal;
    memcpy(&(msg_2b->value),instance.acceptor.lval,sizeof(value_t));
    call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(phase2b_msg_t));
  }

  // EVENT HANDLERS

  event void Timer0.fired() {
    atomic{
      if (instance.phase == PHASE_1A && instance.leader.toPropose != NULL && TOS_NODE_ID ==1) {
	instance.leader.ballot++;
	phase1a();
      } else if (instance.phase == PHASE_2A) {
	phase2a();
      }
    }
  }

  event void Timer1.fired() {
    atomic{
      instance.phase = PHASE_1A;
    }
  }


  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    
    phase1a_msg_t* msg_1a;
    phase1b_msg_t* msg_1b;
    phase2a_msg_t* msg_2a;
    phase2b_msg_t* msg_2b;
    decision_msg_t* msg_decision;

    atomic{

      switch(len){
	
      case sizeof(propose_msg_t):
	if(instance.leader.toPropose==NULL)
	  memcpy(instance.leader.toPropose,&(((propose_msg_t*)payload)->value),sizeof(value_t));
	break;

      case sizeof(phase1a_msg_t):
	msg_1a  = (phase1a_msg_t*)payload; 
	if(msg_1a->instance < instance.id)
	  break;
	if(msg_1a->instance > instance.id)
	  initInstance(msg_1a->instance);
	if(msg_1a->ballot > instance.acceptor.cbal){
	  phase1b(msg_1a);
	}
	break;

      case sizeof(phase1b_msg_t):
	msg_1b = (phase1b_msg_t*)payload; 
	if(msg_1b->instance == instance.id && instance.phase == PHASE_1B && msg_1b->ballot == instance.leader.ballot && msg_1b->leaderid == TOS_NODE_ID) {
	  instance.leader.nmsgs++;
	  if(instance.leader.hbal < msg_1b->ballot) {
	    instance.leader.hbal = msg_1b->lbal;
	    memcpy(instance.leader.hval, &(msg_1b->lval),sizeof(value_t));
	  }
	  if(instance.leader.nmsgs >= QUORUM_SIZE) {
	    instance.phase = PHASE_2A;
	  }
	}
	break;

      case sizeof(phase2a_msg_t):
	msg_2a  = (phase2a_msg_t*)payload;
	if(msg_2a->instance == instance.id && msg_2a->ballot >= instance.acceptor.cbal){
	  phase2b(msg_2a);
	}
	break;

      case sizeof(phase2b_msg_t):
	msg_2b = (phase2b_msg_t*)payload; 
	if(msg_2b->instance == instance.id){
	  if(msg_2b->ballot > instance.learner.ballot) {
	    instance.learner.ballot = msg_2b->ballot;
	    memcpy(instance.learner.decision,&(msg_2b->value),sizeof(value_t));
	    instance.learner.nmsgs = 1;
	  }else if(msg_2b->ballot == instance.learner.ballot){
	    instance.learner.nmsgs++;
	    if(instance.learner.nmsgs == QUORUM_SIZE){
	      msg_decision = (decision_msg_t*)(call Packet.getPayload(&pkt, sizeof (decision_msg_t)));
	      msg_decision->instance = instance.id;
	      memcpy(&(msg_decision->value),instance.learner.decision,sizeof(value_t));
	      call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(decision_msg_t));
	      printf("Decision %u\n",instance.learner.decision->data[0]);
	      printfflush();
	      signal Paxos.learn(instance.learner.decision);	      
	      initInstance(instance.id+1);
	    }
	  }
	}
	break;

      case sizeof(decision_msg_t):
	msg_decision = (decision_msg_t*)payload; 
	if(msg_decision->instance == instance.id){
	  memcpy(instance.learner.decision,&(msg_decision->value),sizeof(value_t));
	  printf("Decision %u\n",instance.learner.decision->data[0]);
	  printfflush();
	  signal Paxos.learn(instance.learner.decision);
	  initInstance(instance.id+1);
	}

      } // end switch(len)
    
    } // end atomic{}
    
    return msg;

  }
  
}

