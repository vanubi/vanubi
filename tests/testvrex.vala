/**
 * Test Vrex language.
 */

using Vanubi;
using Vanubi.Vrex;

void assert_tok_id (Token tok, string str) {
	assert (tok.type == TType.ID);
	assert (tok.str == str);
}

void assert_tok_str (Token tok, string str) {
	assert (tok.type == TType.STRING);
	assert (tok.str == str);
}

void assert_tok_num (Token tok, double num) {
	assert (tok.type == TType.NUM);
	assert (tok.num == num);
}

void assert_tok (Token tok, TType type) {
	assert (tok.type == type);
}

void test_lexer () {
	var code = "foo++ bar-- 'esc\\'ape' 123 321.456";
	var lex = new Lexer (code);
	assert_tok_id (lex.next (), "foo");
	assert_tok (lex.next (), TType.INC);
	assert_tok_id (lex.next (), "bar");
	assert_tok (lex.next (), TType.DEC);
	assert_tok_str (lex.next (), "esc'ape");
	assert_tok_num (lex.next (), 123);
	assert_tok_num (lex.next (), 321.456);
	assert_tok (lex.next (), TType.END);
}

void test_parser () {
	var code = "foo++";
	var parser = new Parser.for_string (code);
	var expr = parser.parse_expression ();
	assert (expr is PostfixExpression);
	var inner = ((PostfixExpression) expr).inner;
	assert (inner is MemberAccess);
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/vrex/lexer", test_lexer);
	Test.add_func ("/vrex/parser", test_parser);

	return Test.run ();
}