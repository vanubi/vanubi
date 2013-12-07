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
			this.bool = b;
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
		
		public string to_string () {
			return str;
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
