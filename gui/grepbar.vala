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

namespace Vanubi.UI {
	public class GrepView : SourceView {
		public GrepView (Configuration conf) {
			Object (buffer: new GrepBuffer ());
			var style_manager = SourceStyleSchemeManager.get_default ();
			// try a specific style for grep first
			var st = style_manager.get_scheme (conf.get_global_string ("theme", "zen")+"-grep");
			if (st == null) {
				style_manager.get_scheme (conf.get_global_string ("theme", "zen"));
			}
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
									if (((string)converted).length != converted.length) message("asd");
									insert_text (ref end, (string) converted, converted.length);
									// apply tags
									TextIter start;
									get_iter_at_offset (out start, offset);
									foreach (unowned TextTag tag in tags) {
										apply_tag (tag, start, end);
									}
								} catch (IOError.CANCELLED e) {
									return null;
								} catch (Error e) {
								} finally {
									Gdk.threads_leave ();
								}
							}
							
							// parse command
							i++; // [
							i++;
							if (i < new_text_length && new_text[i] == 'm') {
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
									if (i < new_text_length && new_text[i] == ';') {
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
		DataSource base_source;
		
		public GrepBar (Manager manager, Configuration conf, DataSource base_source, string default = "") {
			base (default);
			this.manager = manager;
			this.base_source = base_source;
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

		public Location? get_location_at_line (int lineiter) {
			TextIter start, end;
			view.buffer.get_iter_at_line (out start, lineiter);
			end = start;
			end.forward_to_line_end ();
			var line = view.buffer.get_text (start, end, false);
			if (line == null || line.strip() == "") {
				return null;
			}
			var data = line.strip().split(":");
			if (data.length < 2) {
				return null;
			}
			
			var filename = data[0];
			var lineno = int.parse (data[1]) - 1;

			return new Location (base_source.child (filename), lineno);
		}
		
		protected override void on_activate () {
			TextIter insert;
			view.buffer.get_iter_at_mark (out insert, view.buffer.get_insert ());
			location = get_location_at_line (insert.get_line ());
			
			base.on_activate ();
		}
		
		protected override bool on_key_press_event (Gdk.EventKey e) {
			TextIter insert;
			view.buffer.get_iter_at_mark (out insert, view.buffer.get_insert ());

			if (Gdk.ModifierType.MOD1_MASK in e.state) {
				// ALT+key used for history
				return base.on_key_press_event (e);
			}
			
			switch (e.keyval) {
			case Gdk.Key.Up:
				if (Gdk.ModifierType.CONTROL_MASK in e.state) {
					var loc = get_location_at_line (insert.get_line ());
					string curfile = loc != null ? loc.source.to_string () : null;
					while (insert.backward_line ()) {
						loc = get_location_at_line (insert.get_line ());
						if (loc != null && loc.source.to_string () != curfile) {
							break;
						}
					}
				} else {
					insert.backward_line ();
				}

				view.buffer.place_cursor (insert);
				view.scroll_mark_onscreen (view.buffer.get_insert ());
				return true;
				
			case Gdk.Key.Down:
				if (Gdk.ModifierType.CONTROL_MASK in e.state) {
					var loc = get_location_at_line (insert.get_line ());
					string curfile = loc != null ? loc.source.to_string () : null;
					while (insert.forward_line ()) {
						loc = get_location_at_line (insert.get_line ());
						if (loc != null && loc.source.to_string () != curfile) {
							break;
						}
					}
				} else {
					insert.forward_line ();
				}
				
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
			var buf = view.buffer;
			TextIter cursor;
			buf.get_iter_at_mark (out cursor, buf.get_insert ());
			var cursor_offset = cursor.get_offset ();
			
			try {
				uint8[] buffer = new uint8[1025];
				buffer.length--; // trailing zero
				while (true) {
					manager.set_status ("Searching...", "grep");
					var read = yield stream.read_async (buffer, Priority.DEFAULT, cancellable);
					if (read == 0) {
						break;
					}

					// keep the cursor at the beginning, or honor any user movement
					var old_offset = cursor_offset;
					buf.get_iter_at_mark (out cursor, buf.get_insert ());
					cursor_offset = old_offset;
					TextIter iter;
					buf.get_end_iter (out iter);
					
					if (iter.equal (cursor)) {
						// reset cursor
						buf.get_iter_at_offset (out cursor, old_offset);
						buf.place_cursor (cursor);
					}
					
					// write
					cancellable.set_error_if_cancelled ();
					buffer[read] = '\0';
					yield ((GrepBuffer) buf).insert_text_colored (iter, (string) buffer, (int) read, cancellable);
					cancellable.set_error_if_cancelled ();
				}
				
				// delete the last line if it's empty
				TextIter start_iter, end_iter;
				buf.get_end_iter (out end_iter);
				buf.get_iter_at_line (out start_iter, end_iter.get_line ());
				var text = buf.get_text (start_iter, end_iter, false);
				if (text.strip () == "") {
					start_iter.backward_char ();
					buf.delete (ref start_iter, ref end_iter);
				}
			} catch (Error e) {
			} finally {
				manager.clear_status ("grep");
			}
		}
	}
}
