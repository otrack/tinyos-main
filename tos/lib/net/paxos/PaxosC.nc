#include <Timer.h>
#include "Paxos.h"
// #include "printf.h"

// TODO 
// add stdcontrol to start/stop this module.
// use SendQueue
// remove TOS_NODE_ID from msg_t
// unify instance_id behavior in rcv

generic module PaxosC(typedef T, 
		      int LEADER_PERIOD_MILLI, 
		      int CONCURRENT_INSTANCES){
  provides interface Paxos<T>;
  uses interface Boot;
  uses interface Timer<TMilli> as Timer0; // ballot timeout
  uses interface Packet;
  uses interface AMPacket;
  uses interface AMSend;
  uses interface SplitControl as AMControl;
  uses interface Receive;
  uses interface Membership;
}
implementation {

  instance_t instances[CONCURRENT_INSTANCES];
  instance_t instance;
  message_t pkt;

  // INSTANCE MANAGEMENT

  void initInstance(int i){
    atomic{
      instance = instances[i%CONCURRENT_INSTANCES-1];
      instance.id = i;
      instance.phase = PHASE_1A;
      
      instance.leader.ballot = 0;
      instance.leader.gotProposal = FALSE;
      instance.leader.nmsgs = 0;
      instance.leader.hbal = 0;

      instance.acceptor.cbal = 0;
      instance.acceptor.lbal = 0;

      instance.learner.ballot = 0;
      instance.learner.nmsgs = 0;
    }
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
      dbg("PAXOS", "up and running\n");
    }else{
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
  }
 
  event void AMSend.sendDone(message_t* msg, error_t error) {
  }

  // PAXOS PHASES 

  command void Paxos.propose(T* v){
    propose_msg_t* msg_propose;    
    dbg("PAXOS", "propose %u\n",*v);
    atomic{
      if (instance.leader.gotProposal == TRUE) return;
      msg_propose = (propose_msg_t*)(call Packet.getPayload(&pkt, sizeof(propose_msg_t)));
      if (msg_propose == NULL || sizeof(T) > PAXOS_PAYLOAD_SIZE) {
	dbg("PAXOS", "Error invalid payload size %u \n", sizeof(T));
	return;
      }
      instance.leader.gotProposal=TRUE;
      memcpy(&(instance.leader.toPropose),v,sizeof(T));
      memcpy(&(msg_propose->value),v,sizeof(T));
      call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(propose_msg_t));
    }
  }

  void phase1a(){
    phase1a_msg_t* msg_1a;
    dbg("PAXOS", "phase1A (%u,%u) \n",instance.leader.ballot,instance.id);
    msg_1a = (phase1a_msg_t*)(call Packet.getPayload(&pkt, sizeof (phase1a_msg_t)));
    msg_1a->nodeid = TOS_NODE_ID;
    msg_1a->instance = instance.id;
    msg_1a->ballot = instance.leader.ballot;
    call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(phase1a_msg_t));
    instance.phase = PHASE_1B;
    instance.leader.nmsgs = 0;
  }

  void phase1b(phase1a_msg_t* msg_1a){
    phase1b_msg_t* msg_1b;
    dbg("PAXOS", "phase 1B (%u,%u) \n",instance.acceptor.cbal, instance.id); 
    msg_1b = (phase1b_msg_t*)(call Packet.getPayload(&pkt, sizeof (phase1b_msg_t)));
    msg_1b->nodeid = TOS_NODE_ID;
    msg_1b->leaderid = msg_1a->nodeid;
    msg_1b->instance = instance.id;
    msg_1b->ballot = instance.acceptor.cbal;
    msg_1b->lbal = instance.acceptor.lbal;
    memcpy(&(msg_1b->lval),&(instance.acceptor.lval),sizeof(T));
    call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(phase1b_msg_t));
  }

  void phase2a(){
    phase2a_msg_t* msg_2a;
    dbg("PAXOS", "phase 2A (%u,%u) \n",instance.leader.ballot, instance.id); 
    msg_2a = (phase2a_msg_t*)(call Packet.getPayload(&pkt, sizeof (phase2a_msg_t)));
    msg_2a->nodeid = TOS_NODE_ID;
    msg_2a->instance = instance.id;
    msg_2a->ballot = instance.leader.ballot;
    if (instance.leader.hbal>0) {
      memcpy(&(msg_2a->value),&(instance.leader.hval),sizeof(T));
    }else{
      memcpy(&(msg_2a->value),&(instance.leader.toPropose),sizeof(T));
    }
    if (call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(phase2a_msg_t)) == SUCCESS )
      dbg("PAXOS", "failed");
    instance.phase = PHASE_2B;
  }

  void phase2b(phase2a_msg_t* msg_2a){
    phase2b_msg_t* msg_2b;
    dbg("PAXOS" "phase 2B (%u,%u) \n",instance.acceptor.cbal, instance.id); 
    msg_2b = (phase2b_msg_t*)(call Packet.getPayload(&pkt, sizeof (phase2b_msg_t)));
    msg_2b->nodeid = TOS_NODE_ID;
    msg_2b->instance = instance.id;
    msg_2b->ballot = instance.acceptor.lbal;
    memcpy(&(msg_2b->value),&(instance.acceptor.lval),sizeof(T));
    call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(phase2b_msg_t));
  }

  // EVENT HANDLERS

  event void Timer0.fired() {
    
    atomic{

      if (instance.leader.gotProposal == TRUE 
	  && instance.learner.nmsgs < call Membership.quorumSize()
	  && TOS_NODE_ID == call Membership.leader() ) { // FIXME add leader election here

	if(instance.leader.ballot < instance.leader.hbal)
	  instance.leader.ballot = instance.leader.hbal;
	instance.leader.ballot++;
	dbg("PAXOS", "start (bal=%u,inst=%u)\n",instance.leader.ballot,instance.id);

	// Phase 2A
	if (instance.leader.ballot == 1
	    && instance.phase == PHASE_1A
	    && TOS_NODE_ID == 1	) { // FIXME

	  dbg("PAXOS", "skip phase 1A\n");
	  instance.phase = PHASE_2A;

	  // local accept
	  if (instance.acceptor.cbal < instance.leader.ballot) {
	    instance.acceptor.cbal = instance.leader.ballot;
	    instance.acceptor.lbal = instance.leader.ballot;
	    memcpy(&(instance.acceptor.lval),&(instance.leader.toPropose),sizeof(T));
	  }

	  // distributed accept
	  if (call Membership.quorumSize() > 1) {
	    phase2a();
	  }

	  // local learn
	  if (instance.acceptor.lbal > instance.learner.ballot) {
	    instance.learner.ballot = instance.acceptor.lbal;
	    instance.learner.nmsgs = 1;
	    memcpy(&(instance.learner.decision),&(instance.acceptor.lval),sizeof(T));
	  }

	  // fast local decision for dummy case
	  if (call Membership.quorumSize() == 1) {
	    signal Paxos.learn(&(instance.learner.decision));
	    // start next instance
	    initInstance(instance.id+1);
	    return;
	  }

	/* // Phase 1A */
	}else{

	  instance.phase = PHASE_1B; 		

	  // local prepare
	  if (instance.acceptor.cbal<instance.leader.ballot) { 
	    instance.phase = PHASE_1B;
	    instance.acceptor.cbal = instance.leader.ballot;
	    instance.leader.nmsgs++;
	    if (instance.acceptor.lbal>0) {
	      instance.leader.hbal = instance.acceptor.lbal;
	      memcpy(&(instance.leader.hval), &(instance.acceptor.lval),sizeof(T));
	    }
	  }	
	  
	  // distributed prepare
	  if (call Membership.quorumSize() > 1) 
	    phase1a();

	} // phase 2A/1A

      } // gotProposal == TRUE
      
    } // atomic

  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    
    phase1a_msg_t* msg_1a;
    phase1b_msg_t* msg_1b;
    phase2a_msg_t* msg_2a;
    phase2b_msg_t* msg_2b;

    atomic{

      switch(len){
	
      case sizeof(propose_msg_t):
	// dbg("PAXOS", "propose message rcv\n");
	if (instance.leader.gotProposal == FALSE)
	  instance.leader.gotProposal=TRUE;
	memcpy(&(instance.leader.toPropose),&(((propose_msg_t*)payload)->value),sizeof(T));
	break;

      case sizeof(phase1a_msg_t):
	msg_1a  = (phase1a_msg_t*)payload; 
	dbg("PAXOS","phase 1A message rcv\n");
	if(msg_1a->instance < instance.id)
	  break;
	if(msg_1a->instance > instance.id)
	  initInstance(msg_1a->instance);
	if(msg_1a->ballot > instance.acceptor.cbal){
	  instance.acceptor.cbal = msg_1a->ballot;
	  phase1b(msg_1a);
	}
	break;

      case sizeof(phase1b_msg_t):
	dbg("PAXOS","phase 1B message rcv\n");
	msg_1b = (phase1b_msg_t*)payload; 
	if (msg_1b->instance == instance.id 
	    && instance.phase == PHASE_1B 
	    && msg_1b->ballot == instance.leader.ballot 
	    && msg_1b->leaderid == TOS_NODE_ID) {
	  instance.leader.nmsgs++;
	  if(instance.leader.hbal < msg_1b->ballot) {
	    instance.leader.hbal = msg_1b->lbal;
	    memcpy(&(instance.leader.hval), &(msg_1b->lval),sizeof(T));
	  }
	  if(instance.leader.nmsgs >= call Membership.quorumSize()) {
	    dbg("PAXOS","1B quorum reached\n");
	    instance.phase = PHASE_2A;
	    phase2a();
	  }
	}
	break;

      case sizeof(phase2a_msg_t):
	dbg("PAXOS","phase 2A message rcv\n");
	msg_2a  = (phase2a_msg_t*)payload;

	if (msg_2a->instance == instance.id 
	    && msg_2a->ballot >= instance.acceptor.cbal) {

	  instance.phase = PHASE_2B;
	  instance.acceptor.cbal = msg_2a->ballot;
	  instance.acceptor.lbal = msg_2a->ballot;
	  memcpy(&(instance.acceptor.lval),&(msg_2a->value),sizeof(T));
	  phase2b(msg_2a);

	  // local learn
	  if (instance.acceptor.lbal >= instance.learner.ballot) { 
	    if (instance.acceptor.lbal >  instance.learner.ballot){
	      instance.learner.ballot = instance.acceptor.lbal;
	      instance.learner.nmsgs = 1;
	      memcpy(&(instance.learner.decision),&(instance.acceptor.lval),sizeof(T));
	    }else{ // ==
	      instance.learner.nmsgs++;
	    }
	    if (instance.learner.nmsgs == call Membership.quorumSize()) {
	      dbg("PAXOS","2B quorum reached\n");	
	      signal Paxos.learn(&(instance.learner.decision));
	      initInstance(instance.id+1);
	    }
	  }

	}
	break;

      case sizeof(phase2b_msg_t):
	dbg("PAXOS", "phase 2B message rcv\n");
	msg_2b = (phase2b_msg_t*)payload; 
	if(msg_2b->instance == instance.id){
	  if(msg_2b->ballot > instance.learner.ballot) {
	    instance.learner.ballot = msg_2b->ballot;
	    memcpy(&(instance.learner.decision),&(msg_2b->value),sizeof(T));
	    instance.learner.nmsgs = 1;
	  }else if(msg_2b->ballot == instance.learner.ballot){
	    instance.learner.nmsgs++;
	  }	  
	  if(instance.learner.nmsgs == call Membership.quorumSize()){
	    dbg("PAXOS","2B quorum reached\n");	
	    signal Paxos.learn(&(instance.learner.decision));
	    initInstance(instance.id+1);
	  }
	}
	break;

      } // end switch(len)

    } // end atomic{}
    
    return msg;

  }
  
}

