/**
 * Test chunked input stream.
 */

using Vanubi;

void test_buffer () {
	var is = new MemoryInputStream.from_data ("line1\nline2\n".data, GLib.free);
	var bis = new BufferInputStream (is);
	var line = bis.read_line ();
	assert (line == "line1");

	line = bis.read_line ();
	assert (line == "line2");

	line = bis.read_line ();
	assert (line == null);

	line = bis.read_line ();
	assert (line == null);
}

/* void test_simple () { */
	/* var loop = new MainLoop (MainContext.default ()); */
	/* test_simple_async.begin (loop); */
	/* loop.run (); */
/* } */

/* async void test_simple_async (MainLoop loop) { */
	/* var is = new MemoryInputStream.from_data ("\x00\x00\x00\x05xxxx\n".data, GLib.free); */
	/* var os = new MemoryOutputStream (null, GLib.realloc, GLib.free); */

	/* var ch = new DataInputStream (new ChunkedInputStream (is, os, null)); */
	/* \/* var line = yield ch.read_line_async (); *\/ */
	/* \/* message("asd %s", line); *\/ */
	
	/* loop.quit (); */
/* }	 */

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/streams/buffer/sync", test_buffer);

	return Test.run ();
}
