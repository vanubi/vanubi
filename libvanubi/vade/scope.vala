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
	[Immutable]
	public class Function {
		public string[] parameters;
		public Expression body;
		
		public Function (string[]? parameters, Expression body) {
			this.parameters = parameters;
			this.body = body;
		}
		
		public Value eval (Scope? captured, Value[] arguments) {
			var scope = new Scope (captured);
			for (var i=0; i < int.min(parameters.length, arguments.length); i++) {
				scope.set_local (parameters[i], arguments[i]);
			}
			return scope.eval (body);
		}
		
		public string to_string () {
			if (parameters.length == 0) {
				return @"{ $body }";
			} else {
				var pars = string.joinv (" ", parameters);
				return @"{ $pars | $body }";
			}
		}
	}
	
	[Immutable]
	public class Value {
		public enum Type {
			STRING,
			FUNCTION
		}
		
		public Type type;
		public string str;
		public Function func;
		public Scope func_scope;
		
		public Value.for_string (string str) {
			this.type = Type.STRING;
			this.str = str;
		}
		
		public Value.for_num (double num) {
			this.type = Type.STRING;
			this.str = "%g".printf (num);
		}

		public Value.for_bool (bool b) {
			this.type = Type.STRING;
			this.str = ((int) b).to_string ();
		}
		
		public Value.for_function (Function func, Scope scope) {
			this.type = Type.FUNCTION;
			this.func = func;
			this.func_scope = scope;
		}

		public double num {
			get {
				return double.parse (str);
			}
		}
		
		public bool @bool {
			get {
				return @int != 0;
			}
		}

		public int @int {
			get {
				return (int) num;
			}
		}
		
		public bool equal (Value v) {
			return str == v.str;
		}
		
		public string to_string () {
			if (type == Type.FUNCTION) {
				return func.to_string();
			}
			return str;
		}
	}
	
	[Immutable]
	public class Scope {
		public HashTable<string, Value> registers = new HashTable<string, Value> (str_hash, str_equal);
		public Scope? parent;
		
		public Scope (Scope? parent) {
			this.parent = parent;
		}
		
		public void set_local (string name, Value val) {
			registers[name] = val;
		}
		
		public Value get_local (string name) {
			return registers[name];
		}
		
		public unowned Value? get (string name) {
			unowned Value? val = registers[name];
			if (val == null && parent != null) {
				val = parent[name];
			}
			return val;
		}
		
		public void set (string name, Value val) {
			if (parent == null) {
				registers[name] = val;
			} else {
				if (name in registers) {
					registers[name] = val;
				} else {
					parent[name] = val;
				}
			}
		}
		
		public Value eval (Expression expr) {
			var ev = new EvalVisitor ();
			return ev.eval (this, expr);
		}
	}
	
	public errordomain VError {
		SYNTAX_ERROR,
		SEMANTIC_ERROR,
		EVAL_ERROR
	}
}