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

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/files/basedir", test_basedir);
	Test.add_func ("/files/abspath", test_abspath);

	return Test.run ();
}
