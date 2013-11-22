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

using Gtk;

namespace Vanubi {
	public class EditorView : SourceView {
#if 0
		TextTag caret_text_tag;
		int caret_offset = 0;
#endif

		construct {
			tab_width = 4;
			buffer = new SourceBuffer (null);
			buffer.mark_set.connect (update_caret_position);
			buffer.changed.connect (update_caret_position);
#if 0
			caret_text_tag = buffer.create_tag ("caret_text", foreground: "black");
			((SourceBuffer) buffer).highlight_matching_brackets = true;
			get_settings().gtk_cursor_blink = false;
#endif
		}

		void update_caret_position () {
#if 0
			// remove previous tag
			TextIter start;
			buffer.get_iter_at_offset (out start, caret_offset);
			var end = start;
			end.forward_char ();
			buffer.remove_tag (caret_text_tag, start, end);

			buffer.get_iter_at_mark (out start, buffer.get_insert ());
			caret_offset = start.get_offset ();
			end = start;
			end.forward_char ();
			// change the color of the text
			buffer.apply_tag (caret_text_tag, start, end);
#endif
		}

#if 0
		public override bool draw (Cairo.Context cr) {
			var buffer = this.buffer;
			TextIter it;
			// get the location of the caret
			buffer.get_iter_at_mark (out it, buffer.get_insert ());
			Gdk.Rectangle rect;
			get_iter_location (it, out rect);
			int x, y;
			// convert location to view coords
			buffer_to_window_coords (TextWindowType.TEXT, rect.x, rect.y, out x, out y);
			// now get the size of a generic character, assuming it's monospace
			var layout = create_pango_layout ("X");
			Pango.Rectangle extents;
			layout.get_extents (null, out extents);
			int width = extents.width / Pango.SCALE;
			int height = extents.height / Pango.SCALE;
			// now x,y,width,height is the cursor rectangle

			// first draw the code
			base.draw (cr);

			// now draw the big caret
			cr.set_source_rgba (1, 1, 1, 1.0); // white caret
			cr.rectangle (x, y, width+1, height);
			cr.fill ();

			// make any selection be transparent
			var ctx = get_style_context();
			ctx.save ();
			ctx.add_class ("caret");
			// now redraw the code clipped to the new caret, exluding the old caret
			cr.rectangle (x+1, y, width-1, height); // don't render the original cursor
			cr.clip ();
			base.draw (cr);
			// revert
			ctx.restore ();

			return false;
		}
#endif
	}

	public class Editor : Grid {
		public File file { get; private set; }
		public SourceView view { get; private set; }
		public SourceStyleSchemeManager editor_style { get; private set; }
		ScrolledWindow sw;
		Label file_count;
		Label file_status;

		public Editor (File? file) {
			this.file = file;
			orientation = Orientation.VERTICAL;
			expand = true;

			/* Style */
			editor_style = new SourceStyleSchemeManager();
			editor_style.set_search_path({"./styles/"}); /* TODO: use ~/.vanubi/styles/ */

			// view
			view = new EditorView ();
			view.wrap_mode = WrapMode.CHAR;
			view.set_data ("editor", (Editor*)this);
                        
			/* TODO: read the style from the config file */
			SourceStyleScheme st = editor_style.get_scheme("zen");
			if (st != null) { /* Use default if not found */
				((SourceBuffer)view.buffer).set_style_scheme(st);
			}

			// scrolled window
			sw = new ScrolledWindow (null, null);
			sw.expand = true;
			sw.add (view);
			add (sw);

			// lower information bar
			var infobar = new EditorInfoBar ();
			infobar.expand = false;
			infobar.orientation = Orientation.HORIZONTAL;
			// initially not focused
			infobar.get_style_context().add_class ("nonfocused"); 
			add (infobar);

			var file_label = new Label (get_editor_name ());
			file_label.set_ellipsize(Pango.EllipsizeMode.MIDDLE);
			file_label.margin_left = 20;
			file_label.get_style_context().add_class("filename");
			infobar.add (file_label);

			file_count = new Label ("(0, 0)");
			file_count.margin_left = 20;
			infobar.add (file_count);

			file_status = new Label ("");
			file_status.margin_left = 20;
			infobar.add (file_status);

			view.notify["buffer"].connect_after (on_buffer_changed);
			on_buffer_changed ();

			view.focus_in_event.connect(() => { 
					infobar.get_style_context().remove_class ("nonfocused");
					infobar.reset_style (); // GTK+ 3.4 bug, solved in 3.6
					return false;
				});

			view.focus_out_event.connect(() => { 
					infobar.get_style_context().add_class ("nonfocused");
					infobar.reset_style (); // GTK+ 3.4 bug, solved in 3.6
					return false;
				});
		}

