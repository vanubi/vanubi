/*
 *  Copyright © 2013-2014 Luca Bruno
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

// Runtime system functions for Vade
namespace Vanubi.Vade {
	public abstract class NativeFunction : Function {
		protected string? get_string (Value[]? a, int n) {
			return n < a.length ? a[n].str : null;
		}
		
		protected int? get_int (Value[]? a, int n) {
			return n < a.length ? a[n].@int : null;
		}
	}
	
	// Concatenate two or more strings
	public class NativeConcat : Function {
		public override async Value eval (Scope scope, Value[]? a, out Value? error, Cancellable? cancellable) {
			error = null;
			
			var b = new StringBuilder ();
			foreach (var val in a) {
				b.append (val.str);
			}
			return new StringValue ((owned) b.str);
		}
		
		public override string to_string () {
			return "concat (str1, ...)";
		}
	}
	
	public class NativeLower : NativeFunction {
		public override async Value eval (Scope scope, Value[]? a, out Value? error, Cancellable? cancellable) {
			error = null;
			var s = get_string (a, 0);
			if (s == null) {
				error = new StringValue ("argument 1 must be a string");
				return NullValue.instance;
			}
			
			return new StringValue (s.down ());
		}
		
		public override string to_string () {
			return "lower (str)";
		}
	}
	
	public class NativeUpper : NativeFunction {
		public override async Value eval (Scope scope, Value[]? a, out Value? error, Cancellable? cancellable) {
			error = null;
			
			var s = get_string (a, 0);
			if (s == null) {
				error = new StringValue ("argument 1 must be a string");
				return NullValue.instance;
			}
			
			return new StringValue (s.up ());
		}
		
		public override string to_string () {
			return "upper (str)";
		}
	}

	public class NativeHex : NativeFunction {
		public override async Value eval (Scope scope, Value[]? a, out Value? error, Cancellable? cancellable) {
			error = null;

			var s = get_int (a, 0);
			if (s == null) {
				error = new StringValue ("argument 1 must be an int");
				return NullValue.instance;
			}

			return new StringValue ("0x%x".printf (s));
		}

		public override string to_string () {
			return "hex (int)";
		}
	}

	public class NativeOct : NativeFunction {
		public override async Value eval (Scope scope, Value[]? a, out Value? error, Cancellable? cancellable) {
			error = null;

			var s = get_int (a, 0);
			if (s == null) {
				error = new StringValue ("argument 1 must be an int");
				return NullValue.instance;
			}

			return new StringValue ("0%o".printf (s));
		}

		public override string to_string () {
			return "oct (int)";
		}
	}

	
	public class NativeBin : NativeFunction {
		public override async Value eval (Scope scope, Value[]? a, out Value? error, Cancellable? cancellable) {
			error = null;

			var s = get_int (a, 0);
			if (s == null) {
				error = new StringValue ("argument 1 must be an int");
				return NullValue.instance;
			}

			char bin[65];
			int len = 0;
			while (s > 0) {
				bin[len++] = (char)(s & 1) + '0';
				s >>= 1;
			}
			bin[len] = '\0';
			
			return new StringValue ("0b%s".printf ((string) bin));
		}

		public override string to_string () {
			return "bin (int)";
		}
	}

	public Scope create_base_scope (Scope? parent = null) {
		var scope = new Scope (parent, true);
		
		scope.set_local ("concat", new FunctionValue (new NativeConcat ()));
		scope.set_local ("lower", new FunctionValue (new NativeLower ()));
		scope.set_local ("upper", new FunctionValue (new NativeUpper ()));
		scope.set_local ("hex", new FunctionValue (new NativeHex ()));
		scope.set_local ("oct", new FunctionValue (new NativeOct ()));
		scope.set_local ("bin", new FunctionValue (new NativeBin ()));
		
		return scope;
	}
}