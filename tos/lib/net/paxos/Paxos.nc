#include "Paxos.h"

interface Paxos<T> {
  command void propose(T* v);
  event void learn(T* v);
}

