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

		public EntryHistory (owned History history, Gtk.Entry entry) {
			this.history = (owned) history;
			entry.key_press_event.connect (on_key_press_event);
		}

		protected bool on_key_press_event (Gtk.Widget widget, Gdk.EventKey e) {
			if (e.keyval != Gdk.Key.Up && e.keyval != Gdk.Key.Down && !(Gdk.ModifierType.MOD1_MASK in e.state)) {
				return false;
			}
			
			if (e.keyval == Gdk.Key.Up) {
			} else {
				// key down
			}
			return true;
		}
	}
}
