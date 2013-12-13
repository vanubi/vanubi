/**
 * Test the commentation API.
 */

using Vanubi;

void comment_default (Buffer buffer, int line) {
	var commenter = new Comment_Default (buffer);
	var iter = buffer.line_start (line);
	commenter.comment (iter);
}

void comment_hash (Buffer buffer, int line) {
	var commenter = new Comment_Hash (buffer);
	var iter = buffer.line_start (line);
	commenter.comment (iter);
}

void comment_asm (Buffer buffer, int line) {
	var commenter = new Comment_Asm (buffer);
	var iter = buffer.line_start (line);
	commenter.comment (iter);
}

void test_default () {
	var buffer = new StringBuffer.from_text ("
foo bar
");
	var orig = buffer.line_text (0);
	comment_default (buffer, 0);
	assert (orig == buffer.line_text(0));

	comment_default (buffer, 1);
	assert (/\/\* .+ \*\//.match(buffer.line_text (1)));
}

void test_hash () {
	var buffer = new StringBuffer.from_text ("
foo bar
");
	comment_hash (buffer, 0);
	assert (/# .*/.match(buffer.line_text (0)));

	comment_hash (buffer, 1);
	assert (/# .+/.match(buffer.line_text (1)));
}

void test_asm () {
	var buffer = new StringBuffer.from_text ("
foo bar
");
	comment_asm (buffer, 0);
	assert (/; .*/.match(buffer.line_text (0)));

	comment_asm (buffer, 1);
	assert (/; .+/.match(buffer.line_text (1)));
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/comment/default", test_default);
	Test.add_func ("/comment/hash", test_hash);
	Test.add_func ("/comment/asm", test_asm);

	return Test.run ();
}
