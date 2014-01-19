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

namespace Vanubi.UI {
	/* Based on https://gitorious.org/gedit-trailing-spaces */
	public class TrailingSpaces {
		private const string TAG_NAME = "trailing-space";
		
		unowned SourceView view;
		
		public TrailingSpaces (SourceView view) {
			this.view = view;
			
			/* XXX: get tag from the style */
			if (view.buffer.get_tag_table ().lookup (TAG_NAME) == null) {
				/* Insert default tag */
				view.buffer.create_tag (TAG_NAME, "background", "#160808");
			}
		}
		
		private void find_line_trailing_spaces (int line, out TextIter start, out TextIter end) {
			view.buffer.get_iter_at_line (out end, line);
			end.forward_to_line_end ();
			start = end;

			if (end.get_line_offset () == 0) {
				return;
			}
			
			while (start.get_char ().isspace ()) {
				start.backward_char ();
			}
			start.forward_char ();
		}
		
		private void check_line (int line) {
			cleanup_line (line);
			
			TextIter trail_start, trail_end;
			find_line_trailing_spaces (line, out trail_start, out trail_end);
			view.buffer.apply_tag_by_name (TAG_NAME, trail_start, trail_end);
		}
		
		public void check_buffer ()
		{
			var tot_lines = view.buffer.get_line_count ();
			for (var i=0; i<tot_lines; i++) {
				check_line (i);
			}
		}
		
		private void cleanup_line (int line) {
			TextIter iter_start, iter_end;
			view.buffer.get_iter_at_line_offset (out iter_start, line, 0);
			iter_end = iter_start;
			iter_end.forward_to_line_end ();
			
			view.buffer.remove_tag_by_name (TAG_NAME, iter_start, iter_end);
		}
		
		public void cleanup_buffer () {
			var tot_lines = view.buffer.get_line_count ();
			for (var i=0; i<tot_lines; i++) {
				cleanup_line (i);
			}
		}
		
		public void check_inserted_text (ref TextIter pos, string text) {
			if (text == "\n") {
				var prev = pos;
				prev.backward_line ();
				
				if (prev.get_line () == pos.get_line ()) {
					return;
				}
				
				check_line (prev.get_line ());
			} else {
				check_line (pos.get_line ());
			}
		}
	}
}
