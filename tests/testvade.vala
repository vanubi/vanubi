/**
 * Test Vrex language.
 */

using Vanubi;
using Vanubi.Vade;

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
	var code = "foo++ bar-- 'esc\\'ape' 3 123 321.456";
	var lex = new Lexer (code);
	assert_tok_id (lex.next (), "foo");
	assert_tok (lex.next (), TType.INC);
	assert_tok_id (lex.next (), "bar");
	assert_tok (lex.next (), TType.DEC);
	assert_tok_str (lex.next (), "esc\\'ape");
	assert_tok_num (lex.next (), 3);
	assert_tok_num (lex.next (), 123);
	assert_tok_num (lex.next (), 321.456);
	assert_tok (lex.next (), TType.END);
}



void assert_expr (string code, string expect) {
	var parser = new Parser.for_string (code);
	var expr = parser.parse_expression ();
	var str = expr.to_string ();
	if (str != expect) {
		message (@"Expect $expect got $str");
	}
	assert (str == expect);
}

void test_parser () {
	assert_expr ("foo++", "foo++");	
	assert_expr ("foo+bar+3", "(foo + (bar + 3))");
	assert_expr ("foo*bar+3", "((foo * bar) + 3)");
	assert_expr ("(++foo)-(--bar)", "(++foo - --bar)");
	assert_expr ("foo; bar = baz", "foo; bar = baz");
	assert_expr ("a=1;b=2;if (a>b) c=5 else c=3", "a = 1; b = 2; if ((a > b)) c = 5 else c = 3");
	assert_expr ("foo; bar; baz={ a b | foo }; end", "foo; bar; baz = { a b | foo }; end");
}



void assert_eval (Scope scope, string code, Vade.Value expect) {
	var parser = new Parser.for_string (code);
	var expr = parser.parse_expression ();
	var val = scope.eval_sync (expr);
	if (!val.equal (expect)) {
		message (@"Expect $expect got $val");
	}
	assert (val.equal (expect));
}

void test_eval () {
	var scope = new Scope (null);
	assert_eval (scope, "foo++", new Vade.Value.for_string (""));
	assert_eval (scope, "foo+3", new Vade.Value.for_num (4));
	assert_eval (scope, "a=b=3; c=4; d=a+b+c", new Vade.Value.for_num (10));
	assert_eval (scope, "a=1;b=2;if (a>b) c=5 else c=3", new Vade.Value.for_num (3));
	assert_eval (scope, "'foo\\'bar'", new Vade.Value.for_string ("foo'bar"));
	
	// captured/local scope
	var higher = new Scope (scope);
	assert_eval (higher, "++foo", new Vade.Value.for_num (2));
	assert (higher.get_local ("foo") == null);
	assert_eval (scope, "foo", new Vade.Value.for_num (2));
	higher.set_local ("foo", new Vade.Value.for_num (14));
	assert_eval (higher, "++foo", new Vade.Value.for_num (15));
	assert_eval (scope, "foo", new Vade.Value.for_num (2));
	assert_eval (scope, "a = 3; f = { nonex = 2; a = a+nonex }; f(); a+nonex", new Vade.Value.for_num (5));

	// user defined functions
	assert_eval (scope, "f1={a|a+2}; f2={x|x*2}; f1(3)+f2(4)", new Vade.Value.for_num (13));
	
	// conditions
	assert_eval (scope, "if (2>3) 4 else { bar++; bar }", new Vade.Value.for_num (1));
}




void test_native_functions () {
	var scope = Vade.create_base_scope ();
	assert_eval (scope, "a='foo'; concat(a, 'bar', 'baz')", new Vade.Value.for_string ("foobarbaz"));
}




void assert_embed (Scope scope, string code, Vade.Value expect) {
	var parser = new Parser.for_string (code);
	var expr = parser.parse_embedded ();
	var val = scope.eval_sync (expr);
	if (!val.equal (expect)) {
		message (@"Expect $expect got $val");
	}
	assert (val.equal (expect));
}

void test_embedded () {
	var scope = Vade.create_base_scope ();
	assert_embed (scope, "$(1+2)", new Vade.Value.for_num (3));
	assert_embed (scope, "\\$(1+2)", new Vade.Value.for_string ("$(1+2)"));
	assert_embed (scope, "$(1+2) foo $(foo++) $(foo)", new Vade.Value.for_string ("3 foo  1"));
}
	
int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/vade/lexer", test_lexer);
	Test.add_func ("/vade/parser", test_parser);
	Test.add_func ("/vade/eval", test_eval);
	Test.add_func ("/vade/native", test_native_functions);
	Test.add_func ("/vade/embedded", test_embedded);

	return Test.run ();
}