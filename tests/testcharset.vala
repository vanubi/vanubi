using Vanubi;

void test_detect () {
	var charset = detect_charset ("foobar".data);
	assert (charset == "ISO-8859-1");
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/charset/detect", test_detect);

	return Test.run ();
}