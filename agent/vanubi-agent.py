#!/usr/bin/env python

import sys, socket, os, os.path, struct, stat, getpass, threading, signal

PORT = 62517
VERSION = "1"

def thread (func):
	class Th (threading.Thread):
		def run (self):
			func ()
	th = Th()
	th.start()
	return th

def connect (is_main):
	s = socket.socket (socket.AF_INET, socket.SOCK_STREAM)
	s.connect(("localhost", PORT))

	s.send ("%s\n" % VERSION)
	
	if is_main:
		s.send ("main\n");
	
	s.send ("ident\n");
	s.send (getpass.getuser()+"@"+socket.gethostname()+"\n")
	return s

def main_conn ():
	s = connect (True)
	if len (sys.argv) > 1:
		# send open request
		path = os.path.abspath (sys.argv[1])
		s.sendall ("open\n%s\n" % path)
	s.close ()

def pool_conn ():
	s = connect (False)
	f = s.makefile ("r+b")
	s.close ()
	while True:
		cmd = f.readline ()
		if not cmd:
			f.close ()
			return
		if cmd == "read":
			process_read (f)
		elif cmd == "exists":
			process_exists (f)
		elif cmd == "is_directory":
			process_is_directory (f)
		else:
			print "Unknown command", cmd
			return

def autopath (func):
	def _wrap (f, *args, **kw):
		path = f.readline ()
		if not path:
			f.close ()
			return
		path = os.path.abspath (path)
		return func (f, args+[path], **kw)
	return _wrap

@autopath
def process_exists (f, path):
	if os.path.exists (path):
		f.write ("true\n")
	else:
		f.write ("false\n")

@autopath
def process_is_directory (f, path):
	if os.path.isdir (path):
		f.write ("true\n")
	else:
		f.write ("false\n")

@autopath
def process_read (f, path):
	try:
		size = os.path.getsize (path)
	except Exception, e:
		f.write ("error\n")
		f.write ("Cannot read file: %s\n" % e)
		return

	try:
		file = open (path, "r+b")
	except Exception, e:
		f.write ("error\n")
		f.write ("Cannot read file: %s\n" %e)

	f.write ("%d\n" % size)
	os.sendfile (f, file, 0, size)
	f.write ("0\n")
	file.close ()
	
@autopath
def process_write (f, path):
	try:
		file = open (path, "w+b")
		f.write ("ok\n")
	except Exception, e:
		f.write ("error\n")
		f.write ("Cannot read file: %s\n" %e)
	
	while True:
		size = int(f.readline ())
		if size > 0:
			os.sendfile (file, f, 0, size)
	file.close()

def sigint_handler(*args):
	print 'exiting'
	sys.exit(0)

def main ():
	ths = [thread (main_conn)]
	for x in range(3):
		ths.append (thread (pool_conn))

if __name__ == "__main__":
	main ()
