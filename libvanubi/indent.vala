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
		public virtual int tab_width { get; set; }
		public abstract int length { get; }
		public abstract BufferIter line_start (int line);
		public abstract BufferIter line_end (int line);
		public abstract void begin_undo_action ();
		public abstract void end_undo_action ();
		
		public virtual bool empty_line (int line) {
			var it = line_start (line);
			return it.line_text.strip()[0] == '\0';
		}

		public virtual void set_indent (int line, int indent) {
			indent = int.max (indent, 0);

			var start = line_start (line);
			var iter = start.copy ();
			while (iter.char.isspace() && !iter.eol) {
				iter.forward_char ();
			}

			begin_undo_action ();
			var tab_width = tab_width;
			var text = iter.line_text.substring (iter.line_offset);
			var fill = string.nfill(indent/tab_width, '\t')+string.nfill(indent-(indent/tab_width)*tab_width, ' ');
			iter.line_text = fill+text;
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
		public unowned Buffer buffer { get; set; }
		public abstract bool valid { get; }

		public BufferIter (Buffer buffer) {
			this.buffer = buffer;
		}

		public abstract void forward_char ();
		public abstract void backward_char ();
		public abstract bool is_in_code { get; }
		public abstract int line_offset { get; }
		public abstract int line { get; }
		public abstract string line_text { owned get; owned set; }
		public abstract bool eol { get; }
		public abstract unichar char { get; }
		public abstract BufferIter copy ();
	}

	public interface Indent {
		public abstract void indent (BufferIter iter);
	}

	public abstract class StringBuffer : Buffer {
		internal string[] lines;
		internal int timestamp;

		public BufferIter line_start (int line) {
			return new StringBufferIter (this, line, 0);
		}

		public BufferIter line_end (int line) {
			unowned string l = lines[line];
			return new StringBufferIter (this, line, l.length-1);
		}

		public string get_line (int line) {
			return lines[line];
		}

		public void set_line (int line, string text) {
			lines[line] = text;
			timestamp++;
		}

		public void begin_undo_action () { }
		public void end_undo_action () { }
	}

	/* ASCII string buffer iter */
	public class StringBufferIter : BufferIter {
		internal int _line;
		internal int _line_offset;
		int timestamp;
		StringBuffer buf;

		public StringBufferIter (StringBuffer buffer, int line, int line_offset) {
			base (buffer);
			buf = buffer;
			_line = line;
			_line_offset = line_offset;
			timestamp = buf.timestamp;
		}

		public override bool valid {
			get {
				return timestamp == buf.timestamp;
			}
		}

		public override void forward_char () requires (valid) {
			if (eol) {
				if (_line >= buf.lines.length-1) {
					return;
				}
				_line++;
				_line_offset = 0;
			} else {
				_line_offset++;
			}
		}

		public override void backward_char () requires (valid) {
			if (_line_offset == 0) {
				if (_line == 0) {
					return;
				}
				_line--;
				unowned string l = buf.lines[_line];
				_line_offset = l.length-1;
			} else {
				_line_offset--;
			}
		}

		public override bool is_in_code {
			get {
				
				// assume no strings and no comments for the tests
				return true;
			}
		}

		public override int line_offset {
			get {
				return _line_offset;
			}
		}

		public override int line {
			get {
				return _line;
			}
		}

		public override string line_text {
			owned get {
				return buf.lines[_line];
			}

			owned set {
				buf.lines[_line] = (owned) value;
				buf.timestamp++;
			}
		}

		public override bool eol {
			get {
				unowned string l = buf.lines[line];
				return line_offset == l.length-1;
			}
		}

		public override unichar char {
			get {
				unowned string l = buf.lines[line];
				return l[line_offset];
			}
		}

		public override BufferIter copy () requires (valid) {
			var it = new StringBufferIter (buf, _line, _line_offset);
			it.timestamp = timestamp;
			return it;
		}
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
