/*
 *  Copyright © 2011-2012 Luca Bruno
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

using Gtk;

namespace Vanubi {
	class HelpBar : EntryBar {
		public enum Type {
			COMMAND,
			LANGUAGE
		}

		unowned Manager manager;
		CompletionBox completion_box;
		Type type;

		public HelpBar (Manager manager, Type type) {
			this.manager = manager;
			this.type = type;
			entry.changed.connect (on_changed);
			completion_box = new CompletionBox (manager, type);
			attach_next_to (completion_box, entry, PositionType.TOP, 1, 1);
			show_all ();
		}

		void on_changed () {
			var text = entry.get_text ();
			search (text);
		}

		void search (string query) {
			List<SearchResultItem> result;
			if (type == Type.COMMAND) {
				result = manager.command_index.search (query, true);
			} else {
				result = manager.lang_index.search (query, true);
			}
			completion_box.set_docs (result);
		}

		protected override void on_activate () {
			var command = completion_box.get_selected_command ();
			if (command != null) {
				activate (command);
			}
		}

		protected override bool on_key_press_event (Gdk.EventKey e) {
			if (e.keyval == Gdk.Key.Up || e.keyval == Gdk.Key.Down) {
				completion_box.view.grab_focus ();
				var res = completion_box.view.key_press_event (e);
				entry.grab_focus ();
				return res;
			}
			return base.on_key_press_event (e);
		}

		class CompletionBox : Grid {
			ListStore store;
			public TreeView view;
			unowned Manager manager;
			HelpBar.Type type;

			public CompletionBox (Manager manager, Type type) {
				this.manager = manager;
				this.type = type;
				store = new ListStore (3, typeof (string), typeof (string), typeof (string));
				view = new TreeView.with_model (store);			
				view.headers_visible = false;
				var sel = view.get_selection ();
				sel.mode = SelectionMode.BROWSE;

				Gtk.CellRendererText cell = new Gtk.CellRendererText ();
				if (type == Type.COMMAND) {
					view.insert_column_with_attributes (-1, "Name", cell, "text", 0);
					view.insert_column_with_attributes (-1, "Key", cell, "text", 1);
					view.insert_column_with_attributes (-1, "Description", cell, "text", 2);
				} else {
					view.insert_column_with_attributes (-1, "Id", cell, "text", 0);
					view.insert_column_with_attributes (-1, "Name", cell, "text", 1);
				}

				var sw = new ScrolledWindow (null, null);
				sw.expand = true;
				sw.add (view);
				add (sw);
			}

			public string key_to_string (Key key) {
				var res = "";
				if (Gdk.ModifierType.CONTROL_MASK in (Gdk.ModifierType) key.modifiers) {
					res = "C-";
				}
				if (Gdk.ModifierType.SHIFT_MASK in (Gdk.ModifierType) key.modifiers) {
					res += "S-";
				}
				res += Gdk.keyval_name (key.keyval);
				return res;
			}

			public string keys_to_string (Key?[] keys) {
				var res = new StringBuilder ();
				foreach (var key in keys) {
					res.append (key_to_string (key));
					res.append (" ");
				}
				res.truncate (res.len - 1);
				return (string) res.data;
			}

			public void set_docs (List<SearchResultItem> items) {
				store.clear ();
				Gtk.TreeIter iter;
				foreach (var item in items) {
					store.append (out iter);
					var doc = (StringSearchDocument) item.doc;
					if (type == Type.COMMAND) {
						var keys = manager.keymanager.get_binding (doc.name);
						string keystring = "";
						if (keys != null) {
							keystring = keys_to_string (keys);
						}
						store.set (iter, 0, doc.name, 1, keystring, 2, doc.fields[0]);
					} else {
						store.set (iter, 0, doc.name, 1, doc.fields[0]);
					}
				}
				// select first item
				if (store.get_iter_first (out iter)) {
					var sel = view.get_selection ();
					sel.select_iter (iter);
				}
			}

			public string? get_selected_command () {
				var sel = view.get_selection ();
				TreeIter iter;
				if (sel.get_selected (null, out iter)) {
					string val;
					store.get (iter, 0, out val);
					return val;
				}
				return null;
			}
		}
	}
}