/*
 *  Copyright © 2013 Luca Bruno
 *
 *  This file is part of Vanubi.
 *
 *  Vanubi is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  Vanubi is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Vanubi.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Vanubi.Vrex {
	public class Value {
		public enum Type {
			STRING
		}
		
		public Type type;
		public string str;
		
		public Value.for_string (string str) {
			this.type = Type.STRING;
			this.str = str;
		}
		
		public Value.for_num (double num) {
			this.type = Type.STRING;
			this.num = num;
		}

		public Value.for_bool (bool b) {
			this.type = Type.STRING;
			this.bool = bool;
		}

		public double num {
			get {
				return double.parse (str);
			}
			set {
				str = value.to_string ();
			}
		}
		
		public bool @bool {
			get {
				return @int != 0;
			}
			set {
				@int = (int) value;
			}
		}

		public int @int {
			get {
				return (int) num;
			}
			set {
				num = value;
			}
		}
		
		public bool equal (Value v) {
			return str == v.str;
		}
	}
	
	public class Env {
		public HashTable<string, Value> registers = new HashTable<string, Value> (str_hash, str_equal);
		
		public unowned Value? get (string name) {
			return registers.lookup (name);
		}
		
		public void set (string name, Value val) {
			registers.insert (name, val);
		}
		
		public Value eval (Expression expr) {
			return expr.eval (this);
		}
	}

	public errordomain VError {
		SYNTAX_ERROR,
		SEMANTIC_ERROR,
		EVAL_ERROR
	}
	
	public abstract class Expression {
		public abstract Value eval (Env env);
		public abstract string to_string ();
	}
	
	public enum TType {
		OPEN_BRACE,
		CLOSE_BRACE,
		OPEN_PAREN,
		CLOSE_PAREN,
		OPEN_SQUARE,
		CLOSE_SQUARE,
		COMMA,
		SEMICOMMA,
		PLUS,
		MINUS,
		INC,
		DEC,
		STRING,
		ADDRESS,
		ID,
		NUM,
		MOD,
		DIV,
		MUL,
		GT,
		LT,
		GE,
		LE,
		EQ,
		AND,
		OR,
		BIT_AND,
		BIT_OR,
		ASSIGN,
		DOT,
		END
	}
	
	public struct Token {
		public TType type;
		public int offset;
		public int length;
		public double num;
		public string str;
		
		public Token (TType type, int offset, int length) {
			this.type = type;
			this.offset = offset;
			this.length = length;
		}
		
		public string to_string () {
			return @"$(type.to_string())($offset,$length)";
		}
	}
	
	public class Lexer {
		internal string code;
		internal int len;
		internal int pos;
		
		char @char {
			get {
				return code[pos];
			}
		}
		
		public Lexer (string code) {
			this.code = code;
			this.len = code.length;
			this.pos = 0;
		}
		
		public Token next () throws VError.SYNTAX_ERROR {
			while (pos < len && char.isspace ()) pos++;
			if (pos >= len) {
				return Token (TType.END, pos, 0);
			}
			
			var orig = pos;
			switch (char) {
			case '+':
				pos++;
				if (char == '+') {
					pos++;
					return Token (TType.INC, orig, 2);
				}
				return Token (TType.PLUS, orig, 1);
			case '-':
				pos++;
				if (char == '-') {
					pos++;
					return Token (TType.DEC, orig, 2);
				}
				return Token (TType.MINUS, orig, 1);
			case '.':
				pos++;
				return Token (TType.DOT, orig, 1);
			case '{':
				pos++;
				return Token (TType.OPEN_BRACE, orig, 1);
			case '[':
				pos++;
				return Token (TType.OPEN_SQUARE, orig, 1);
			case '(':
				pos++;
				return Token (TType.OPEN_PAREN, orig, 1);
			case '}':
				pos++;
				return Token (TType.CLOSE_BRACE, orig, 1);
			case ']':
				pos++;
				return Token (TType.CLOSE_SQUARE, orig, 1);
			case ')':
				pos++;
				return Token (TType.CLOSE_PAREN, orig, 1);
			case ',':
				pos++;
				return Token (TType.COMMA, orig, 1);
			case ';':
				pos++;
				return Token (TType.SEMICOMMA, orig, 1);
			case '&':
				pos++;
				if (char == '&') {
					pos++;
					return Token (TType.AND, orig, 1);
				}
				return Token (TType.BIT_AND, orig, 1);
			case '|':
				pos++;
				if (char == '|') {
					pos++;
					return Token (TType.OR, orig, 1);
				}
				return Token (TType.BIT_OR, orig, 1);
			case '=':
				pos++;
				if (char == '=') {
					pos++;
					return Token (TType.EQ, orig, 2);
				}
				return Token (TType.ASSIGN, orig, 1);
			case '>':
				pos++;
				if (char == '=') {
					pos++;
					return Token (TType.GE, orig, 2);
				}
				return Token (TType.GT, orig, 1);
			case '<':
				pos++;
				if (char == '<') {
					pos++;
					return Token (TType.LE, orig, 2);
				}
				return Token (TType.LT, orig, 1);
			case '\'':
				pos++;
				var b = new StringBuilder ();
				while (char != '\'') {
					if (char == '\\') {
						b.append_c (char);
						pos++;
						b.append_c (char);
						pos++;
					} else {
						b.append_c (char);
						pos++;
					}
				}
				pos++;
				var tok = Token (TType.STRING, orig, pos);
				tok.str = (owned) b.str;
				return tok;
			}
			
			if (char.isdigit ()) {
				// number
				double num = 0;
				while (char.isdigit ()) {
					num += char-'0';
					num *= 10;
					pos++;
				}
				if (char == '.') {
					pos++;
					var ndec = 1;
					while (char.isdigit ()) {					
						num += char-'0';
						num *= 10;
						ndec *= 10;
						pos++;
					}
					num /= ndec;
				}
				num /= 10;
				var tok = Token (TType.NUM, orig, pos);
				tok.num = num;
				return tok;
			}
			
			if (char.isalpha ()) {
				// identifier
				var b = new StringBuilder ();
				while (char.isalpha ()) {
					b.append_c (char);
					pos++;
				}
				var tok = Token (TType.ID, orig, pos);
				tok.str = (owned) b.str;
				return tok;
			}
			
			throw new VError.SYNTAX_ERROR ("Unknown char '%c' at pos %d in '%s'", char, pos, code);
		}
	}	
	
	public class NumLiteral : Expression {
		double num;
		
		public NumLiteral (double num) {
			this.num = num;
		}
		
		public override Value eval (Env env) {
			return new Value.for_num (num);
		}
		
		public override string to_string () {
			return "%g".printf (num);
		}
	}
	
	public class StringLiteral : Expression {
		string str;
		
		public StringLiteral (string str) {
			this.str = str;
		}
		
		public override Value eval (Env env) {
			return new Value.for_string (str);
		}
		
		public override string to_string () {
			return "'"+str+"'";
		}
	}
		
	public class MemberAccess : Expression {
		public string id;
		public Expression inner;
		
		public MemberAccess (string id, Expression? inner = null) {
			this.id = id;
			this.inner = inner;
		}
		
		public override Value eval (Env env) {
			if (inner == null) {
				var val = env[id];
				if (val == null) {
					val = new Value.for_string ("");
					env[id] = val;
				}
				return val;
			} else {
				return inner.eval (env);
			}
		}
		
		public override string to_string () {
			if (inner == null) {
				return id;
			} else {
				return inner.to_string()+"."+id;
			}
		}
	}
		
	public class PostfixExpression : Expression {
		public PostfixOperator op;
		public Expression inner;
		
		public PostfixExpression (PostfixOperator op, Expression inner) {
			this.op = op;
			this.inner = inner;
		}
		
		public override Value eval (Env env) {
			var iv = inner.eval (env);
			var num = iv.num;
			Value newval;
			switch (op) {
			case PostfixOperator.INC:
				newval = new Value.for_num (num+1);
				break;
			case PostfixOperator.DEC:
				newval = new Value.for_num (num-1);
				break;
			default:
				assert_not_reached ();
			}
			env[((MemberAccess) inner).id] = newval;
			return iv;
		}
		
		public override string to_string () {
			return @"$inner$op";
		}
	}
	
	public class UnaryExpression : Expression {
		public UnaryOperator op;
		public Expression inner;
		
		public UnaryExpression (UnaryOperator op, Expression inner) {
			this.op = op;
			this.inner = inner;
		}
		
		public override Value eval (Env env) {
			var iv = inner.eval (env);
			var num = iv.num;
			Value newval;
			switch (op) {
			case UnaryOperator.NEGATE:
				newval = new Value.for_num (-num);
				break;
			case UnaryOperator.INC:
				newval = new Value.for_num (num+1);
				env[((MemberAccess) inner).id] = newval;
				break;
			case UnaryOperator.DEC:
				newval = new Value.for_num (num-1);
				env[((MemberAccess) inner).id] = newval;
				break;
			default:
				assert_not_reached ();
			}
			return newval;
		}
		
		public override string to_string () {
			return @"$op$inner";
		}
	}
	
	public class BinaryExpression : Expression {
		public BinaryOperator op;
		public Expression left;
		public Expression right;
		
		public BinaryExpression (BinaryOperator op, Expression left, Expression right) {
			this.op = op;
			this.left = left;
			this.right = right;
		}
		
		public override Value eval (Env env) {
			var vleft = left.eval (env);
			Value newval;
			switch (op) {
			case BinaryOperator.ADD:
				var vright = right.eval (env);
				newval = new Value.for_num (vleft.num+vright.num);
				break;
			case BinaryOperator.SUB:
				var vright = right.eval (env);
				newval = new Value.for_num (vleft.num-vright.num);
				break;
			case BinaryOperator.MUL:
				var vright = right.eval (env);
				newval = new Value.for_num (vleft.num*vright.num);
				break;
			case BinaryOperator.DIV:
				var vright = right.eval (env);
				newval = new Value.for_num (vleft.num/vright.num);
				break;
			case BinaryOperator.AND:
				if (vleft.bool) {
					var vright = right.eval (env);
					newval = new Value.for_bool (vright.bool);
				} else {
					newval = new Value.for_bool (false);
				}
				break;
			case BinaryOperator.OR:
				if (vleft.bool) {
					newval = new Value.for_bool (true);
				} else {
					var vright = right.eval (env);
					newval = new Value.for_bool (vright.bool);
				}
				break;
			default:
				assert_not_reached ();
			}		
			return newval;
		}
		
		public override string to_string () {
			return @"($left $op $right)";
		}
	}
	
	public enum PostfixOperator {
		INC,
		DEC;
		
		public string to_string () {
			switch (this) {
			case INC:
				return "++";
			case DEC:
				return "--";
			default:
				assert_not_reached ();
			}
		}
	}
	
	public enum UnaryOperator {
		NEGATE,
		INC,
		DEC;
		
		public string to_string () {
			switch (this) {
			case INC:
				return "++";
			case DEC:
				return "--";
			case NEGATE:
				return "-";
			default:
				assert_not_reached ();
			}
		}
	}
	
	public enum BinaryOperator {
		ADD,
		SUB,
		MUL,
		DIV,
		AND,
		OR;
		
		public string to_string () {
			switch (this) {
			case ADD:
				return "+";
			case SUB:
				return "-";
			case MUL:
				return "*";
			case DIV:
				return "/";
			case AND:
				return "&&";
			case OR:
				return "||";
			default:
				assert_not_reached ();
			}
		}		
	}
	
	public class Parser {
		Lexer lex;
		Token cur;
		
		public Parser (Lexer lex) throws VError {
			this.lex = lex;
			next ();
		}
		
		public Parser.for_string (string str) throws VError {
			this (new Lexer (str));
		}
		
		public Token next () throws VError {
			this.cur = lex.next ();
			return this.cur;
		}
		
		public void expect (TType type) throws VError {
			if (cur.type != type) {
				generic_error ();
			}
			next ();
		}
		
		public Expression parse_expression () throws VError {
			var expr = parse_binary_expression ();
			return expr;
		}
		
		public Expression parse_binary_expression () throws VError {
			var expr = parse_add_expression ();
			return expr;
		}
		
		public Expression parse_add_expression () throws VError {
			var expr = parse_mul_expression ();
			switch (cur.type) {
			case TType.PLUS:
				next ();
				var right = parse_add_expression ();
				expr = new BinaryExpression (BinaryOperator.ADD, expr, right);
				break;
			case TType.MINUS:
				next ();
				var right = parse_add_expression ();
				expr = new BinaryExpression (BinaryOperator.SUB, expr, right);
				break;
			}
			return expr;
		}
		
		public Expression parse_mul_expression () throws VError {
			var expr = parse_unary_expression ();
			switch (cur.type) {
			case TType.MUL:
				next ();
				var right = parse_mul_expression ();
				expr = new BinaryExpression (BinaryOperator.MUL, expr, right);
				break;
			case TType.DIV:
				next ();
				var right = parse_mul_expression ();
				expr = new BinaryExpression (BinaryOperator.DIV, expr, right);
				break;
			}
			return expr;
		}
			
		public Expression parse_unary_expression () throws VError {
			Expression expr;
			switch (cur.type) {
			case TType.MINUS:
				next ();
				expr = parse_simple_expression ();
				expr = new UnaryExpression (UnaryOperator.NEGATE, expr);
				break;
			case TType.INC:
				next ();
				expr = parse_simple_expression ();
				expr = new UnaryExpression (UnaryOperator.INC, expr);
				break;
			case TType.DEC:
				next ();
				expr = parse_simple_expression ();
				expr = new UnaryExpression (UnaryOperator.DEC, expr);
				break;
			default:
				expr = parse_simple_expression ();
				break;
			}
			return expr;
		}
		
		public Expression parse_simple_expression () throws VError {
			Expression expr;
			if (cur.type == TType.OPEN_PAREN) {
				next ();
				expr = parse_expression ();
				expect (TType.CLOSE_PAREN);
				return expr;
			}

			switch (cur.type) {
			case TType.ID:
				expr = parse_member_access (null);			
				switch (cur.type) {
				case TType.INC:
				case TType.DEC:
					expr = parse_postfix_expression (expr);
					break;
				}
				break;
			case TType.OPEN_BRACE:
				expr = parse_function ();
				break;
			case TType.OPEN_PAREN:
				expr = parse_expression ();
				if (cur.type != TType.CLOSE_PAREN) {
					generic_error ();
				}
				break;
			case TType.NUM:
				expr = parse_num_literal ();
				break;
			case TType.STRING:
				expr = parse_string_literal ();
				break;
			default:
				generic_error ();
			}
			return expr;
		}
		
		public Expression parse_member_access (Expression? inner) throws VError {
			var id = parse_identifier ();
			var expr = new MemberAccess (id, inner);
			if (cur.type == TType.DOT) {
				next ();
				return parse_member_access (expr);
			} else {
				return expr;
			}			
		}
		
		public Expression parse_postfix_expression (Expression inner) throws VError {
			switch (cur.type) {
			case TType.INC:
				next ();
				return new PostfixExpression (PostfixOperator.INC, inner);
			case TType.DEC:
				next ();
				return new PostfixExpression (PostfixOperator.DEC, inner);
			default:
				generic_error ();
			}
		}
		
		public Expression parse_function () throws VError {
			expect (TType.OPEN_BRACE);
			var expr = parse_expression ();
			expect (TType.CLOSE_BRACE);
			return expr;
		}
		
		public Expression parse_num_literal () throws VError {
			expect (TType.NUM);
			var expr = new NumLiteral (cur.num);
			next ();
			return expr;
		}
		
		public Expression parse_string_literal () throws VError {
			expect (TType.STRING);
			var expr = new StringLiteral (cur.str);
			next ();
			return expr;
		}
		
		[NoReturn]
		public void generic_error () throws VError {
			throw new VError.SYNTAX_ERROR ("Unexpected %s at pos %d in '%s'",
										   cur.to_string(),
										   lex.pos,
										   lex.code);		
		}
		
		public string? parse_identifier () throws VError {
			if (cur.type == TType.ID) {
				var str = cur.str;
				next ();
				return str;
			} else {
				generic_error ();
			}
		}
	}
}