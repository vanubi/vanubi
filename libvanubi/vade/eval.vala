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
	public class EvalVisitor : Visitor {
		Value value;
		public Value error; // make it publicy accessible to get the original error
		Scope scope;
		Cancellable cancellable;
		
		public async Value eval (Scope scope, Expression expr, Cancellable cancellable) throws IOError.CANCELLED, VError.EVAL_ERROR {
			this.scope = scope;
			this.cancellable = cancellable;
			yield expr.visit (this);
			
			if (is_cancelled ()) {
				throw new IOError.CANCELLED ("Evaluation has been cancelled");
			}

			if (is_error ()) {
				throw new VError.EVAL_ERROR (error.str);
			}
			return value;
		}
		
		/* Always check this function before running a loop or side effects */
		public bool is_cancelled () {
			return cancellable.is_cancelled ();
		}
		
		public bool is_error () {
			return error != null;
		}
		
		public bool should_return () {
			return is_cancelled () || is_error ();
		}
		
		public override async void visit_string_literal (StringLiteral lit) {
			value = new Value.for_string (lit.str.compress ());
		}
		
		public override async void visit_num_literal (NumLiteral lit) {
			value = new Value.for_num (lit.num);
		}
		
		public override async void visit_binary_expression (BinaryExpression expr) {
			yield expr.left.visit (this);
			if (should_return ()) {
				return;
			}

			var vleft = value;
			switch (expr.op) {
			case BinaryOperator.ADD:
				yield expr.right.visit (this);
				value = new Value.for_num (vleft.num+value.num);
				break;
			case BinaryOperator.SUB:
				yield expr.right.visit (this);
				value = new Value.for_num (vleft.num-value.num);
				break;
			case BinaryOperator.MUL:
				yield expr.right.visit (this);
				value = new Value.for_num (vleft.num*value.num);
				break;
			case BinaryOperator.DIV:
				yield expr.right.visit (this);
				value = new Value.for_num (vleft.num/value.num);
				break;
			case BinaryOperator.GT:
				yield expr.right.visit (this);
				value = new Value.for_bool (vleft.num>value.num);
				break;
			case BinaryOperator.GE:
				yield expr.right.visit (this);
				value = new Value.for_bool (vleft.num>=value.num);
				break;
			case BinaryOperator.LT:
				yield expr.right.visit (this);
				value = new Value.for_bool (vleft.num<value.num);
				break;
			case BinaryOperator.LE:
				yield expr.right.visit (this);
				value = new Value.for_bool (vleft.num<=value.num);
				break;
			case BinaryOperator.EQ:
				yield expr.right.visit (this);
				value = new Value.for_bool (vleft.str==value.str);
				break;
			case BinaryOperator.AND:
				if (vleft.bool) {
					yield expr.right.visit (this);
					value = new Value.for_bool (value.bool);
				} else {
					value = new Value.for_bool (false);
				}
				break;
			case BinaryOperator.OR:
				if (vleft.bool) {
					value = new Value.for_bool (true);
				} else {
					yield expr.right.visit (this);
					value = new Value.for_bool (value.bool);
				}
				break;
			default:
				assert_not_reached ();
			}		
		}
		
		public override async void visit_unary_expression (UnaryExpression expr) {
			yield expr.inner.visit (this);
			if (should_return ()) {
				return;
			}

			var num = value.num;
			switch (expr.op) {
			case UnaryOperator.NEGATE:
				value = new Value.for_num (-num);
				break;
			case UnaryOperator.INC:
				value = new Value.for_num (num+1);
				scope[((MemberAccess) expr.inner).id] = value;
				break;
			case UnaryOperator.DEC:
				value = new Value.for_num (num-1);
				scope[((MemberAccess) expr.inner).id] = value;
				break;
			default:
				assert_not_reached ();
			}
		}
		
		public override async void visit_member_access (MemberAccess expr) {
			if (expr.inner == null) {
				var val = scope[expr.id];
				if (val == null) {
					val = new Value.for_string ("");
				}
				value = val;
			} else {
				yield expr.visit (this);
			}
		}
		
		public override async void visit_postfix_expression (PostfixExpression expr) {
			yield expr.inner.visit (this);
			if (should_return ()) {
				return;
			}

			var num = value.num;
			Value newval;
			switch (expr.op) {
			case PostfixOperator.INC:
				newval = new Value.for_num (num+1);
				break;
			case PostfixOperator.DEC:
				newval = new Value.for_num (num-1);
				break;
			default:
				assert_not_reached ();
			}
			
			scope[((MemberAccess) expr.inner).id] = newval;
		}
		
		public override async void visit_seq_expression (SeqExpression expr) {
			yield expr.inner.visit (this);
			if (should_return ()) {
				return;
			}

			yield expr.next.visit (this);
		}
		
		public override async void visit_assign_expression (AssignExpression expr) {
			yield expr.right.visit (this);
			if (should_return ()) {
				return;
			}

			scope[((MemberAccess) expr.left).id] = value;
		}
		
		public override async void visit_if_expression (IfExpression expr) {
			yield expr.condition.visit (this);
			if (should_return ()) {
				return;
			}

			if (value.bool) {
				yield expr.true_expr.visit (this);
			} else {
				yield expr.false_expr.visit (this);
			}
		}
		
		public override async void visit_function_expression (FunctionExpression expr) {
			value = new Value.for_function (expr.func, scope);
		}
		
		public override async void visit_call_expression (CallExpression expr) {
			yield expr.inner.visit (this);
			if (should_return ()) {
				return;
			}

			var func = value;
			
			Value[] args = new Value[expr.arguments.length];
			for (var i=0; i < args.length; i++) {
				yield expr.arguments[i].visit (this);
				if (should_return ()) {
					return;
				}
				args[i] = value;
			}
			
			if (func.type == Value.Type.FUNCTION) {
				var innerscope = new Scope (func.func_scope);
				value = yield func.func.eval (innerscope, args, out error, cancellable);
			}
		}
		
		public override async void visit_try_expression (TryExpression expr) {
			yield expr.try_expr.visit (this);
			if (is_error () && expr.catch_expr != null) {
				var oldvar = scope.get_local (expr.error_variable);
				scope.set_local (expr.error_variable, error);

				error = null; // error catched
				yield expr.catch_expr.visit (this);
				scope.set_local (expr.error_variable, oldvar);
			}
			
			if (expr.finally_expr != null) {
				var old_error = error;
				error = null; // ensure we run the finally statement
				yield expr.finally_expr.visit (this);
				error = old_error;
			}
		}
		
		public override async void visit_throw_expression (ThrowExpression expr) {
			yield expr.inner.visit (this);
			if (should_return ()) {
				return;
			}
			
			error = value;
		}
	}
}