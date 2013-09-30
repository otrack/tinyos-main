#!/usr/bin/env python

import math
#import angles
from numpy import *
import pyglet
from pyglet.gl import *
from TOSSIM import *
from Location import *
import path

from Location import *


tossim = Tossim([])

LIMITSPEED = 12.0/100.0   # M/mill
MAXSTEER = math.pi/40.0
ACCELERATION = 0.0008
DESACCELERATION = 0.001
REFRESH = 40

TIME = 0

class LaneChange:
  def ccw(self, A,B,C):
	return (C.y-A.y)*(B.x-A.x) > (B.y-A.y)*(C.x-A.x)

  def intersect(self, A,B,C,D):
        return self.ccw(A,C,D) != self.ccw(B,C,D) and self.ccw(A,B,C) != self.ccw(A,B,D)

  
  def __init__(self):
    self.path = path.Path(MAXSTEER)
    self.computed = False
    self.inProgress = 0    
    self.p1 = path.Point(0,0)
    self.p2 = path.Point(0,0)
    self.theta = 0
    
  def Compute(self, x, y,currPath, desPath,  theta, r, d):    
    del self.path.route
    del self.path.point    
    self.path = path.Path(MAXSTEER)
    p1  = path.Point(x,y)
    self.currentPath = currPath
    self.destPath = desPath        
    p2  = path.Point(x + 14*math.cos(theta+ d*math.pi/16.0),  y + 14*math.sin(theta+ d*math.pi/16.0))
    self.computed = False
    for j in range(0, len(self.destPath.point)-1):
      p3 = self.destPath.point[j]     
      p4 = self.destPath.point[j+1]      
      if p4.id == r:
	if self.intersect(p1, p2, p3, p4) :
	  #print '{0} {1} {2} {3}'.format(1*d, math.pi/7.8, -1*d, math.pi/7.8)
	  self.path.append(1*d, math.pi/7.8)    
	  self.path.append(-1*d, math.pi/7.8)
	  self.path.computePath(p1.x, p1.y)
	  self.computed = True	
	break;      

    self.p1 = p1
    self.p2 = p2
    self.theta  = theta
 
  def draw(self):
    glPushMatrix();
    glTranslatef(self.p1.x, self.p1.y, 0)    
    glRotatef(self.theta*180/math.pi, 0, 0, 1)
    glTranslatef(-self.p1.x, -self.p1.y, 0)   
    self.laneChange.path.drawPath()      
    glPopMatrix();
 
 

class Commands:
  def __init__(self, command):
    self.command = command;

    
class Sensor:
  def __init__(self, orientation, angle, r):
    self.orientation = orientation
    self.angle = angle
    self.r = r
    self.id = 0
    self.distance = 0


 

