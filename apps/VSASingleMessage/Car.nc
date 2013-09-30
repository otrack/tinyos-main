#include "message.h"
#include "ControlSystem.h"


interface Car {
  command void init();
  event message_t* receive(message_t* msg, void* payload, uint8_t len);
  command void SendCommand(CarCommands_t c);
}

