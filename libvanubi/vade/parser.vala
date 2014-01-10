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

namespace Vanubi.Vade {	
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
		}
		
		// If regex match is provided, will substitute back references with the relative matched groups
		public Expression parse_embedded (MatchInfo? regex_match = null) throws VError {
			// Idea 1: transform each $(...) in an expression, substitute regex backreferences in it
			// Idea 2: concatenate literal strings and expressions with concat()
			var s = new StringBuilder ();
			lex.pos = 0;
			Expression[] args = null;
			while (lex.pos < lex.len) {
				if (lex.char == '\\') {
					lex.pos++;
					if (lex.pos < lex.len && lex.char == '$') {
						s.append_c ('$');
						lex.pos++;
					} else {
						s.append_c ('\\');
					}
				} else if (lex.char == '$') {
					lex.pos++;
					if (lex.char == '(') {
						// add last string to be concatenated
						var str = s.str;
						str = str.escape("\"").replace ("'", "\\'");
						args += new StringLiteral ((owned) str);
						
						lex.pos++;
						next ();
						var expr = parse_expression ();
						expect (TType.CLOSE_PAREN);
						args += expr;
						
						s.truncate ();
					}
				} else {
					s.append_c (lex.char);
					lex.pos++;
				}
			}
			
			// append remaining string
			var str = s.str;
			str = str.escape("\"").replace ("'", "\\'");
			args += new StringLiteral ((owned) str);
			
			var expr = new CallExpression (new MemberAccess ("concat", null), args);
			return expr;
		}
		
		public Expression parse_expression () throws VError {
			var expr = parse_seq_expression ();
			return expr;
		}
		
		public Expression parse_seq_expression () throws VError {
			var expr = parse_nonseq_expression ();
			if (cur.type == TType.SEMICOLON) {
				next ();
				var next = parse_seq_expression ();
				expr = new SeqExpression (expr, next);
			}
			return expr;
		}
		
		public Expression parse_nonseq_expression () throws VError {
			var expr = parse_try_expression ();
			return expr;
		}
		
		public Expression parse_try_expression () throws VError {
			Expression expr;
			if (cur.type == TType.ID && cur.str == "try") {
				next ();
				Expression try_expr, catch_expr = null, finally_expr = null;
				string error_variable = null;
				try_expr = parse_expression ();
				
				if (cur.type == TType.ID && cur.str == "catch") {
					next ();
					error_variable = parse_identifier ();
					catch_expr = parse_expression ();
				}
				
				if (cur.type == TType.ID && cur.str == "finally") {
					next () ;
					finally_expr = parse_expression ();
				}
				
				if (catch_expr == null && finally_expr == null) {
					throw new VError.SYNTAX_ERROR ("No catch or finally clause in try expression at pos %d in '%s'",
												   lex.pos,
												   lex.code);
				}
				
				expr = new TryExpression (try_expr, catch_expr, error_variable, finally_expr);
			} else {
				expr = parse_throw_expression ();
			}
			return expr;
		}
		
		public Expression parse_throw_expression () throws VError {
			Expression expr;
			if (cur.type == TType.ID && cur.str == "throw") {
				next ();
				var inner = parse_if_expression ();
				expr = new ThrowExpression (inner);
			} else {
				expr = parse_if_expression ();
			}
			return expr;
		}
		
		public Expression parse_if_expression () throws VError {
			Expression expr;
			if (cur.type == TType.ID && cur.str == "if") {
				next ();
				
				expect (TType.OPEN_PAREN);
				next ();
				var cond = parse_expression ();
				expect (TType.CLOSE_PAREN);
				next ();
				
				var true_expr = parse_primary_expression ();
				
				if (cur.type == TType.ID && cur.str == "else") {
					next ();
					var false_expr = parse_primary_expression ();
					expr = new IfExpression (cond, true_expr, false_expr);
				} else {
					expr = new IfExpression (cond, true_expr, null);
				}
			} else {
				expr = parse_primary_expression ();
			}
			return expr;
		}
		
		public Expression parse_primary_expression () throws VError {
			var expr = parse_assign_expression ();
			return expr;
		}
		
		public Expression parse_assign_expression () throws VError {
			var expr = parse_relational_expression ();
			if (cur.type == TType.ASSIGN) {
				next ();
				var right = parse_assign_expression ();
				expr = new AssignExpression (AssignOperator.SIMPLE, expr, right);
			}
			return expr;
		}
		
		public Expression parse_relational_expression () throws VError {
			var expr = parse_add_expression ();
			switch (cur.type) {
			case TType.GT:
				next ();
				var right = parse_relational_expression ();
				expr = new BinaryExpression (BinaryOperator.GT, expr, right);
				break;
			case TType.GE:
				next ();
				var right = parse_relational_expression ();
				expr = new BinaryExpression (BinaryOperator.GE, expr, right);
				break;
			case TType.LT:
				next ();
				var right = parse_add_expression ();
				expr = new BinaryExpression (BinaryOperator.LT, expr, right);
				break;
			case TType.LE:
				next ();
				var right = parse_relational_expression ();
				expr = new BinaryExpression (BinaryOperator.LE, expr, right);
				break;
			case TType.EQ:
				next ();
				var right = parse_relational_expression ();
				expr = new BinaryExpression (BinaryOperator.EQ, expr, right);
				break;
			}
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
			Expression expr = null;
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
				next ();
				expr = parse_expression ();
				expect (TType.CLOSE_PAREN);
				next ();
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
			
			var found = true;
			while (found) {
				switch (cur.type) {
				case TType.DOT:
					next ();
					expr = parse_member_access (expr);
					break;
				case TType.OPEN_PAREN:
					expr = parse_call_expression (expr);
					break;
				default:
					found = false;
					break;
				}
			}
			
			return expr;
		}
		
		public Expression parse_member_access (Expression? inner) throws VError {
			var id = parse_identifier ();
			var expr = new MemberAccess (id, inner);
			return expr;
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
			var rollback = lex.pos;
			next ();
			
			ObjectLiteral obj = null;
			string[] parameters = null;
			if (cur.type == TType.ID) {
				while (cur.type == TType.ID) {
					parameters += cur.str;
					next ();
				}
			} else if (cur.type == TType.STRING) {
				obj = new ObjectLiteral ();
				while (cur.type == TType.STRING) {
					var key = cur.str;
					next ();
					if (cur.type != TType.COLON) {
						lex.pos = rollback;
						obj = null;
						next ();
						break;
					}
					
					next ();
					var expr = parse_if_expression ();
					obj.set_member (key, expr);
				}
				
				if (cur.type != TType.CLOSE_BRACE) {
					lex.pos = rollback;
					obj = null;
					next ();
				}
			}
			
			if (obj != null) {
				return obj;
			}
			
			bool is_function = cur.type == TType.BIT_OR;
			if (!is_function) {
				lex.pos = rollback;
			}
			next ();
			
			Expression expr;
			if (!is_function && cur.type == TType.CLOSE_BRACE) {
				// empty object
				expr = new ObjectLiteral ();
				next ();
			} else {
				expr = parse_expression ();
				expect (TType.CLOSE_BRACE);
				next ();
			
				if (is_function) {
					expr = new FunctionExpression (new UserFunction (parameters, expr));
				}
			}
			
			return expr;
		}

		public Expression parse_call_expression (Expression inner) throws VError {
			expect (TType.OPEN_PAREN);
			next ();
			
			Expression[] args = null;
			while (cur.type != TType.CLOSE_PAREN && cur.type != TType.END) {
				args += parse_nonseq_expression ();
				if (cur.type != TType.COMMA) {
					break;
				}
				next ();
			}
			
			expect (TType.CLOSE_PAREN);
			next ();
			
			var expr = new CallExpression (inner, (owned) args);
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
			var expr = new StringLiteral ((owned) cur.str);
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
		
		public string parse_identifier () throws VError {
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
