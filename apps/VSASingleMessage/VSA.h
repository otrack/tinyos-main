#ifndef VSA_H
#define VSA_H

//#define 		SIM 0


#define AM_BROADCAST  0x88
#define MAXSYNCTRIES   2

#define UINT 	     uint8_t
#define IDS	     4 		// Max number of vehicles
#define IDVSAS	     1	 	// Max number of regions
#define MAX_VSA_NEIGHBORS 1
#define TIMEUNIT     20        // INTERVAL  

#define D 	     1        // Delay
#define K	     3        // Num of Guards
#define E	     33       // Difference between real and virtual time
#define TSLICE       10      //  D < TSLICE <= E/K (constant)


#define MAX_NUM_MESSAGES     7	      //
#define MAX_PROC_MESSAGES    7	      //
#define MAX_SIM_MESSAGES     7	      //   


#if D >= TSLICE
#error TSlice Must be greater than D
#endif

#if E/K < TSLICE
#error TSlice Must be smaller than E/K
#endif

/*
#pragma pack(push,1)



#pragma pack(pop)*/

typedef struct GV
{
   uint8_t  		src;
   nx_uint32_t     	ts;
} GV_t;



#define ID_bits         3
#define MESSAGE_bits    3
#define REGIONS_bits    3
#define NUMPROC_bits    3
#define NUMGUARD_bits   2
#define VSTATE_bits     4
#define SPEED_bits      8
#define SPACE_bits      3
#define INTERSECTION_bits 2

////////                7
////////                2 BYTES


#if ID_bits*MAX_PROC_MESSAGES > 36
#error Wrong data type in CompleteMessage
#endif

#if MESSAGE_bits*MAX_PROC_MESSAGES > 36
#error Wrong data type in CompleteMessage
#endif


typedef nx_struct SINGEMESSAGE
{
  nx_uint32_t     	ts;
  nx_uint8_t     	src;
  nx_uint8_t 		msg;
} SingleMsg_t;		

enum {
  NULLSTATE = 0,
  STARTJOIN = 1,
  TRYING = 2,
  GUARD = 3,	
  LEADER = 4
  
};


enum {        
	JOIN = 1,
	RESTART = 2,
	END = 3
};

typedef struct VSTATE{	
	uint32_t    duration;
	uint32_t    now;
	uint32_t    start;
	uint8_t     state;
	uint8_t     platoon : IDS;
}Vstate_t;				// sizeof(Vstate_t) == 10




#pragma pack(push,1)
typedef struct CompleteMessage
{
    uint32_t     	ts;			// Timestamp
    uint32_t    	vduration;			// The real time that the leader started
    uint32_t    	vnow;			// the virtual clock
    float		x,y;			// Position
   
    uint32_t    	start;			// [start + ppoffset, start + ppoffset + 2TSLICE + 2D] interval where the speed in the CC is valid   
    
    uint32_t	 	procts[MAX_PROC_MESSAGES];    // Timestamp  of the processed messages 
    uint32_t	 	gvts[K];			// Timestamp  of the guard update
    
    uint32_t		src 		: ID_bits;		// Originator of the message
    uint32_t 		msg 		: MESSAGE_bits;		// Message to be sent
    uint32_t 		reg 		: REGIONS_bits;    	// Region where the node is 
    uint32_t 		numproc	   	: NUMPROC_bits;		// Number of processed messages  
    uint32_t		numguards  	: NUMGUARD_bits;	// Num of guards
    
    uint32_t	 	procmsg  	: MESSAGE_bits*MAX_PROC_MESSAGES;	// Processed Messages 
    uint32_t	 	procsrc  	: ID_bits*MAX_PROC_MESSAGES;    	// Source of the processed messages  
    uint16_t 		gvsrc  		: ID_bits*K;				//   Guards
    
    uint8_t		distanceFront	: 4;				// Distance to the car
    uint8_t		heading		: 4;			// Heading of the car  
    uint8_t		lane		: 1;				// Lane 
    uint8_t		distanceIntersection	: 5;				// Distance to the car
    uint8_t		platoon		: IDS;				// Distance to the car
    
      
    uint8_t		vstate		: VSTATE_bits;				// Vstate	    
    
    uint8_t		speed		: SPEED_bits;				// speed KM/h
    uint8_t		pressSpeed	: SPEED_bits;				// speed KM/h
    
    uint8_t		intersection	: INTERSECTION_bits;		// id of the intersection approaching
    uint8_t		arrivaltimesr0	: ID_bits;		// arrivaltime[arrivaltimesr0]
    
    uint8_t		v0	: ID_bits;		// v is allowed to change lanes between v0,v1
    uint8_t		v1	: ID_bits;
    uint8_t		v2	: ID_bits;
} CompleteMessage_t;






typedef struct HoldQueue
{
     CompleteMessage_t m[MAX_NUM_MESSAGES];
     uint8_t len;
} HoldQueue_t;

typedef struct SimQueue
{
     CompleteMessage_t 		m[MAX_SIM_MESSAGES];
     uint8_t 			len;
} SimQueue_t;




#pragma pack(pop)



typedef struct GuardQueue
{
     GV_t 	gv[IDS];
     uint8_t len;
} GuardQueue_t;

typedef struct JoinRequestQueue
{
     GV_t 	gv[IDS];
     uint8_t len;
} JoinRequestQueue_t;

typedef struct ProcQueue
{
     SingleMsg_t 	m[MAX_NUM_MESSAGES];
     uint8_t len;
} ProcQueue_t;






#endif
