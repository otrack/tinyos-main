interface Membership {
  command uint16_t quorumSize();
  command bool contains(uint16_t node);
  command uint16_t leader();
  command uint16_t size();
}
