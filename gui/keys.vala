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

/* Manage key bindings in Gtk */
 
using Gtk;

namespace Vanubi.UI {
	public class KeyHandler {
		KeyManager keymanager;
		
		public KeyHandler (KeyManager keymanager) {
			this.keymanager = keymanager;
		}

		public static const uint[] skip_keyvals = {Gdk.Key.Control_L, Gdk.Key.Control_R,
												   Gdk.Key.Shift_L, Gdk.Key.Shift_R,
												   Gdk.Key.Alt_L, Gdk.Key.Alt_R};

		public bool key_press_event (Object subject, Gdk.EventKey e, out bool abort) {
			abort = false;
			
			var keyval = e.keyval;
			var modifiers = e.state;
			
			if (Gdk.ModifierType.SHIFT_MASK in modifiers || Gdk.ModifierType.LOCK_MASK in modifiers) {
				if (keyval < 256 && ((char)keyval).isalpha ()) {
					keyval = ((char)keyval).tolower ();
				}
			}
			
			modifiers &= Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK | Gdk.ModifierType.MOD1_MASK;
			if (keyval == Gdk.Key.Escape || (keyval == Gdk.Key.g && modifiers == Gdk.ModifierType.CONTROL_MASK)) {
				abort = true;
				return true;
			}
			if (keyval in skip_keyvals) {
				// skip
				return true;
			}

			var key = Key (keyval, modifiers);
			return keymanager.key_press (subject, key);
		}
	}
}

