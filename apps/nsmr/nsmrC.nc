module TestPaxosC {
  uses interface Boot;
  uses interface Timer<TMilli> as Timer0;
  uses interface ABroadcast<uint8_t>;
  uses interface Leds;
}
implementation {

  uint8_t round;
  uint4_t counter = 4480;

  event void Boot.booted()
  {
    call Timer0.startPeriodic(1000);
  }

  void setLeds(uint16_t val) {
    if (val & 0x01)
      call Leds.led0On();
    else 
      call Leds.led0Off();
    if (val & 0x02)
      call Leds.led1On();
    else
      call Leds.led1Off();
    if (val & 0x04)
      call Leds.led2On();
    else
      call Leds.led2Off();
  }
  
  event void Timer0.fired() {
    counter++;
    call ABroadcast.bcast(counter);
  }

  event void ABroadcast.brcv(uint4_t v){
    setLeads(v)
  }

}