		public override void grab_focus () {
			view.grab_focus ();
		}

		public string get_editor_name () {
			if (file == null) {
				return "*scratch*";
			} else {
				return file.get_path();
			}
		}

		/**
		 * Returns true if the iter is neither a string nor a comment
		 */
		public bool is_in_code (TextIter iter) {
			var buf = (SourceBuffer) view.buffer;
			var classes = buf.get_context_classes_at_iter (iter);
			foreach (var cls in classes) {
				if (cls == "comment" || cls == "string") {
					return false;
				}
			}
			return true;
		}

		public string get_line_text (int line) {
			TextIter line_start;
			var buf = view.buffer;
			buf.get_iter_at_line (out line_start, line);
			TextIter line_end = line_start;
			line_end.forward_to_line_end ();
			string text = buf.get_text (line_start, line_end, false);
			return text;
		}

		public void set_line_indentation (int line, int indent) {
			indent = int.max (indent, 0);

			TextIter start;
			var buf = view.buffer;
			buf.get_iter_at_line (out start, line);

			var iter = start;
			while (iter.get_char().isspace() && !iter.ends_line () && !iter.is_end ()) {
				iter.forward_char ();
			}

			buf.begin_user_action ();
			buf.delete (ref start, ref iter);
			var tab_width = view.tab_width;
			// mixed tab + spaces, TODO: handle SourceView.insert_spaces_instead_of_tabs
			buf.insert (ref start, string.nfill(indent/tab_width, '\t')+string.nfill(indent-(indent/tab_width)*tab_width, ' '), -1);

			// reset cursor, textbuffer bug?
			buf.get_iter_at_mark (out iter, buf.get_insert ());
			buf.place_cursor (iter);
			buf.end_user_action ();
		}

		public int get_line_indentation (int line) {
			var tab_width = view.tab_width;
			uint indent = 0;

			TextIter iter;
			var buf = view.buffer;
			buf.get_iter_at_line (out iter, line);

			while (iter.get_char().isspace () && !iter.ends_line ()) {
				if (iter.get_char() == '\t') {
					indent += tab_width;
				} else {
					indent++;
				}
				iter.forward_char ();
			}
			return (int) indent;
		}

		/**
		 * Considers tabs as tab-width spaces.
		 */
		public int get_effective_line_offset (TextIter iter) {
			uint off = 0;
			while (true) {
				if (iter.get_char() == '\t') {
					off += view.tab_width;
				} else {
					off++;
				}
				if (iter.starts_line ()) {
					break;
				}
				iter.backward_char ();
			}
			return (int) off - 1; // -1 because we refer to the start of the character
		}

		/* events */

		void on_buffer_changed () {
			var buf = (SourceBuffer) view.buffer;
			buf.mark_set.connect (on_file_count);
			buf.changed.connect (on_file_count);
			buf.modified_changed.connect (on_modified_changed);
			on_file_count ();
		}

		void on_file_count () {
			TextIter insert;
			var buf = view.buffer;
			buf.get_iter_at_mark (out insert, buf.get_insert ());
			int line = insert.get_line ();
			TextIter iter;
			buf.get_iter_at_line (out iter, line);
			int column = 0;
			while (!iter.equal (insert)) {
				if (iter.get_char () == '\t') {
					column += (int) view.tab_width;
				} else {
					column++;
				}
				iter.forward_char ();
			}

			file_count.set_label ("(%d, %d)".printf (line+1, column+1));
		}

		void on_modified_changed () {
			var buf = view.buffer;
			file_status.set_label (buf.get_modified () ? "modified" : "");
		}
	}
}
