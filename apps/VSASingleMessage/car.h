#ifndef CAR_H
#define CAR_H

typedef struct CarCommands{	
	uint8_t    msg;
	uint8_t	   param1;
} CarCommands_t;


enum {
  STARTPLATOON = 1,
  STOPPLATOON,
  SETSPEED,
  SETLANECHANGE,
  SETSAFETYDISTANCE,
  STATUS
};

#endif
