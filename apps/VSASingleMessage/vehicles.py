#!/usr/bin/env python

import math
import pyglet
from pyglet.gl import *

SPEEDLIMIT = 1.0
MAXSTEER = math.pi/10
ACCELERATION = 0.01
 
win = pyglet.window.Window()

class primitive:
  def __init__(self, word, length):
    self.word = word
    self.length = length
     
  
path = []
path.append(primitive(0, 50))
path.append(primitive(1, math.pi/4))
path.append(primitive(0, 100))
path.append(primitive(1, math.pi/4))
path.append(primitive(0, 1))
path.append(primitive(1, math.pi/2))
path.append(primitive(0, 50))
path.append(primitive(1, math.pi/4))
path.append(primitive(0, 100))
path.append(primitive(1, math.pi/4))
path.append(primitive(0, 1))
path.append(primitive(1, math.pi/2))


def drawPath():
  originx = 0.0
  originy = 0.0
  theta = 0
  zeta = 0
  glBegin(GL_LINE_LOOP)  
  glColor3f(1.0, 1.0, 1.0);
  glVertex3f(originx, originx, 0.0)
  for prim in path: 
    if prim.word == 0:
      originx =  originx + prim.length*math.cos(theta)
      originy =  originy + prim.length*math.sin(theta) 
      glVertex2f(originx, originy)
    else:
      zeta = zeta + prim.length
      theta = theta + MAXSTEER
      while theta + MAXSTEER <= zeta:
	originx = originx + math.cos(theta) * 20
	originy = originy + math.sin(theta) * 20
        theta = theta + MAXSTEER
	glVertex2f(originx, originy);
      if theta + MAXSTEER >  zeta:
	theta = zeta
	originx = originx + math.cos(theta) * 20
	originy = originy + math.sin(theta) * 20
	glVertex2f(originx, originy);
  glEnd();
   


class Car:
  def __init__(self, x, y, route):
    self.x = x
    self.y = y
    self.route = route 
    self.omega = 0   # speed of the front wheels
    self.zeta = 0  #the angle of the front wheels
    self.theta = 0  # main direction of the car
    self.initX = 0
    self.initY = 0
  
  
  def draw(self):
    glTranslatef(self.x, self.y, 0)
    glPushMatrix();
    glRotatef(self.theta*180/math.pi, 0, 0, 1)
    glBegin(GL_TRIANGLES)
    glColor3f(1.0, 1.0, 0.0);
    glVertex2i(5, 0)
    glVertex2i(-5, 5)
    glVertex2i(-5, -5)
    glEnd()
    glPopMatrix();
       
    if path[self.route].word == 0:
      self.x = self.x + self.omega*math.cos(self.zeta)*math.cos(self.theta)
      self.y = self.y + self.omega*math.cos(self.zeta)*math.sin(self.theta)
      #print self.omega*math.cos(self.zeta)*math.cos(self.theta), self.omega*math.cos(self.zeta)*math.sin(self.theta)
      self.theta = self.theta + self.omega*math.sin(self.zeta)
      self.omega = min(self.omega + ACCELERATION, SPEEDLIMIT/2)
      self.zeta =  0
      if (self.x-self.initX)*(self.x-self.initX) + (self.y-self.initY)*(self.y-self.initY) >= (path[self.route].length)*(path[self.route].length):
	self.route += 1
	if self.route == len(path):
	  self.route = 0
	if path[self.route].word == 0:
	  self.initX = self.x
	  self.initY = self.y
    else:
      
      
      self.zeta =  min(MAXSTEER, path[self.route].length) * path[self.route].word
      if self.theta + MAXSTEER <  path[self.route].length:
	self.x = self.x + self.omega*math.cos(self.zeta)*math.cos(self.theta)  * 20
	self.y = self.y + self.omega*math.cos(self.zeta)*math.sin(self.theta)  * 20
	self.theta = self.theta + MAXSTEER * math.sin(self.zeta)
	print self.zeta , self.theta ,self.x ,self.y 
      #else:
	#self.x = self.x + self.omega*math.cos(self.zeta)*math.cos(self.theta)  * 20
	#self.y = self.y + self.omega*math.cos(self.zeta)*math.sin(self.theta)  * 20
	#self.route += 1
	#if self.route == len(path):
	  #self.route = 0
	#if path[self.route].word == 0:
	  #self.initX = self.x
	  #self.initY = self.y
	#self.theta = self.theta + MAXSTEER * path[self.route].word
    
    
    
    
car1 = Car(0, 0, 0)
 
@win.event
def on_draw():
 
        # Clear buffers
        glClear(GL_COLOR_BUFFER_BIT)
        # Draw outlines only
        #glPolygonMode(GL_FRONT_AND_BACK, GL_LINE)
        glLoadIdentity();
        glTranslatef(100, 100, 0)
        # Draw some stuff
        drawPath()
        car1.draw()
        

pyglet.app.run()
