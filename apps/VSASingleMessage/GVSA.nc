#include "VSA.h"			

interface GVSA {
  command void init(Vstate_t startu);
  command void bcastNode(uint8_t Message);
  
  //command void GPSUpdate(UINT r, UINT *ng, UINT num);
  command void GPSUpdate(uint8_t region, PKTLocation_t *data);  
  event bool nodebrcv(CompleteMessage_t *msg);
  event void Clock(uint32_t now);
  command void sendPlatoonMode(uint8_t speed);
  command void sendCoordination(uint8_t id, uint8_t speed);
  command void sendLaneChange(uint8_t car1, uint8_t car2, uint8_t car3, uint8_t speed);
  /*event Vstate_t VSAstartLeadership(Vstate_t *state);
  event Vstate_t VSAendLeadership(Vstate_t *state);*/
  event void VSAclock(Vstate_t *vstate);
  
  command void VSAint(uint8_t act);
  command void VSAbcast(uint8_t m);  
  event Vstate_t transition(Vstate_t *state, uint8_t m);
  
  event Vstate_t VSAbrcv(Vstate_t *state, uint8_t m);
  
}

