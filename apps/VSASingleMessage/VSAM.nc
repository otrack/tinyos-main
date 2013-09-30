// #include "assert.h"
#include "VSA.h"
#include <Timer.h>
#include <math.h>

module VSAM{
  provides interface GVSA;	
  uses{
    interface Timer<TMilli> as   clock;
    interface Broadcast<CompleteMessage_t> as Broadcast;
    interface Leds;
  }
}
implementation{
  
  UINT	reg;
  uint8_t   status;
  uint32_t  now, joinreqts,timeslice, round, nowBase, steps;
  bool   leadup, sync;
  Vstate_t vstate;
  Vstate_t startu;
  HoldQueue_t holdq;
  ProcQueue_t procedq;
  SimQueue_t simq;
  JoinRequestQueue_t joinreqs;
  GuardQueue_t guards;
      
  CompleteMessage_t cMessage;
      
  uint32_t vinit;
      
      
  uint8_t   numVSAnbgs;
  uint16_t  ngbs[MAX_VSA_NEIGHBORS];      
      
      
  void set(uint8_t s)
  {	
    call Leds.set(s);
    dbg("LEDS","STATUS %lu,%lu\n", TOS_NODE_ID, s);
    /* if (s != 0)
       dbg("LEDS","Info %lu STATUS %lu\n", TOS_NODE_ID, s);		*/ 
	  
    if (s== LEADER && status != LEADER)
      {
	vinit = now;
	//vstate = signal GVSA.VSAstartLeadership(&vstate);
      }
    if (s==GUARD && status == LEADER)
      {
	cMessage.vduration = now - vinit;
	//vstate = signal GVSA.VSAendLeadership(&vstate);
      }
    //dbg("SERIAL", "STATUS %lu,%lu\%lu\n", now, vstate.now, vstate.duration);
    status = s;
	  
  }
      
  void createCompleteMessage(uint8_t m, uint8_t src)
  {
    uint8_t i;
	 
    cMessage.msg = m;
    cMessage.ts = now;
    cMessage.src = src;
    cMessage.reg = reg;
	  
    if (status == LEADER)
      {
	cMessage.numproc = procedq.len;
	cMessage.numguards = guards.len;
	cMessage.vstate = vstate.state;
	cMessage.platoon = vstate.platoon;
	cMessage.vnow = vstate.now;
	cMessage.start = vstate.start;
	cMessage.procsrc = 0;
	cMessage.procmsg = 0;
	cMessage.gvsrc   = 0;
	for (i=0; i<procedq.len; i++)
	  {
	    cMessage.procts[i] = procedq.m[i].ts;
	    cMessage.procmsg |=  (procedq.m[i].msg) << i*MESSAGE_bits;
	    cMessage.procsrc |=  (procedq.m[i].src) << i*ID_bits;
	  }
	for (i=0; i<guards.len;i++)
	  {
	    cMessage.gvts[i] = guards.gv[i].ts;
	    cMessage.gvsrc |=  (guards.gv[i].src) << i*ID_bits;		
	  }
	      
      }
  }
      
     
  
  command void GVSA.init(Vstate_t s) {
    holdq.len = procedq.len = simq.len = joinreqs.len = guards.len  = 0;
    sync = FALSE;
    call Broadcast.init();
    reg=0;
    steps = 0;
    set(NULLSTATE);	
    now = floor(call clock.getNow()/(float)TIMEUNIT);	  
    startu = s;
    startu.now =now;
    call clock.startOneShot(TIMEUNIT);
  }     
      
  bool isInVSANeighbors(UINT x)
  {
    uint8_t i;
	 
    if (x == reg) return TRUE;
    for(i = 0; i<numVSAnbgs ; i++)
      if (ngbs[i] == x)
	return TRUE;
    return FALSE;
  }
      
      
  bool searchguards(uint8_t nodeID)
  {
    uint8_t i;
    for (i=0; i<guards.len; i++)
      if (guards.gv[i].src == nodeID && guards.gv[i].ts == joinreqts)	 
	return TRUE;		     	     
    return FALSE;		    
  }
      
  void insertsort(uint8_t src, uint32_t ts)
  {
    GV_t gvtemp; 
    uint8_t i, j;
	  
    if (guards.len < IDS)
      {
	guards.gv[guards.len].src = src;
	guards.gv[guards.len++].ts = ts;
	    	    
	    
	for (i=0; i<guards.len-1; i++)
	  for (j=i+1; j<guards.len; j++)
	    if (guards.gv[i].src > guards.gv[j].src)
	      {
		gvtemp = guards.gv[i];
		guards.gv[i] = guards.gv[j];
		guards.gv[j] = gvtemp;		        
	      }  
      }
  }
  
      
  void bcast()
  {	
    call Broadcast.bcast(cMessage);
  }
      
  command void GVSA.bcastNode(uint8_t Message)
  {	
    if (sync)
      {
	createCompleteMessage(Message, TOS_NODE_ID);
	bcast();
      }
  }
      
  command void GVSA.sendPlatoonMode(uint8_t speed)            
  {
    createCompleteMessage(PLATOON_FORMATION, reg); // On behalf of the VSA
    cMessage.pressSpeed = speed;
    //dbg("LEDS", "Info sendPlatoonMode (%lu,%lu)\n", cMessage.start,  cMessage.pressspeed);
    bcast();
  }
      
      
  command void GVSA.sendCoordination(uint8_t id, uint8_t speed)            
  {
    createCompleteMessage(COORDINATION, reg); // On behalf of the VSA
    cMessage.pressSpeed = speed;
    cMessage.v0 = id;
    bcast();
  }
  command void GVSA.sendLaneChange(uint8_t v0, uint8_t v1, uint8_t v2, uint8_t speed)
  {
    createCompleteMessage(START_LANE_CHANGE, reg); // On behalf of the VSA
    cMessage.v0 = v0;
    cMessage.v1 = v1;
    cMessage.v2 = v2;
    cMessage.pressSpeed = speed;
    bcast();
  }
    
  command void GVSA.GPSUpdate(uint8_t region, PKTLocation_t *location)
  {
    if (reg != region)
      {
	if (sync)
	  set(STARTJOIN);	    
	reg =  region;
      }
    cMessage.x = location->x;
    cMessage.y = location->y;
    cMessage.speed = location->speed;
    cMessage.pressSpeed = location->pressSpeed;
    cMessage.distanceFront = location->distanceFront;
    cMessage.heading = location->heading;				// Heading of the car
    cMessage.lane = location->lane;
    cMessage.distanceIntersection = location->disJunction;
      
    //cMessage.arrivaltime = at;	  
  }

      
  event void Broadcast.brcv(CompleteMessage_t *ms)   
  {
    CompleteMessage_t m;
    memcpy(&m, ms, sizeof(CompleteMessage_t));
		  
    if ((0 < m.src && m.src <= IDS) || isInVSANeighbors(m.src)) 
      {	
	if (sync)
	  {
	    if (signal GVSA.nodebrcv(ms) && holdq.len < MAX_NUM_MESSAGES)
	      {		  		
		holdq.m[holdq.len++] = m;		
	      }
	  }
	else
	  {
		  
	    if (m.ts > now)
	      {
		call clock.startPeriodicAt(call clock.getNow() - 10,  TIMEUNIT);
		now = m.ts;
		sync = TRUE;
	      }
	  }
      }
  }  
      
  void bcastjoin()
  {
		  
    //dbg("LEDS","Info bcast(<<join %lu>,%lu, %lu>)\n",  reg, TOS_NODE_ID, now);
      
    joinreqts = now;	  
    timeslice = now+TSLICE;
    nowBase = now;
    round = timeslice + K*TSLICE + D;
    set(TRYING);
    createCompleteMessage(JOIN, TOS_NODE_ID);
    holdq.len = procedq.len = simq.len = joinreqs.len = guards.len  = 0;	    
    bcast();
    //dbg("LEDS","Info trying now=%lu round=%lu, timeslice=%lu \n", now, round, timeslice);
  }
      
  void bcastrestart()
  {	  
    joinreqts = now;
    dbg("LEDS","Info bcast(<<restart %lu>,%lu, %lu>)\n",  reg, TOS_NODE_ID, now);
    guards.len = 0;
    createCompleteMessage(RESTART, TOS_NODE_ID);
    bcast();     	
  }
           
      
  void delayrcv(CompleteMessage_t msg)
  {
    uint8_t j,k;
    GV_t gv;
    CompleteMessage_t ms;
	
    //dbg("LEDS","Info delayrcv %lu, %lu\n", msg.msg, msg.reg);	   
    if (RESTART == msg.msg)
      {	
	if (reg == msg.reg)
	  {
	    if (TRYING == status && round < now)	 
	      {
		insertsort(msg.src, msg.ts);	      
		if (guards.len > K)
		  guards.len = K;	      
	      }
	    else
	      {
		//dbg("LEDS", "Info %lu in STARTJOIN status because TRYING != status and %lu round > now %lu\n", TOS_NODE_ID, round, now);
		set(STARTJOIN);
	      }
	  }
      }
    else if (JOIN == msg.msg)
      {
	// dbg("VSA OUTPUT","joinreqs <- joinreqs U {%lu, %lu}\n", msg.reg, msg.ts);
	if (reg == msg.reg && joinreqs.len < IDS)
	  {
	    joinreqs.gv[joinreqs.len].src =  msg.src;
	    joinreqs.gv[joinreqs.len++].ts =  msg.ts;
	  }
      }
    else 
      {	  
	if (msg.msg != END)
	  {
	    //dbg("VSACode","simq <- simq U {m}\n");
	    if (reg == msg.reg && simq.len < MAX_SIM_MESSAGES)
	      simq.m[simq.len++] = msg;
	  }
      }
    if (msg.src == reg)
      {
	uint8_t len;
	uint32_t Test;
	uint8_t Index;
	    
	if (guards.len > 0 && msg.ghead !=  guards.gv[0].src)
	  {	      
	    set(STARTJOIN);
	    //dbg("LEDS", "Info %lu in STARTJOIN status because %lu is not in the header %lu\n", TOS_NODE_ID, guards.gv[0].src, msg.ghead );
	  }
	if (status != LEADER)
	  {
	    //dbg("LEDS","Info simq <- simq U {m}\n");
	    vstate.duration = msg.vduration; 
	    vstate.now = msg.vnow;
	    vstate.state = msg.vstate;
	    vstate.platoon = msg.platoon;
	    vstate.start = msg.start;
	    vstate.start = msg.start;
	    guards.len = msg.numguards;
	    for (j=0; j<msg.numguards; j++)
	      {		
		guards.gv[j].src = (msg.gvsrc >> (j*ID_bits)) & 0x7;
		guards.gv[j].ts = msg.gvts[j];
	      }
	  }

	len = simq.len;
	simq.len = 0;
	    
	for (j=0; j<len; j++)   // simq = simq/ procedq' and simq = simq/ (ms : ms.ts < mstg.ts-d && ms.ts >= vstate.now
	  {
	    ms = simq.m[j];
	    if (!(ms.ts < msg.ts-D && ms.ts <= vstate.now))
	      {
		
		for (k=0; k<msg.numproc; k++)
		  if (ms.msg == ((msg.procmsg >> k*ID_bits) & 0x7) && 
		      ms.ts == msg.procts[k] &&
		      ms.src == ((msg.procsrc >> k*ID_bits) & 0x7))
		    break;
		if (k == msg.numproc && simq.len < MAX_SIM_MESSAGES) // It does not exist in procedqp
		  simq.m[simq.len++] = ms;
	      }
	  }
	    
	      
	len = joinreqs.len;
	joinreqs.len = 0;
	for (j=0; j<len; j++)  // joinreqs = joinreqs/ guards && joinreqs = joinreqs/ (<q,t> : t < mstg.ts-d
	  {
	    gv = joinreqs.gv[j];
	    if (gv.ts >= msg.ts-D)
	      {
		for (k=0; k<guards.len; k++)
		  if (gv.src == guards.gv[k].src && gv.ts == guards.gv[k].ts)
		    break;
		if (k == guards.len && joinreqs.len < IDS) // It does not exist in guards
		  joinreqs.gv[joinreqs.len++] = gv;
	      }
	  }	    
	if (searchguards(TOS_NODE_ID))
	  {
	    if (TRYING == status)
	      {
		set(GUARD);		
		leadup = FALSE;	       
	      }
	  }
	else if (joinreqts < msg.ts-D)
	  {
	    //dbg("LEDS", "Info %lu in STARTJOIN status because %lu is less than  %lu\n", TOS_NODE_ID, joinreqts, msg.ts-D);
	    set(STARTJOIN);   
	  }
	if (msg.msg == END) 
	  leadup = TRUE;  
      }
    signal GVSA.nodebrcv(&msg);	   
  }
      
  void tsBegin()
  {
    GV_t gv;
    uint8_t i;
    //dbg("LEDS","Info %lu tsBegin: NOW=%lu ROUND=%lu\n", TOS_NODE_ID,now, round); 	  
    if (GUARD == status)
      {	      	      
	//dbg("LEDS","Info %lu tsBegin: Guard=%lu leadup=%lu\n", TOS_NODE_ID,guards.gv[0].src, leadup); 	  
	gv = guards.gv[0];	      
	for (i=1; i<guards.len; i++)
	  guards.gv[i-1] = guards.gv[i];
	if (guards.len > 0)  guards.len--;
	if (leadup)
	  guards.gv[guards.len++] = gv;	      
      } 	   
    if (TRYING == status  && searchguards(TOS_NODE_ID)  && round < now)
      {
	startu.now = now;
	vstate = startu;
	simq.len = joinreqs.len = 0;	      
	set(GUARD);
	//dbg("LEDS","Info Node %lu becomes GUARD  at %lu of region %lu\n", TOS_NODE_ID, now, reg);
      }
    if (GUARD == status  && guards.gv[0].src == TOS_NODE_ID && guards.gv[0].ts == joinreqts)
      {
	//dbg("LEDS","Info Node %lu becomes LEADER at %lu of region %lu\n", TOS_NODE_ID, now, reg);
	set(LEADER);
      }
    leadup = FALSE;
    procedq.len = 0;
    timeslice = now+TSLICE;
    nowBase = now;
  }
      
  void joinhandle(GV_t gv) {
    uint8_t i;
    uint8_t len;
    bool exists = FALSE; 
	   
    //dbg("VSA OUTPUT","joinhandle: %lu\n", now);
    len = guards.len; 
    guards.len = 0; 
    for (i=0; i<len; i++)
      {
	if (gv.src == guards.gv[i].src)
	  {
	    exists = TRUE;
	    if (gv.ts <= guards.gv[i].ts)
	      guards.gv[guards.len++] = guards.gv[i];
	    else 
	      guards.gv[guards.len++] = gv;	      
	  }	 
	else
	  guards.gv[guards.len++] = guards.gv[i];	      
      }
    if (K > guards.len && !exists)
      guards.gv[guards.len++] = gv;
  }
      
  void VSArcv(CompleteMessage_t m)
  {
    vstate = signal GVSA.VSAbrcv(&vstate, m.msg);	
    if (procedq.len < MAX_PROC_MESSAGES)
      {
	procedq.m[procedq.len].msg = m.msg;
	procedq.m[procedq.len].ts = m.ts;
	procedq.m[procedq.len++].src = m.src;
      }
  }
      
           
  command void  GVSA.VSAint(uint8_t act)
  {
    Vstate_t vstatep;
    if (LEADER == status)
      {
	vstate = signal GVSA.transition(&vstate, act);
	if (vstatep.state != NULLSTATE)
	  vstate = vstatep;
      }
  }

  command void GVSA.VSAbcast(uint8_t m)
  {
    uint8_t i;
    Vstate_t vstatep;
    if (LEADER == status)
      {
	createCompleteMessage(m, reg);
	vstatep = signal GVSA.transition(&vstate, m);
	if (vstatep.state != NULLSTATE)
	  {
	    bcast();
	    vstate = vstatep;
	  }        
      } 
  }  
      
  void bcastend()
  {
    uint8_t i;	  
    //dbg("LEDS","Info Node %lu ends leadership at %lu of region %lu and becomes GUARD \n", TOS_NODE_ID, now, reg);
    cMessage.ghead = guards.gv[0].src;
    set(GUARD);
    createCompleteMessage(END, reg);	   	  
    bcast();
	 
    //leadup = TRUE;
  }
    
  event void clock.fired(){ 
    CompleteMessage_t  msg;
    CompleteMessage_t  ms;
    uint8_t i,len;
	   
    now = now + 1;
    signal GVSA.Clock(now);
	   
    if (sync == FALSE)
      {	      
	set(NULLSTATE);
	steps++;
	if (steps == MAXSYNCTRIES)
	  {
	    sync = TRUE;
	    set(STARTJOIN);	      
	    call clock.startPeriodic(TIMEUNIT);
	  }
	else
	  {
	    call clock.startOneShot(TIMEUNIT);
	    return;
	  }
      }
	   
	
	   
    if (LEADER == status &&  guards.len > 0 && (guards.gv[0].src != TOS_NODE_ID && guards.gv[0].ts != joinreqts))
      {
	dbg("LEDS", "Info LEADER == status &&  guards.len > 0 && (guards.gv[0].src != TOS_NODE_ID && guards.gv[0].ts != joinreqts %lu, %lu\n", TOS_NODE_ID, now);
	set(STARTJOIN);
      }
    if (joinreqts > now)
      {
	dbg("LEDS", "Info joinreqts > now %lu, %lu %lu\n", TOS_NODE_ID, now, joinreqts);
	set(STARTJOIN);
      }
    if (round > timeslice + K*TSLICE + D)
      {
	dbg("LEDS", "Info round > timeslice + K*TSLICE + D %lu, %lu %lu\n", TOS_NODE_ID, round, timeslice + K*TSLICE + D);
	set(STARTJOIN);
      }
    if (timeslice != nowBase+TSLICE)
      {
	dbg("LEDS", "Info timeslice != nowBase+TSLICE %lu, %lu %lu\n", TOS_NODE_ID, timeslice, nowBase+TSLICE);
	set(STARTJOIN);
      }
    for (i=0; i<procedq.len; i++)
      if (procedq.m[i].ts > now - D)
	break;
    if (i != procedq.len)
      {
	dbg("LEDS", "Info procedq.m[i].ts > now - D  %lu, %lu\n", TOS_NODE_ID, procedq.len);
	set(STARTJOIN);
      }
    for (i=0; i<simq.len; i++)
      if ((simq.m[i].ts > now - D) && 
	  (simq.m[i].ts < now - ((K+1)*TSLICE+2*D)))
	break;
    if (i != simq.len)
      {
	dbg("LEDS", "Info simq.m[i].ts > now - D) &&  (simq.m[i].ts < now - ((K+1)*TSLICE+2*D)) %lu, %lu\n", TOS_NODE_ID, simq.len);
	set(STARTJOIN);
      }
    for (i=0; i<joinreqs.len; i++)
      if (joinreqs.gv[i].ts > now - D)
	break;
    if (i != joinreqs.len)
      {
	dbg("LEDS", "Info joinreqs.gv[i].ts > now - D %lu, %lu\n", TOS_NODE_ID, joinreqs.len);
	set(STARTJOIN);
      }      	  
	   
    if (vstate.now < now)   // Trajectory of vstate.now
      {
	vstate.now = vstate.now + floor((K*TSLICE)/((float )(TSLICE-D)));
	if (vstate.now < now -E)
	  vstate.now = now - E;
      }
    if (vstate.now > now)   
      vstate.now = now;	   	   
               		    
    if (STARTJOIN == status)  // bcast(<JOIN>)
      bcastjoin();
    else if (TRYING == status && round == now)   // bcast(<restart>)
      bcastrestart();
   
	   
    len = holdq.len;
    holdq.len = 0;
    for(i=0; i<len; i++)
      {	    	      	      	     
	msg = holdq.m[i]; 
	//dbg("LEDS", "Info %lu checking time %lu for delayrcv  %lu\n", TOS_NODE_ID, msg.ts, now - D);
	if (msg.ts == now - D)
	  delayrcv(msg);
	else if (now - D < msg.ts && msg.ts <= now)
	  holdq.m[holdq.len++] = msg;
      }
	    
    if (now == timeslice+D)   // tsBegin
      tsBegin();
    else  if (GUARD == status && !searchguards(TOS_NODE_ID))
      set(STARTJOIN);
	    
    if (status == LEADER)	   
      {	
	signal GVSA.VSAclock(&vstate);
	for (i=0; i<joinreqs.len; i++)
	  joinhandle(joinreqs.gv[i]);
	joinreqs.len = 0;
		
	if (simq.len > 0)
	  {
	    len = simq.len;
	    simq.len = 0;
	    for (i=0; i<len;  i++)
	      {
		if (ms.ts <= vstate.now)
		  VSArcv(simq.m[i]);
		else
		  simq.m[simq.len++] = simq.m[i];
	      }
	  } 
	if (now == timeslice && simq.len == 0 && 
	    joinreqs.len == 0)  
	  bcastend();						
      }
    if (status == LEADER)
      signal GVSA.VSAclock(&vstate);       		
  }
	
}