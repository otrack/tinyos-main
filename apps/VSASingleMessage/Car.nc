#include "message.h"

interface Car {
  command void init();
  event message_t* receive(message_t* msg, void* payload, uint8_t len);
  
}

