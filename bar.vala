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
	public class Grid : Gtk.Grid {
		public override bool draw (Cairo.Context cr) {
			Allocation alloc;
			get_allocation (out alloc);
			get_style_context().render_background (cr, 0, 0, alloc.width, alloc.height);
			return base.draw (cr);
		}
	}
	
	public class Bar : Grid {
		protected Entry entry;

		public new signal void activate (string s);
		public signal void aborted ();

		public Bar (string? initial = null) {
			expand = false;
			entry = new Entry ();
			if (initial != null) {
				entry.set_text (initial);
			}
			entry.set_activates_default (true);
			entry.expand = true;
			entry.activate.connect (on_activate);
			entry.key_press_event.connect (on_key_press_event);
			add (entry);
			show_all ();
		}

		public override void grab_focus () {
			entry.grab_focus ();
		}

		protected virtual void on_activate () {
			activate (entry.get_text ());
		}

		protected virtual bool on_key_press_event (Gdk.EventKey e) {
			if (e.keyval == Gdk.Key.Escape || (e.keyval == Gdk.Key.g && Gdk.ModifierType.CONTROL_MASK in e.state)) {
				aborted ();
				return true;
			}
			return false;
		}
	}

	class EditorInfoBar : Grid {
	}

	class CompletionBar : Bar {
		string original_pattern;
		string? common_choice;
		CompletionBox completion_box;
		Cancellable current_completion;
		int64 last_tab_time = 0;
		bool navigated = false;
		bool allow_new_value;

		public CompletionBar (bool allow_new_value) {
			this.allow_new_value = allow_new_value;
			entry.changed.connect (on_changed);
			Idle.add (() => { on_changed (); return false; });
		}

		~Bar () {
			if (current_completion != null) {
				current_completion.cancel ();
			}
		}

		protected virtual async string[]? complete (string pattern, out string? common_choice, Cancellable cancellable) {
			common_choice = null;
			return null;
		}

		protected virtual string get_pattern_from_choice (string original_pattern, string choice) {
			return choice;
		}

		void set_choice () {
			entry.set_text (get_pattern_from_choice (original_pattern, completion_box.get_choice ()));
			entry.move_cursor (MovementStep.BUFFER_ENDS, 1, false);
		}

		void set_common_pattern () {
			if (common_choice != null) {
				entry.set_text (get_pattern_from_choice (original_pattern, common_choice));
				entry.move_cursor (MovementStep.BUFFER_ENDS, 1, false);
			}
		}

		protected override void on_activate () {
			unowned string choice = completion_box.get_choice ();
			if (allow_new_value || choice == null) {
				activate (entry.get_text ());
			} else {
				activate (choice);
			}
		}

		void on_changed () {
			original_pattern = entry.get_text ();
			common_choice = null;
			navigated = false;
			if (current_completion != null) {
				current_completion.cancel ();
			}
			var cancellable = current_completion = new Cancellable ();
			complete (entry.get_text (), cancellable, (s,r) => {
					try {
						var result = complete.end (r, out common_choice);
						cancellable.set_error_if_cancelled ();
						cancellable = null;
						if (completion_box != null) {
							remove (completion_box);
						}
						if (result != null) {
							completion_box = new CompletionBox (result);
							attach_next_to (completion_box, entry, PositionType.TOP, 1, 1);
							show_all ();
						}
					} catch (Error e) {
						message (e.message);
					}
				});
		}

		protected override bool on_key_press_event (Gdk.EventKey e) {
			if (e.keyval == Gdk.Key.Escape || (e.keyval == Gdk.Key.g && Gdk.ModifierType.CONTROL_MASK in e.state)) {
				aborted ();
				return true;
			} else if (e.keyval == Gdk.Key.Up) {
				completion_box.back ();
				navigated = true;
				return true;
			} else if (e.keyval == Gdk.Key.Down) {
				completion_box.next ();
				navigated = true;
				return true;
			} else if (e.keyval == Gdk.Key.Tab) {
				if (completion_box.get_choices().length > 0) {
					if (navigated || completion_box.get_choices().length == 1) {
						set_choice ();
					} else {
						int64 time = get_monotonic_time ();
						if (time - last_tab_time < 300000) {
							set_choice ();
						} else {
							set_common_pattern ();
						}
						last_tab_time = time;
					}
				}
				return true;
			}
			return false;
		}

		public class CompletionBox : Grid {
			string[] choices;
			int index = 0;

			public CompletionBox (string[] choices) {
				orientation = Orientation.HORIZONTAL;
				column_spacing = 10;
				this.choices = choices;
				for (int i=0; i < 5 && i < choices.length; i++) {
					if (i > 0) {
						add (new Separator (Orientation.VERTICAL));
					}
					var l = new Label (choices[i]);
					l.ellipsize = Pango.EllipsizeMode.MIDDLE;
					add (l);
				}
				show_all ();
			}

			public void next () {
				if (index < choices.length-1) {
					remove (get_child_at (index*2, 0));
					remove (get_child_at (index*2+1, 0));
					index++;
					if (index+4 < choices.length) {
						add (new Separator (Orientation.VERTICAL));
						var l = new Label (choices[index+4]);
						l.ellipsize = Pango.EllipsizeMode.MIDDLE;
						add (l);
						show_all ();
					}
				}
			}

			public void back () {
				if (index > 0) {
					var c1 = get_child_at ((index+4)*2, 0);
					var c2 = get_child_at ((index+4)*2-1, 0);
					if (c1 != null) {
						remove (c1);
					}
					if (c2 != null) {
						remove (c2);
					}
					index--;
					attach (new Separator (Orientation.VERTICAL), index*2+1, 0, 1, 1);
					var l = new Label (choices[index]);
					l.ellipsize = Pango.EllipsizeMode.MIDDLE;
					attach (l, index*2, 0, 1, 1);
					show_all ();
				}
			}

			public unowned string? get_choice () {
				if (choices.length == 0) {
					return null;
				}
				return ((Label) get_child_at (index*2, 0)).get_label ();
			}

			public unowned string[] get_choices () {
				return choices;
			}
		}
	}

	public class SearchBar : Bar {
		weak Editor editor;
		int original_insert;
		int original_bound;
		Label at_end_label;

		public SearchBar (Editor editor, string initial) {
			this.editor = editor;
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
			while (!iter.is_end ()) {
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
				iter.forward_char ();
			}
			at_end_label = new Label ("No matches. C-s again to search from the top.");
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
			} else if (e.keyval == Gdk.Key.s && Gdk.ModifierType.CONTROL_MASK in e.state) {
				// step
				var buf = editor.view.buffer;
				TextIter iter;
				if (at_end_label != null) {
					// restart search
					buf.get_start_iter (out iter);
					at_end_label.destroy ();
					at_end_label = null;
				} else {
					buf.get_iter_at_mark (out iter, buf.get_insert ());
					iter.forward_char ();
				}
				search (iter);
				return true;
			}
			return base.on_key_press_event (e);
		}
	}
}
