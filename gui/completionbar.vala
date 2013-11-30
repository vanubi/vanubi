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
	class CompletionBar<G> : EntryBar {
		protected string original_pattern;
		string? common_choice;
		CompletionBox completion_box;
		Cancellable current_completion;
		bool navigated = false;
		bool allow_new_value;
		bool changed = true;

		public CompletionBar (bool allow_new_value) {
			this.allow_new_value = allow_new_value;
			entry.changed.connect (on_changed);
		}

		~Bar () {
			if (current_completion != null) {
				current_completion.cancel ();
			}
		}

		public override void grab_focus () {
			base.grab_focus ();
			on_changed ();
			if (entry.get_text () != "") {
				entry.move_cursor (MovementStep.BUFFER_ENDS, 1, false);
			}
		}

		protected virtual async Annotated<File>[]? complete (string pattern, out string common_choice, Cancellable cancellable) {
			common_choice = pattern;
			return null;
		}

		protected virtual string get_pattern_from_choice (string original_pattern, string choice) {
			return choice;
		}

		public G get_choice () {
			return completion_box.get_choice().obj;
		}
		
		protected virtual void set_choice_to_entry () {
			Annotated choice = completion_box.get_choice ();
			entry.set_text (choice.str);
			entry.move_cursor (MovementStep.BUFFER_ENDS, 1, false);
		}

		void set_common_pattern () {
			if (common_choice != null) {
				var new_pattern = get_pattern_from_choice (original_pattern, common_choice);
				entry.set_text (new_pattern);
				entry.move_cursor (MovementStep.BUFFER_ENDS, 1, false);
				if (new_pattern == original_pattern) {
					entry.get_style_context().add_class ("error");
				}				
			}
		}

		void on_changed () {
			entry.get_style_context().remove_class ("error");
			changed = true;
			original_pattern = entry.get_text ();
			common_choice = null;
			navigated = false;
			if (current_completion != null) {
				current_completion.cancel ();
			}
			var cancellable = current_completion = new Cancellable ();
			complete.begin (entry.get_text (), cancellable, (s,r) => {
					try {
						var result = complete.end (r, out common_choice);
						cancellable.set_error_if_cancelled ();
						cancellable = null;
						if (completion_box != null) {
							remove (completion_box);
						}
						if (result != null) {
							completion_box = new CompletionBox<G> (result);
							attach_next_to (completion_box, entry, PositionType.TOP, 1, 1);
							show_all ();
						}
					} catch (IOError.CANCELLED e) {
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
						set_choice_to_entry ();
					} else {
						if (!changed) {
							set_choice_to_entry ();
						} else {
							changed = false;
							set_common_pattern ();
						}
					}
				} else {
					entry.get_style_context().add_class ("error");
				}
				return true;
			}
			return false;
		}

		public class CompletionBox<G> : Grid {
			Annotated[] choices;
			int index = 0;
			Label label;
			int n_render = 100; // too few means not all space is exploited, too many means more things to negotiate size with

			public CompletionBox (owned Annotated[] choices) {
				orientation = Orientation.HORIZONTAL;
				this.choices = (owned) choices;
				label = new Label (null);
				#if GTK_3_10
				label.wrap = true;
				label.wrap_mode = Pango.WrapMode.WORD;
				label.set_lines (2);
				#endif
				label.ellipsize = Pango.EllipsizeMode.END;
				label.justify = Justification.LEFT;
				update ();
				add (label);
				show_all ();
			}

			public void update () {
				if (choices.length == 0) {
					label.set_markup ("<i>No matches</i>");
				} else {
					var n = int.min (n_render, choices.length);
					var s = new StringBuilder ();
					for (int i=index,j=0; j < n; j++, i = (i+1)%choices.length) {
						s.append (choices[i].str);
						s.append ("   ");
					}
					label.set_text (s.str);
				}
			}
				
			public void next () {
				index = (index+1)%choices.length;
				update ();
			}
			
			public void back () {
				index = index == 0 ? choices.length-1 : index-1;
				update ();
			}
			
			public unowned Annotated<G>? get_choice () {
				if (choices.length == 0) {
					return null;
				}
				return choices[index];
			}

			public unowned Annotated[] get_choices () {
				return choices;
			}
		}
	}
}