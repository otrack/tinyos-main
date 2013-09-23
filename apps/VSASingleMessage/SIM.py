#!/usr/bin/env python

import math
import pyglet
from pyglet.gl import *
from TOSSIM import *
from Location import *
import sys
import subprocess
import re
import path
import car

from pyglet.window import key


 
 
myBuffer = ""


radio = car.tossim.radio()
sf = SerialForwarder(9001)

f = open("pipe", 'w')
f1 = open("pipe", 'r')
car.tossim.addChannel("LEDS",f)
car.tossim.addChannel("SERIAL", sys.stdout);
car.tossim.addChannel("VSA OUTPUT", sys.stdout);
car.tossim.addChannel("LOG", sys.stdout);


keys = key.KeyStateHandler()
win = pyglet.window.Window()

route = path.Path(car.MAXSTEER)

if len(sys.argv) == 1:
   TestCase = "1"
else:
  TestCase = sys.argv[1]

m=[]


if TestCase == "2":
  CARS = 2
  route.append(0, 23.3)
  route.append(-1, 4*math.pi/6)
  route.append(0, 1.5)
  route.append(-1, 4*math.pi/6)
  route.append(0, 24, 1)
  route.append(0, 23.3)
  route.append(1, 4*math.pi/6)
  route.append(0, 1.5)
  route.append(1, 4*math.pi/6)
  route.append(0, 24, 1 )
  route.computePath(0, 0)
  
  for i in range(0, CARS):	
    m.append(car.tossim.getNode(i+1))
  cars = []
  cars.append(car.Car(1, 2, 0, 2, route, route, m[0]))
  cars.append(car.Car(2, 7, 0, 2, route, route, m[1]))
  
  
elif TestCase == "3":  
  CARS = 3
  route2 = path.Path(car.MAXSTEER)
  route.append(0, 24)
  route.append(1, math.pi/4)
  route.append(0, 0.1)
  route.append(1, math.pi/4)
  route.append(0, 1.1)
  route.append(1, math.pi/4)
  route.append(0, 0.1)
  route.append(1, math.pi/4)
  route.append(0, 23.9)
  route.append(1, math.pi/4)
  route.append(0, 0.1)
  route.append(1, math.pi/4)
  route.append(0, 1.1)
  route.append(1, math.pi/4)
  route.append(0, 0.1)
  route.append(1, math.pi/4)
  l1 = 1.4

  route2.append(0, 26)
  route2.append(1, math.pi/4)
  route2.append(0, l1)
  route2.append(1, math.pi/4)
  route2.append(0, 3.5)
  route2.append(1, math.pi/4)
  route2.append(0, l1)
  route2.append(1, math.pi/4)
  route2.append(0, 25.91)
  route2.append(1, math.pi/4)
  route2.append(0, l1)
  route2.append(1, math.pi/4)
  route2.append(0, 3.5)
  route2.append(1, math.pi/4)
  route2.append(0, l1)
  route2.append(1, math.pi/4)

  route.computePath(0, 0)
  route2.computePath(-1, -2.05)
  for i in range(0, CARS):	
    m.append(car.tossim.getNode(i+1))
  cars = []
  cars.append(car.Car(1, 0, 1,  0, route, route2,  m[0]))
  cars.append(car.Car(2, 0, 1, 3, route, route2, m[1]))
  cars.append(car.Car(3, 0, 0, 1, route, route2, m[2]))
  
else:
  CARS = 3
  route.append(0, 24)
  route.append(1, math.pi/4)
  route.append(0, 0.1)
  route.append(1, math.pi/4)
  route.append(0, 1.1)
  route.append(1, math.pi/4)
  route.append(0, 0.1)
  route.append(1, math.pi/4)
  route.append(0, 24)
  route.append(1, math.pi/4)
  route.append(0, 0.1)
  route.append(1, math.pi/4)
  route.append(0, 1.1)
  route.append(1, math.pi/4)
  route.append(0, 0.1)
  route.append(1, math.pi/4)
  
  route.computePath(0, 0)

  for i in range(0, CARS):	
    m.append(car.tossim.getNode(i+1))
  cars = []
  cars.append(car.Car(1, 0, 0, 7, route, route, m[0]))
  cars.append(car.Car(2, 0, 0, 4, route, route, m[1]))
  cars.append(car.Car(3, 0, 0, 1, route, route, m[2]))		      

 

cars[0].active = True

for i in range(0, CARS):
  for j in range(0, CARS):
    if i!=j:
      radio.add(i+1, j+1, 1.0);


