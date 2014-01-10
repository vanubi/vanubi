/*
 *  Copyright © 2014 Luca Bruno
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

using Vanubi.Vade;
 
namespace Vanubi.UI {
	public void fill_vade_member (Scope scope, Object o, string name, ThreadFunc<Function> cb) {
		var key = "vade_"+name;
		unowned Vade.Value? val = o.get_data (key);
		if (val == null) {
			var func = cb ();
			var oval = new FunctionValue (func, scope);
			val = oval;
			o.set_data (key, (owned) oval); // make the object own the value
		}

		scope.set_local (name, val);
	}
	
	public class NativeSetStatus : NativeFunction {
		unowned Manager manager;
		
		public NativeSetStatus (Manager manager) {
			this.manager = manager;
		}
		
		public override async Vade.Value eval (Scope scope, Vade.Value[]? a, out Vade.Value? error, Cancellable cancellable) {
			var msg = get_string (a, 0);
			if (msg == null) {
				error = new StringValue ("1 argument required");
				return NullValue.instance;
			}
			var cat = get_string (a, 1);
			manager.set_status (msg, cat);
			
			return NullValue.instance;
		}
		
		public override string to_string () {
			return "upper(msg, [category])";
		}
	}
	
	public Scope fill_manager_scope (Scope scope, Manager manager) {
		Vade.fill_scope (scope);
		fill_vade_member (scope, manager, "set_status", () => new NativeSetStatus (manager));
		return scope;
	}
}
