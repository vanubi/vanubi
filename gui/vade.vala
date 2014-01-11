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
	public abstract class NativeFunction : Vade.NativeFunction {
		protected Editor? get_editor (Vade.Value[]? a, int n) {
			if (n < a.length && a[n] is NativeEditor) {
				return ((NativeEditor) a[n]).editor;
			}
			return null;
		}
	}
	
	public class NativeSetStatus : NativeFunction {
		unowned Manager manager;
		
		public NativeSetStatus (Manager manager) {
			this.manager = manager;
		}
		
		public override async Vade.Value eval (Scope scope, Vade.Value[]? a, out Vade.Value? error, Cancellable cancellable) {
			error = null;
			
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
			error = null;
			
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

	public class NativeEditor : NativeObject {
		public unowned Editor editor;
		
		public NativeEditor (Editor editor) {
			this.editor = editor;
		}
		
		public override string to_string () {
			return "Editor";
		}
	}
	
	public class NativeCommand : NativeFunction {
		unowned Manager manager;
		
		public NativeCommand (Manager manager) {
			this.manager = manager;
		}
		
		public override async Vade.Value eval (Scope scope, Vade.Value[]? a, out Vade.Value? error, Cancellable cancellable) {
			error = null;
			
			var cmd = get_string (a, 0);
			if (cmd == null) {
				error = new StringValue ("1 argument required");
				return NullValue.instance;
			}
			
			var editor = get_editor (a, 1);
			if (editor == null) {
				editor = get_editor_from_scope (scope);
			}
			if (editor == null) {
				error = new StringValue ("no editor to run the command on in this context");
				return NullValue.instance;
			}
			
			manager.execute_command[cmd](editor, cmd);
			
			return NullValue.instance;
		}
		
		public override string to_string () {
			return "command (name, [editor])";
		}
	}
	
	public unowned Scope get_manager_scope (Manager manager) {
		unowned Scope scope = manager.get_data ("vade_scope");
		if (scope == null) {
			var sc = new Scope (manager.base_scope, true);
			scope = sc;
			manager.set_data ("vade_scope", (owned) sc);
			
			scope.set_local ("set_status", new FunctionValue (new NativeSetStatus (manager), null));
			scope.set_local ("set_status_error", new FunctionValue (new NativeSetStatusError (manager), null));
			scope.set_local ("command", new FunctionValue (new NativeCommand (manager), null));
		}
			
		return scope;
	}

	public unowned Scope get_editor_scope (Editor editor) {
		unowned Scope scope = editor.get_data ("vade_scope");
		if (scope == null) {
			var sc = new Scope (get_manager_scope (editor.manager), true);
			scope = sc;
			editor.set_data ("vade_scope", (owned) sc);
			
			scope.set_local ("editor", new NativeEditor (editor));
		}
		
		return scope;
	}
	
	public Editor? get_editor_from_scope (Scope scope) {
		var val = scope["editor"] as NativeEditor;
		if (val != null) {
			return val.editor;
		}
		return null;
	}
}
