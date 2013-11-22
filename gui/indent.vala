/*
 *  Copyright © 2013 Luca Bruno
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

namespace Vanubi.UI {
	/*****************
	 * GTK BUFFER
	 *****************/

	public class Buffer : Vanubi.Buffer {
		Gtk.TextBuffer buf;

		public Buffer (Gtk.TextBuffer buf) {
			this.buf = buf;
		}

		public string text {
			owned get {
				return buf.text;
			}
		}

		public override string line_text (int line) {
			Gtk.TextIter start;
			buf.get_iter_at_line (out start, line);
			start.forward_to_line_end ();
			return buf.get_text (start, end);
		}

		public override BufferIter line_start (int line) {
			Gtk.TextIter iter;
			buf.get_iter_at_line (out iter, line);		
			return new GUIBufferIter (iter);
		}

		public override BufferIter line_end (int line) {
			Gtk.TextIter iter;
			buf.get_iter_at_line (out iter, line);		
			iter.forward_to_line_end ();
			return new StringBufferIter (iter);
		}

		// only on a single line
		public override void insert (BufferIter iter, string text) {
			buf.insert (iter.iter, text, -1);
		}

		// only on a single line
		public override void delete (BufferIter start, BufferIter end) {
			buf.delete (start.iter, end.iter);
		}

		public override void begin_undo_action () {
			buf.begin_user_action ();
		}

		public override void end_undo_action () {
			buf.end_user_action ();
		}
	}

	public class BufferIter : Vanubi.BufferIter {
		Gtk.TextIter iter;

		public BufferIter (Gtk.TextIter iter) {
			this.iter = iter;
		}

		public override void forward_char () {
			iter.forward_char ();
		}

		public override void backward_char () {
			iter.backward_char ();
		}

		public override bool is_in_code {
			get {
				var buf = (SourceBuffer) iter.get_buffer ();
				var classes = buf.get_context_classes_at_iter (iter);
				foreach (var cls in classes) {
					if (cls == "comment" || cls == "string") {
						return false;
					}
				}
				return true;
			}
		}

		public override int line_offset {
			get {
				return iter.get_line_offset ();
			}
		}

		public override int line {
			get {
				return iter.get_line ();
			}
		}

		public override bool eol {
			get {
				return iter.ends_line ();
			}
		}

		public override unichar char {
			get {
				return iter.get_char ();
			}
		}

		public override BufferIter copy () {
			var it = new BufferIter (iter);
			return it;
		}
	}
}
