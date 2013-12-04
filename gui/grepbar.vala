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

using Vte;
using Gtk;

namespace Vanubi {
	public class GrepBar : EntryBar {
		public Location location { get; private set; }
		public InputStream stream {
			set {
				view.buffer.set_text ("");
				read_stream.begin (value);
			}
		}
		
		TextView view;
		
		public GrepBar () {
			entry.expand = false;
			view = new TextView ();
			view.editable = false;
			view.key_press_event.connect (on_key_press_event);
			var sw = new ScrolledWindow (null, null);
			sw.expand = true;
			sw.add (view);
			sw.show_all ();
			attach_next_to (sw, entry, PositionType.TOP, 1, 1);
		}

		public async void read_stream (InputStream stream) {
			try {
				uint8[] buffer = new uint8[1024];
				while (true) {
					var read = yield stream.read_async (buffer);
					if (read == 0) {
						break;
					}
					TextIter iter;
					view.buffer.get_end_iter (out iter);
					view.buffer.insert (ref iter, (string) buffer, (int) read);
				}
			} catch (Error e) {
			}
		}
	}
}
