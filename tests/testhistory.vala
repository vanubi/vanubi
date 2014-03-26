using Vanubi;

void test_history () {
	var str1 = "foo";
	var str2 = "bar";
	var str3 = "baz";
	var str4 = "qux";

	var hist = new History<string> (str_equal, 3);
	assert (hist.length == 0);

	hist.add (str1);
	assert (hist[0] == str1);

	hist.add (str2);
	assert (hist[0] == str2);
	assert (hist[1] == str1);

	hist.add (str3);
	assert (hist[0] == str3);
	assert (hist[1] == str2);
	assert (hist[2] == str1);
	assert (hist.length == 3);

	hist.add (str4);
	assert (hist[0] == str4);
	assert (hist[1] == str3);
	assert (hist.length == 3);

	hist.add (str4);
	assert (hist[1] == str3);
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/history", test_history);

	return Test.run ();
}