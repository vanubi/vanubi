/*
 *  Copyright © 2011-2016 Luca Bruno
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

namespace Vanubi.UI {
	public class Grid : Gtk.Grid {
		public override bool draw (Cairo.Context cr) {
			Allocation alloc;
			get_allocation (out alloc);
			get_style_context().render_background (cr, 0, 0, alloc.width, alloc.height);
			return base.draw (cr);
		}
	}
	
	public class Bar : Grid {
		construct {
			get_style_context().add_class ("VanubiUIBar");
			reset_style ();
		}
		
		public signal void aborted ();

		protected virtual bool on_key_press_event (Gdk.EventKey e) {
			if (e.keyval == Gdk.Key.Escape || (e.keyval == Gdk.Key.g && Gdk.ModifierType.CONTROL_MASK in e.state)) {
				aborted ();
				return true;
			}
			return false;
		}
	}

	public class StatusBar : Label {
		construct {
			get_style_context().add_class ("VanubiUIStatusBar");
			reset_style ();
		}
	}

	public class MessageBar : Bar {
		EventBox box;
		
		public signal bool key_pressed (Gdk.EventKey e);
		
		public MessageBar (string markup) {
			column_homogeneous = true;
			
			box = new EventBox ();
			box.set_above_child (true);
			box.can_focus = true;
			var label = new Label (markup);
			label.use_markup = true;
			box.add (label);

			box.key_press_event.connect (on_key_press_event);
			add (box);
			show_all ();
		}

		public override void grab_focus () {
			box.grab_focus ();
		}
	
		protected override bool on_key_press_event (Gdk.EventKey e) {
			if (key_pressed (e)) {
				return true;
			}
			return base.on_key_press_event (e);
		}
	}

	public class EntryBar : Bar {
		public Entry entry { get; private set; }

		public new signal void activate (string s);
		public signal void changed (string s);
		public string text { get { return entry.get_text(); } }

		public EntryBar (string? initial = null) {
			expand = false;
			column_homogeneous = true;
			
			entry = new Entry ();
			if (initial != null) {
				entry.text = initial;
			}
			entry.set_activates_default (true);
			entry.expand = false;
			/* because others may connect to activate, */
			/* but in the while the widget may get destroyed */
			entry.activate.connect_after (on_activate);
			entry.changed.connect (on_changed);
			entry.key_press_event.connect (on_key_press_event);
			add (entry);
			show_all ();
			
			if (initial != null && initial != "") {
				Idle.add_full (Priority.HIGH, () => {
						changed (initial);
						return false;
				});
			}
		}

		public override void grab_focus () {
			entry.grab_focus ();
		}

		protected virtual void on_changed () {
			changed (entry.get_text ());
		}
		
		protected virtual void on_activate () {
			activate (entry.get_text ());
		}
	}

	class EditorInfoBar : Grid {
		construct {
			get_style_context().add_class ("VanubiUIEditorInfoBar");
			reset_style ();
		}
	}

	class SimpleCompletionBar<G> : CompletionBar<G> {
		protected Annotated[] choices;
		bool sort;

		public SimpleCompletionBar (owned Annotated[] choices, string default = "", bool sort = true) {
			base (default);
			this.choices = (owned) choices;
			this.sort = sort;
		}

		protected override async Annotated[]? complete (string pattern, out string common_choice, Cancellable cancellable) {
			common_choice = pattern;
			if (pattern[0] == '\0') {
				// needed for keeping the order of original choices
				return choices;
			}
			
			GenericArray<Annotated<G>> matches;
			try {
				matches = yield run_in_thread (() => { return pattern_match_many<G> (pattern, choices, sort, cancellable); });
			} catch (IOError.CANCELLED e) {
				return null;
			} catch (Error e) {
				message (e.message);
				return null;
			}

			if (matches.length > 0) {
				common_choice = matches[0].str;
				for (var i=1; i < matches.length; i++) {
					compute_common_prefix (matches[i].str, ref common_choice);
				}
				if (common_choice.length < pattern.length) {
					common_choice = pattern;
				}
			}

			var res = (owned)matches.data;
			matches.data.length = 0; // recent vala bug fix
			return res;
		}
	}
	
	class SwitchBufferBar : SimpleCompletionBar<DataSource> {
		public SwitchBufferBar (owned Annotated[] choices) {
			base ((owned) choices, "", true);
		}
	}
	
	class SessionCompletionBar : SimpleCompletionBar<string> {
		public SessionCompletionBar (owned Annotated[] choices) {
			base ((owned) choices, "default");
		}
		
		protected override async Annotated[]? complete (string pattern, out string common_choice, Cancellable cancellable) throws Error {
			if (pattern == "default") {
				// like empty
				common_choice = pattern;
				return choices;
			}
			
			return yield base.complete (pattern, out common_choice, cancellable);
		}
	}
}
