/**
 * Test chunked input stream.
 */

using Vanubi;

void test_simple_async () {
	var loop = new MainLoop (MainContext.default ());
	test_simple_async_helper.begin (loop);
	loop.run ();
}

async void test_simple_async_helper (MainLoop loop) {
	uint8[] data = {5, 0, 0, 0, 'x', 'x', 'x', 'x', '\n'};
	var is = new MemoryInputStream.from_data (data, GLib.free);
	var os = new MemoryOutputStream (null, GLib.realloc, GLib.free);

	var ch = new ChunkedInputStream (is, os, null);
	var buf = new BufferInputStream (ch);
	var line = yield buf.read_line_async ();
	assert(line == "xxxx");

	unowned uint8[] outdata = os.get_data ();
	assert (((string) outdata) == "continue\n");
	
	loop.quit ();
}	

void test_simple_sync_thread () {
	var loop = new MainLoop (MainContext.default ());
	Idle.add (() => {
			new Thread<void*> ("chunked/simple", () => { test_simple_sync_helper(loop); return null; });
			return false;
	});
	loop.run ();
}

void test_simple_sync_helper (MainLoop loop) {
	uint8[] data = {5, 0, 0, 0, 'x', 'x', 'x', 'x', '\n'};
	var is = new MemoryInputStream.from_data (data, GLib.free);
	var os = new MemoryOutputStream (null, GLib.realloc, GLib.free);

	var ch = new ChunkedInputStream (is, os, null);
	var buf = new BufferInputStream (ch);
	var line = buf.read_line ();
	assert(line == "xxxx");

	unowned uint8[] outdata = os.get_data ();
	assert (((string) outdata) == "continue\n");

	loop.quit ();
}

void test_simple_sync_mainloop () {
	MainLoop loop = new MainLoop (MainContext.default ());
	
	uint8[] data = {5, 0, 0, 0, 'x', 'x', 'x', 'x', '\n'};
	var is = new MemoryInputStream.from_data (data, GLib.free);
	var os = new MemoryOutputStream (null, GLib.realloc, GLib.free);

	var ch = new ChunkedInputStream (is, os, null);
	var buf = new BufferInputStream (ch);

	Idle.add (() => {
			var line = buf.read_line ();
			assert (line == "xxxx");

			unowned uint8[] outdata = os.get_data ();
			assert (((string) outdata) == "continue\n");

			loop.quit();
			return false;
	});

	loop.run ();
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/chunked/simple/sync/thread", test_simple_sync_thread);
	Test.add_func ("/chunked/simple/sync/mainloop", test_simple_sync_mainloop);
	Test.add_func ("/chunked/simple/async", test_simple_async);

	return Test.run ();
}
