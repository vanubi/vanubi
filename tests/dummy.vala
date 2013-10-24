void test_dummy () {
	assert (true);
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/dummy", test_dummy);

	return Test.run ();
}
