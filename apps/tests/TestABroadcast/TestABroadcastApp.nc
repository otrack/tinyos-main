generic module TestABroadcastApp(int PERIOD) {
  uses interface Boot;
  uses interface Timer<TMilli> as Timer0;
  uses interface ABroadcast<uint16_t> as ABroadcast;
  uses interface Leds;
}
implementation {

  uint16_t counter;
  bool locked;

  event void Boot.booted() {
    counter = TOS_NODE_ID;
    locked = FALSE;
    call Timer0.startPeriodic(PERIOD);
  }

  void setLeds(uint16_t val) {
    if (val%2==0)
      call Leds.led0On();
    else 
      call Leds.led0Off();
    if (val%4==0)
      call Leds.led1On();
    else
      call Leds.led1Off();
    if (val%16==0)
      call Leds.led2On();
    else
      call Leds.led2Off();
  }
  
  event void Timer0.fired() {
    if (locked) return;
    counter+=TOS_NODE_ID;
    if (TOS_NODE_ID==1){
      dbg("TEST","broadcasting(%u)\n",counter); 
      call ABroadcast.bcast(&counter);
    }
    locked = TRUE;
  }

  event void ABroadcast.brcv(uint16_t *v){
    if (*v == counter) locked = FALSE;
    setLeds(*v);
    dbg("TEST","received(%u)\n",*v); 
  }

}
