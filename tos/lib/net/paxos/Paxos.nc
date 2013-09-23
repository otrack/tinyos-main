#include "Paxos.h"

interface Paxos {
  command void propose(value_t* v);
  event void learn(value_t* v);
}
