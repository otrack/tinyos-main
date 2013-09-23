interface Broadcast {
  command void init();
  command void bcast(CompleteMessage_t m);
  event void brcv(CompleteMessage_t *m);
}

