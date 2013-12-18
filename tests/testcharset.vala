using Vanubi;

void assert_charset (string text, string echarset, string expect, int efallbacks = 0) {
	string charset = "UTF-8";
	int read;
	int fallbacks;
	var res = (string) convert_to_utf8 (text.data, ref charset, out read, out fallbacks);

	if (charset != echarset) {
		message ("Expected charset %s got %s from string '%s'", echarset, charset, text);
	}
	
	if (res != expect) {
		message ("Expected text '%s' got '%s'", expect, res);
	}
	
	if (fallbacks != efallbacks) {
		message ("Expected %d fallbacks got %d from '%s'", efallbacks, fallbacks, text);
	}
	
	assert (charset == echarset);
	assert (fallbacks == efallbacks);
	assert (res == expect);
}

void test_detect () {
	assert_charset ("foobar", "UTF-8", "foobar");
	assert_charset ("foobar\xc3\xaczz", "UTF-8", "foobarìzz");
	assert_charset ("foobar\xeczz", "ISO-8859-1", "foobarìzz");
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/charset/detect", test_detect);

	return Test.run ();
}