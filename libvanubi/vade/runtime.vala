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

// Runtime system functions for Vade
namespace Vanubi.Vade {
	public abstract class NativeFunction : Function {
		protected string? get_string (Value[]? a, int n) {
			return n < a.length ? a[n].str : null;
		}
	}
	
	// Concatenate two or more strings
	public class NativeConcat : Function {
		public override async Value eval (Scope scope, Value[]? a, out Value? error, Cancellable cancellable) {
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
		public override async Value eval (Scope scope, Value[]? a, out Value? error, Cancellable cancellable) {
			error = null;
			var s = get_string (a, 0);
			if (s == null) {
				error = new StringValue ("1 argument required");
				return NullValue.instance;
			}
			
			return new StringValue (s.down ());
		}
		
		public override string to_string () {
			return "lower (str)";
		}
	}
	
	public class NativeUpper : NativeFunction {
		public override async Value eval (Scope scope, Value[]? a, out Value? error, Cancellable cancellable) {
			var s = get_string (a, 0);
			if (s == null) {
				error = new StringValue ("1 argument required");
				return NullValue.instance;
			}
			
			return new StringValue (s.up ());
		}
		
		public override string to_string () {
			return "upper (str)";
		}
	}
	
	public Scope create_base_scope (Scope? parent = null) {
		var scope = new Scope (parent, true);
		
		scope.set_local ("concat", new FunctionValue (new NativeConcat (), scope));
		scope.set_local ("lower", new FunctionValue (new NativeLower (), scope));
		scope.set_local ("upper", new FunctionValue (new NativeUpper (), scope));
		
		return scope;
	}
}