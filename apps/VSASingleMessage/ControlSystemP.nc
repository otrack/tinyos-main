#include "VSA.h"
#include <Timer.h>
#include <math.h>
// #include <assert.h>
#include "ControlSystem.h"

#define PLATOON_INTERVAL 2*TSLICE + 2*D
#define NUMLANES 2

module ControlSystemP{
  uses{
    interface Boot;
    interface GVSA;
    interface Car;
    interface Leds;
  }
}

implementation{
  Vstate_t state;
  uint8_t pressSpeed;
  uint8_t modeOfOperation=0;
      
  PPInterval_t ppInterval;
  uint32_t lcstart;
      
  /* uint32_t arrivalTimes[IDS];*/
      
  CarsData_t carData[IDS];
  uint32_t now;
  uint8_t laneChangeRole[2];
  uint8_t laneChangeSpeed;
  uint8_t originalChangeSpeed;
  uint32_t timeout;
  uint32_t timeout2;
      
     
      
  uint8_t f(uint32_t delay, uint32_t duration)
  {
    if (duration==TSLICE)
      {
	if (delay <= D)
	  return 80;
	else
	  return 70;
      }
    return 60;
  }
     
  event void Boot.booted() {
    Vstate_t startu;
    ppInterval.length = 0;
    startu.state=0;
    startu.duration=0;
    startu.state = 0;
    call Car.init();
    call GVSA.init(startu);
  }
      
  /////////////CAR
  // Receive location,heading,speed from the vehicle
  event message_t* Car.receive(message_t* msg, void* payload, uint8_t len){
    dbg("log","ControlSystem.receive %lu, %lu \n", len, sizeof(PKTLocation_t));
    //dbg("LEDS", "Info Getting size %lu %lu %lu\n", sizeof(PKTLocation_t) , len, sizeof(CompleteMessage_t));
    if(sizeof(PKTLocation_t) == len){

      PKTLocation_t* rx_pkt = (PKTLocation_t*)payload;

      call GVSA.GPSUpdate(IDS+1, rx_pkt);
    }
    return msg;
  }
      
      
      
  event void GVSA.Clock(uint32_t n)
  {
    bool inInterval = FALSE;
    now = n;

    if (ppInterval.length > 0)
      {
	if (ppInterval.ppStart[0] <= now && now <= ppInterval.ppStart[0] +PLATOON_INTERVAL)
	  inInterval = TRUE;
	else if (now > ppInterval.ppStart[0] +PLATOON_INTERVAL)
	  {
	    ppInterval.ppStart[0] = ppInterval.ppStart[1];
	    ppInterval.length--;
	    if (ppInterval.ppStart[0] <= now && now <= ppInterval.ppStart[0]+PLATOON_INTERVAL)
	      inInterval = TRUE;
	  }
      }

    if (!(modeOfOperation & PLATOON_MODE) && inInterval)
      {
	modeOfOperation |= PLATOON_MODE;
	dbg("LEDS", "SetPlatoon %lu,%lu\n", TOS_NODE_ID, 60);
      }
    // else if ((modeOfOperation & PLATOON_MODE) && inInterval)
    // {
    // ;
    // //dbg("LEDS", "SetPlatoon %lu,%lu\n", TOS_NODE_ID, 60);
    // }
    else if ((modeOfOperation & PLATOON_MODE) && !inInterval)
      {
	modeOfOperation &= ~PLATOON_MODE;
	//dbg("LEDS", "Info End of platoon interval %lu %lu\n", now, ppInterval.length);
	dbg("LEDS", "SetCruiseControl %lu\n", TOS_NODE_ID);
      }
    // else
    // {
    // //dbg("LEDS", "SetCruiseControl %lu\n", TOS_NODE_ID);
    // }
    //if (QualityDSI())

    if (0 < carData[TOS_NODE_ID].distanceIntersection &&
	carData[TOS_NODE_ID].distanceIntersection <= 3
	&& !(modeOfOperation & COOPERATIVE_INTERSECTION_MODE))
      {
	dbg("LEDS", "SetSpeed %lu,%lu\n", TOS_NODE_ID, carData[TOS_NODE_ID -1 ].pressSpeed / 2.0);
      }
 
    if (timeout > 0 && modeOfOperation & LANECHANGE)
      {
	timeout--;
	if (timeout == 0 && modeOfOperation & LANECHANGE)
	  {
	    modeOfOperation &= ~LANECHANGE;
	    dbg("LEDS", "SetSpeed %lu,%lu\n", TOS_NODE_ID, originalChangeSpeed);
	    dbg("LEDS", "Info %lu returning original speed %lu\n", TOS_NODE_ID, originalChangeSpeed);
	  }
      }


    call GVSA.bcastNode(POSITION);
    //alignSpeeds();
  }
     
     

  event bool GVSA.nodebrcv(CompleteMessage_t *msg)
  {
    //if (POSITION != msg->msg)
    // /dbg("VSA OUTPUT", "Info %lu receiving message from %lu\n", TOS_NODE_ID,msg->src);
    if (POSITION == msg->msg)
      {
	//if (QualityDSI())
	carData[msg->src-1].x = msg->x;
	carData[msg->src-1].y = msg->y;
	carData[msg->src-1].distanceFront = msg->distanceFront;
	carData[msg->src-1].ts = msg->ts;
	carData[msg->src-1].heading = msg->heading;
	carData[msg->src-1].lane = msg->lane;
	carData[msg->src-1].distanceIntersection = msg->distanceIntersection;
	carData[msg->src-1].pressSpeed = msg->pressSpeed;
	if (carData[TOS_NODE_ID].distanceIntersection == 0)
	  modeOfOperation &= ~COOPERATIVE_INTERSECTION_MODE;
	return FALSE;
      }
    else if (PLATOON_FORMATION == msg->msg)
      {
	if (msg->vstate & PLATOON_MODE)
	  {
	    if ((1<<(TOS_NODE_ID-1)) & msg->platoon)
	      {
		if (ppInterval.length < 2)
		  ppInterval.ppStart[ppInterval.length++] = msg->start;
		pressSpeed = msg->pressSpeed;
	      }
	  }
	else
	  {
	    if (ppInterval.length >= 1)
	      ppInterval.length = 1;
	  }
	return FALSE;
      }
    else if (COORDINATION == msg->msg)
      {
	modeOfOperation |= COOPERATIVE_INTERSECTION_MODE;
	if (msg->v0 == TOS_NODE_ID)
	  {
	    modeOfOperation |= COOPERATIVE_INTERSECTION_MODE;
	    dbg("LEDS", "Info Receiving Coordination %lu,%lu\n", msg->v0, msg->pressSpeed);
	    dbg("LEDS", "SetSpeed %lu,%lu\n", TOS_NODE_ID, msg->pressSpeed);
	  }
	return FALSE;
      }
    else if (START_LANE_CHANGE == msg->msg)
      {
	lcstart = msg->start;
	laneChangeRole[0] = msg->v0;
	laneChangeRole[1] = msg->v1;
	laneChangeRole[2] = msg->v2;
	laneChangeSpeed = msg->pressSpeed;
	originalChangeSpeed = laneChangeSpeed;
	if (msg->v2 == TOS_NODE_ID)
	  laneChangeSpeed = msg->pressSpeed -15 > 0 ? msg->pressSpeed -15 : 0;
	else if (msg->v1 == TOS_NODE_ID-1)
	  {
	    laneChangeSpeed = msg->pressSpeed -7 > 0 ? msg->pressSpeed -7 : 0;
	    dbg("LEDS", "setChangeLane %lu\n", TOS_NODE_ID);
	  }

	dbg("LEDS", "SetSpeed %lu,%lu\n", TOS_NODE_ID, laneChangeSpeed);

	dbg("LEDS", "Info %lu preparing for lane change %lu,%lu\n", TOS_NODE_ID, msg->start, laneChangeSpeed);
	modeOfOperation |= LANECHANGE;
	timeout = 50;
	return FALSE;
      }
    return TRUE;
  }
      
      
  ///////////// Coordinator
  event Vstate_t GVSA.transition(Vstate_t *vstate, uint8_t m)
  {
    state =*vstate;
    return state;
  }
  event Vstate_t GVSA.VSAbrcv(Vstate_t *vstate, uint8_t m)
  {
    state = *vstate;
    return state;
  }
      
  void processCoordination(Vstate_t *vstate)
  {
    uint8_t i,j, v, carNotRequired=0;

    for (i=0; i<IDS-1; i++)
      {
	// dbg("LOG", "Distance intersection %u",carData[i].distanceIntersection);
	if (!(vstate->state & COOPERATIVE_INTERSECTION_MODE))
	  {
	    if (carData[i].distanceIntersection > 3)
	      {
		for (j=0; j<IDS; j++)
		  {
		    if (carData[j].distanceIntersection > 0 && i != j)
		      {
			float t1 = (float)carData[i].distanceIntersection/(float)carData[i].pressSpeed;
			float t2 = (float)carData[j].distanceIntersection/(float)carData[j].pressSpeed;
			dbg("LEDS", "Info Sending Coordination %lu,%f, %f \n", v, t1, t2);
			if (abs(t1 - t2) < TIMEBETWEENCROSSING)
			  {
			    float speed;
			    if (t1 <= t2)
			      {
				v = j;
				speed = (float)(carData[v].distanceIntersection) / (t2+(float)TIMEBETWEENCROSSING);
			      }
			    else
			      {
				v = i;
				speed = (float)(carData[v].distanceIntersection) / (t1+(float)TIMEBETWEENCROSSING);
			      }
			    call GVSA.sendCoordination(v+1, (uint8_t)speed);
			    dbg("LEDS", "Info Sending Coordination %lu,%lu \n", v, (uint8_t)speed);
			    vstate->state |= COOPERATIVE_INTERSECTION_MODE;
			  }
		      }
		  }
	      }
	    else
	      carNotRequired++;
	  }
      }
    if (carNotRequired <= 1)
      vstate->state &= COOPERATIVE_INTERSECTION_MODE;
  }

      
          
  bool health(uint32_t t)
  {

    return t >= now-1;
  }
      
  void stateMachinePlatoon(bool tr, Vstate_t *vstate)
  {
    //dbg("LEDS", "Info stateMachinePlatoon %lu, %lu %lu\n", (vstate->state & PLATOON_MODE), tr, ppInterval.length == 0);
    if ((tr && !(vstate->state & PLATOON_MODE)) || (ppInterval.length == 0 && tr))
      {
	//speed = f(a);
	//headway = g(a);
	vstate->state |= PLATOON_MODE;
	vstate->start = vstate->now+2*D;
	call GVSA.sendPlatoonMode(f(0,0));
	dbg("LEDS", "Info Cars will start platoon mode %lu %lu %lu\n", TOS_NODE_ID, vstate->start, vstate->platoon );
      }
    else if (tr && (vstate->state & PLATOON_MODE))
      {
	//speed = f(a);
	//headway = g(a);
	if (ppInterval.length <= 1 && ppInterval.ppStart[0] < now)
	  {
	    vstate->state |= PLATOON_MODE;
	    vstate->start = ppInterval.ppStart[0] + PLATOON_INTERVAL;
	    call GVSA.sendPlatoonMode(f(0,0));
	    //dbg("LEDS", "Info Cars will Continue platoon mode %lu %lu %lu\n", TOS_NODE_ID, vstate->start, vstate->platoon );
	  }
	//else
	//dbg("LEDS", "Info Checking platton %lu %lu\n", TOS_NODE_ID, ppInterval.ppStart[0], now);

      }
    else if (!tr && (vstate->state & PLATOON_MODE))
      {
	vstate->state &= ~PLATOON_MODE;
	call GVSA.sendPlatoonMode(f(0,0));
	//dbg("LEDS", "Info Cars will return to cruise control mode %lu %lu\n", TOS_NODE_ID, vstate->state);
      }
    /*else if (!tr && !(vstate->state & PLATOON_MODE))
      {
      dbg("LEDS", "Info Cars will continue in cruise control mode %lu %lu %lu\n", TOS_NODE_ID, vstate->state, tr);
      } */

  }
      
  inline uint32_t distance2(uint8_t i, uint8_t j)
  {
    return (carData[i].x -carData[j].x)*(carData[i].x -carData[j].x) +
      (carData[i].y -carData[j].y)*(carData[i].y -carData[j].y);

  }
      
  void processPlatoon(Vstate_t *vstate)
  {
    uint8_t i,j, car1, car2, car3, p;

    uint8_t count=0;
    uint8_t lane, lane2;
    uint8_t carlane[NUMLANES][IDS];
    uint8_t num[NUMLANES];
    uint32_t c1c2, c1c3, c2c3;
    uint32_t d1;
    uint32_t ht1 = 0;

    c1c2 = 0xffffff;
    c1c3 = 0xffffff;
    c2c3 = 0xffffff;

    for (lane=0; lane<NUMLANES; lane++)
      num[lane] = 0;

    for (i=0; i<IDS; i++)
      {
	if (health(carData[i].ts))
	  {
	    ht1++;
	    carlane[carData[i].lane][num[carData[i].lane]++] = i;
	  }
      }
    //dbg("LEDS", "Info Cars Checking health %lu %lu %lu\n", TOS_NODE_ID, carData[i].ts, ht1);


    count = 0;
    vstate->platoon = 0;
    /// Check for platoon

    for (lane = 0; lane < NUMLANES; lane++)
      {
	if (num[lane]>2)
	  {

	    for (i=0; i<num[lane]; i++)
	      {
		car1 = carlane[lane][i];
		if (carData[car1].distanceFront <= 5 && carData[car1].distanceFront > 0)
		  {
		    vstate->platoon |= 1 << car1;
		    count++;
		  }
		else if (carData[car1].distanceFront == 0xf) // one in front?
		  {
		    for (j=0; j<num[lane]; j++)
		      {
			car2 = carlane[lane][j];
			if (car1 != car2)
			  {
			    if (abs(distance2(car1, car2) -
				    carData[car2].distanceFront*carData[car2].distanceFront) <= 2)
			      {
				vstate->platoon |= 1 << car1;
				count++;
				break;
			      }
			  }
		      }
		  }
		if (count >= 3 && ht1 >= count)
		  stateMachinePlatoon(count >= 3, vstate);
	      }
	  }
      }
    if (vstate->state & LANECHANGE)
      return;
    lane = num[0] <= num[1] ? 0 : 1;
    lane2 = num[0] > num[1] ? 0 : 1;
    car2 = 0xff;
    car3 = 0xff;
    if (num[lane]>0 && num[lane2]>0)
      {

	for (i=0; i<num[lane]; i++)
	  {
	    car1 = carlane[lane][i];
	    if (carData[car1].distanceFront == 0xf) /// only the header can change lanes
	      {
		for (j=0; j<num[lane2]; j++)
		  {
		    p = carlane[lane2][j];
		    d1 = distance2(car1, p);
		    if (carData[p].distanceFront == 0xf && d1 < c1c3)
		      {
			c1c3 = d1;
			car3 = p;
		      }
		    else if (carData[p].distanceFront < 0xf && d1 < c1c2)
		      {
			c1c2 = d1;
			car2 = p;
		      }
		  }
		c2c3 = distance2(car2, car3);
		if (c1c2 > c1c3 && c1c3 < c2c3*3 && c1c2 < c1c3 + c2c3 &&
		    abs(c2c3 - carData[car2].distanceFront*carData[car2].distanceFront) <= 4 &&
		    carData[car2].pressSpeed > 0)
		  {
		    vstate->state |= LANECHANGE;
		    vstate->start = vstate->now+2*D;
		    call GVSA.sendLaneChange(car2, car1, car3, carData[car2].pressSpeed);
		    timeout2 = 50;
		  }
	      }
	  }
      }
  }
      
      
  event void GVSA.VSAclock(Vstate_t *vstate)
  {
    //if (vstate->duration == 0)
    //return FALSE;
    processCoordination(vstate);
    processPlatoon(vstate);

    state =*vstate;
    if (timeout2 > 0 && vstate->state & LANECHANGE)
      {
	timeout2--;
	if (timeout2 == 0)
	  vstate->state &= ~LANECHANGE;
      }

  }
}
