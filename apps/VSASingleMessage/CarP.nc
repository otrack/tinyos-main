module CarP {
  provides interface Car;	
  uses{
    interface SplitControl as Control;
    interface Receive;
    interface Packet;

  }
}
implementation {
  message_t packet;
  uint8_t busy;
     
  command void Car.init() {
    call Control.start();
  }
    
  event void Control.startDone(error_t err) {
    if (err != SUCCESS) {
      call Control.start();
    }	
  }

  event void Control.stopDone(error_t err) {
  }

  event message_t* Receive.receive(message_t* msg, void* payload, uint8_t len)
  {	      
    signal  Car.receive(msg, payload, len);
    return msg;
  }
	
}