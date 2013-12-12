/**
 * Test the commentation API.
 */

using Vanubi;

void assert_comment (Comment commenter, Buffer buffer, int line) {
	var iter = buffer.line_start (line);
	commenter.comment (iter);
	/* XXX TODO: use asser! */
	message(buffer.line_text (line));
/*	
        if (!res) {
		message("Got indent %d instead of %d for line %d", buffer.get_indent (line), indent, line);
		assert (buffer.get_indent (line) == indent);
	}
*/
}

void assert_comment_default (Buffer buffer, int line) {
	var commenter = new Comment_Default (buffer);
	assert_comment (commenter, buffer, line);
}

void test_default () {
	var buffer = new StringBuffer.from_text ("
foo bar
");
	assert_comment_default (buffer, 1);
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/comment/default", test_default);

	return Test.run ();
}
