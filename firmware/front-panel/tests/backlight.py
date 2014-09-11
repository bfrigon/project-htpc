import serial
import time
import random




r = 0
g = 0
b = 0

while(True):
	
	r = r + 1
	if (r > 255):
		r = 0
		g = g + 10

		

	setrgb(r,g,b)
	time.sleep(0.05)



