/**
 * Test string matching algorithm.
 * Lower score is better.
 */

using Vanubi;

void test_simple () {
	assert (pattern_match ("foo", "foobar") < pattern_match ("fo", "foobar"));
}

void test_long () {
	var file = "longlonglonglongfile";
	assert (pattern_match ("l", file) < pattern_match ("f", file));
}

void test_substring () {
	assert (pattern_match ("fb", "foobar") < pattern_match ("or", "foobar"));
}

void test_similar () {
	assert (pattern_match ("ab", "abcd") < pattern_match ("ac", "abcd"));
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/match/simple", test_simple);
	Test.add_func ("/match/long", test_long);
	Test.add_func ("/match/substring", test_substring);
	Test.add_func ("/match/similar", test_similar);

	return Test.run ();
}
