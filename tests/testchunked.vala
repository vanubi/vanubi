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
	uint8[] data = {5, 0, 0, 0, 'x', 'x', 'x', 'x', '\n'};
	var is = new MemoryInputStream.from_data (data, GLib.free);
	var os = new MemoryOutputStream (null, GLib.realloc, GLib.free);

	var ch = new ChunkedInputStream (is, os, null);
	var buf = new BufferInputStream (ch);
	var line = yield buf.read_line_async ();
	assert(line == "xxxx");
	
	loop.quit ();
}	

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/chunked/simple", test_simple);

	return Test.run ();
}
