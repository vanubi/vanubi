/**
 * Test string matching algorithm.
 * Lower score is better.
 */

using Vanubi;

void test_basedir () {
	assert (get_base_directory (File.new_for_path ("foo/bar")) == Environment.get_current_dir()+"/foo/");
}

void test_abspath () {
	assert (absolute_path ("/foo/", "bar") == "/foo/bar");
	assert (absolute_path ("/foo/", "/bar") == "/bar");
	assert (absolute_path ("/foo/", "~/bar") == Environment.get_home_dir()+"/bar");
	assert (absolute_path ("/foo/", "bar/") == "/foo/bar/");
}

void assert_sp (string[] orig, string[] expected) {
	File[]? files = null;
	foreach (unowned string o in orig) {
		files += File.new_for_path (o);
	}
	
	var shorts = short_paths (files);	
	assert (shorts.length == expected.length);
	foreach (unowned string s in shorts) {
		assert (s in expected);
	}
}

void test_short_paths () {
	assert_sp ({"/foo/a", "/foo/b"}, {"a", "b"});
	assert_sp ({"/foo/a", "/bar/a"}, {"foo/a", "bar/a"});
	assert_sp ({"/bar/foo/a", "/baz/foo/a"}, {"bar/foo/a", "baz/foo/a"});
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/files/basedir", test_basedir);
	Test.add_func ("/files/abspath", test_abspath);
	Test.add_func ("/files/short_paths", test_short_paths);

	return Test.run ();
}
