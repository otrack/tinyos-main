#include <Timer.h>
#include "Paxos.h"

// TODO 
// add stdcontrol to start/stop this module.
// use SendQueue
// remove TOS_NODE_ID from msg_t
// unify instance_id behavior in rcv

generic module PaxosC(typedef T, 
		      int LEADER_PERIOD_MILLI, 
		      int CONCURRENT_INSTANCES){

  provides interface Paxos<T>;
  uses{
    interface Boot;
    interface Timer<TMilli> as TimerLeader; 
    interface Packet;
    interface AMPacket;
    interface AMSend as AMSendLeader;
    interface AMSend as AMSendAcceptor;
    interface SplitControl as AMControl;
    interface Receive;
    interface Membership;
  }

}implementation {

  instance_t instances[CONCURRENT_INSTANCES];
  instance_t instance;
  message_t pktLeader, pktAcceptor;

  // INSTANCE MANAGEMENT

  void initInstance(int i){
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

    instance.decided = FALSE;

    dbg("PAXOS", "Instance %u created \n",i);
  }

  bool handleInstance(nx_uint16_t i){
    if (i == instance.id)
      return TRUE;
    if (i > instance.id) {
      initInstance(i);
      return TRUE;
    }
    return FALSE;
  }
   
  // INIT

  event void Boot.booted() {
    call AMControl.start();
    initInstance(1);
  } 
 
  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      call TimerLeader.startPeriodic(LEADER_PERIOD_MILLI);
      dbg("PAXOS", "Paxos up and running\n");
    }else{
      call AMControl.start();
    }
  }

  event void AMControl.stopDone(error_t err) {
  }
 
  // COMMAND

  command void Paxos.propose(T* v){
    propose_msg_t* msg_propose;    
    if (instance.leader.gotProposal == TRUE) return;
    instance.leader.gotProposal=TRUE;
    memcpy(&(instance.leader.toPropose),v,sizeof(T));

    if (call Membership.quorumSize() > 1) {
      msg_propose = (propose_msg_t*)(call Packet.getPayload(&pktLeader, sizeof(propose_msg_t)));
      if (msg_propose == NULL || sizeof(T) > PAXOS_PAYLOAD_SIZE) {
	dbg("PAXOS", "Error invalid payload size %u \n", sizeof(T));
	return;
      } 
      memcpy(&(msg_propose->value),v,sizeof(T));
      call AMSendLeader.send(AM_BROADCAST_ADDR, &pktLeader, sizeof(propose_msg_t));
    }
  }


  // PAXOS PHASES 

  void phase1a(){
    phase1a_msg_t* msg_1a;
    instance.phase = PHASE_1A;
    dbg("PAXOS", "1A (%u,%u) \n",instance.leader.ballot,instance.id);
    if (call Membership.quorumSize() > 1) {
      msg_1a = (phase1a_msg_t*)(call Packet.getPayload(&pktLeader, sizeof (phase1a_msg_t)));
      msg_1a->leaderid = TOS_NODE_ID;
      msg_1a->instance = instance.id;
      msg_1a->ballot = instance.leader.ballot;
      call AMSendLeader.send(AM_BROADCAST_ADDR, &pktLeader, sizeof(phase1a_msg_t));
    }
  }

  bool phase1b(nx_uint16_t ballot, nx_uint16_t leaderid){
    phase1b_msg_t* msg_1b;
    if (ballot <= instance.acceptor.cbal){
      dbg("PAXOS", "1B (%u,%u) -> IGNORED \n",instance.acceptor.cbal, instance.id); 
      return FALSE;
    }else{
      dbg("PAXOS", "1B (%u,%u) \n",instance.acceptor.cbal, instance.id); 
    }
    instance.phase = PHASE_1B;
    instance.acceptor.cbal = ballot;
    if (call Membership.quorumSize() > 1 && leaderid != TOS_NODE_ID) {
      msg_1b = (phase1b_msg_t*)(call Packet.getPayload(&pktAcceptor, sizeof (phase1b_msg_t)));
      msg_1b->nodeid = TOS_NODE_ID;
      msg_1b->leaderid = leaderid;
      msg_1b->instance = instance.id;
      msg_1b->ballot = instance.acceptor.cbal;
      msg_1b->lbal = instance.acceptor.lbal;
      memcpy(&(msg_1b->lval),&(instance.acceptor.lval),sizeof(T));
      call AMSendAcceptor.send(AM_BROADCAST_ADDR, &pktAcceptor, sizeof(phase1b_msg_t));
    }
    return TRUE;
  }
  
  bool phase2a(int ballot, int leaderid, int lbal, value_t* lval){
    phase2a_msg_t* msg_2a;
    if (ballot != instance.leader.ballot || leaderid != TOS_NODE_ID) {
      dbg("PAXOS", "2A (%u,%u) -> IGNORED \n",ballot, instance.id); 
      return FALSE;
    }else{
      dbg("PAXOS", "2A (%u,%u) \n",instance.leader.ballot, instance.id); 
      instance.phase = PHASE_2A;
    }

    instance.leader.nmsgs++;

    if (lbal != 0 && instance.leader.hbal < lbal) {
      instance.leader.hbal = lbal;
      memcpy(&(instance.leader.hval), lval,sizeof(T));
    }

    if (instance.leader.nmsgs == call Membership.quorumSize()) {

      dbg("PAXOS","1B quorum reached\n");

      if (instance.leader.hbal == 0){	
	if (instance.leader.gotProposal==FALSE){
	  dbg("PAXOS","no proposal to offer !\n");
	  return FALSE;
	}
	memcpy(&(instance.leader.hval), &(instance.leader.toPropose),sizeof(T));
      }

      if (call Membership.quorumSize() > 1) {
	msg_2a = (phase2a_msg_t*)(call Packet.getPayload(&pktLeader, sizeof (phase2a_msg_t)));    
	msg_2a->nodeid = TOS_NODE_ID;
	msg_2a->instance = instance.id;
	msg_2a->ballot = instance.leader.ballot;
	if (instance.leader.hbal>0) {
	  memcpy(&(msg_2a->value),&(instance.leader.hval),sizeof(T));
	}else{
	  memcpy(&(msg_2a->value),&(instance.leader.toPropose),sizeof(T));
	}
	call AMSendLeader.send(AM_BROADCAST_ADDR, &pktLeader, sizeof(phase2a_msg_t));
      }

      return TRUE;

    } // 1B quorum reached

    return FALSE;
  }

  bool phase2b(nx_uint16_t ballot, value_t* value){
    phase2b_msg_t* msg_2b;
    if (ballot < instance.acceptor.cbal){
      dbg("PAXOS", "2B (%u,%u) -> IGNORED \n",ballot, instance.id); 
      return FALSE;
    }else{
      dbg("PAXOS", "2B (%u,%u) \n",ballot, instance.id); 
    }
    instance.phase = PHASE_2B;
    instance.acceptor.cbal = ballot;
    instance.acceptor.lbal = ballot;
    memcpy(&(instance.acceptor.lval),value,sizeof(T));
    if (call Membership.quorumSize() > 1 ) {
      msg_2b = (phase2b_msg_t*)(call Packet.getPayload(&pktAcceptor, sizeof (phase2b_msg_t)));
      msg_2b->nodeid = TOS_NODE_ID;
      msg_2b->instance = instance.id;
      msg_2b->ballot = instance.acceptor.lbal;
      memcpy(&(msg_2b->value),&(instance.acceptor.lval),sizeof(T));
      call AMSendAcceptor.send(AM_BROADCAST_ADDR, &pktAcceptor, sizeof(phase2b_msg_t));
    }
    return TRUE;
  }

  void learn(nx_uint16_t ballot, value_t* value){
    if (ballot < instance.learner.ballot){
      dbg("PAXOS", "LEARN (%u,%u) -> IGNORED \n",ballot,instance.id); 
    }else{
      dbg("PAXOS", "LEARN (%u,%u) \n",ballot,instance.id); 
    }    
    instance.learner.ballot = ballot;
    instance.learner.nmsgs += 1;
    if (instance.learner.nmsgs == 1)
      memcpy(&(instance.learner.decision),value,sizeof(T));    
    if (instance.learner.nmsgs == call Membership.quorumSize()) {
      dbg("PAXOS","2B quorum reached\n");
      instance.decided = TRUE;
      signal Paxos.learn(&(instance.learner.decision));
    }
  }

  // EVENT HANDLERS

  event void TimerLeader.fired() {

    if (TOS_NODE_ID == call Membership.leader() ) {

      if (instance.decided == TRUE ){
	initInstance(instance.id+1);
      }

      if(instance.leader.ballot < instance.leader.hbal)
	instance.leader.ballot = instance.leader.hbal;
      instance.leader.ballot++;
      instance.leader.nmsgs = 0;

      dbg("PAXOS", "start (bal=%u,inst=%u)\n",instance.leader.ballot,instance.id);

      // skip Phase 1A ?
      if (TOS_NODE_ID == 0 && instance.leader.ballot == 0 && instance.phase == PHASE_1A){
	if (phase2a(instance.leader.ballot,TOS_NODE_ID,instance.leader.ballot,&(instance.leader.toPropose)))
	  if (phase2b(instance.leader.ballot,&instance.leader.toPropose))
	    learn(instance.acceptor.lbal,&(instance.acceptor.lval));

      // Phase 1A 
      }else{
	phase1a();	  
	if (phase1b(instance.leader.ballot,TOS_NODE_ID))
	  if (phase2a(instance.leader.ballot,TOS_NODE_ID,instance.acceptor.lbal,&(instance.acceptor.lval)))
	    if (phase2b(instance.leader.ballot,&(instance.leader.hval)))
	      learn(instance.acceptor.lbal,&(instance.acceptor.lval));
      }

    } 

  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    
    phase1a_msg_t* msg_1a;
    phase1b_msg_t* msg_1b;
    phase2a_msg_t* msg_2a;
    phase2b_msg_t* msg_2b;

    atomic{

      switch(len){
	
      case sizeof(propose_msg_t):
	dbg("PAXOS", "propose message rcv\n");
	if (instance.leader.gotProposal == FALSE){
	  instance.leader.gotProposal=TRUE;
	  memcpy(&(instance.leader.toPropose),&(((propose_msg_t*)payload)->value),sizeof(T));
	}
	break;

      case sizeof(phase1a_msg_t):
	msg_1a  = (phase1a_msg_t*)payload;
	dbg("PAXOS","1A msg (%u,%u,%u)\n",msg_1a->ballot,msg_1a->instance,msg_1a->leaderid);
	if (handleInstance(msg_1a->instance))
	  phase1b(msg_1a->ballot, msg_1a->leaderid);
	break;

      case sizeof(phase1b_msg_t):
	msg_1b = (phase1b_msg_t*)payload;
	dbg("PAXOS","1B msg (%u,%u)\n",msg_1b->ballot,msg_1b->instance);
	if (handleInstance(msg_1b->instance))
	  if (phase2a(msg_1b->ballot,msg_1b->leaderid,msg_1b->lbal,&(msg_1b->lval)))
	    if (phase2b(instance.leader.ballot,&(instance.leader.hval)))
	      learn(instance.acceptor.lbal,&(instance.acceptor.lval));
	break;

      case sizeof(phase2a_msg_t):
	msg_2a  = (phase2a_msg_t*)payload;
	dbg("PAXOS","2A msg (%u,%u)\n",msg_2a->ballot,msg_2a->instance);
	if (handleInstance(msg_2a->instance))
	  if (phase2b(msg_2a->ballot,&(msg_2a->value)))
	    learn(instance.acceptor.lbal,&(instance.acceptor.lval));
	break;

      case sizeof(phase2b_msg_t):
	msg_2b = (phase2b_msg_t*)payload;
	dbg("PAXOS","2B msg (%u,%u)\n",msg_2b->ballot,msg_2b->instance);
	if(handleInstance(msg_2b->instance)){
	  learn(msg_2b->ballot,&(msg_2b->value));
	}
	break;

      } // end switch(len)

      return msg;

    }
  
  }

  event void AMSendLeader.sendDone(message_t* msg, error_t error) {
  }

  event void AMSendAcceptor.sendDone(message_t* msg, error_t error) {
  }

} // implementation

