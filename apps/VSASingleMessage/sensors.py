#!/usr/bin/env python

import math
import angles
from numpy import *
import pyglet
from pyglet.gl import *

from Location import *

    
class Sensor:
  def __init__(self, id, angle, r, x, y):
    self.angle = angle
    self.r = r
    self.id = 0
    self.distance = 0
    self.x = 0
    self.y = 0


  def draw(self) :
    glBegin(GL_TRIANGLES)
    glColor4f(0.1, 0.1, 0.1, 1);
    x1 = self.r
    y1 = 0
    x2 = math.cos(self.angle)*self.r
    y2 = math.sin(self.angle)*self.r
    glVertex2f(self.x, self.y)
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
    
    
  
    self.front.id = 0
    self.d2 = self.front.distance
    self.front.distance = -1
    for car in cars:
      if self.id != car.id:
	x1 = math.cos(self.theta)
	y1 = math.sin(self.theta)
	x2 = car.x - self.x
	y2 = car.y - self.y
	norm = x2*x2 + y2*y2 
	if 0 < norm and norm <= self.front.r**2 and norm < self.front.distance**2:  # in range
	   print self.front.distance
	  if math.acos((x1*x2+y1*y2)/math.sqrt(norm)) < self.front.angle:
	    self.front.id = car.id
	    self.front.distance = math.sqrt(norm)
	    print self.front.distance
	    if self.d2 > -1:
	      self.cv2=(self.front.distance-self.d2+REFRESH*self.omega)/REFRESH;
	    else:
	      self.cv2 = -1
	    break;
    print self.cv2
	
 
	    
   	    

      
