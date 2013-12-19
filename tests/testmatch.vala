/**
 * Test string matching algorithm.
 * Lower score is better.
 */

using Vanubi;

void test_nomatch () {
	assert (pattern_match ("foo", "bar") < 0);
}

void test_simple () {
	assert (pattern_match ("bar", "bar") == 0);
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
	assert (pattern_match ("op", "open") < pattern_match ("op", "compile"));
}

void test_count () {
	assert (count ("foobar", 'o') == 2);
}

void test_common_prefix () {
	var common = "foobar";
	compute_common_prefix ("foobaz", ref common);
	assert (common == "fooba");
	
	compute_common_prefix ("foobia", ref common);
	assert (common == "foob");
	
	compute_common_prefix ("fqux", ref common);
	assert (common == "f");
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/match/nomatch", test_nomatch);
	Test.add_func ("/match/simple", test_simple);
	Test.add_func ("/match/long", test_long);
	Test.add_func ("/match/substring", test_substring);
	Test.add_func ("/match/similar", test_similar);
	Test.add_func ("/match/count", test_count);
	Test.add_func ("/match/common-prefix", test_common_prefix);

	return Test.run ();
}
