interface Broadcast<T>{
  command void init();
  command void bcast(T m);
  event void brcv(T *m);
}

