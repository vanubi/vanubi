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

using Vte;
using Gtk;

namespace Vanubi {
	public class GrepView : SourceView {
		public GrepView (Configuration conf) {
			Object (buffer: new GrepBuffer ());
			var sm = new SourceStyleSchemeManager();
			sm.set_search_path({absolute_path("", "~/.vanubi/styles/"), "./data/styles/"});
			var st = sm.get_scheme (conf.get_editor_string ("style", "zen"));
			if (st != null) { /* Use default if not found */
				((SourceBuffer) buffer).set_style_scheme (st);
			}
			highlight_current_line = true;
		}
	}
	
	public class GrepBuffer : SourceBuffer {
		TextTag[] attrs = null;
		
		construct {
			attrs = new TextTag[50];
			attrs[30] = create_tag ("fg_black", foreground: "black");
			attrs[31] = create_tag ("fg_red", foreground: "red");
			attrs[32] = create_tag ("fg_green", foreground: "green");
			attrs[33] = create_tag ("fg_yellow", foreground: "yellow");
			attrs[34] = create_tag ("fg_blue", foreground: "blue");
			attrs[35] = create_tag ("fg_magenta", foreground: "magenta");
			attrs[36] = create_tag ("fg_cyan", foreground: "cyan");
			attrs[37] = create_tag ("fg_white", foreground: "white");
			
			attrs[40] = create_tag ("bg_black", background: "black");
			attrs[41] = create_tag ("bg_red", background: "red");
			attrs[42] = create_tag ("bg_green", background: "green");
			attrs[43] = create_tag ("bg_yellow", background: "yellow");
			attrs[44] = create_tag ("bg_blue", background: "blue");
			attrs[45] = create_tag ("bg_magenta", background: "magenta");
			attrs[46] = create_tag ("bg_cyan", background: "cyan");
			attrs[47] = create_tag ("bg_white", background: "white");
		}
		
		public async void insert_text_colored (Gtk.TextIter pos, string new_text, int new_text_length, Cancellable? cancellable) {
			yield run_in_thread<void*> (() => {
					TextTag[] tags = null;
					int last_start = 0;
					for (var i=0; i < new_text_length; i++) {
						// escape char
						if (new_text[i] == 0x1b) {
							// write last string with tags
							unowned string cur = new_text.offset (last_start);
							Gdk.threads_enter ();
							TextIter end;
							get_end_iter (out end);
							var offset = end.get_offset ();
							insert_text (ref end, cur, i-last_start);
							// apply tags
							TextIter start;
							get_iter_at_offset (out start, offset);
							foreach (unowned TextTag tag in tags) {
								apply_tag (tag, start, end);
							}
							Gdk.threads_leave ();
							
							// parse command
							i++; // [
							i++;
							if (new_text[i] == 'm') {
								tags.length = 0;
								last_start = i+1;
							} else {
								while (i < new_text_length && new_text[i] != 'm') {
									cur = new_text.offset (i);
									var attr = int.parse (cur);
									if ((attr >= 30 && attr <= 37) || (attr >= 40 && attr <= 47)) {
										tags += attrs[attr];
									}
									// next attribute
									while (++i < new_text_length && new_text[i] != ';' && new_text[i] != 'm');
									if (new_text[i] == ';') {
										i++;
									}
								}
								last_start = i+1;
							}
						}
					}
					return null;
			});
		}
	}
	
	public class GrepBar : EntryBar {
		public Location location { get; private set; }
		public InputStream stream {
			set {
				view.buffer.set_text ("");
				read_stream.begin (value);
			}
		}
		
		TextView view;
		ScrolledWindow sw;
		
		public GrepBar (Configuration conf) {
			entry.expand = false;
			view = new GrepView (conf);
			view.editable = false;
			view.key_press_event.connect (on_key_press_event);
			sw = new ScrolledWindow (null, null);
			sw.expand = true;
			sw.add (view);
			sw.show_all ();
			attach_next_to (sw, entry, PositionType.TOP, 1, 1);
		}

		protected override void on_activate () {
			TextIter insert, start, end;
			view.buffer.get_iter_at_mark (out insert, view.buffer.get_insert ());
			view.buffer.get_iter_at_line (out start, insert.get_line ());
			end = start;
			end.forward_to_line_end ();
			var line = view.buffer.get_text (start, end, false);
			if (line == null || line.strip() == "") {
				return;
			}
			var data = line.strip().split(":");
			if (data.length < 2) {
				return;
			}
			
			var filename = data[0];
			var lineno = int.parse (data[1]) - 1;
			location = new Location (File.new_for_path (filename), lineno);
			
			base.on_activate ();
		}
		
		protected override bool on_key_press_event (Gdk.EventKey e) {
			TextIter insert;
			view.buffer.get_iter_at_mark (out insert, view.buffer.get_insert ());
			switch (e.keyval) {
			case Gdk.Key.Up:
				insert.backward_line ();
				view.buffer.place_cursor (insert);
				view.scroll_mark_onscreen (view.buffer.get_insert ());
				return true;
			case Gdk.Key.Down:
				insert.forward_line ();
				view.buffer.place_cursor (insert);
				view.scroll_mark_onscreen (view.buffer.get_insert ());
				return true;
			case Gdk.Key.Page_Down:
			case Gdk.Key.Page_Up:		
				var pos = entry.cursor_position;
				var res = sw.key_press_event (e);
				view.place_cursor_onscreen ();
				entry.grab_focus ();
				entry.set_position (pos);
				return res;
			}
			return base.on_key_press_event (e);
		}
		
		public async void read_stream (InputStream stream) {
			try {
				uint8[] buffer = new uint8[1024];
				while (true) {
					var read = yield stream.read_async (buffer);
					if (read == 0) {
						break;
					}
					// save current cursor position
					TextIter insert;
					view.buffer.get_iter_at_mark (out insert, view.buffer.get_insert ());
					int offset = insert.get_offset ();
					// write
					TextIter iter;
					view.buffer.get_end_iter (out iter);
					yield ((GrepBuffer) view.buffer).insert_text_colored (iter, (string) buffer, (int) read, null);
					// restore cursor position
					view.buffer.get_iter_at_offset (out insert, offset);
					view.buffer.place_cursor (insert);
				}
			} catch (Error e) {
			}
		}
	}
}