noise = open("meyer-short.txt", "r")
lines = noise.readlines()
for line in lines:
  str = line.strip()
  if (str != ""):
    val = int(str)
    for i in range(0, CARS):
      cars[i].micaz.addNoiseTraceReading(val)
    #m3.addNoiseTraceReading(val)

for i in range(0, CARS):
  cars[i].micaz.createNoiseModel()
 
status = []
status.append(1)
status.append(1)
status.append(1)
status.append(1)
pause = False 
scale =5
tranx =375
trany =200
active = 0

@win.event
def on_key_press(symbol, modifiers):  
  global pause, scale, tranx, trany, active
  cars[active].active = False
  if symbol == key.SPACE:
    if pause:
      pause = False
    else:
      pause = True
  if symbol == key.LEFT:
    tranx  = tranx+2
  if symbol == key.RIGHT:
    tranx  = tranx-2
  if symbol == key.UP:
    trany  = trany-2
#    cars[0].setSpeedGain(0.01)
  if symbol == key.DOWN:
    trany  = trany+2
  if symbol == key.A:  # Accelerate active car
    cars[active].setSpeed(cars[active].pressSpeed + 0.01)
  if symbol == key.D:  # Desacelerate active car
    cars[active].setSpeed(max(0, cars[active].pressSpeed - 0.01))
  if symbol ==  key.I:  #Scale 
    scale = scale+1
  if symbol == key.O:
    scale = scale-1
  if symbol ==  key._1:
    active = 0
  if symbol ==  key._2:
    active = 1
  if symbol ==  key._3:
    active = 2
  if symbol ==  key._4:
    active = 3    
    
  if active > CARS:
    active = 0
  cars[active].active = True   
    
  if symbol ==  key.C:
    cars[active].changeLane()
  
  if symbol == key.S:
    for c in cars:
      c.setSpeed(car.LIMITSPEED/3)
  #if symbol == key.C:
    #cars[active].tryChanginLanes = True
  
  

# Pierre : periodic timer to simulate the events processing ?
 
@win.event
def on_draw():	
   # Clear buffers
    global pause, scale
        
    if not pause:
	myBuffer =  f1.readlines()	
	if len(myBuffer) > 0:
	  for line in myBuffer:
	    mm = re.split(r".*STATUS (\d),(\d)", line)
	    if len(mm) > 1:
	      status[int(mm[1])-1] = mm[2]
	    mm = re.split(r".*SetPlatoon (\d),(\d)", line)
	    if len(mm) > 1:
	     print  " cars[ ", int(mm[1])-1, "].pushMode(", int(mm[2])/100.0, " 2)"
	     cars[int(mm[1])-1].pushMode(int(mm[2])/100.0,  2)
	     cars[int(mm[1])-1].setPlatoon()
	    mm = re.split(r".*SetCruiseControl (\d)", line)
	    if len(mm) > 1:
	      #print  " cars[ ", int(mm[1])-1, "].popMode()"
	      cars[int(mm[1])-1].popMode()
	    mm = re.split(r".*SetSpeed (\d),(\d+)", line)
	    if len(mm) > 1:
	      #print "SetSpeed", mm[1], int(mm[2]),  cars[int(mm[1])-1].pressSpeed
	      cars[int(mm[1])-1].setSpeed(int(mm[2])/600.0)
	      #print("SetSpeed", mm[1], mm[2])
	    mm = re.split(r".*setChangeLane (\d)", line)
	    if len(mm) > 1:
	      print "changeLane", mm[1]
	      cars[int(mm[1])-1].changeLane()
	      #print("SetSpeed", mm[1], mm[2])
	    mm = re.split(r".*Info (.*)", line)	
	    if len(mm) > 1:
	      print(mm[1])

        glClear(GL_COLOR_BUFFER_BIT)
        # Draw outlines only
        #glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
        glLoadIdentity();
        glTranslatef(tranx, trany, 0)
        glScalef(scale, scale,1)
        route.drawPath()
        if TestCase == "3":   
	  route2.drawPath()
        #glPopMatrix();
        
        
        for i in range(0, 10):
	  car.tossim.runNextEvent();
        #print car.TIME
        for c in cars:
	  c.runNextEvent(cars, status[c.id-1])
	 
	car.TIME = car.TIME +1
	
	#"Vehicle " + c.id + " at " + self.omega*10000.0/36.0
     
	
glEnable(GL_BLEND);
glBlendFunc(GL_ONE, GL_ONE);



pyglet.app.run()
