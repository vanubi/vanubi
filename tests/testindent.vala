/**
 * Test the indentation API.
 */

using Vanubi;

unowned string text = "
foo (
	bar (

";

StringBuffer setup () {
	var buffer = new StringBuffer.from_text (text);
	return buffer;
}

bool help_test_c (string buf, int line, int indent) {
	var buffer = new StringBuffer.from_text (buf);
	var iter = buffer.line_start (line);
	var indenter = new Indent_C (buffer);
	indenter.indent (iter);
	var res = buffer.get_indent (line) == indent;
	if (!res) {
		message("Got indent %d instead of %d", buffer.get_indent (line), indent);
	}
	return res;
}

void test_simple () {
	var buffer = setup ();
	assert (buffer.text == text);

	var iter = buffer.line_start (0);
	iter.forward_char ();
	assert (iter.line == 1);
	assert (iter.char == 'f');
	iter.forward_char ();
	assert (iter.char == 'o');
	assert (iter.line_offset == 1);
	assert (buffer.get_indent (1) == 0);
}

void test_insert_delete () {
	var buffer = setup ();
	// set indent to 8 (2 tabs)
	var iter = buffer.line_start (1);
	buffer.set_indent (1, 8);

	iter = buffer.line_start (1);
	assert (iter.char == '\t');
	iter.forward_char ();
	assert (iter.char == '\t');
	iter.forward_char ();
	assert (iter.char == 'f');
	assert (buffer.get_indent (1) == 8);

	// set indent to 4 (1 tab)
	buffer.set_indent (1, 4);

	iter = buffer.line_start (1);
	assert (iter.char == '\t');
	iter.forward_char ();
	assert (iter.char == 'f');
	assert (buffer.get_indent (1) == 4);

	// delete 0 chars
	iter = buffer.line_start (1);
	var iter2 = iter.copy ();
	buffer.delete (iter, iter2);
	assert (buffer.get_indent (1) == 4);

	// delete 1 char
	iter2.forward_char ();
	assert (iter2.line_offset == iter.line_offset+1);
	buffer.delete (iter, iter2);
	assert (buffer.get_indent (1) == 0);
	assert (iter.line_offset == iter2.line_offset);

	// insert
	buffer.insert (iter, "\t");
	assert (iter.line_offset == 1);
	assert (buffer.get_indent (1) == 4);
}

void test_lang_c () {
	var buffer = setup ();
	var iter = buffer.line_start (3);
	var indenter = new Indent_C (buffer);
	indenter.indent (iter);
	assert (buffer.get_indent (3) == buffer.tab_width*2);

	buffer = new StringBuffer.from_text ("
foo (
	bar (foo

");
	iter = buffer.line_start (3);
	indenter = new Indent_C (buffer);
	indenter.indent (iter);
	assert (buffer.get_indent (3) == 9);

	buffer = new StringBuffer.from_text ("
foo (param1,
	 param2) {

");
	iter = buffer.line_start (3);
	indenter = new Indent_C (buffer);
	indenter.indent (iter);
	assert (buffer.get_indent (3) == 4);

	buffer = new StringBuffer.from_text ("
foo (param1,
	 param2) {
                      }
");
	iter = buffer.line_start (3);
	indenter = new Indent_C (buffer);
	indenter.indent (iter);
	assert (buffer.get_indent (3) == 0);
	
	assert (help_test_c("
try {
    {
        foo;
    }
} catch {

", 6, 4));

	assert (help_test_c("
foo (
	bar(
	));

", 4, 0));
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/indent/simple", test_simple);
	Test.add_func ("/indent/insert_delete", test_insert_delete);
	Test.add_func ("/indent/lang_c", test_lang_c);

	return Test.run ();
}
