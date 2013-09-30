#! /usr/bin/python

import sys
import random
import os
import time
import math
sys.path.append('/opt/tinyos-2.1.0/support/sdk/python')
from TOSSIM import *
from tinyos.tossim.TossimApp import *

variables = NescApp().variables.variables()
t = Tossim(variables)
r = t.radio()
mac = t.mac()

layout_file = "layout"
layout_file2 = "layout2"
topo_file = "topo"
logFile1 = "log"
ft1 = open(logFile1, "w")

t.addChannel("log", ft1)
t.addChannel("Boot", sys.stdout)

NODE = 2;
n=NescApp()
SIMULATION_PERIOD = 70000000000000;
MaxDistance = 2 #200
AreaX = 2 #200
AreaY = 2 #200
NeighborRadius = 11
MaxNeighbors = 50
nodesSet = [i for i in range(0,NODE)]

class point:
	def __init__(self, posX, posY):
		self.x = posX
		self.y = posY

class node:
	def __init__(self, nodeId, posX, posY, Target):
		self.id = nodeId
		self.x = posX
		self.y = posY
		self.target = Target
#		self.speedX = SpeedX 
n = [node(0,0,0,point(0,0)) for i in range(0,NODE)]
c = [0 for j in range(0,NODE)];
b = [0 for j in range(0,NODE)];

def readTopo(fname):
	fgain = open(fname, "r")
	lines = fgain.readlines()
	if lines == None:
		print "No topology!"
		sys.exit()
	for line in lines:
		s = line.split()
		if (s[0] == "gain"):
			r.remove(int(s[1]), int(s[2]))
			r.add(int(s[1]), int(s[2]), float(s[3]))
		elif (s[0] == "noise"):
			r.setNoise(int(s[1]), float(s[2]), float(s[3]))
	fgain.close()

def initialTopo():
	ftopo = open(topo_file, "w")  	
	for i in range(0,NODE):
		x = random.uniform(0,AreaX)
		y = random.uniform(0,AreaY)
		targetX = round(random.uniform(0,AreaX),2)
		targetY = round(random.uniform(0,AreaY),2)
		n[i] = node(i,x,y,point(targetX,targetY))  #initialize all the nodes						
		c[i]= str(n[i].id) + "       " + str(n[i].x) + "          " + str(n[i].y) + "\n"
		ftopo.write(c[i])
	ftopo.close()
	os.popen("java LinkLayerModel config.txt " + layout_file + " " + topo_file)


initialTopo()
readTopo(layout_file)

noise = open("meyer-heavy.txt", "r")
lines = noise.readlines()
counter = 0;
for line in lines:
	str1 = line.strip()
	if (str1 != ""):		
		if (counter > 25):
			break;		
		val = int(str1)
		counter = counter + 1	
		for i in range(0, NODE):
			t.getNode(i).addNoiseTraceReading(val)

for i in range(0, NODE):
	t.getNode(i).createNoiseModel()

for i in range(0,NODE):
	t.getNode(i).bootAtTime(200);


########## wait every node is booted ###########
time = t.time()
while(time + 2000 > t.time()):
	t.runNextEvent()
#########################

time = t.time()
terminated = 0
t_node = t.getNode(0)

while(time + SIMULATION_PERIOD > t.time()):
	t.runNextEvent()
