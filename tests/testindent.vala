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

bool assert_indent (Buffer buffer, int line, int indent) {
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
	var buffer = new StringBuffer.from_text ("
foo {
    bar (foo
         baz);
} test;

single ')' {
inner ')';
next
}

multi (param1,
param2) {
body
}

try {
{
foo;
}
} catch {
inside
}

double (
close(
));

toplevel
");
	var w = buffer.tab_width;
	assert_indent (buffer, 0, 0);
	assert_indent (buffer, 1, 0);
	assert_indent (buffer, 2, w);
	assert_indent (buffer, 3, w*2+1);
	assert_indent (buffer, 4, 0);
	
	assert_indent (buffer, 6, 0);
	assert_indent (buffer, 7, w);
	assert_indent (buffer, 8, w);
	assert_indent (buffer, 9, 0);
	
	assert_indent (buffer, 11, 0);
	assert_indent (buffer, 12, 7);
	assert_indent (buffer, 13, 7);
	assert_indent (buffer, 14, w);
	assert_indent (buffer, 15, 0);
	
	assert_indent (buffer, 17, 0);
	assert_indent (buffer, 18, w);
	assert_indent (buffer, 19, w*2);
	assert_indent (buffer, 20, w);
	assert_indent (buffer, 21, 0);
	assert_indent (buffer, 22, w);
	assert_indent (buffer, 23, 0);
	
	assert_indent (buffer, 25, 0);
	assert_indent (buffer, 26, w);
	assert_indent (buffer, 27, 0);
}

void test_lang_asm () {
	var buffer = new StringBuffer.from_text ("
section .text
label1:
mov eax, ebx
xor eax, eax
label2:
enter
ret
");
	var w = buffer.tab_width;
	assert_indent (buffer, 0, 0);
	assert_indent (buffer, 1, w);
	assert_indent (buffer, 2, 0);
	assert_indent (buffer, 3, w);
	assert_indent (buffer, 4, w);
	assert_indent (buffer, 5, 0);
	assert_indent (buffer, 6, w);
	assert_indent (buffer, 7, w);
}
	
int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/indent/simple", test_simple);
	Test.add_func ("/indent/insert_delete", test_insert_delete);
	Test.add_func ("/indent/lang_c", test_lang_c);
	Test.add_func ("/indent/lang_asm", test_lang_asm);

	return Test.run ();
}
