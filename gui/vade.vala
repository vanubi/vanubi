/*
 *  Copyright © 2014-2016 Luca Bruno
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
using Gtk;
 
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
		
		public override async Vade.Value eval (Scope scope, Vade.Value[]? a, out Vade.Value? error, Cancellable? cancellable) {
			error = null;
			
			var msg = get_string (a, 0);
			if (msg == null) {
				error = new StringValue ("argument 1 must be a string");
				return NullValue.instance;
			}
			var cat = get_string (a, 1);
			manager.state.status.set (msg, cat);
			
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
		
		public override async Vade.Value eval (Scope scope, Vade.Value[]? a, out Vade.Value? error, Cancellable? cancellable) {
			error = null;
			
			var msg = get_string (a, 0);
			if (msg == null) {
				error = new StringValue ("argument 1 must be a string");
				return NullValue.instance;
			}
			var cat = get_string (a, 1);
			manager.state.status.set (msg, cat, Status.Type.ERROR);
			
			return NullValue.instance;
		}
		
		public override string to_string () {
			return "set_status_error (msg, [category])";
		}
	}

	public class NativeCommand : NativeFunction {
		unowned Manager manager;
		
		public NativeCommand (Manager manager) {
			this.manager = manager;
		}
		
		public override async Vade.Value eval (Scope scope, Vade.Value[]? a, out Vade.Value? error, Cancellable? cancellable) {
			error = null;
			
			var cmd = get_string (a, 0);
			if (cmd == null) {
				error = new StringValue ("argument 1 must be a string");
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

	/* Editor */
	
	public class NativeEditor : NativeObject {
		public unowned Editor editor;
		
		public NativeEditor (Editor editor) {
			this.editor = editor;
		}

		class construct {
			vtable["file"] =  new FunctionValue (new NativeEditorFile ());
			vtable["text"] =  new FunctionValue (new NativeEditorText ());
		}
			
		internal string file () {
			return editor.source.to_string ();
		}
		
		internal string text () {
			var buf = editor.view.buffer;
			TextIter start, end;
			buf.get_start_iter (out start);
			buf.get_end_iter (out end);
			string text = buf.get_text (start, end, false);
			return text;
		}

		public override string to_string () {
			return "Editor";
		}
	}

	public class NativeEditorFile : NativeFunction {
		public override async Vade.Value eval (Scope scope, Vade.Value[]? a, out Vade.Value? error, Cancellable? cancellable) {
			error = null;
			
			NativeEditor editor = a.length > 0 ? ((NativeEditor) a[0]) : null;
			if (editor == null) {
				error = new StringValue ("argument 1 must be an Editor");
				return NullValue.instance;
			}
			
			var res = new StringValue (editor.file ());
			return res;
		}
		
		public override string to_string () {
			return "string file (editor)";
		}
	}
	
	public class NativeEditorText : NativeFunction {
		public override async Vade.Value eval (Scope scope, Vade.Value[]? a, out Vade.Value? error, Cancellable? cancellable) {
			error = null;
			
			NativeEditor editor = a.length > 0 ? ((NativeEditor) a[0]) : null;
			if (editor == null) {
				error = new StringValue ("argument 1 must be an Editor");
				return NullValue.instance;
			}
			
			var res = new StringValue (editor.text ());
			return res;
		}
		
		public override string to_string () {
			return "string text (editor)";
		}
	}

	/* CURSOR */

	public class NativeCursorMoveChars : NativeFunction {
		public override async Vade.Value eval (Scope scope, Vade.Value[]? a, out Vade.Value? error, Cancellable? cancellable) {
			error = null;
			
			NativeCursor cursor = a.length > 0 ? ((NativeCursor) a[0]) : null;
			if (cursor == null) {
				error = new StringValue ("argument 1 must be a Cursor");
				return NullValue.instance;
			}
			
			int? n = get_int (a, 1);
			if (n == null) {
				error = new StringValue ("argument 2 must be a number");
				return NullValue.instance;
			}
			
			cursor.move_chars (n);
			return cursor;
		}
		
		public override string to_string () {
			return "cursor move_chars (cursor, num_chars)";
		}
	}

	public class NativeCursorInsert : NativeFunction  {
		public override async Vade.Value eval (Scope scope, Vade.Value[]? a, out Vade.Value? error, Cancellable? cancellable) {
			error = null;

			NativeCursor cursor = a.length > 0 ? ((NativeCursor) a[0]) : null;
			if (cursor == null) {
				error = new StringValue ("argument 1 must be a Cursor");
				return NullValue.instance;
			}

			string? s = get_string (a, 1);
			if (s == null) {
				error = new StringValue ("argument 2 must be a string");
				return NullValue.instance;
			}

			cursor.insert (s);
			return cursor;
		}

		public override string to_string () {
			return "cursor insert (cursor, text)";
		}
	}
	
	public class NativeCursor : NativeObject {
		public unowned Editor editor;
		
		public NativeCursor (Editor editor) {
			this.editor = editor;
		}
		
		class construct {
			vtable["move_chars"] = new FunctionValue (new NativeCursorMoveChars ());
			vtable["insert"] = new FunctionValue (new NativeCursorInsert ());
		}
			
		internal void move_chars (int n) {
			editor.view.move_cursor (MovementStep.LOGICAL_POSITIONS, n, false);
		}

		internal void insert (string text) {
			var buf = editor.view.buffer;
			var mark = buf.get_insert ();
			TextIter iter;
			buf.get_iter_at_mark (out iter, mark);
			buf.insert (ref iter, text, -1);
		}
		
		public override string to_string () {
			return "Cursor";
		}
	}

	public unowned Scope get_manager_scope (Manager manager) {
		unowned Scope scope = manager.get_data ("vade_scope");
		if (scope == null) {
			var sc = new Scope (manager.base_scope, true);
			scope = sc;
			manager.set_data ("vade_scope", (owned) sc);
			
			scope.set_local ("set_status", new FunctionValue (new NativeSetStatus (manager)));
			scope.set_local ("set_status_error", new FunctionValue (new NativeSetStatusError (manager)));
			scope.set_local ("command", new FunctionValue (new NativeCommand (manager)));
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
			scope.set_local ("cursor", new NativeCursor (editor));
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
