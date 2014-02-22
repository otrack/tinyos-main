#ifndef _PAXOS_H_
#define _PAXOS_H_

/* 
 *   Useful Aliases and Constants
 */

enum {
  PHASE_1A = 0,
  PHASE_1B = 1,
  PHASE_2A = 2,
  PHASE_2B = 3,
  QUORUM_SIZE = 2,
  PAXOS_PAYLOAD_SIZE = 10 // FIXME do a proper evaluation of this
};

typedef nx_uint16_t ballot_t;
typedef nx_uint16_t iid_t;
typedef nx_struct value_t{
  nx_uint8_t data[PAXOS_PAYLOAD_SIZE];
}value_t;

/*
 * Propose and Phase 1 messages
 */

typedef nx_struct propose_msg_t {
  value_t value;
} propose_msg_t;

typedef nx_struct phase1a_msg_t {
  nx_uint16_t nodeid;
  iid_t instance;
  ballot_t ballot;
} phase1a_msg_t;

typedef nx_struct phase1b_msg_t {
  nx_uint16_t nodeid;
  nx_uint16_t leaderid;
  iid_t instance;
  ballot_t ballot;
  ballot_t lbal;
  value_t lval;
} phase1b_msg_t;

/*
 * Phase 2 messages
 */

typedef nx_struct phase2a_msg_t {
  nx_uint16_t nodeid;
  iid_t instance;
  ballot_t ballot;
  value_t value;
} phase2a_msg_t;

typedef nx_struct phase2b_msg_t {
  nx_uint16_t nodeid;
  iid_t instance;
  ballot_t ballot;
  value_t value;
  nx_uint16_t notUsed;
} phase2b_msg_t;

/*
 * Leader
 */

typedef struct leader_t {
  ballot_t ballot;
  bool gotProposal;
  value_t toPropose;
  uint16_t nmsgs;
  ballot_t hbal;
  value_t hval;
} leader_t;

/*
 * Acceptor
 */

typedef struct acceptor_t {
  ballot_t cbal;
  ballot_t lbal;
  value_t lval;
} acceptor_t;

/*
 * Learner
 */

typedef struct learner_t {
  ballot_t ballot;
  nx_uint16_t nmsgs;
  value_t decision;
} learner_t;


/*
 * Instance
 */

typedef struct instance_t{
  iid_t id;
  nx_uint16_t phase;
  leader_t leader;
  acceptor_t acceptor;
  learner_t learner;
} instance_t;

#endif
