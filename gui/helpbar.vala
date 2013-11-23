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
	class HelpBar : Bar {
		StringSearchIndex index;
		CompletionBox completion_box;

		public HelpBar (StringSearchIndex index) {
			this.index = index;
			entry.changed.connect (on_changed);
			completion_box = new CompletionBox ();
			attach_next_to (completion_box, entry, PositionType.TOP, 1, 1);
			show_all ();
		}

		void on_changed () {
			var text = entry.get_text ();
			search (text);
		}

		void search (string query) {
			var result = index.search (query);
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
				return true;
			}
			return base.on_key_press_event (e);
		}

		class CompletionBox : Grid {
			ListStore store;
			public TreeView view;

			public CompletionBox () {
				store = new ListStore (2, typeof (string), typeof (string));
				view = new TreeView.with_model (store);			
				view.headers_visible = false;
				var sel = view.get_selection ();
				sel.mode = SelectionMode.BROWSE;

				Gtk.CellRendererText cell = new Gtk.CellRendererText ();
				view.insert_column_with_attributes (-1, "Name", cell, "text", 0);
				view.insert_column_with_attributes (-1, "Description", cell, "text", 1);

				var sw = new ScrolledWindow (null, null);
				sw.expand = true;
				sw.add (view);
				add (sw);
			}

			public void set_docs (List<SearchResultItem> items) {
				store.clear ();
				Gtk.TreeIter iter;
				foreach (var item in items) {
					var doc = (StringSearchDocument) item.doc;
					store.append (out iter);
					store.set (iter, 0, doc.name, 1, doc.fields[0]);
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