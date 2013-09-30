#ifndef CONTROLSYSTEM_H
#define CONTROLSYSTEM_H

#ifdef PLATFORM_MICAZ
#define powf pow
#define TDMA
#include "StorageVolumes.h"
#endif

#include "car.h"

#define MAXSPEED 60
#define Tr 100
#define INF 1000

#define HCC 3
#define HPP 1.5

#define TIMEBETWEENCROSSING 0.5

typedef struct CarData {
	float 		x;
	float 		y;
	uint32_t 	ts;
	uint8_t		distanceFront;
	uint8_t		heading;
	uint8_t		lane;
	uint8_t 	distanceIntersection;
	uint8_t 	pressSpeed;
	//float 		s;
/*	uint32_t init;
	uint32_t end;	*/
} CarsData_t;

#pragma pack(push,1)
typedef struct Location {    
	float x;
	float y;	
	uint8_t pressSpeed;
	uint8_t speed;
	uint8_t distanceFront;	
	uint8_t disJunction;
	uint8_t heading;
	uint8_t lane;
	uint8_t distanright;
	uint8_t distanleft;
} PKTLocation_t;
#pragma pack(pop)



typedef struct SpeedCC {
	float speed;
	uint32_t init;
	uint32_t end;	
} Speed_t;


typedef struct PPInterval {
	uint32_t ppStart[2];
	uint8_t  length;
} PPInterval_t;

enum {
  POSITION = 4,
  PLATOON_FORMATION = 5,
  COORDINATION = 6,
  START_LANE_CHANGE = 7
};

enum {
  PLATOON_MODE = 1,
  COOPERATIVE_INTERSECTION_MODE = 4,
  LANECHANGE = 	32,
  LANECHANGEINPROGRESS = 64
};

enum {
  WANTS_TO_CHANGE_LANE = 1,
  MAKE_SPACE = 2
};


#endif
