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

void assert_indent (Indent indenter, Buffer buffer, int line, int indent) {
	var iter = buffer.line_start (line);
	indenter.indent (iter);
	var res = buffer.get_indent (line) == indent;
	if (!res) {
		message("Got indent %d instead of %d for line %d", buffer.get_indent (line), indent, line);
		assert (buffer.get_indent (line) == indent);
	}
}

void assert_indent_c (Buffer buffer, int line, int indent) {
	var indenter = new Indent_C (buffer);
	assert_indent (indenter, buffer, line, indent);
}

void assert_indent_asm (Buffer buffer, int line, int indent) {
	var indenter = new Indent_Asm (buffer);
	assert_indent (indenter, buffer, line, indent);
}

void assert_indent_shell (Buffer buffer, int line, int indent) {
	var indenter = new Indent_C (buffer);
	assert_indent (indenter, buffer, line, indent);
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
body1
body2
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

switch(foo) {
case bar:
test
break;
default:
break;
}

if {
if {
} else {
}
}

toplevel
");
	var w = buffer.tab_width;
	assert_indent_c (buffer, 0, 0);
	assert_indent_c (buffer, 1, 0);
	assert_indent_c (buffer, 2, w);
	assert_indent_c (buffer, 3, w*2+1);
	assert_indent_c (buffer, 4, 0);
	
	assert_indent_c (buffer, 6, 0);
	assert_indent_c (buffer, 7, w);
	assert_indent_c (buffer, 8, w);
	assert_indent_c (buffer, 9, 0);
	
	assert_indent_c (buffer, 11, 0);
	assert_indent_c (buffer, 12, 7);
	assert_indent_c (buffer, 13, w);
	assert_indent_c (buffer, 14, w);
	assert_indent_c (buffer, 15, 0);
	
	assert_indent_c (buffer, 17, 0);
	assert_indent_c (buffer, 18, w);
	assert_indent_c (buffer, 19, w*2);
	assert_indent_c (buffer, 20, w);
	assert_indent_c (buffer, 21, 0);
	assert_indent_c (buffer, 22, w);
	assert_indent_c (buffer, 23, 0);
	
	assert_indent_c (buffer, 25, 0);
	assert_indent_c (buffer, 26, w);
	assert_indent_c (buffer, 27, 0);
	
	assert_indent_c (buffer, 29, 0);
	assert_indent_c (buffer, 30, 0);
	assert_indent_c (buffer, 31, w);
	assert_indent_c (buffer, 32, w);
	assert_indent_c (buffer, 33, 0);
	assert_indent_c (buffer, 34, w);
	assert_indent_c (buffer, 35, 0);		
	
	assert_indent_c (buffer, 37, 0);
	assert_indent_c (buffer, 38, w);
	assert_indent_c (buffer, 39, w);
	assert_indent_c (buffer, 40, w);
	assert_indent_c (buffer, 41, 0);
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
	assert_indent_asm (buffer, 0, w);
	assert_indent_asm (buffer, 1, w);
	assert_indent_asm (buffer, 2, 0);
	assert_indent_asm (buffer, 3, w);
	assert_indent_asm (buffer, 4, w);
	assert_indent_asm (buffer, 5, 0);
	assert_indent_asm (buffer, 6, w);
	assert_indent_asm (buffer, 7, w);
}

void test_lang_shell () {
	var buffer = new StringBuffer.from_text ("
if foo; then
bar
else
baz
fi
");
	var w = buffer.tab_width;
	assert_indent_shell (buffer, 0, 0);
	assert_indent_shell (buffer, 1, 0);
	assert_indent_shell (buffer, 2, w);
	assert_indent_shell (buffer, 3, 0);
	assert_indent_shell (buffer, 4, w);
	assert_indent_shell (buffer, 5, 0);
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/indent/simple", test_simple);
	Test.add_func ("/indent/insert_delete", test_insert_delete);
	Test.add_func ("/indent/lang_c", test_lang_c);
	Test.add_func ("/indent/lang_asm", test_lang_asm);
	Test.add_func ("/indent/lang_shell", test_lang_shell);

	return Test.run ();
}
