/*
 *  Copyright © 2014 Luca Bruno
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

namespace Vanubi.UI {
	public class EntryHistory {
		History<string> history;
		int prev_pos = 0;
		string user_text = null;
		ulong changed_signal = 0;

		public EntryHistory (owned History history, Gtk.Entry entry) {
			this.history = (owned) history;
			// connect like this for keeping a reference to self
			var self = this;
			entry.key_press_event.connect ((w, e) => { return self.on_key_press_event (w, e); });
			entry.activate.connect ((w) => { self.on_activate (w); });
			changed_signal = entry.changed.connect ((w) => { self.on_changed (w); });
		}

		bool on_key_press_event (Gtk.Widget widget, Gdk.EventKey e) {
			var entry = (Gtk.Entry) widget;
			
			if (e.keyval != Gdk.Key.Up && e.keyval != Gdk.Key.Down && !(Gdk.ModifierType.MOD1_MASK in e.state)) {
				return false;
			}

			if (user_text == null) {
				user_text = entry.text;
			}

			var entry_pos = entry.cursor_position;
			if (e.keyval == Gdk.Key.Up) {
				unowned string text = history.older (ref prev_pos);
				while (text == entry.text) {
					text = history.older (ref prev_pos);
				}
				if (text != null) {
					SignalHandler.block (entry, changed_signal);
					entry.text = text;
					SignalHandler.unblock (entry, changed_signal);
				}
			} else {
				unowned string text = history.newer (ref prev_pos);
				while (text == entry.text) {
					text = history.newer (ref prev_pos);
				}
				SignalHandler.block (entry, changed_signal);
				if (text != null) {
					entry.text = text;
				} else {
					entry.text = user_text;
				}
				SignalHandler.unblock (entry, changed_signal);
			}
			entry.grab_focus ();
			entry.set_position (entry_pos);

			return true;
		}

		void on_changed (Gtk.Editable widget) {
			var entry = (Gtk.Entry) widget;

			user_text = entry.text;
		}
		
		void on_activate (Gtk.Widget widget) {
			var entry = (Gtk.Entry) widget;

			history.add (entry.text);
		}
	}
}
