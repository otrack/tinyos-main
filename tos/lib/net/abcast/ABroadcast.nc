interface ABroadcast<T>{
  command void init();
  command T* bcast(T *m);
  event void brcv(T *m);
}

