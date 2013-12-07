/*
 *  Copyright © 2011-2013 Luca Bruno
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
		public signal void aborted ();

		protected virtual bool on_key_press_event (Gdk.EventKey e) {
			if (e.keyval == Gdk.Key.Escape || (e.keyval == Gdk.Key.g && Gdk.ModifierType.CONTROL_MASK in e.state)) {
				aborted ();
				return true;
			}
			return false;
		}
	}
	
	public class MessageBar : Bar {
		EventBox box;
		
		public signal bool key_pressed (Gdk.EventKey e);
		
		public MessageBar (string markup) {
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
		protected Entry entry;

		public new signal void activate (string s);
		public signal void changed (string s);
		public string text { get { return entry.get_text(); } }

		public EntryBar (string? initial = null) {
			expand = false;
			entry = new Entry ();
			if (initial != null) {
				entry.set_text (initial);
			}
			entry.set_activates_default (true);
			entry.expand = true;
			entry.activate.connect (on_activate);
			entry.changed.connect (on_changed);
			entry.key_press_event.connect (on_key_press_event);
			add (entry);
			show_all ();
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
	}

	class SwitchBufferBar<G> : CompletionBar<G> {
		Annotated[] choices;

		public SwitchBufferBar (Annotated[] choices) {
			this.choices = choices;
		}

		protected override async Annotated[]? complete (string pattern, out string common_choice, Cancellable cancellable) {
			common_choice = pattern;
			if (pattern[0] == '\0') {
				// needed for keeping the order of the file lru
				return choices;
			}
			
			GenericArray<Annotated<G>> matches;
			try {
				matches = yield run_in_thread (() => { return pattern_match_many<G> (pattern, choices, cancellable); });
			} catch (Error e) {
				message (e.message);
				return null;
			}

			if (matches.length > 0) {
				common_choice = matches[0].str;
				for (var i=1; i < matches.length; i++) {
					compute_common_prefix (matches[i].str, ref common_choice);
				}
			}

			var res = (owned)matches.data;
			matches.data.length = 0; // recent vala bug fix
			return res;
		}
	}
}
