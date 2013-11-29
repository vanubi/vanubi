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

	public class EntryBar : Bar {
		protected Entry entry;

		public new signal void activate (string s);
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
	}

	class EditorInfoBar : Grid {
	}

	class SwitchBufferBar : CompletionBar {
		string[] choices;

		public SwitchBufferBar (string[] choices) {
			base (false);
			this.choices = choices;
		}

		protected override async string[]? complete (string pattern, out string common_choice, Cancellable cancellable) {
			Annotated<string>[] a = null;
			foreach (unowned string c in choices) {
				a += new Annotated<string?> (c, null);
			}
			try {
				a = yield run_in_thread<Annotated<string>[]> ((c) => { return pattern_match_many<string> (pattern, a, c); }, cancellable);
			} catch (Error e) {
				message (e.message);
				return null;
			}
			string[] res = null;
			foreach (unowned Annotated an in a) {
				res += an.str;
			}
			return res;
		}
	}
}
