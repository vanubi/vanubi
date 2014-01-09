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
	public class Visitor {
		public virtual async void visit_string_literal (StringLiteral lit) { }
		public virtual async void visit_num_literal (NumLiteral lit) { }
		public virtual async void visit_binary_expression (BinaryExpression expr) { }
		public virtual async void visit_unary_expression (UnaryExpression expr) { }
		public virtual async void visit_member_access (MemberAccess expr) { }
		public virtual async void visit_postfix_expression (PostfixExpression expr) { }
		public virtual async void visit_seq_expression (SeqExpression expr) { }
		public virtual async void visit_assign_expression (AssignExpression expr) { }
		public virtual async void visit_if_expression (IfExpression expr) { }
		public virtual async void visit_function_expression (FunctionExpression expr) { }
		public virtual async void visit_call_expression (CallExpression expr) { }
		public virtual async void visit_try_expression (TryExpression expr) { }
		public virtual async void visit_throw_expression (ThrowExpression expr) { }
	}
	
	public abstract class Expression {
		public abstract async void visit (Visitor v);
		public abstract string to_string ();
	}

	[Immutable]
	public class NumLiteral : Expression {
		public double num;
		
		public NumLiteral (double num) {
			this.num = num;
		}
		
		public override async void visit (Visitor v) {
			yield v.visit_num_literal (this);
		}
		
		public override string to_string () {
			return "%g".printf (num);
		}
	}
	
	[Immutable]
	public class StringLiteral : Expression {
		public string str;
		
		public StringLiteral (owned string str) {
			this.str = (owned) str;
		}
		
		public override async void visit (Visitor v) {
			yield v.visit_string_literal (this);
		}
		
		public override string to_string () {
			return "'"+str+"'";
		}
	}
		
	[Immutable]
	public class MemberAccess : Expression {
		public string id;
		public Expression inner;
		
		public MemberAccess (string id, Expression? inner = null) {
			this.id = id;
			this.inner = inner;
		}
		
		public override async void visit (Visitor v) {
			yield v.visit_member_access (this);
		}
		
		public override string to_string () {
			if (inner == null) {
				return id;
			} else {
				return inner.to_string()+"."+id;
			}
		}
	}
		
	[Immutable]
	public class PostfixExpression : Expression {
		public PostfixOperator op;
		public Expression inner;
		
		public PostfixExpression (PostfixOperator op, Expression inner) {
			this.op = op;
			this.inner = inner;
		}
		
		public override async void visit (Visitor v) {
			yield v.visit_postfix_expression (this);
		}
		
		public override string to_string () {
			return @"$inner$op";
		}
	}
	
	[Immutable]
	public class UnaryExpression : Expression {
		public UnaryOperator op;
		public Expression inner;
		
		public UnaryExpression (UnaryOperator op, Expression inner) {
			this.op = op;
			this.inner = inner;
		}
		
		public override async void visit (Visitor v) {
			yield v.visit_unary_expression (this);
		}
		
		public override string to_string () {
			return @"$op$inner";
		}
	}
	
	[Immutable]
	public class BinaryExpression : Expression {
		public BinaryOperator op;
		public Expression left;
		public Expression right;
		
		public BinaryExpression (BinaryOperator op, Expression left, Expression right) {
			this.op = op;
			this.left = left;
			this.right = right;
		}
		
		public override async void visit (Visitor v) {
			yield v.visit_binary_expression (this);
		}
		
		public override string to_string () {
			return @"($left $op $right)";
		}
	}
	
	[Immutable]
	public class SeqExpression : Expression {
		public Expression inner;
		public Expression next;
		
		public SeqExpression (Expression inner, Expression next) {
			this.inner = inner;
			this.next = next;
		}
		
		public override async void visit (Visitor v) {
			yield v.visit_seq_expression (this);
		}
		
		public override string to_string () {
			return @"$inner; $next";
		}
	}

	[Immutable]
	public class IfExpression : Expression {
		public Expression condition;
		public Expression true_expr;
		public Expression? false_expr;
		
		public IfExpression (Expression condition, Expression true_expr, Expression? false_expr) {
			this.condition = condition;
			this.true_expr = true_expr;
			this.false_expr = false_expr;
		}
		
		public override async void visit (Visitor v) {
			yield v.visit_if_expression (this);
		}
		
		public override string to_string () {
			if (false_expr == null) {
				return @"if ($condition) $true_expr";
			} else {
				return @"if ($condition) $true_expr else $false_expr";
			}
		}			
	}
	
	[Immutable]
	public class AssignExpression : Expression {
		public AssignOperator op;
		public Expression left;
		public Expression right;
		
		public AssignExpression (AssignOperator op, Expression left, Expression right) {
			this.left = left;
			this.right = right;
		}
		
		public override async void visit (Visitor v) {
			yield v.visit_assign_expression (this);
		}
		
		public override string to_string () {
			return @"$left $op $right";
		}
	}

	[Immutable]
	public class FunctionExpression : Expression {
		public Function func;
		
		public FunctionExpression (Function func) {
			this.func = func;
		}
		
		public override async void visit (Visitor v) {
			yield v.visit_function_expression (this);
		}
		
		public override string to_string () {
			return func.to_string ();
		}
	}

	[Immutable]
	public class CallExpression : Expression {
		public Expression inner;
		public Expression[] arguments;
		
		public CallExpression (Expression inner, owned Expression[] arguments) {
			this.inner = inner;
			this.arguments = (owned) arguments;
		}
		
		public override async void visit (Visitor v) {
			yield v.visit_call_expression (this);
		}
		
		public override string to_string () {
			var b = new StringBuilder ();
			for (var i=0; i < arguments.length; i++) {
				if (i > 0) {
					b.append (", ");
				}
				b.append (arguments[i].to_string ());
			}
			return @"$inner($(b.str))";
		}
	}
	
	[Immutable]
	public class TryExpression : Expression {
		public Expression try_expr;
		public Expression catch_expr;
		public Expression finally_expr;
		public string error_variable;
		
		public TryExpression (Expression try_expr, Expression? catch_expr, string? error_variable, Expression? finally_expr) {
			this.try_expr = try_expr;
			this.catch_expr = catch_expr;
			this.error_variable = error_variable;
			this.finally_expr = finally_expr;
		}
		
		public override async void visit (Visitor v) {
			yield v.visit_try_expression (this);
		}
		
		public override string to_string () {
			var b = new StringBuilder ();
			b.append ("try (");
			b.append (try_expr.to_string ());
			b.append (")");
			
			if (catch_expr != null) {
				b.append ("catch ");
				b.append (error_variable);
				b.append (" (");
				b.append (catch_expr.to_string ());
				b.append (")");
			}
			
			if (finally_expr != null) {
				b.append ("finally (");
				b.append (finally_expr.to_string ());
				b.append (")");
			}
			
			return b.str;
		}
	}		

	[Immutable]
	public class ThrowExpression : Expression {
		public Expression inner;
		
		public ThrowExpression (Expression inner) {
			this.inner = inner;
		}
		
		public override async void visit (Visitor v) {
			yield v.visit_throw_expression (this);
		}
		
		public override string to_string () {
			return @"throw $inner";
		}
	}

	/* Operators */
	
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
		OR,
		GT,
		GE,
		LT,
		LE,
		EQ;
		
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
			case GT:
				return ">";
			case GE:
				return ">=";
			case LT:
				return "<";
			case LE:
				return "<=";
			case EQ:
				return "==";
			default:
				assert_not_reached ();
			}
		}		
	}
	
	public enum AssignOperator {
		SIMPLE,
		ADD,
		SUB,
		MUL,
		DIV;
		
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
			case SIMPLE:
				return "=";
			default:
				assert_not_reached ();
			}
		}
	}
}