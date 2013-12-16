/**
 * Test the commentation API.
 */

using Vanubi;

void comment_default (Buffer buffer, int line) {
	var commenter = new Comment_Default (buffer);
	var iter = buffer.line_start (line);
	commenter.comment (iter, iter);
}

void comment_hash (Buffer buffer, int line) {
	var commenter = new Comment_Hash (buffer);
	var iter = buffer.line_start (line);
	commenter.comment (iter, iter);
}

void comment_asm (Buffer buffer, int line) {
	var commenter = new Comment_Asm (buffer);
	var iter = buffer.line_start (line);
	commenter.comment (iter, iter);
}

void comment_lua (Buffer buffer, int line) {
	var commenter = new Comment_Lua (buffer);
	var iter = buffer.line_start (line);
	commenter.comment (iter, iter);
}

void test_default () {
	var buffer = new StringBuffer.from_text ("
foo bar
/* asd asd */
");
	var orig = buffer.line_text (0);
	comment_default (buffer, 0);
	assert (orig == buffer.line_text(0));

	comment_default (buffer, 1);
	assert (/\/\* .+ \*\//.match(buffer.line_text (1)));

	comment_default (buffer, 2);
	assert (buffer.line_text (2) == "asd asd\n");
}

void test_default_region () {
	var buffer = new StringBuffer.from_text ("
foo bar
/* asd asd */
   
");
	var commenter = new Comment_Default (buffer);

	commenter.comment (buffer.line_start (1), buffer.line_start (3));
	assert (/\/\* .+ \*\//.match(buffer.line_text (1)));
	assert (buffer.line_text (2) == "/* \\/* asd asd *\\/ */\n");
	assert (buffer.line_text (3) == "   \n");

	commenter.comment (buffer.line_start (1), buffer.line_start (3));
	assert (buffer.line_text (1) == "foo bar\n");
	assert (buffer.line_text (2) == "/* asd asd */\n");
	assert (buffer.line_text (3) == "   \n");
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

void test_hash_region () {
	var buffer = new StringBuffer.from_text ("
foo bar
# asd asd
");
	var commenter = new Comment_Hash (buffer);

	commenter.comment (buffer.line_start (1), buffer.line_start (2));
	assert (buffer.line_text (1) == "# foo bar\n");
	assert (buffer.line_text (2) == "# # asd asd\n");

	commenter.comment (buffer.line_start (1), buffer.line_start (2));
	assert (buffer.line_text (1) == "foo bar\n");
	assert (buffer.line_text (2) == "# asd asd\n");
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

void test_asm_region () {
	var buffer = new StringBuffer.from_text ("
foo bar
; asd asd
");
	var commenter = new Comment_Asm (buffer);

	commenter.comment (buffer.line_start (1), buffer.line_start (2));
	assert (buffer.line_text (1) == "; foo bar\n");
	assert (buffer.line_text (2) == "; ; asd asd\n");

	commenter.comment (buffer.line_start (1), buffer.line_start (2));
	assert (buffer.line_text (1) == "foo bar\n");
	assert (buffer.line_text (2) == "; asd asd\n");
}

void test_lua () {
	var buffer = new StringBuffer.from_text ("
foo bar
");
	comment_lua (buffer, 0);
	assert (/-- .*/.match(buffer.line_text (0)));

	comment_lua (buffer, 1);
	assert (/-- .+/.match(buffer.line_text (1)));
}

void test_lua_region () {
	var buffer = new StringBuffer.from_text ("
foo bar
-- asd asd
");
	var commenter = new Comment_Lua (buffer);

	commenter.comment (buffer.line_start (1), buffer.line_start (2));
	assert (buffer.line_text (1) == "-- foo bar\n");
	assert (buffer.line_text (2) == "-- -- asd asd\n");

	commenter.comment (buffer.line_start (1), buffer.line_start (2));
	assert (buffer.line_text (1) == "foo bar\n");
	assert (buffer.line_text (2) == "-- asd asd\n");
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/comment/default", test_default);
	Test.add_func ("/comment/default-region", test_default_region);
	Test.add_func ("/comment/hash", test_hash);
	Test.add_func ("/comment/hash-region", test_hash_region);
	Test.add_func ("/comment/asm", test_asm);
	Test.add_func ("/comment/asm-region", test_asm_region);
	Test.add_func ("/comment/lua", test_lua);
	Test.add_func ("/comment/lua-region", test_lua_region);

	return Test.run ();
}
