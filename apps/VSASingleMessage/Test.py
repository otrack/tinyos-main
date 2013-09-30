#!/usr/bin/python
import sys
import time

from TOSSIM import *
from Location import *

NUMSENSORS = 3

t = Tossim([])
r = t.radio()
sf = SerialForwarder(9001)

#t.addChannel("log", sys.stdout);
#t.addChannel("Boot", sys.stdout);
#t.addChannel("TRACKING", sys.stdout);
#t.addChannel("VSACode", sys.stdout);
#t.addChannel("VSAMessages", sys.stdout);
#t.addChannel("MAC", sys.stdout);
#t.addChannel("VSA", sys.stdout);
t.addChannel("VSA OUTPUT", sys.stdout);
#t.addChannel("AUTOMATON", sys.stdout);
#t.addChannel("SYNC", sys.stdout);
t.addChannel("LEDS", sys.stdout);


m1 = t.getNode(1)
#m3 = t.getNode(3)
m1.bootAtTime(0);
sf.process();


msg = Location()
msg.set_x(8);
msg.set_y(8);
msg.set_theta(0);
#./msg.set_s(50);
#msg.set_lane(1);
#msg.set_region(4);
#msg.set_numngbs(0);
#msg.set_ngbs([0]);
#msg.set_ts(1);
#serialpkt = t.newSerialPacket()
#serialpkt.setData(msg.data)
#serialpkt.setType(0x89)
#serialpkt.setDestination(1)
#serialpkt.deliver(1, 1)

#serialpkt = t.newSerialPacket()
#serialpkt.setData(msg.data)
#serialpkt.setType(0x89)
#serialpkt.setDestination(2)
#serialpkt.deliver(2, 1)

#serialpkt = t.newSerialPacket()
#serialpkt.setData(msg.data)
#serialpkt.setType(0x89)
#serialpkt.setDestination(3)
#serialpkt.deliver(3, 1)


for i in range(0, 1000):
  t.runNextEvent();
     
m2 = t.getNode(2)
m2.bootAtTime(1000);
r.add(1, 2, -9.0);
#r.add(1, 3, 10.0);
r.add(2, 1, -9.0);
#r.add(2, 3, 10.0);
#r.add(3, 1, 10.0);
#r.add(3, 2, 10.0);

noise = open("meyer-short.txt", "r")
lines = noise.readlines()
for line in lines:
  str = line.strip()
  if (str != ""):
    val = int(str)
    m1.addNoiseTraceReading(val)
    m2.addNoiseTraceReading(val)
    #m3.addNoiseTraceReading(val)

m1.createNoiseModel()
m2.createNoiseModel()
#m3.createNoiseModel()
sf.process();
for i in range(0, 10000):
  t.runNextEvent();
