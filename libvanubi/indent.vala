/*
 *  Copyright © 2011-2016 Luca Bruno
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

	public abstract class Indent {
		public Buffer buffer { get; protected set; }

		public Indent (Buffer buffer) {
			this.buffer = buffer;
		}

		public abstract void indent (BufferIter iter);

		// utils
		protected int first_non_empty_prev_line (int line) {
			// find first non-blank prev line, excluding line
			var buf = buffer;
			while (--line >= 0 && buf.empty_line (line));
			return line;
		}
	}

	public class Indent_C : Indent {
		public Indent_C (Buffer buffer) {
			base (buffer);
		}

		bool is_char (BufferIter iter) {
			if (!iter.is_in_code) {
				return false;
			}
			var cp = iter.copy ();
			cp.backward_char ();
			if (cp.char == '\'') {
				cp = iter.copy ();
				cp.forward_char ();
				if (cp.char == '\'') {
					return true;
				}
			}
			return false;
		}

		bool is_open_paren (BufferIter iter) {
			var c = iter.char;
			return (c == '{' || c == '[' || c == '(') && iter.is_in_code && !is_char (iter);
		}

		bool is_close_paren (BufferIter iter) {
			var c = iter.char;
			return (c == '}' || c == ']' || c == ')') && iter.is_in_code && !is_char (iter);
		}

		// counts closed parens in front of a line
		int count_closed (int line) {
			var buf = buffer;
			var closed = 0;
			var iter = buf.line_start (line);
			while (!iter.eol) {
				var c = iter.char;
				if (is_close_paren (iter)) {
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
			var buf = buffer;
			var unclosed = 0;
			var iter = buf.line_start (line);
			while (!iter.eol) {
				if (is_open_paren (iter)) {
					unclosed++;
				} else if (is_close_paren (iter)) {
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
			var buf = buffer;
			// find line that is semantically opening the paren
			int balance = 0;
			var iter = buf.line_start (line);
			var paren_iter = iter;
			while (true) {
				if (is_open_paren (iter)) {
					balance++;
					if (balance == unbalance) {
						paren_iter = iter.copy ();
					}
				} else if (is_close_paren (iter)) {
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

		public override void indent (BufferIter indent_iter) {
			var buf = buffer;

			var line = indent_iter.line;
			if (line == 0) {
				buf.set_indent (line, 0);
				return;
			}

			var new_indent = 0;
			var tab_width = buf.tab_width;

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
			if (text_after_semicomma == "do" || text_after_semicomma == "then" || prev_text.strip() == "else") {
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
				// skip spaces, comments and backslash
				while (!paren_iter.eol && (paren_iter.char.isspace() || paren_iter.is_in_comment || (paren_iter.is_in_code && paren_iter.char == '\\'))) {
					paren_iter.forward_char ();
				}
				if (paren_iter.line != prev_line || paren_iter.eol || paren_iter.line > prev_line) {
					new_indent = buf.get_indent (paren_iter.line) + unclosed * tab_width;
				} else {
					new_indent = paren_iter.effective_line_offset-1;
				}
			}

			// unindent
			var closed = count_closed (line);
			if (closed > 0) {
				unclosed = count_unclosed (line);
				var paren_iter = unclosed_paren (line, unclosed);
				new_indent = buf.get_indent (paren_iter.line);
				// TODO: fix for nested objects ala javascript/php or C structs
			}

			// done, fi in bash
			// TODO: move to Indent_Shell
			var text = buf.line_text(line).strip ();
			if (text == "done" || text == "fi" || text == "else" || text == "elif") {
				new_indent -= tab_width;
			}

			// prev label or case statement
			if (prev_text.strip().has_suffix (":")) {
				new_indent += tab_width;
			}

			// label or case statement on this line
			if (text.has_suffix (":")) {
				new_indent -= tab_width;
			}

			buf.set_indent (line, new_indent);
		}
	}

	public class Indent_Python : Indent {
		public Indent_Python (Buffer buffer) {
			base (buffer);
		}

		bool is_char (BufferIter iter) {
			if (!iter.is_in_code) {
				return false;
			}
			var cp = iter.copy ();
			cp.backward_char ();
			if (cp.char == '\'') {
				cp = iter.copy ();
				cp.forward_char ();
				if (cp.char == '\'') {
					return true;
				}
			}
			return false;
		}

		bool is_open_paren (BufferIter iter) {
			var c = iter.char;
			return (c == '{' || c == '[' || c == '(') && iter.is_in_code && !is_char (iter);
		}

		bool is_close_paren (BufferIter iter) {
			var c = iter.char;
			return (c == '}' || c == ']' || c == ')') && iter.is_in_code && !is_char (iter);
		}

		// counts closed parens in front of a line
		int count_closed (int line) {
			var buf = buffer;
			var closed = 0;
			var iter = buf.line_start (line);
			while (!iter.eol) {
				var c = iter.char;
				if (is_close_paren (iter)) {
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
			var buf = buffer;
			var unclosed = 0;
			var iter = buf.line_start (line);
			while (!iter.eol) {
				if (is_open_paren (iter)) {
					unclosed++;
				} else if (is_close_paren (iter)) {
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
			var buf = buffer;
			// find line that is semantically opening the paren
			int balance = 0;
			var iter = buf.line_start (line);
			var paren_iter = iter;
			while (true) {
				if (is_open_paren (iter)) {
					balance++;
					if (balance == unbalance) {
						paren_iter = iter.copy ();
					}
				} else if (is_close_paren (iter)) {
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

		public override void indent (BufferIter indent_iter) {
			var buf = buffer;

			var line = indent_iter.line;
			if (line == 0) {
				buf.set_indent (line, 0);
				return;
			}

			var new_indent = 0;
			var tab_width = buf.tab_width;

			var prev_line = first_non_empty_prev_line (line);
			if (prev_line < 0) {
				buf.set_indent (line, 0);
				return;
			}

			var prev_text = buf.line_text(prev_line);

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
				// skip spaces and comments
				while (!paren_iter.eol && (paren_iter.char.isspace() || paren_iter.is_in_comment)) {
					paren_iter.forward_char ();
				}
				if (paren_iter.line != prev_line || paren_iter.eol || paren_iter.line > prev_line) {
					new_indent = buf.get_indent (paren_iter.line) + unclosed * tab_width;
				} else {
					new_indent = paren_iter.effective_line_offset-1;
				}
			}

			// unindent
			var closed = count_closed (line);
			if (closed > 0) {
				unclosed = count_unclosed (line);
				var paren_iter = unclosed_paren (line, unclosed);
				new_indent = buf.get_indent (paren_iter.line);
				// TODO: fix for nested objects ala javascript/php or C structs
			}

			// prev label or case statement
			if (prev_text.strip().has_suffix (":")) {
				new_indent += tab_width;
			}

			buf.set_indent (line, new_indent);
		}
	}

	public class Indent_Markup : Indent {
		public Indent_Markup (Buffer buffer) {
			base (buffer);
		}

		bool is_open_tag (BufferIter iter) {
			if (!iter.is_in_code) {
				return false;
			}
			if (iter.char != '<') {
				return false;
			}
			var cp = iter.copy ();
			cp.forward_char ();
			return cp.is_in_code && cp.char != '!' && cp.char != '/';
		}

		bool is_close_tag (BufferIter iter) {
			if (!iter.is_in_code) {
				return false;
			}

			if (iter.char == '<') {
				var cp = iter.copy ();
				cp.forward_char ();
				return cp.is_in_code && cp.char != '!' && cp.char == '/';
			} else if (iter.char == '/') {
				var cp = iter.copy ();
				cp.forward_char ();
				return cp.is_in_code && cp.char == '>';
			}
			return false;
		}

		// counts closed parens in front of a line
		int count_closed (int line) {
			var buf = buffer;
			var closed = 0;
			var iter = buf.line_start (line);
			while (!iter.eol) {
				var c = iter.char;
				if (is_close_tag (iter)) {
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
			var buf = buffer;
			var unclosed = 0;
			var iter = buf.line_start (line);
			while (!iter.eol) {
				if (is_open_tag (iter)) {
					unclosed++;
				} else if (is_close_tag (iter)) {
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
			var buf = buffer;
			// find line that is semantically opening the paren
			int balance = 0;
			var iter = buf.line_start (line);
			var paren_iter = iter;
			while (true) {
				if (is_open_tag (iter)) {
					balance++;
					if (balance == unbalance) {
						paren_iter = iter.copy ();
					}
				} else if (is_close_tag (iter)) {
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

		public override void indent (BufferIter indent_iter) {
			var buf = buffer;

			var line = indent_iter.line;
			if (line == 0) {
				buf.set_indent (line, 0);
				return;
			}

			var new_indent = 0;
			var tab_width = buf.tab_width;

			var prev_line = first_non_empty_prev_line (line);
			if (prev_line < 0) {
				buf.set_indent (line, 0);
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
				// skip spaces and comments
				while (!paren_iter.eol && (paren_iter.char.isspace() || paren_iter.is_in_comment)) {
					paren_iter.forward_char ();
				}
				if (paren_iter.line != prev_line || paren_iter.eol || paren_iter.line > prev_line) {
					new_indent = buf.get_indent (paren_iter.line) + unclosed * tab_width;
				} else {
					new_indent = paren_iter.effective_line_offset-1;
				}
			}

			// unindent
			var closed = count_closed (line);
			if (closed > 0) {
				unclosed = count_unclosed (line);
				var paren_iter = unclosed_paren (line, unclosed);
				new_indent = buf.get_indent (paren_iter.line);
			}

			buf.set_indent (line, new_indent);
		}
	}

	public class Indent_Asm : Indent {
		public Indent_Asm (Buffer buffer) {
			base (buffer);
		}

		public override void indent (BufferIter indent_iter) {
			var buf = buffer;

			var line = indent_iter.line;

			// indent everything to tab_width except for labels
			var new_indent = buf.tab_width;
			var text = buf.line_text(line);
			if (text.strip().has_suffix (":")) {
				new_indent = 0;
			}

			buf.set_indent (line, new_indent);
		}
	}

	public class Indent_Lua : Indent {
		public Indent_Lua (Buffer buffer) {
			base (buffer);
		}

		bool is_open_paren (BufferIter iter) {
			var c = iter.char;
			return (c == '{' || c == '[' || c == '(') && iter.is_in_code;
		}

		bool is_close_paren (BufferIter iter) {
			var c = iter.char;
			return (c == '}' || c == ']' || c == ')') && iter.is_in_code;
		}

		// counts closed parens in front of a line
		int count_closed (int line) {
			var buf = buffer;
			var closed = 0;
			var iter = buf.line_start (line);
			while (!iter.eol) {
				var c = iter.char;
				if (is_close_paren (iter)) {
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
			var buf = buffer;
			var unclosed = 0;
			var iter = buf.line_start (line);
			while (!iter.eol) {
				if (is_open_paren (iter)) {
					unclosed++;
				} else if (is_close_paren (iter)) {
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
			var buf = buffer;
			// find line that is semantically opening the paren
			int balance = 0;
			var iter = buf.line_start (line);
			var paren_iter = iter;
			while (true) {
				if (is_open_paren (iter)) {
					balance++;
					if (balance == unbalance) {
						paren_iter = iter.copy ();
					}
				} else if (is_close_paren (iter)) {
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

		public override void indent (BufferIter indent_iter) {
			var buf = buffer;

			var line = indent_iter.line;
			if (line == 0) {
				buf.set_indent (line, 0);
				return;
			}

			var new_indent = 0;
			var tab_width = buf.tab_width;

			var prev_line = first_non_empty_prev_line (line);
			if (prev_line < 0) {
				buf.set_indent (line, 0);
				return;
			}

			var prev_indent = buf.get_indent (prev_line);

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
				// skip spaces and comments
				while (!paren_iter.eol && (paren_iter.char.isspace() || paren_iter.is_in_comment)) {
					paren_iter.forward_char ();
				}
				if (paren_iter.line != prev_line || paren_iter.eol || paren_iter.line > prev_line) {
					new_indent = buf.get_indent (paren_iter.line) + unclosed * tab_width;
				} else {
					new_indent = paren_iter.effective_line_offset-1;
				}
			}

			// unindent
			var closed = count_closed (line);
			if (closed > 0) {
				unclosed = count_unclosed (line);
				var paren_iter = unclosed_paren (line, unclosed);
				new_indent = buf.get_indent (paren_iter.line);
				// TODO: fix for nested objects ala javascript/php or C structs
			}

			// lua keywords
			var prev_text = buf.line_text (prev_line).strip ();
			if (prev_text.has_suffix (" do") || prev_text.has_suffix (" then") || prev_text == "else" || prev_text.has_prefix ("function ") || prev_text.has_prefix ("local function ")) {
				new_indent = prev_indent + tab_width;
			}

			// end
			var text = buf.line_text(line).strip ();
			if (text == "end" || text == "else") {
				new_indent -= tab_width;
			}

			buf.set_indent (line, new_indent);
		}
	}

	public class Indent_Haskell : Indent {
		public Indent_Haskell (Buffer buffer) {
			base (buffer);
		}

		bool is_open_paren (BufferIter iter) {
			var c = iter.char;
			return (c == '{' || c == '[' || c == '(') && iter.is_in_code;
		}

		bool is_close_paren (BufferIter iter) {
			var c = iter.char;
			return (c == '}' || c == ']' || c == ')') && iter.is_in_code;
		}

		// counts closed parens in front of a line
		int count_closed (int line) {
			var buf = buffer;
			var closed = 0;
			var iter = buf.line_start (line);
			while (!iter.eol) {
				var c = iter.char;
				if (is_close_paren (iter)) {
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
			var buf = buffer;
			var unclosed = 0;
			var iter = buf.line_start (line);
			while (!iter.eol) {
				if (is_open_paren (iter)) {
					unclosed++;
				} else if (is_close_paren (iter)) {
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
			var buf = buffer;
			// find line that is semantically opening the paren
			int balance = 0;
			var iter = buf.line_start (line);
			var paren_iter = iter;
			while (true) {
				if (is_open_paren (iter)) {
					balance++;
					if (balance == unbalance) {
						paren_iter = iter.copy ();
					}
				} else if (is_close_paren (iter)) {
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

		public override void indent (BufferIter indent_iter) {
			var buf = buffer;

			var line = indent_iter.line;
			if (line == 0) {
				buf.set_indent (line, 0);
				return;
			}

			var new_indent = 0;
			var tab_width = buf.tab_width;

			var prev_line = first_non_empty_prev_line (line);
			if (prev_line < 0) {
				buf.set_indent (line, 0);
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
				// skip spaces and comments
				while (!paren_iter.eol && (paren_iter.char.isspace() || paren_iter.is_in_comment)) {
					paren_iter.forward_char ();
				}
				if (paren_iter.line != prev_line || paren_iter.eol || paren_iter.line > prev_line) {
					new_indent = buf.get_indent (paren_iter.line) + unclosed * tab_width;
				} else {
					new_indent = paren_iter.effective_line_offset-1;
				}
			}

			// unindent
			var closed = count_closed (line);
			if (closed > 0) {
				unclosed = count_unclosed (line);
				var paren_iter = unclosed_paren (line, unclosed);
				new_indent = buf.get_indent (paren_iter.line);
				// TODO: fix for nested objects ala javascript/php or C structs
			}

			// haskell keywords
			var prev_text = buf.line_text (prev_line).strip ();
			if (/(^|\W)(=|do|let|where|of)$/.match (prev_text)) {
				new_indent += tab_width;
			} else {
				// find the first expression starting from the right
				var idx = int.max (prev_text.last_index_of ("do"),
								   int.max (prev_text.last_index_of ("let"),
											int.max (prev_text.last_index_of ("where"),
													 prev_text.last_index_of ("of"))));
				if (idx >= 0) {
					while (prev_text[idx++].isalpha()); // skip keyword
					var len = prev_text.length;
					while (idx < len && prev_text[idx].isspace ()) idx++;

					var iter = buf.line_at_byte (prev_line, idx);
					new_indent = iter.effective_line_offset;
				}
			}

			var cur_text = buf.line_text (line).strip ();
			if (cur_text.has_prefix ("deriving ")) {
				new_indent += tab_width;
			}

			buf.set_indent (line, new_indent);
		}
	}
}
