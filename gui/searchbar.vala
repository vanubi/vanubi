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
			SEARCH_FORWARD,
			SEARCH_BACKWARD,
			REPLACE_FORWARD,
			REPLACE_BACKWARD
		}
		
		weak Manager manager;
		weak Editor editor;
		int original_insert;
		int original_bound;
		Label at_end_label;
		Mode mode;
		Entry replace_entry;
		EventBox replace_box;
		bool first_search = true;
		bool is_replacing = false;
		bool replace_complete = false;
		bool is_regex = false;
		string matching_string; // keep alive for regex
		MatchInfo current_match;
		Vade.Scope? scope; // scope in which to execute Vade expressions, or null to avoid parsing expressions
		Cancellable cancellable;

		public SearchBar (Manager manager, Vade.Scope? scope, Editor editor, Mode mode, bool is_regex, string search_initial = "", string replace_initial = "") {
			base (search_initial);
			this.manager = manager;
			this.editor = editor;
			this.mode = mode;
			this.scope = scope;
			this.is_regex = is_regex;
			
			if (mode == Mode.REPLACE_FORWARD || mode == Mode.REPLACE_BACKWARD) {
				replace_entry = new Entry ();
				replace_entry.set_text (replace_initial);
				replace_entry.set_activates_default (true);
				replace_entry.activate.connect (on_activate);
				replace_entry.key_press_event.connect (on_key_press_event);
				attach_next_to (replace_entry, entry, PositionType.BOTTOM, 1, 1);
				show_all ();
				// tab focus will cycle between entry and replace_entry
				var focusable = new List<Widget> ();
				focusable.append (entry);
				focusable.append (replace_entry);
				focusable.append (entry);
				set_focus_chain (focusable);
			}

			var buf = editor.view.buffer;
			TextIter insert, bound;
			buf.get_iter_at_mark (out insert, buf.get_insert ());
			buf.get_iter_at_mark (out bound, buf.get_insert ());
			original_insert = insert.get_offset ();
			original_bound = bound.get_offset ();
		}

		public override void on_activate () {
			if (mode == Mode.SEARCH_FORWARD || mode == Mode.SEARCH_BACKWARD) {
				base.on_activate ();
			} else {
				is_replacing = true;
				entry.hide ();
				replace_entry.hide ();

				// help box, and key press event handler
				replace_box = new EventBox ();
				replace_box.expand = true;
				replace_box.set_above_child (true);
				replace_box.can_focus = true;
				replace_box.key_press_event.connect (on_key_press_event);
				var label = new Label ("<b>r = replace     s = skip</b>");
				label.use_markup = true;
				replace_box.add (label);
				add (replace_box);
				replace_box.show_all ();
				replace_box.grab_focus ();
				
				// find first occurence to replace
				var buf = editor.view.buffer;
				TextIter iter;
				buf.get_iter_at_mark (out iter, buf.get_insert ());
				
				search.begin (iter);
			}
		}
		
		public string replace_text {
			get {
				if (replace_entry != null) {
					return replace_entry.get_text ();
				} else {
					return "";
				}
			}
		}
		
		protected override void on_changed () {
			base.on_changed ();
			var buf = editor.view.buffer;
			TextIter iter;
			if (first_search) {
				// search from beginning
				buf.get_iter_at_offset (out iter, original_insert);
			} else {
				buf.get_iter_at_mark (out iter, buf.get_insert ());
			}
			search.begin (iter);
		}

		async void search (TextIter iter) {
			if (cancellable != null) {
				cancellable.cancel ();
			}
			cancellable = new Cancellable ();
			var cur_cancellable = cancellable;
			
			// inefficient naive implementation
			var buf = editor.view.buffer;
			var p = entry.get_text ();
			var insensitive = p.down () == p;
			
			// Eval pattern expression
			if (scope != null) {
				try {
					var parser = new Vade.Parser.for_string (p);
					var expr = parser.parse_embedded ();
					var value = yield scope.eval (expr, cur_cancellable);
					p = value.str;
				} catch (Error e) {
					// do not parse in case of any error during parsing or evaluating the expression
				}
			}
			
			Regex regex = null;
			if (is_regex) {
				try {
					regex = new Regex (p, RegexCompileFlags.OPTIMIZE, RegexMatchFlags.ANCHORED);
				} catch (Error e) {
					// user still writing regex
					return;
				}
			}
			
			// yield to gui every 50 iterations
			int iterations = 0;
			manager.set_overlay_status ("Searching...");
			
			while (((mode == Mode.SEARCH_FORWARD || mode == Mode.REPLACE_FORWARD) && !iter.is_end ()) ||
				   ((mode == Mode.SEARCH_BACKWARD || mode == Mode.REPLACE_BACKWARD) && !iter.is_start ())) {
				if (cur_cancellable.is_cancelled ()) {
					return;
				}
				
				if (iterations++ >= 50) {
					iterations = 0;
					SourceFunc resume = search.callback;
					Idle.add ((owned) resume);
					yield;
				}
				var subiter = iter;
				bool found = true;
				if (is_regex) {
					var end_line = iter;
					end_line.forward_to_line_end ();
					matching_string = buf.get_text (iter, end_line, false);
					found = regex.match (matching_string, 0, out current_match);
					if (found) {
						var full = current_match.fetch (0);
						subiter.forward_chars (full.length);
					}
				} else {
					int i = 0;
					unichar c;
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
				}
				if (found) {
					// found
					buf.select_range (iter, subiter);
					editor.update_old_selection ();
					editor.view.scroll_to_mark (buf.get_insert (), 0, true, 0.5, 0.5);
					manager.clear_overlay_status ();
					return;
				}
				if (mode == Mode.SEARCH_FORWARD || mode == Mode.REPLACE_FORWARD) {
					iter.forward_char ();
				} else {
					iter.backward_char ();
				}
			}
			manager.clear_overlay_status ();

			if (mode == Mode.REPLACE_FORWARD || mode == Mode.REPLACE_BACKWARD) {
				if (replace_box != null) {
					var replace_label = (Label) replace_box.get_child ();
					replace_label.set_markup ("<b>Replaced occurrences till end of file</b>");
					replace_complete = true;
				}
				return;
			}
			
			if (mode == Mode.SEARCH_FORWARD) {
				at_end_label = new Label ("<b>No matches. C-s again to search from the top.</b>");
			} else {
				at_end_label = new Label ("<b>No matches. C-r again to search from the bottom.</b>");
			}			
			at_end_label.use_markup = true;
			attach_next_to (at_end_label, entry, PositionType.TOP, 1, 1);
			show_all ();
		}

		async void replace () {
			if (cancellable != null) {
				cancellable.cancel ();
			}
			cancellable = new Cancellable ();
			var cur_cancellable = cancellable;
			
			// replace occurrence
			var r = replace_text;
			if (is_regex) {
				// parse back references
				for (var i=1; i < current_match.get_match_count (); i++) {
					r = r.replace (@"\\$i", current_match.fetch (i));
				}
			}

			// evaluate replace expression, TODO: pass the current match
			try {
				var parser = new Vade.Parser.for_string (r);
				var expr = parser.parse_embedded ();
				var value = yield scope.eval (expr, cur_cancellable);
				r = value.str;
			} catch (Error e) {
				// do not parse in case of any error during parsing or evaluating the expression
			}
			
			var buf = editor.view.buffer;
			buf.begin_user_action ();		
			buf.delete_selection (true, true);
			buf.insert_at_cursor (r, -1);
			buf.end_user_action ();
						
			TextIter iter;
			buf.get_iter_at_mark (out iter, buf.get_insert ());
			search.begin (iter);
		}
		
		protected override bool on_key_press_event (Gdk.EventKey e) {
			if (e.keyval == Gdk.Key.Escape || (e.keyval == Gdk.Key.g && Gdk.ModifierType.CONTROL_MASK in e.state)) {
				// abort
				if (cancellable != null) {
					cancellable.cancel ();
				}
				
				TextIter insert, bound;
				var buf = editor.view.buffer;
				buf.get_iter_at_offset (out insert, original_insert);
				buf.get_iter_at_offset (out bound, original_bound);
				editor.view.buffer.select_range (insert, bound);
				editor.view.scroll_to_mark (editor.view.buffer.get_insert (), 0, false, 0.5, 0.5);
				editor.update_old_selection ();
				aborted ();
				return true;
			} else if (mode == Mode.SEARCH_FORWARD || mode == Mode.SEARCH_BACKWARD) {
				if ((e.keyval == Gdk.Key.Up || e.keyval == Gdk.Key.Down) || ((e.keyval == Gdk.Key.s || e.keyval == Gdk.Key.r) && Gdk.ModifierType.CONTROL_MASK in e.state)) {
					// step search
					first_search = false;
					mode = (e.keyval == Gdk.Key.Down || e.keyval == Gdk.Key.s) ? Mode.SEARCH_FORWARD : Mode.SEARCH_BACKWARD;
					var buf = editor.view.buffer;
					TextIter iter;
					if (at_end_label != null) {
						// restart search
						if (mode == Mode.SEARCH_FORWARD) {
							buf.get_start_iter (out iter);
						} else {
							buf.get_end_iter (out iter);
						}
						at_end_label.destroy ();
						at_end_label = null;
					} else {
						buf.get_iter_at_mark (out iter, buf.get_insert ());
						if (mode == Mode.SEARCH_FORWARD) {
							iter.forward_char ();
						} else {
							iter.backward_char ();
						}
					}
					search.begin (iter);
					return true;
				}
			} else if (is_replacing && (mode == Mode.REPLACE_FORWARD || mode == Mode.REPLACE_BACKWARD)) {
				if (!replace_complete) {
					if (e.keyval == Gdk.Key.r) {
						replace.begin ();
						return true;
					} else if (e.keyval == Gdk.Key.s) {
						// skip occurrence
						var buf = editor.view.buffer;
						TextIter iter;
						buf.get_iter_at_mark (out iter, buf.get_insert ());
						iter.forward_char ();
						search.begin (iter);
						return true;
					}
				}
				if (e.keyval == Gdk.Key.Return) {
					activate (text);
					return true;
				}
			}

			return base.on_key_press_event (e);
		}
	}
}