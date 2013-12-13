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

using Vte;
using Gtk;

namespace Vanubi {
	public string key_to_string (Key key) {
		var res = "";
		if (Gdk.ModifierType.CONTROL_MASK in (Gdk.ModifierType) key.modifiers) {
			res = "C-";
		}
		if (Gdk.ModifierType.SHIFT_MASK in (Gdk.ModifierType) key.modifiers) {
			res += "S-";
		}
		res += Gdk.keyval_name (key.keyval);
		return res;
	}

	public string keys_to_string (Key?[] keys) {
		var res = new StringBuilder ();
		foreach (var key in keys) {
			res.append (key_to_string (key));
			res.append (" ");
		}
		res.truncate (res.len - 1);
		return res.str;
	}
}