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
	
	public unowned TextMark get_start_mark_for_location (Location loc, TextBuffer buf) {
		unowned TextMark? mark = loc.get_data ("start-mark");
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
		mark.weak_ref (() => { loc.set_data ("start-mark", null); });

		return mark;
	}
	
	public TextMark get_end_mark_for_location (Location loc, TextBuffer buf) {
		weak TextMark? mark = loc.get_data ("end-mark");
		if (mark != null) {
			return mark;
		}
		
		var start_mark = get_start_mark_for_location (loc, buf);
		TextIter iter;
		if (loc.start_line >= 0 && loc.end_line >= 0) {
			buf.get_iter_at_mark (out iter, start_mark);
			if (loc.end_column >= 0) {
				iter.forward_chars (loc.end_column);
			} else {
				iter.forward_chars (loc.start_column);
			}
			
			mark = buf.create_mark (null, iter, false);
		} else {
			mark = start_mark;
		}
		
		loc.set_data ("end-mark", mark);
		mark.weak_ref (() => { loc.set_data ("end-mark", null); });
		
		return mark;
	}
	
	public string[] get_styles_search_path () {
		return {absolute_path("", "~/.vanubi/styles/"), "./data/styles/", Configuration.VANUBI_DATADIR + "/vanubi/styles/"};
	}
}