class Car:
  def __init__(self, id, route, lane, dis, path1, path2, micaz):
    self.path1 = path1
    self.path2 = path2
    if lane == 1:
      self.currentpath = path1
    else:
      self.currentpath = path2
    self.lane = lane
    self.laneChange = LaneChange()
    self.laneChangeInProgress = 0
    self.id = id	
    self.point = self.currentpath.computePosition(route, dis)
    self.x = self.point.x
    self.y = self.point.y
    self.route = route -1 
    self.omega = 0  # speed of the front wheels
    self.zeta = 0  #the angle of the front wheels
    self.theta = self.point.angle  # main direction of the car
    self.initX = self.point.x
    self.initY = self.point.y
    self.pressSpeed = 0
    self.speedwithobstacles = 0
    self.nextangle = 0
    self.nextangle = 0
  
    self.front = Sensor(0, math.pi/12.0, 6)
    self.nextWord(True, dis);
    self.micaz = micaz
    self.micaz.bootAtTime(0);
    self.routeLength = self.currentpath.length(self.route) 
    self.completed = dis / self.currentpath.length(self.route) 
    self.speedStacks = []
    self.active = False
    self.x1 = self.x
    self.y1 = self.y
    self.cv2 = -1
    self.d2 = -1
    self.operMode = []
    self.headway = 4
    self.platoon = False
    
  
  def addSensor(self, orientation, angle, R):
    self.sensors.append(Sensor(orientation, angle, R))
     
  def setSpeed(self, speed):
      self.pressSpeed = min(float(speed), LIMITSPEED)
  
  def setPlatoon(self):
    self.platoon = True;
    
  def setSafetyDistance(self, d):
    self.headway = d;
      
  def pushMode(self, Speed, Headway) :
    self.operMode.append([self.pressSpeed, self.headway])   
    self.pressSpeed  = Speed
    self.headway = Headway
    print "Speed ", Speed, " Headway ", Headway
    
  def popMode(self) :
    if len(self.operMode) > 0:
      p = self.operMode.pop()     
      self.pressSpeed = p[0]
      self.headway = p[1]
      print "Pop Speed ", self.pressSpeed, " Headway ", self.headway
    
  def newSpeed(self) :
    print "HERE"
    if self.platoon and self.front.id != 0:
      self.speedwithobstacles = max(self.pressSpeed + ((self.front.distance-self.headway )/(REFRESH*10)), 0);
      
      #print self.id, self.cv2, self.front.distance, self.speedwithobstacles      
      if self.speedwithobstacles  > self.omega:
	self.omega = min(self.omega + ACCELERATION, self.speedwithobstacles)
      else:
	self.omega = min(self.omega + DESACCELERATION, self.speedwithobstacles)
      
    elif self.front.id != 0 and self.front.distance < 8 and self.cv2 < 0xffff:   
      self.speedwithobstacles = self.cv2 + .95*((self.front.distance-self.headway )/REFRESH);
      self.speedwithobstacles = max(min(self.pressSpeed, self.speedwithobstacles), 0)
      
      #print self.id, self.cv2, self.front.distance, self.speedwithobstacles      
      if self.speedwithobstacles  > self.omega:
	self.omega = min(self.omega + ACCELERATION, self.speedwithobstacles)
      else:
	self.omega = min(self.omega + DESACCELERATION, self.speedwithobstacles)
    else:
      self.speedwithobstacles = self.pressSpeed
      if self.pressSpeed > self.omega:
	self.omega = min(self.omega + ACCELERATION, self.pressSpeed)
      else:
	self.omega = min(self.omega + DESACCELERATION, self.pressSpeed)
	if self.omega < 0:
	  self.omega = 0

  
  def changeLane(self) : 
    #print self.route
    if self.path1 != self.path2 and not self.laneChange.computed:
      if self.path1 == self.currentpath:
	self.lane = 0	
	self.destinationPath = self.path2
	self.laneChange.Compute(self.x, self.y, self.currentpath, self.destinationPath, self.theta, self.route, -1)
      else:
	self.lane = 1	
	self.destinationPath = self.path1
	self.laneChange.Compute(self.x, self.y, self.currentpath, self.destinationPath, self.theta, self.route, 1)
      if self.laneChange.computed:
	self.nextWord(0, 0)    
    
  
  def nextWord(self, relative, dis) :    
    if self.laneChange.computed and not self.laneChangeInProgress:
	self.storedRoute = self.route 
	self.route = -1
	self.currentpath = self.laneChange.path
	self.laneChangeInProgress = 1
        
    self.route += 1
    if self.route >= self.currentpath.len():
      if self.laneChangeInProgress:
	self.laneChangeInProgress = 0
	self.laneChange.computed = False
	self.route = self.storedRoute
	self.currentpath = self.destinationPath
	relative = True
	for j in range(0, len(self.currentpath.point)-1):
	  p3 = self.currentpath.point[j]     
	  p4 = self.currentpath.point[j+1]      
	  if p4.id == self.route:
	    dis = math.sqrt((p3.x - self.x)**2 +(p3.y - self.y)**2)
	    break
	  self.theta = self.laneChange.theta
      else:
	self.route = 0
    self.monitored = self.currentpath.monitored(self.route)
    #print "Route ", self.route, self.monitored
      
    if self.currentpath.word(self.route) == 0:
      if relative == True:
	self.desX = self.x + (self.currentpath.length(self.route)-dis)*math.cos(self.theta)
	self.desY = self.y + (self.currentpath.length(self.route)-dis)*math.sin(self.theta)
	self.initX = self.x - dis*math.cos(self.theta)
	self.initY = self.y - dis*math.sin(self.theta)
      else:	
	self.initX = self.x
	self.initY = self.y
	self.desX = self.x + self.currentpath.length(self.route)*math.cos(self.theta)
	self.desY = self.y + self.currentpath.length(self.route)*math.sin(self.theta)
    else:
      self.nextangle = self.theta + self.currentpath.length(self.route) * self.currentpath.word(self.route) 
    
      
  def goStraight(self) :
    cosTheta = math.cos(self.theta)
    sinTheta = math.sin(self.theta)
    self.routeLength = self.currentpath.length(self.route);
    x = self.x + 3*self.omega*cosTheta
    y = self.y + 3*self.omega*sinTheta
    
    d = math.sqrt((x - self.initX)**2 +  (y - self.initY)**2 ) 
    
    if d > self.routeLength:
      self.omega = self.omega + DESACCELERATION
    else: 
      self.newSpeed()
    x = self.x + self.omega*cosTheta
    y = self.y + self.omega*sinTheta
    
    #d = (x - self.initX) / cosTheta
    d = math.sqrt((x - self.initX)**2 +  (y - self.initY)**2 )  
    self.completed = d/self.routeLength
    self.x = x
    self.y = y
    if self.completed > 1:
      self.nextWord(False, 0)     
      
  def goLeft(self) :
    self.zeta =  min(MAXSTEER, self.currentpath.length(self.route))
    if self.theta + self.omega*math.sin(self.zeta) > self.nextangle:
      self.zeta = math.asin((self.nextangle - self.theta)/self.omega)
    else:
      self.newSpeed()
    self.x = self.x + self.omega*math.cos(self.zeta)*math.cos(self.theta)
    self.y = self.y + self.omega*math.cos(self.zeta)*math.sin(self.theta)
    self.theta = self.theta + self.omega*math.sin(self.zeta)      
    
    if self.theta >= self.nextangle:
      self.theta = self.nextangle
      self.nextWord(False, 0)
  
  def goRight(self) :
    self.zeta =  min(MAXSTEER, self.currentpath.length(self.route)) * self.currentpath.word(self.route)
    if self.theta + self.omega*math.sin(self.zeta) < self.nextangle:
      self.zeta = math.asin((self.nextangle - self.theta)/self.omega)
    else:
      self.newSpeed()
    self.x = self.x + self.omega*math.cos(self.zeta)*math.cos(self.theta)
    self.y = self.y + self.omega*math.cos(self.zeta)*math.sin(self.theta)
    self.theta = self.theta + self.omega*math.sin(self.zeta)    
    
    if self.theta <= self.nextangle:
      self.theta = self.nextangle
      self.nextWord(False, 0)
      
  def updateMicaz(self) :
    heading = int(self.theta*180/math.pi)
    heading = heading % 360
    speed = int(self.omega*100.0)
    pressSpeed = int(self.pressSpeed*100.0)
    
    msg = Location()
    msg.set_x(self.x);
    msg.set_y(self.y);    
    msg.set_heading(heading/30);
    if self.laneChangeInProgress:
      msg.set_lane(2);
    else:
      msg.set_lane(self.lane);
    #print self.id,  "in Lane ", self.lane
    msg.set_speed(self.omega);
    msg.set_pressSpeed(self.pressSpeed*600)
        
    #print  self.id, " Updating Micaz: Heading ", heading % 360, "Current Speed K/H", speed, "Press Speed K/H ", pressSpeed
    
    if self.front.id != 0 and self.front.distance < (2**4)-1:
      #print self.id,  " at ", self.omega, " distance ", self.front.distance, " to car ", self.front.id
      #if self.front.distance
      msg.set_distanceFront(int(self.front.distance));      
    else:
      msg.set_distanceFront((2**4)-1);
    if self.monitored == 1:
      if self.omega ==0:
	dis=int(self.routeLength)
      else:
	dis= int(self.routeLength*(1-self.completed))
      msg.set_disJunction(dis);
    else:
      msg.set_disJunction(0);
    serialpkt = tossim.newSerialPacket()
    serialpkt.setData(msg.data)
    serialpkt.setType(0x89)
    serialpkt.setDestination(self.id)
    serialpkt.deliver(self.id,  TIME)
       
      
  def runNextEvent(self, cars, status):
   
    if TIME % REFRESH == 0:
      self.updateMicaz();       
    glPushMatrix();
    glTranslatef(self.x, self.y, 0)    
    glRotatef(self.theta*180/math.pi, 0, 0, 1)
    #glBegin(GL_TRIANGLES)
    if status == '4':
        glColor3f(1, 0.5, 0.5);
    elif status == '3':
	glColor3f(0.5, 1, .5);
    elif status == '2':
	glColor3f(0.5, .5, 1);
    else:
	glColor3f(1.0, 1.0, 1.0);
    if self.active:
      glBegin(GL_QUADS)
      glVertex2f(0.5, 0.5)
      glVertex2f(-0.5, 0.5)
      glVertex2f(-0.5, -0.5)
      glVertex2f(0.5, -0.5)
    else:
      glBegin(GL_TRIANGLES)
      glVertex2f(0.5, 0.0)
      glVertex2f(-0.5, 0.5)
      glVertex2f(-0.5, -0.5)
    glEnd()
  
   
    
    glBegin(GL_TRIANGLES)
    glColor4f(0.1, 0.1, 0.1, 1);
    x1 = self.front.r
    y1 = 0
    x2 = math.cos(self.front.angle)*self.front.r
    y2 = math.sin(self.front.angle)*self.front.r
    glVertex2f(0.5, 0.0)
    glVertex2f(x1, y1)
    glVertex2f(x2, y2)
    
    x1 = self.front.r
    y1 = 0
    x2 = math.cos(-self.front.angle)*self.front.r
    y2 = math.sin(-self.front.angle)*self.front.r
    glVertex2f(0.5, 0.0)
    glVertex2f(x1, y1)
    glVertex2f(x2, y2)
    glEnd()
    glPopMatrix();
    
    if self.laneChange.computed:
      glPushMatrix();
      glTranslatef( self.laneChange.p1.x,  self.laneChange.p1.y, 0)    
      glRotatef( self.laneChange.theta*180/math.pi, 0, 0, 1)
      glTranslatef(- self.laneChange.p1.x, - self.laneChange.p1.y, 0)   
      self.laneChange.path.drawPath()      
      glPopMatrix();
      #self.laneChange.path.drawPath()      
  
    
    self.front.id = 0
    self.d2 = self.front.distance
    self.front.distance = 0xffff
    for car in cars:
      if self.id != car.id:
	x1 = math.cos(self.theta)
	y1 = math.sin(self.theta)
	x2 = car.x - self.x
	y2 = car.y - self.y
	norm = x2**2 + y2**2
	#print norm,self.front.r**2, self.front.distance
	if 0 < norm and norm <= self.front.r**2 and norm < self.front.distance**2:  # in range
	   if math.acos((x1*x2+y1*y2)/math.sqrt(norm)) < self.front.angle:
	    self.front.id = car.id
	    self.front.distance = math.sqrt(norm)	    
	    if self.d2 < 0xffff:
	      self.cv2=(self.front.distance-self.d2+REFRESH*self.omega)/REFRESH;
	    else:
	      self.cv2 = 0xffff
	    
   
    
    if self.currentpath.word(self.route)== 0:
      self.goStraight()
    elif self.currentpath.word(self.route) == 1:
      self.goLeft()
    elif self.currentpath.word(self.route) == -1:
      self.goRight()
	    
   	    

      
