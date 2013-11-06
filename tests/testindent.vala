/**
 * Test the indentation API.
 */

using Vanubi;

void test_simple () {
	var text = "
foo (
	bar (
";
	var buffer = new StringBuffer.from_text (text);
	assert (buffer.text == text);
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/indent/simple", test_simple);

	return Test.run ();
}
