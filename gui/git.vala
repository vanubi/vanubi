/*
*  Copyright © 2014 Rocco Folino
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
	public class GitGutterRenderer : SourceGutterRenderer {
		HashTable<int, DiffType> table;
		
		public GitGutterRenderer () {
			Gdk.RGBA bg = Gdk.RGBA ();
			bg.parse ("#000000");
			background_rgba = bg; /* XXX: get editor bg color */
			size = 3;
			table = new HashTable<int, DiffType> (null, null);
		}
		
		public void update_table (HashTable<int, DiffType> table) {
			this.table = table;
		}
		
		private void colorize_gutter (Cairo.Context cr, Gdk.Rectangle rect, int r, int g, int b) {
			cr.save ();
			cr.rectangle (rect.x, rect.y, rect.width, rect.height);
			cr.set_source_rgb (r/255.0, g/255.0, b/255.0);
			cr.fill ();
			cr.restore ();
		}
		
		public override void draw (Cairo.Context cr,
								   Gdk.Rectangle background_area, Gdk.Rectangle cell_area,
								   TextIter start, TextIter end,
								   SourceGutterRendererState state) {
			base.draw (cr, background_area, cell_area, start, end, state);
			
			if (table == null) {
				return;
			}

			if (table.contains (start.get_line () + 1)) {
				DiffType t = table.lookup (start.get_line () + 1);
				if (t == DiffType.ADD) {
					colorize_gutter (cr, background_area, 0x73, 0xd2, 0x16); /* chamaeleon */
				} else if (t == DiffType.DEL) {
					colorize_gutter (cr, background_area, 0xcc, 0, 0); /* scarlet red */
				} else {
					colorize_gutter (cr, background_area, 0xb0, 0x37, 0xa3); /* plum */
				}
			} else {
				/* XXX: get editor bg color */
				colorize_gutter (cr, background_area, 0, 0, 0); /* black */
			}
		}
	}
}
