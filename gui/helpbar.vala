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
	class HelpBar : Bar {
		StringSearchIndex index;

		public HelpBar (StringSearchIndex index) {
			this.index = index;
			entry.changed.connect (on_changed);
		}


		void on_changed () {
			var text = entry.get_text ();
			search (text);
		}

		void search (string query) {
			message(query);
			var result = index.search (query);
			foreach (var item in result) {
				var doc = (StringSearchDocument) item.doc;
				message(doc.name);
			}
		}

		protected override bool on_key_press_event (Gdk.EventKey e) {
			if (e.keyval == Gdk.Key.Escape || (e.keyval == Gdk.Key.g && Gdk.ModifierType.CONTROL_MASK in e.state)) {
				aborted ();
				return true;
			}
			return false;
		}
	}
}