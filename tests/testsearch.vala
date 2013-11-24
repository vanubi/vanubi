/**
 * Test the search API.
 */

using Vanubi;

StringSearchIndex idx;

void setup () {
	idx = new StringSearchIndex ();
	var doc1 = new StringSearchDocument ("foo", {"bar", "baz"});
	var doc2 = new StringSearchDocument ("test", {"foo", "qux"});
	idx.index_document (doc1);
	idx.index_document (doc2);
}

void test_simple () {
	setup ();

	var result = idx.search ("bar baz", false);
	message("%u", result.length ());
	assert (result.length () == 1);

	result = idx.search ("test qux", false);
	assert (result.length () == 1);

	result = idx.search ("test foo bar", false);
	assert (result.length () == 0);
}

void test_synonyms () {
	setup ();

	var result = idx.search ("syn", false);
	assert (result.length () == 0);

	idx.synonyms["syn"] = "foo";

	result = idx.search ("syn", false);
	assert (result.length () == 2);
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/search/simple", test_simple);
	Test.add_func ("/search/synonyms", test_synonyms);

	return Test.run ();
}
