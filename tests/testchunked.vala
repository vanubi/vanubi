/**
 * Test chunked input stream.
 */

using Vanubi;

void test_simple () {
	var loop = new MainLoop (MainContext.default ());
	test_simple_async.begin (loop);
	loop.run ();
}

async void test_simple_async (MainLoop loop) {
	var is = new MemoryInputStream.from_data ("\x00\x00\x00\x05xxxx\n".data, GLib.free);
	var os = new MemoryOutputStream (null, GLib.realloc, GLib.free);

	var ch = new DataInputStream (new ChunkedInputStream (is, os, null));
	/* var line = yield ch.read_line_async (); */
	/* message("asd %s", line); */
	
	loop.quit ();
}	

int main (string[] args) {
	Test.init (ref args);

	/* Test.add_func ("/chunked/simple", test_simple); */

	return Test.run ();
}
