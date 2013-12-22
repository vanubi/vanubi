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
		Gtk.SourceView view;

		public Buffer (Gtk.SourceView view) {
			this.view = view;
		}

		public string text {
			owned get {
				return buf.text;
			}
		}

		public Gtk.TextBuffer buf {
			get {
				return view.buffer;
			}
		}

		public override int tab_width {
			get {
				return (int) view.tab_width;
			}
			set {
				view.tab_width = value;
			}
		}

		public override string line_text (int line) {
			Gtk.TextIter start;
			buf.get_iter_at_line (out start, line);
			var end = start;
			end.forward_to_line_end ();
			if (line != end.get_line ()) {
				return "";
			}
			return buf.get_text (start, end, false);
		}

		public override Vanubi.BufferIter line_start (int line) {
			Gtk.TextIter iter;
			buf.get_iter_at_line (out iter, line);		
			return new BufferIter (this, iter);
		}

		public override Vanubi.BufferIter line_end (int line) {
			Gtk.TextIter iter;
			buf.get_iter_at_line (out iter, line);		
			iter.forward_to_line_end ();
			return new BufferIter (this, iter);
		}
		
		public override Vanubi.BufferIter line_at_offset (int line, int line_offset) {
			Gtk.TextIter iter;
			buf.get_iter_at_line_offset (out iter, line, line_offset);
			return new BufferIter (this, iter);
		}

		// only on a single line
		public override void insert (Vanubi.BufferIter iter, string text) {
			buf.insert (ref ((BufferIter) iter).iter, text, -1);
		}

		// only on a single line
		public override void delete (Vanubi.BufferIter start, Vanubi.BufferIter end) {
			buf.delete (ref ((BufferIter) start).iter, ref ((BufferIter) end).iter);
		}

		public override void set_indent (int line, int indent) {
			indent = int.max (indent, 0);
			var cur_indent = get_indent (line);
			if (cur_indent == indent) {
				// avoid adding unfriendly undo actions, however move the cursor
				Gtk.TextIter insert_iter;
				buf.get_iter_at_mark (out insert_iter, buf.get_insert ());
				if (insert_iter.get_line_offset () < indent) {
					var viter = new BufferIter (this, insert_iter);
					while (viter.effective_line_offset <= indent) {
						viter.forward_char ();
					}
					buf.place_cursor (viter.iter);
				}
				return;
			}
			buf.begin_user_action ();
			base.set_indent (line, indent);
			buf.end_user_action ();
		}
	}

	public class BufferIter : Vanubi.BufferIter {
		internal Gtk.TextIter iter;

		public BufferIter (Vanubi.Buffer buf, Gtk.TextIter iter) {
			base (buf);
			this.iter = iter;
		}

		public override Vanubi.BufferIter forward_char () {
			iter.forward_char ();
			return this;
		}

		public override Vanubi.BufferIter backward_char () {
			iter.backward_char ();
			return this;
		}

		public override bool is_in_code {
			get {
				var buf = (Gtk.SourceBuffer) iter.get_buffer ();
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

		public override bool sol {
			get {
				return iter.starts_line ();
			}
		}

		public override unichar char {
			get {
				return iter.get_char ();
			}
		}

		public override Vanubi.BufferIter copy () {
			var it = new BufferIter (buffer, iter);
			return it;
		}
	}
}
