/*
 *  Copyright © 2014 Luca Bruno
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
			sm.set_search_path (get_styles_search_path ());
			var st = sm.get_scheme (conf.get_editor_string ("style", "zen-grep"));
		
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
		
		public async void insert_text_colored (Gtk.TextIter pos, string new_text, int new_text_length, Cancellable cancellable) throws Error {
			yield run_in_thread<void*> (() => {
					TextTag[] tags = null;
					int last_start = 0;
					string? default_charset = null;
					for (var i=0; i < new_text_length; i++) {
						// escape char
						if (new_text[i] == 0x1b) {
							if (i > last_start) {
								// write last string with tags
								string cur = new_text.substring (last_start, i-last_start);
								uint8[] converted = convert_to_utf8 (cur.data, ref default_charset, null, null);

								Gdk.threads_enter ();
								try {
									cancellable.set_error_if_cancelled ();
									TextIter end;
									get_end_iter (out end);
									var offset = end.get_offset ();
									insert_text (ref end, (string) converted, converted.length);
									// apply tags
									TextIter start;
									get_iter_at_offset (out start, offset);
									foreach (unowned TextTag tag in tags) {
										apply_tag (tag, start, end);
									}
								} catch (Error e) {
								} finally {
									Gdk.threads_leave ();
								}
							}
							
							// parse command
							i++; // [
							i++;
							if (new_text[i] == 'm') {
								tags.length = 0;
								last_start = i+1;
							} else {
								while (i < new_text_length && new_text[i] != 'm') {
									unowned string cur = new_text.offset (i);
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
						} else if (new_text[i] == '\n') {
							// reset default charset for each file
							default_charset = null;
						}
					}
					
					// write remaining text
					if (last_start < new_text_length) {
						string cur = new_text.substring (last_start, new_text_length-last_start);
						uint8[] converted = convert_to_utf8 (cur.data, ref default_charset, null, null);

						Gdk.threads_enter ();
						try {
							cancellable.set_error_if_cancelled ();
							TextIter end;
							get_end_iter (out end);
							var offset = end.get_offset ();
							insert_text (ref end, (string) converted, converted.length);
							// apply tags
							TextIter start;
							get_iter_at_offset (out start, offset);
							foreach (unowned TextTag tag in tags) {
								apply_tag (tag, start, end);
							}
						} catch (Error e) {
						} finally {
							Gdk.threads_leave ();
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
				if (cancellable != null) {
					cancellable.cancel ();
				}
				cancellable = new Cancellable ();
				view.buffer.set_text ("");
				read_stream.begin (value, cancellable);
			}
		}
		
		unowned Manager manager;
		TextView view;
		ScrolledWindow sw;
		Cancellable cancellable;
		File base_path;
		
		public GrepBar (Manager manager, Configuration conf, File base_path, string default = "") {
			base (default);
			this.manager = manager;
			this.base_path = base_path;
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

		public override void dispose () {
			if (cancellable != null) {
				cancellable.cancel ();
			}
			base.dispose ();
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
			location = new Location (File.new_for_path (base_path.get_path()+"/"+filename), lineno);
			
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
		
		public async void read_stream (InputStream stream, Cancellable cancellable) {
			try {
				uint8[] buffer = new uint8[1024];
				bool first_load = true;
				while (true) {
					manager.set_status ("Searching...", "grep");
					ssize_t read;
					if (first_load) { // first loads sync
						read = stream.read (buffer, cancellable);
					} else {
						read = yield stream.read_async (buffer, Priority.DEFAULT, cancellable);
					}
					if (read == 0) {
						break;
					}
					
					// write
					TextIter iter;
					view.buffer.get_end_iter (out iter);
					cancellable.set_error_if_cancelled ();
					yield ((GrepBuffer) view.buffer).insert_text_colored (iter, (string) buffer, (int) read, cancellable);
					cancellable.set_error_if_cancelled ();
					
					// restore cursor position
					if (first_load) {
						first_load = false;
						view.buffer.get_start_iter (out iter);
						view.buffer.place_cursor (iter);
					}
				}
				
				// delete the last line if it's empty
				TextIter start_iter, end_iter;
				view.buffer.get_end_iter (out end_iter);
				view.buffer.get_iter_at_line (out start_iter, end_iter.get_line ());
				var text = view.buffer.get_text (start_iter, end_iter, false);
				if (text.strip () == "") {
					start_iter.backward_char ();
					view.buffer.delete (ref start_iter, ref end_iter);
				}
			} catch (Error e) {
			} finally {
				manager.clear_status ("grep");
			}
		}
	}
}
