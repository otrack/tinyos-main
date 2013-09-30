#!/usr/bin/env python

import math
import pyglet 
from pyglet.gl import *


class Primitive:
  def __init__(self, word, length, id, mon=0):
    self.word = word
    self.length = length
    self.id = id
    self.mon = mon
    
class Point:
  def __init__(self, x,y, angle=0, id=0):
    self.x = x
    self.y = y
    self.angle = angle
    self.id = id
    

class Path:
  def __init__(self, maxsteering, angle = 0):
    self.route = []
    self.point = []
    self.maxsteering = maxsteering
    self.initialAngle = angle
    
  def len(self):
    return len(self.route)
  
  def word(self, id):
    return self.route[id].word
  
  def monitored(self, id):
    return self.route[id].mon
  
  def length(self, id):
    return self.route[id].length
    
  def append(self, word, length, mon=0):
    self.route.append(Primitive(word, length, len(self.route), mon))
   
  def computePosition(self, id, dis)  :  
    theta = self.point[0].angle
    x=self.point[0].x
    y=self.point[0].y
    for p in self.point:
      if id == p.id:
	break;
      x = p.x
      y = p.y
      theta = p.angle
    return Point(x+dis*math.cos(theta), y+dis*math.sin(theta), theta, id) 
    
  def computePath(self, initx, inity):
    x = initx
    y = inity
    self.point.append(Point(initx, inity, self.initialAngle, len(self.route)-1))
    nextangle = self.initialAngle
    theta = self.initialAngle
    zeta = 0
    omega = 1
    idRoute = 0
    for prim in self.route:       
      if prim.word == 0:      
	x =  x + prim.length*math.cos(theta)
	y =  y + prim.length*math.sin(theta) 
	
	self.point.append(Point(x,y, nextangle, idRoute))
      elif prim.word == 1:
	zeta =  min(self.maxsteering, prim.length)    
	angle = theta + prim.length 
	while abs(theta -angle) > 0.01:
	  x = x + omega*math.cos(zeta)*math.cos(theta)
	  y = y + omega*math.cos(zeta)*math.sin(theta)	  
	  theta = theta + omega*math.sin(zeta)   
	  self.point.append(Point(x,y, theta, idRoute))
	  zeta =  min(self.maxsteering, angle-theta) 
	nextangle += prim.length
	#idRoute = idRoute +1
	self.point.append(Point(x,y, nextangle, idRoute))
      else:
	zeta =  min(self.maxsteering, prim.length) * prim.word      
	angle = theta + prim.length * prim.word
	while abs(theta -angle) > 0.01:
	  x = x + omega*math.cos(zeta)*math.cos(theta)
	  y = y + omega*math.cos(zeta)*math.sin(theta)
	  theta = theta + omega*math.sin(zeta)   
	  self.point.append(Point(x,y, theta, idRoute))	  
	  zeta =  min(self.maxsteering, theta-angle) * prim.word	
	nextangle -= prim.length  
	#idRoute = idRoute +1
	self.point.append(Point(x,y, nextangle, idRoute))
      idRoute = idRoute +1
    
  def drawPath(self):
    glBegin(GL_LINE_STRIP)  
    glColor3f(1.0, 1.0, 1.0);
    for p in self.point:
      glVertex2f(p.x, p.y)      
    glEnd();
    
   
   
