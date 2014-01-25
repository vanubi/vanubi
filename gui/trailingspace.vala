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
		int old_cursor;
		
		public TrailingSpaces (SourceView view) {
			this.view = view;
			
			/* XXX: get tag from the style */
			if (view.buffer.get_tag_table ().lookup (TAG_NAME) == null) {
				/* Insert default tag */
				view.buffer.create_tag (TAG_NAME, "background", "#160808");
			}
			
			old_cursor = get_cursor_line ();
		}
		
		private void find_line_trailing_spaces (int line, out TextIter start, out TextIter end) {
			view.buffer.get_iter_at_line (out end, line);
			end.forward_to_line_end ();
			start = end;

			if (end.get_line_offset () == 0) {
				return;
			}
			
			while (start.get_line_offset () != 0 && start.get_char ().isspace ()) {
				start.backward_char ();
			}
			
			if (!start.get_char ().isspace ()) {
				start.forward_char ();
			}
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
			for (var i=1; i<=tot_lines; i++) {
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
		
		private void untrail_line (int line) {
			cleanup_line (line);
			
			TextIter trail_start, trail_end;
			find_line_trailing_spaces (line, out trail_start, out trail_end);
			
			if (trail_end.get_offset () > trail_start.get_offset ()) {
				var buf = view.buffer;
				buf.begin_user_action ();
				view.buffer.@delete (ref trail_start, ref trail_end);
				buf.end_user_action ();
			}
		}
		
		public void cleanup_buffer () {
			var tot_lines = view.buffer.get_line_count ();
			for (var i=1; i<=tot_lines; i++) {
				cleanup_line (i);
			}
		}
		
		public void check_inserted_text (ref TextIter pos, string text, bool untrail) {
			if (text == "\n") {
				var line_num = pos.get_line ();
				var prev = pos;
				prev.backward_line ();

				if (prev.get_line () == pos.get_line ()) {
					return;
				}

				if (untrail) {
					untrail_line (prev.get_line ());

					/* Revalidate the iter for other listeners */
					TextIter new_iter;
					view.buffer.get_iter_at_line (out new_iter, line_num);
					pos.assign (new_iter);

					/* Colorize next line because doesn't maintain the tag */
					var next = pos;
					next.forward_line ();
					check_line (next.get_line ());
				} else {
					check_line (prev.get_line ());
				}
			}
		}
		
		private int get_cursor_line () {
			TextIter insert;
			view.buffer.get_iter_at_mark (out insert, view.buffer.get_insert ());
			return insert.get_line ();
		}
		
		public void check_cursor_line () {
			int curr_cursor = get_cursor_line ();
			if (curr_cursor == old_cursor) {
				return;
			}
			check_line (old_cursor);
			cleanup_line (curr_cursor);
			old_cursor = curr_cursor;
		}
	}
}
