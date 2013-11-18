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
	public enum IndentMode {
		TABS,
		SPACES
	}

	public abstract class Buffer {
		public virtual int tab_width { get; set; default = 4; }
		public virtual IndentMode indent_mode { get; set; default = IndentMode.TABS; }
		public abstract int length { get; }
		public abstract BufferIter line_start (int line);
		public abstract BufferIter line_end (int line);
		public abstract void begin_undo_action ();
		public abstract void end_undo_action ();
		public abstract void insert (BufferIter iter, string text);
		public abstract void delete (BufferIter start, BufferIter end);
		public abstract string line_text (int line);

		public virtual bool empty_line (int line) {
			return line_text(line).strip()[0] == '\0';
		}

		public virtual void set_indent (int line, int indent) {
			indent = int.max (indent, 0);

			var start = line_start (line);
			var iter = start.copy ();
			while (iter.char.isspace() && !iter.eol) {
				iter.forward_char ();
			}

			begin_undo_action ();
			@delete (start, iter);
			var tab_width = tab_width;
			// mixed tab + spaces, TODO: handle indent_mode
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
		public abstract bool eol { get; }
		public abstract unichar char { get; }
		public abstract BufferIter copy ();

		public virtual int effective_line_offset {
			get {
				var iter = copy ();
				var off = 0;
				while (iter.line_offset > 0) {
					if (iter.char == '\t') {
						off += buffer.tab_width;
					} else {
						off++;
					}
				}
				return off;
			}
		}
	}

	public interface Indent {
		public abstract void indent (BufferIter iter);
	}

	/*****************
	 * STRING BUFFER
	 *****************/

	public class StringBuffer : Buffer {
		internal string[] lines;
		internal int timestamp;
		int _length;

		public StringBuffer (owned string[] lines) {
			this.lines = (owned) lines;
		}

		public StringBuffer.from_text (string text) {
			var lines = text.split ("\n");
			foreach (unowned string line in lines) {
				this.lines += line+"\n";
			}
			unowned string last = this.lines[this.lines.length-1];
			last.data[last.length-1] = '\0';
		}

		public string text {
			owned get {
				return string.joinv ("", lines);
			}
		}

		public override string line_text (int line) {
			return lines[line];
		}

		public override int length { get { return _length; } }

		public override BufferIter line_start (int line) {
			return new StringBufferIter (this, line, 0);
		}

		public override BufferIter line_end (int line) {
			unowned string l = lines[line];
			return new StringBufferIter (this, line, l.length-1);
		}

		// only on a single line
		public override void insert (BufferIter iter, string text) requires (iter.valid && text.index_of ("\n") < 0) {
			unowned string l = lines[iter.line];
			lines[iter.line] = l.substring(0, iter.line_offset) + text + l.substring (iter.line_offset);
			// update the iter
			var siter = (StringBufferIter) iter;
			siter._line_offset += text.length;
			siter.timestamp = ++timestamp;
		}

		// only on a single line
		public override void delete (BufferIter start, BufferIter end) requires (start.valid && end.valid && start.line == end.line) {
			unowned string l = lines[start.line];
			lines[start.line] = l.substring(0, start.line_offset) + l.substring (end.line_offset);
			// update the iter
			var sstart = (StringBufferIter) start;
			var send = (StringBufferIter) end;
			send._line_offset = sstart.line_offset;
			sstart.timestamp = send.timestamp = ++timestamp;
		}

		public override void begin_undo_action () { }
		public override void end_undo_action () { }
	}

	/* ASCII string buffer iter */
	public class StringBufferIter : BufferIter {
		internal int _line;
		internal int _line_offset;
		internal int timestamp;
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
				warn_if_fail (valid);
				return _line_offset;
			}
		}

		public override int line {
			get {
				warn_if_fail (valid);
				return _line;
			}
		}

		public override bool eol {
			get {
				warn_if_fail (valid);
				unowned string l = buf.lines[line];
				return line_offset >= l.length-1;
			}
		}

		public override unichar char {
			get {
				warn_if_fail (valid);
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

		int first_non_empty_prev_line (int line) {
			// find first non-blank prev line, excluding line
			int prev_line = line-1;
			while (!buf.empty_line (prev_line--));
			return prev_line;
		}

		public void indent (int line) {
			if (line == 0) {
				buf.set_indent (line, 0);
				return;
			}

			var new_indent = 0;
			var tab_width = buf.tab_width;

			var text = buf.line_text(line);
			if (text.strip() == "done" || text.strip() == "fi") {
				new_indent = buf.get_indent (line) - tab_width;
				buf.set_indent (line, new_indent);
				return;
			}

			var prev_line = first_non_empty_prev_line (line);

			if (prev_line < 0) {
				buf.set_indent (line, 0);
				return;
			}

			var prev_indent = buf.get_indent (prev_line);
			
			var prev_text = buf.line_text(prev_line);
			var prev_semicomma = prev_text.last_index_of (";");
			string text_after_semicomma = null;
			if (prev_semicomma >= 0) {
					text_after_semicomma = prev_text.substring (prev_semicomma+1).strip ();
			}
			if (text_after_semicomma == "do" || text_after_semicomma == "then") {
				new_indent = prev_indent + tab_width;
				buf.set_indent (line, new_indent);
				return;
			}

			// count unclosed parens
			int unclosed = 0;
			var iter = buf.line_start (prev_line);
			var first_nonspace = true;
			var last_isparen = false;
			new_indent = prev_indent;
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
						new_indent = iter.effective_line_offset + 1;
						last_isparen = false;
					} else {
						last_isparen = true;
					}
					unclosed++;
				} else if ((c == '}' || c == ']' || c == ')') && !first_nonspace && iter.is_in_code) {
					unclosed--;
				}

				if (!c.isspace ()) {
					first_nonspace = false;
				}
				iter.forward_char ();
			}
			if (unclosed == 0) {
				new_indent = prev_indent;
			} else if (last_isparen || unclosed < 0) {
				// FIXME: for unclosed < 0 this might be wrong
				new_indent = prev_indent + unclosed * tab_width;
			}

			int closed = 0;
			first_nonspace = true;
			// unindent, TODO: use indentation of the opened paren
			iter = buf.line_start (line);
			while (!iter.eol) {
				unichar c = iter.char;
				if (!c.isspace ()) {
					if ((c == '}' || c == ']' || c == ')') && iter.is_in_code) {
						if (!first_nonspace) {
							// don't unindent
							closed = 0;
							break;
						}
						closed++;
					}
					first_nonspace = false;
				}
				iter.forward_char ();
			}
			if (closed > 0) {
				// we have to find the unclosed paren backwards
				bool found = false;
				prev_line = line;
				while (!found) {
					prev_line = first_non_empty_prev_line (prev_line);
					if (prev_line < 0) {
						// TODO: blink error, closing an unopened paren
						new_indent = 0;
						break;
					}
					iter = buf.line_end (prev_line);
					do {
						var c = iter.char;
						if ((c == '}' || c == ']' || c == ')') && iter.is_in_code) {
							closed++;
						} else if ((c == '{' || c == '[' || c == '(') && iter.is_in_code) {
							closed--;
						}
						if (closed == 0) {
							// opened paren found!
							iter.forward_char ();
							if (iter.eol) {
								new_indent = buf.get_indent (prev_line);
							} else {
								new_indent = iter.effective_line_offset;
							}
							found = true;
							break;
						}
						iter.backward_char ();
					} while (iter.line_offset > 0);
				}
			}

			buf.set_indent (line, new_indent);
		}
	}
}
