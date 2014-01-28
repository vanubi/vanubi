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

using Vte;
using Gtk;

namespace Vanubi.UI {
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

	public string keys_to_string (Key[] keys) {
		var res = new StringBuilder ();
		foreach (var key in keys) {
			res.append (key_to_string (key));
			res.append (" ");
		}
		res.truncate (res.len - 1);
		return res.str;
	}

	public Key parse_key (string key) throws Error {
		var len = key.length;
		uint keyval = Gdk.Key.VoidSymbol;
		var modifiers = 0;
		for (var i=0; i < len; i++) {
			if (key[i] == 'C' && i+1 < len && key[i+1] == '-') {
				modifiers |= Gdk.ModifierType.CONTROL_MASK;
				i++;
			} else if (key[i] == 'S' && i+1 < len && key[i+1] == '-') {
				modifiers |= Gdk.ModifierType.SHIFT_MASK;
				i++;
			} else {
				keyval = Gdk.keyval_from_name (key[i].to_string ());
			}
		}
		if (keyval == Gdk.Key.VoidSymbol) {
			throw new ConvertError.ILLEGAL_SEQUENCE ("Invalid key: "+key);
		}
		
		return Key (keyval, modifiers);
	}
	
	public Key[] parse_keys (string keys) throws Error {
		var split = keys.strip().split (" ");
		var res = new Key[0];
		foreach (unowned string key in split) {
			res += parse_key (key);
		}
		return res;
	}
	
	public unowned TextMark get_start_mark_for_location (Location loc, TextBuffer abuf) {
		unowned TextMark? mark = loc.get_data ("start-mark");
		unowned TextBuffer buf = abuf;
		
		if (mark != null) {
			return mark;
		}
		
		TextIter iter;
		if (loc.start_line >= 0) {
			buf.get_iter_at_line (out iter, loc.start_line);
			if (loc.start_column >= 0) {
				iter.forward_chars (loc.start_column);
			}
		} else {
			buf.get_start_iter (out iter);
		}

		mark = buf.create_mark (null, iter, false);
		loc.set_data ("start-mark", mark);

		buf.add_weak_pointer (&buf);
		buf.add_weak_pointer (&mark);
		loc.weak_ref (() => {
				if (buf != null && mark != null) {
					buf.remove_weak_pointer (&mark);
					buf.remove_weak_pointer (&buf);
					buf.delete_mark (mark);
				}
		});

		return mark;
	}
	
	public TextMark get_end_mark_for_location (Location loc, TextBuffer buf) {
		weak TextMark? mark = loc.get_data ("end-mark");
		if (mark != null) {
			return mark;
		}
		
		var start_mark = get_start_mark_for_location (loc, buf);
		if (loc.start_line >= 0 && loc.end_line >= 0) {
			var end_column = loc.end_column >= 0 ? loc.end_column : loc.start_column;
			TextIter iter;
			buf.get_iter_at_line_offset (out iter, loc.end_line, end_column);
			mark = buf.create_mark (null, iter, false);
		} else {
			mark = start_mark;
		}
		
		loc.set_data ("end-mark", mark);
		
		return mark;
	}
	
	public string[] get_styles_search_path () {
		return {absolute_path("", "~/.vanubi/styles/"), "./data/styles/", Configuration.VANUBI_DATADIR + "/vanubi/styles/"};
	}
}