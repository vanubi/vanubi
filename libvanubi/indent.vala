/*
 *  Copyright © 2011-2013 Luca Bruno
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
	public abstract class Buffer {
		public abstract int tab_width { get; set; }
		public abstract BufferIter line_start (int line);
		public abstract BufferIter line_end (int line);
		public abstract string get_text (BufferIter start, BufferIter end);
		public abstract void begin_undo_action ();
		public abstract void end_undo_action ();
		public abstract void delete (BufferIter start, BufferIter end);
		public abstract void insert (BufferIter start, string text);
		
		public virtual string get_line_text (int line) {
			var line_start = line_start (line);
			var line_end = line_end (line);
			var text = get_text (line_start, line_end);
			return text;
		}

		public virtual bool empty_line (int line) {
			return get_line_text (line).strip ()[0] == '\0';
		}

		public virtual void set_indent (int line, int indent) {
			indent = int.max (indent, 0);

			var start = line_start (line);
			var iter = start.copy ();
			while (iter.char.isspace() && !iter.eol) {
				iter.forward_char ();
			}

			begin_undo_action ();
			this.delete (start, iter);
			var tab_width = tab_width;
			// mixed tab + spaces, TODO: handle SourceView.insert_spaces_instead_of_tabs
			insert (start, string.nfill(indent/tab_width, '\t')+string.nfill(indent-(indent/tab_width)*tab_width, ' '));
			end_undo_action ();
		}

		public virtual int get_indent (int line) {
			var tab_width = tab_width;
			int indent = 0;

			var iter = line_start (line);
			while (iter.char.isspace () && !iter.eol) {
				if (iter.char == '\t') {
					indent += tab_width;
				} else {
					indent++;
				}
				iter.forward_char ();
			}
			return indent;
		}
	}

	public abstract class BufferIter : Object {
		public Buffer buffer { get; set; }

		public BufferIter (Buffer buffer) {
			this.buffer = buffer;
		}

		public abstract void forward_char ();
		public abstract void backward_char ();
		public abstract bool is_in_code { get; }
		public abstract int line_offset { get; }
		public abstract int line { get; }
		public abstract bool eol { get; }
		public abstract unichar char { get; }
		public abstract BufferIter copy ();
	}

	public interface Indent {
		public abstract void indent (BufferIter iter);
	}

	public class StringBuffer {
		
	}

	public class Indent_C {
		Buffer buf;

		public Indent_C (Buffer buf) {
			this.buf = buf;
		}

		public void indent (int line) {
			if (line == 0) {
				buf.set_indent (line, 0);
				return;
			}

			// find first non-blank prev line
			int prev_line = line-1;
			while (buf.empty_line (prev_line)) {
				prev_line--;
			}

			if (prev_line < 0) {
				buf.set_indent (line, 0);
			} else {
				var tab_width = buf.tab_width;

				// opened/closed braces
				var iter = buf.line_start (prev_line);
				var first_nonspace = true;
				var old_indent = buf.get_indent (prev_line);
				var new_indent = old_indent;
				while (!iter.eol) {
					var c = iter.char;
					unichar? la = null;
					iter.forward_char ();
					if (!iter.eol) {
						la = iter.char; // look ahead
					}
					iter.backward_char ();

					if ((c == '{' || c == '[' || c == '(') && iter.is_in_code) {
						if (la != null && !la.isspace ()) {
							new_indent = iter.line_offset + 1;
						} else {
							new_indent += tab_width;
						}
					} else if ((c == '}' || c == ']' || c == ')') && !first_nonspace && iter.is_in_code) {
						new_indent -= tab_width;
					}
					
					if (!c.isspace ()) {
						first_nonspace = false;
					}
					iter.forward_char ();
				}

				// unindent
				iter = buf.line_start (line);
				while (!iter.eol) {
					unichar c = iter.char;
					if (!c.isspace ()) {
						if ((c == '}' || c == ']' || c == ')') && iter.is_in_code) {
							new_indent -= tab_width;
						}
						break;
					}
					iter.forward_char ();
				}

				buf.set_indent (line, new_indent);
			}
		}
	}
}
