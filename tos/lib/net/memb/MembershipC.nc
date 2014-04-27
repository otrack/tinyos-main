#include <math.h>
#include "Membership.h"

generic module MembershipC(int MAX_MEMBERS, int MEMBERSHIP_PERIOD_MILLI){
  provides interface Membership;
  uses interface Timer<TMilli> as Timer0;
  uses interface SplitControl as AMControl;
  uses interface Packet;
  uses interface AMSend;
  uses interface Receive;
}
implementation {
  uint16_t members[MAX_MEMBERS];
  uint16_t nmembers = 0;
  uint16_t leader;
  message_t pkt;
  id_msg_t* msg_id;
    
  event void AMControl.startDone(error_t err) {
    if (err == SUCCESS) {
      call Timer0.startPeriodic(MEMBERSHIP_PERIOD_MILLI);
    }else{
      call AMControl.start();
    }
    nmembers++;
    members[nmembers-1] = TOS_NODE_ID;
    leader = TOS_NODE_ID;
    dbg("MEMBERSHIP", "Membership up and running\n");
  }

  event void AMControl.stopDone(error_t err) {
  }
  
  event void AMSend.sendDone(message_t* msg, error_t error) {
  }
    
  event void Timer0.fired() {
    msg_id = (id_msg_t*)(call Packet.getPayload(&pkt, sizeof (id_msg_t)));
    msg_id->nodeid = TOS_NODE_ID;
    call AMSend.send(AM_BROADCAST_ADDR, &pkt, sizeof(id_msg_t));
  }

  bool contains(uint16_t node){
    int i;
    dbg("MEMBERSHIP", "call contains \n");
    for(i=0;i<nmembers;i++)
      if (members[i]==node)
	return TRUE;
    return FALSE;
  }
    
  command uint16_t Membership.quorumSize(){
    uint16_t size = floor(nmembers/2)+1;
    dbg("MEMBERSHIP", "call quorumSize %u\n",size);
    return size;
  }

  command uint16_t Membership.size(){
    dbg("MEMBERSHIP", "call size %u\n",members);
  }

  command bool Membership.contains(uint16_t node){
    return contains(node);
  }

  command uint16_t Membership.leader(){
    dbg("MEMBERSHIP", "call leader %u\n",leader);
    return leader;
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len) {
    id_msg_t* id_msg;
    if (len!=sizeof(id_msg_t)) {
      return msg;
    }
    id_msg = (id_msg_t*) payload;
    if (!contains(id_msg->nodeid)) {
      nmembers++;
      members[nmembers-1] = id_msg->nodeid;
      if (id_msg->nodeid < leader)
	leader = id_msg->nodeid;
    }
    return msg;
  }

}
