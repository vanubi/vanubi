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
			return "set_status (msg, [category])";
		}
	}
	
	public class NativeSetStatusError : NativeFunction {
		unowned Manager manager;
		
		public NativeSetStatusError (Manager manager) {
			this.manager = manager;
		}
		
		public override async Vade.Value eval (Scope scope, Vade.Value[]? a, out Vade.Value? error, Cancellable cancellable) {
			var msg = get_string (a, 0);
			if (msg == null) {
				error = new StringValue ("1 argument required");
				return NullValue.instance;
			}
			var cat = get_string (a, 1);
			manager.set_status_error (msg, cat);
			
			return NullValue.instance;
		}
		
		public override string to_string () {
			return "set_status_error (msg, [category])";
		}
	}

	public unowned Scope get_manager_scope (Manager manager) {
		unowned Scope scope = manager.get_data ("vade_scope");
		if (scope == null) {
			var sc = new Scope (manager.base_scope, true);
			scope = sc;
			manager.set_data ("vade_scope", (owned) sc);
			
			scope.set_local ("set_status", new FunctionValue (new NativeSetStatus (manager), scope));
			scope.set_local ("set_status_error", new FunctionValue (new NativeSetStatusError (manager), scope));
		}
			
		return scope;
	}

	public unowned Scope get_editor_scope (Editor editor) {
		unowned Scope scope = editor.get_data ("vade_scope");
		if (scope == null) {
			var sc = new Scope (get_manager_scope (editor.manager), true);
			scope = sc;
			editor.set_data ("vade_scope", (owned) sc);
		}
		
		return scope;
	}
}
