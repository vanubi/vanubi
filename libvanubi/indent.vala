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
		public abstract int tab_width { get; set; }
		public virtual IndentMode indent_mode { get; set; default = IndentMode.TABS; }
		public abstract BufferIter line_start (int line);
		public abstract BufferIter line_end (int line);
		public abstract void insert (BufferIter iter, string text);
		public abstract void delete (BufferIter start, BufferIter end);
		public abstract string line_text (int line);

		public virtual bool empty_line (int line) {
			return line_text(line).strip()[0] == '\0';
		}

		public virtual void set_indent (int line, int indent) {
			indent = int.max (indent, 0);
			if (get_indent (line) == indent) {
				// avoid adding unfriendly undo actions
				return;
			}

			var start = line_start (line);
			var iter = start.copy ();
			while (iter.char.isspace() && !iter.eol) {
				iter.forward_char ();
			}

			@delete (start, iter);
			var tab_width = tab_width;
			// mixed tab + spaces, TODO: handle indent_mode
			insert (start, string.nfill(indent/tab_width, '\t')+string.nfill(indent-(indent/tab_width)*tab_width, ' '));
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

		public virtual void forward_spaces () {
			while (!eol && char.isspace()) forward_char ();
		}																					
		
		public virtual int effective_line_offset {
			get {
				var iter = copy ();
				var off = 0;
				do {
					if (iter.char == '\t') {
						off += buffer.tab_width;
					} else {
						off++;
					}
					if (iter.line_offset == 0) {
						break;
					}
					iter.backward_char ();
				} while (true);
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

		public override int tab_width { get; set; default = 4; }

		public override string line_text (int line) {
			return lines[line];
		}

		public override BufferIter line_start (int line) {
			return new StringBufferIter (this, line, 0);
		}

		public override BufferIter line_end (int line) {
			unowned string l = lines[line];
			return new StringBufferIter (this, line, l.length-1);
		}

		// only on a single line
		public override void insert (BufferIter iter, string text) requires (((StringBufferIter) iter).valid && text.index_of ("\n") < 0) {
			unowned string l = lines[iter.line];
			lines[iter.line] = l.substring(0, iter.line_offset) + text + l.substring (iter.line_offset);
			// update the iter
			var siter = (StringBufferIter) iter;
			siter._line_offset += text.length;
			siter.timestamp = ++timestamp;
		}

		// only on a single line
		public override void delete (BufferIter start, BufferIter end) requires (((StringBufferIter)start).valid && ((StringBufferIter)end).valid && start.line == end.line) {
			unowned string l = lines[start.line];
			lines[start.line] = l.substring(0, start.line_offset) + l.substring (end.line_offset);
			// update the iter
			var sstart = (StringBufferIter) start;
			var send = (StringBufferIter) end;
			send._line_offset = sstart.line_offset;
			sstart.timestamp = send.timestamp = ++timestamp;
		}
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

		public bool valid {
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

	public class Indent_C : Indent {
		Buffer buf;

		public Indent_C (Buffer buf) {
			this.buf = buf;
		}

		int first_non_empty_prev_line (int line) {
			// find first non-blank prev line, excluding line
			while (--line >= 0 && buf.empty_line (line));
			return line;
		}

		// counts closed parens in front of a line
		int count_closed (int line) {
			var closed = 0;
			var iter = buf.line_start (line);
			while (!iter.eol) {
				var c = iter.char;
				if ((c == '}' || c == ']' || c == ')') && iter.is_in_code) {
					closed++;
				} else if (!c.isspace ()) {
					break;
				}
				iter.forward_char ();
			}
			return closed;
		}
		
		// counts unclosed parens in a line
		int count_unclosed (int line) {
			var unclosed = 0;
			var iter = buf.line_start (line);
			while (!iter.eol) {
				var c = iter.char;
				if ((c == '{' || c == '[' || c == '(') && iter.is_in_code) {
					unclosed++;
				} else if ((c == '}' || c == ']' || c == ')') && iter.is_in_code) {
					if (unclosed > 0) {
						unclosed--;
					}
				}
				iter.forward_char ();
			}
			return unclosed;
		}
		
		// returns the iter for the opened paren for which there's a given unbalance
		BufferIter unclosed_paren (int line, int unbalance) {
			// find line that is semantically opening the paren
			int balance = 0;
			var iter = buf.line_start (line);
			var paren_iter = iter;
			while (true) {
				var c = iter.char;
				if ((c == '{' || c == '[' || c == '(') && iter.is_in_code) {
					balance++;
					if (balance == unbalance) {
						paren_iter = iter.copy ();
					}
				} else if ((c == '}' || c == ']' || c == ')') && iter.is_in_code) {
					balance--;
				}
				if (iter.eol) {
					if (balance == unbalance) {
						return paren_iter;
					}
					line = first_non_empty_prev_line (line);
					if (line < 0) {
						// not found
						return iter;
					}
					iter = buf.line_start (line);
				} else {
					iter.forward_char ();
				}
			}
		}

		public void indent (BufferIter indent_iter) {
			if (!indent_iter.is_in_code) {
				return;
			}
			
			var line = indent_iter.line;
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

			// indent
			var unclosed = count_unclosed (prev_line);
			if (unclosed == 0) {
				var paren_iter = unclosed_paren (prev_line, 0);
				new_indent = buf.get_indent (paren_iter.line);
			} else if (unclosed > 0) {
				var paren_iter = unclosed_paren (prev_line, unclosed);
				if (!paren_iter.eol) {
					paren_iter.forward_char ();
				}
				paren_iter.forward_spaces ();
				if (paren_iter.eol || paren_iter.line < prev_line) {
					new_indent = buf.get_indent (paren_iter.line) + unclosed * tab_width;
				} else {
					new_indent = paren_iter.effective_line_offset-1;
				}
			}
		
			// unindent
			var closed = count_closed (line);
			if (closed > 0) {
				var paren_iter = unclosed_paren (line, 0);
				new_indent = buf.get_indent (paren_iter.line);
				// TODO: fix for nested objects ala javascript/php or C structs
			}

			buf.set_indent (line, new_indent);
		}
	}
}
