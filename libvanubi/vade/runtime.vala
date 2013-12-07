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
	// Concatenate two or more strings
	public class NativeConcat : Function {
		public override Value eval (Scope scope, Value[] arguments) {
			var b = new StringBuilder ();
			foreach (var val in arguments) {
				b.append (val.str);
			}
			return new Value.for_string ((owned) b.str);
		}
		
		public override string to_string () {
			return "concat(s1, ...)";
		}
	}
	
	public Scope create_base_scope () {
		// create a scope with native functions and constants
		var scope = new Scope (null);
		
		scope["concat"] = new Value.for_function (new NativeConcat (), scope);
		
		return scope;
	}
}