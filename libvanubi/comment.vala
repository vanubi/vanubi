/*
 *  Copyright © 2013 Luca Bruno
 *  Copyright © 2013 Rocco Folino
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

namespace Vanubi {
	public abstract class Comment {
		public abstract void comment (BufferIter start_iter, BufferIter end_iter);
	}

	public class Comment_Default : Comment {
		Buffer buf;

		public Comment_Default (Buffer buf) {
			this.buf = buf;
		}

		private bool is_line_commented (int line) {
			return /\s*\/\* .+ \*\//.match(buf.line_text (line));
		}

		private int count_commented_lines (int start_line, int end_line) {
			var count = 0;
			for (var i=start_line; i<=end_line; i++) {
				if (is_line_commented (i)) {
					count++;
				}
			}
			return count;
		}

		private void escape_line (int line) {
			var iter = buf.line_start (line);
			iter.forward_spaces ();
			while (!iter.eol) {
				if (iter.char == '/') {
					buf.insert (iter, "\\");
					iter.forward_char ();
				}
				iter.forward_char ();
			}
		}

		private void unescape_line (int line) {
			var iter = buf.line_start (line);
			iter.forward_spaces ();
			while (!iter.eol) {
				if (iter.char == '\\') {
					var end_iter = iter.copy ();
					end_iter.forward_char ();
					buf.delete (iter, end_iter);
				}
				iter.forward_char ();
			}
		}

		private void comment_line (int line) {
			if (buf.empty_line (line)) {
				return;
			}

			if (is_line_commented (line)) {
				escape_line (line);
			}
			var start_iter = buf.line_start (line);
			start_iter.forward_spaces ();
			buf.insert (start_iter, "/* ");
			var end_iter = buf.line_end (start_iter.line);
			buf.insert (end_iter, " */");
		}

		private void decomment_line (int line) {
			if (buf.empty_line (line)) {
				return;
			}
			if (is_line_commented (line)) {
				var iter = buf.line_start (line);
				iter.forward_spaces ();
				var del_iter = iter.copy ();
				iter.forward_char (); /* Skip '/' */
				iter.forward_char (); /* Skip '*' */
				iter.forward_char (); /* Skip ' ' */
				buf.delete (del_iter, iter);
				iter = buf.line_end (line);
				iter.backward_spaces ();
				iter.forward_char(); /* Must point after '/' */
				del_iter = iter.copy ();
				iter.backward_char (); /* Skip ' ' */
				iter.backward_char (); /* Skip '*' */
				iter.backward_char (); /* Skip '/' */
				buf.delete (iter, del_iter);
				unescape_line (line);
			}
		}

		public override void comment (BufferIter start_iter, BufferIter end_iter) {
			var start_line = start_iter.line;
			var end_line = end_iter.line;
			var tot_lines = (end_line - start_line) + 1;
			if (tot_lines < 0) { /* Invalid region */
				warning ("Invalid comment region [%d]", tot_lines);
				return;
			} else if (tot_lines == 1) { /* Commenting single line */
				if (is_line_commented (start_line)) {
					decomment_line (start_line);
				} else {
					comment_line (start_line);
				}
			} else { /* Commenting region */
				var commented_lines = count_commented_lines (start_iter.line, end_iter.line);
				if (commented_lines == tot_lines) { /* Decomment all */
					for (var i=start_line; i<=end_line; i++) {
						decomment_line (i);
					}
				} else { /* Comment all and escape already commented lines */
					for (var i=start_line; i<=end_line; i++) {
						comment_line (i);
					}
				}
			}
		}
	}

	public class Comment_Hash : Comment {
		Buffer buf;

		public Comment_Hash (Buffer buf) {
			this.buf = buf;
		}

		private bool is_line_commented (int line) {
			return /\s*# .*/.match(buf.line_text (line));
		}

		private int count_commented_lines (int start_line, int end_line) {
			var count = 0;
			for (var i=start_line; i<=end_line; i++) {
				if (is_line_commented (i)) {
					count++;
				}
			}
			return count;
		}

		private void comment_line (int line) {
			var iter = buf.line_start (line);
			iter.forward_spaces ();
			buf.insert (iter, "# ");
		}

		private void decomment_line (int line) {
			if (is_line_commented (line)) {
				var iter = buf.line_start (line);
				iter.forward_spaces ();
				var del_iter = iter.copy ();
				iter.forward_char (); /* Skip '#' */
				iter.forward_char (); /* Skip ' ' */
				buf.delete (del_iter, iter);
			}
		}

		public override void comment (BufferIter start_iter, BufferIter end_iter) {
			var start_line = start_iter.line;
			var end_line = end_iter.line;
			var tot_lines = (end_line - start_line) + 1;
			if (tot_lines < 0) { /* Invalid region */
				warning ("Invalid comment region [%d]", tot_lines);
				return;
			} else if (tot_lines == 1) { /* Commenting single line */
				if (is_line_commented (start_line)) {
					decomment_line (start_line);
				} else {
					comment_line (start_line);
				}
			} else { /* Commenting region */
				var commented_lines = count_commented_lines (start_iter.line, end_iter.line);
				if (commented_lines == tot_lines) { /* Decomment all */
					for (var i=start_line; i<=end_line; i++) {
						decomment_line (i);
					}
				} else { /* Comment all and escape already commented lines */
					for (var i=start_line; i<=end_line; i++) {
						comment_line (i);
					}
				}
			}
		}
	}

	public class Comment_Asm : Comment {
		Buffer buf;

		public Comment_Asm (Buffer buf) {
			this.buf = buf;
		}

		private bool is_line_commented (int line) {
			return /\s*; .*/.match(buf.line_text (line));
		}

		private int count_commented_lines (int start_line, int end_line) {
			var count = 0;
			for (var i=start_line; i<=end_line; i++) {
				if (is_line_commented (i)) {
					count++;
				}
			}
			return count;
		}

		private void comment_line (int line) {
			var iter = buf.line_start (line);
			iter.forward_spaces ();
			buf.insert (iter, "; ");
		}

		private void decomment_line (int line) {
			if (is_line_commented (line)) {
				var iter = buf.line_start (line);
				iter.forward_spaces ();
				var del_iter = iter.copy ();
				iter.forward_char (); /* Skip ';' */
				iter.forward_char (); /* Skip ' ' */
				buf.delete (del_iter, iter);
			}
		}

		public override void comment (BufferIter start_iter, BufferIter end_iter) {
			var start_line = start_iter.line;
			var end_line = end_iter.line;
			var tot_lines = (end_line - start_line) + 1;
			if (tot_lines < 0) { /* Invalid region */
				warning ("Invalid comment region [%d]", tot_lines);
				return;
			} else if (tot_lines == 1) { /* Commenting single line */
				if (is_line_commented (start_line)) {
					decomment_line (start_line);
				} else {
					comment_line (start_line);
				}
			} else { /* Commenting region */
				var commented_lines = count_commented_lines (start_iter.line, end_iter.line);
				if (commented_lines == tot_lines) { /* Decomment all */
					for (var i=start_line; i<=end_line; i++) {
						decomment_line (i);
					}
				} else { /* Comment all and escape already commented lines */
					for (var i=start_line; i<=end_line; i++) {
						comment_line (i);
					}
				}
			}
		}
	}
}
