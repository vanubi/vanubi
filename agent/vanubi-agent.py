#!/usr/bin/env python

import sys, socket, os, os.path, struct, stat, getpass
if len (sys.argv) < 2:
	print "Specify a filename"
	sys.exit (1);

path = os.path.abspath (sys.argv[1])
port = 62517;

try:
	s = os.stat (path)
	if stat.S_ISDIR (s.st_mode):
		print "Path is a directory"
		sys.exit (2)
	size = s.st_size
except Exception, e:
	# new file
	print e
	size = -1
	
if (size >= 0):
	f = open (path, "rb")

s = socket.socket (socket.AF_INET, socket.SOCK_STREAM)
s.connect(("localhost", port))

s.send ("ident\n");
s.send (getpass.getuser()+":"+socket.gethostname()+"\n")

s.send ("open\n");
s.send (struct.pack("%dsx" % (len(path)), path))

if size >= 0:
	while True:
		buf = f.read (4096)
		if not buf:
			break
		s.send (buf)
	f.close ()

while True:
	buf = s.recv (4096)
	if not buf:
		break
	print buf

s.close ()