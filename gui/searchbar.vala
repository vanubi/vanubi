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

using Gtk;

namespace Vanubi {
	public class SearchBar : EntryBar {
		public enum Mode {
			FORWARD,
			BACKWARD
		}
		
		weak Editor editor;
		int original_insert;
		int original_bound;
		Label at_end_label;
		Mode mode;

		public SearchBar (Editor editor, string initial, Mode mode) {
			this.editor = editor;
			this.mode = mode;
			entry.set_text (initial);
			entry.changed.connect (on_changed);

			var buf = editor.view.buffer;
			TextIter insert, bound;
			buf.get_iter_at_mark (out insert, buf.get_insert ());
			buf.get_iter_at_mark (out bound, buf.get_insert ());
			original_insert = insert.get_offset ();
			original_bound = bound.get_offset ();
		}

		void on_changed () {
			var buf = editor.view.buffer;
			TextIter iter;
			buf.get_iter_at_mark (out iter, buf.get_insert ());
			search (iter);
		}

		void search (TextIter iter) {
			// inefficient naive implementation
			var buf = editor.view.buffer;
			var p = entry.get_text ();
			var insensitive = p.down () == p;
			while ((mode == Mode.FORWARD && !iter.is_end ()) || (mode == Mode.BACKWARD && !iter.is_start ())) {
				var subiter = iter;
				int i = 0;
				unichar c;
				bool found = true;
				while (p.get_next_char (ref i, out c)) {
					var c2 = subiter.get_char ();
					if (insensitive) {
						c2 = c2.tolower ();
					}
					if (c != c2) {
						found = false;
						break;
					}
					subiter.forward_char ();
				}
				if (found) {
					// found
					buf.select_range (iter, subiter);
					editor.view.scroll_to_mark (buf.get_insert (), 0, true, 0.5, 0.5);
					return;
				}
				if (mode == Mode.FORWARD) {
					iter.forward_char ();
				} else {
					iter.backward_char ();
				}
			}
			if (mode == Mode.FORWARD) {
				at_end_label = new Label ("No matches. C-s again to search from the top.");
			} else {
				at_end_label = new Label ("No matches. C-r again to search from the bottom.");
			}
			attach_next_to (at_end_label, entry, PositionType.TOP, 1, 1);
			show_all ();
		}

		protected override bool on_key_press_event (Gdk.EventKey e) {
			if (e.keyval == Gdk.Key.Escape || (e.keyval == Gdk.Key.g && Gdk.ModifierType.CONTROL_MASK in e.state)) {
				// abort
				TextIter insert, bound;
				var buf = editor.view.buffer;
				buf.get_iter_at_offset (out insert, original_insert);
				buf.get_iter_at_offset (out bound, original_bound);
				editor.view.buffer.select_range (insert, bound);
				editor.view.scroll_to_mark (editor.view.buffer.get_insert (), 0, false, 0.5, 0.5);
				aborted ();
				return true;
			} else if ((e.keyval == Gdk.Key.s || e.keyval == Gdk.Key.r) && Gdk.ModifierType.CONTROL_MASK in e.state) {
				// step
				mode = e.keyval == Gdk.Key.s ? Mode.FORWARD : Mode.BACKWARD;
				var buf = editor.view.buffer;
				TextIter iter;
				if (at_end_label != null) {
					// restart search
					if (mode == Mode.FORWARD) {
						buf.get_start_iter (out iter);
					} else {
						buf.get_end_iter (out iter);
					}
					at_end_label.destroy ();
					at_end_label = null;
				} else {
					buf.get_iter_at_mark (out iter, buf.get_insert ());
					if (mode == Mode.FORWARD) {
						iter.forward_char ();
					} else {
						iter.backward_char ();
					}
				}
				search (iter);
				return true;
			}
			return base.on_key_press_event (e);
		}
	}
}