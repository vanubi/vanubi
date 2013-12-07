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
		
		public Expression parse_expression () throws VError {
			var expr = parse_seq_expression ();
			return expr;
		}
		
		public Expression parse_seq_expression () throws VError {
			var expr = parse_if_expression ();
			if (cur.type == TType.SEMICOMMA) {
				next ();
				var next = parse_seq_expression ();
				expr = new SeqExpression (expr, next);
			}
			return expr;
		}
		
		public Expression parse_if_expression () throws VError {
			Expression expr;
			if (cur.type == TType.ID && cur.str == "if") {
				next ();
				
				expect (TType.OPEN_PAREN);
				next ();
				var cond = parse_binary_expression ();
				expect (TType.CLOSE_PAREN);
				next ();
				
				var true_expr = parse_binary_expression ();
				
				if (cur.type == TType.ID && cur.str == "else") {
					next ();
					var false_expr = parse_binary_expression ();
					expr = new IfExpression (cond, true_expr, false_expr);
				} else {
					expr = new IfExpression (cond, true_expr, null);
				}
			} else {
				expr = parse_binary_expression ();
			}
			return expr;
		}
		
		public Expression parse_binary_expression () throws VError {
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
				var right = parse_add_expression ();
				expr = new BinaryExpression (BinaryOperator.GT, expr, right);
				break;
			case TType.GE:
				next ();
				var right = parse_add_expression ();
				expr = new BinaryExpression (BinaryOperator.GE, expr, right);
				break;
			case TType.LT:
				next ();
				var right = parse_add_expression ();
				expr = new BinaryExpression (BinaryOperator.LT, expr, right);
				break;
			case TType.LE:
				next ();
				var right = parse_add_expression ();
				expr = new BinaryExpression (BinaryOperator.LE, expr, right);
				break;
			case TType.EQ:
				next ();
				var right = parse_add_expression ();
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
			Expression expr;
			if (cur.type == TType.OPEN_PAREN) {
				next ();
				expr = parse_expression ();
				expect (TType.CLOSE_PAREN);
				next ();
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
			next ();
			string[] parameters = null;
			if (cur.type == TType.ID) {
				while (cur.type == TType.ID) {
					parameters += cur.str;
					next ();
				}
				if (cur.type != TType.BIT_OR) {
					parameters = null;
				} else {
					next ();
				}
			}
			
			var expr = parse_expression ();
			expect (TType.CLOSE_BRACE);
			next ();
			
			expr = new FunctionExpression (new Function (parameters, expr));
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
