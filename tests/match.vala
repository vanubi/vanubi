/**
 * Test string matching algorithm.
 * Lower score is better.
 */

using Vanubi;

void test_simple () {
	assert (pattern_match ("foo", "foobar") < pattern_match ("fo", "foobar"));
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/match/simple", test_simple);

	return Test.run ();
}
