/* Test string buffer operations and utilites */

using Vanubi;

static unowned string text = "
foo (
	bar (

";

StringBuffer setup () {
	var buffer = new StringBuffer.from_text (text);
	return buffer;
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

void test_update_copyright_year () {
	var buffer = new StringBuffer.from_text ("non-comment
/* comment
 * ... Copyright (C) 2000-2010
 */");
	buffer.force_in_comment = true;
	assert (update_copyright_year (buffer));
	
	var text = buffer.line_text (2);
	var year = new DateTime.now_local ().get_year ();
	assert (text == @" * ... Copyright (C) 2000-$(year)\n");
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/buffer/simple", test_simple);
	Test.add_func ("/buffer/insert_delete", test_insert_delete);
	Test.add_func ("/files/update_copyright_year", test_update_copyright_year);

	return Test.run ();
}
