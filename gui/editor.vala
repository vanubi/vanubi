/*
 *  Copyright © 2011-2014 Luca Bruno
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

namespace Vanubi.UI {
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

	public class EditorContainer : EventBox {
		public FileLRU lru = new FileLRU ();
		
		public Editor editor {
			get {
				return (Editor) get_child ();
			}
			set {
				add (value);
			}
		}
		
		public EditorContainer (Editor? ed) {
			editor = ed;
		}

		public override void grab_focus () {
			editor.grab_focus ();
		}

		public override void remove (Widget w) {
			if (editor != null) {
				lru.used (editor.file);
			}
			base.remove (w);
		}
		
		/* Get files in lru order */
		public File[] get_files () {
			File[] res = null;
			foreach (var file in lru.list ()) {
				res += file;
			}
			return res;
		}
	}
	
	public class Editor : Grid {
		public weak Manager manager;
		Configuration conf;
		public File file { get; private set; }
		public SourceView view { get; private set; }
		public SourceStyleSchemeManager editor_style { get; private set; }
		ScrolledWindow sw;
		Label file_count;
		Label file_status;
		Label file_external_changed;
		Label git_branch;
		Label file_loading;
		EditorInfoBar infobar;
		int old_selection_start_offset = -1;
		int old_selection_end_offset = -1;
		FileMonitor monitor;
		SourceGutter? gutter = null;
		GitGutterRenderer? gutter_renderer = null;
		bool file_loaded = false;
		Cancellable diff_cancellable = null;
		uint diff_timer = 0;
		uint save_session_timer = 0;
		Git git;
		
		public Editor (Manager manager, Configuration conf, File? file) {
			this.manager = manager;
			this.file = file;
			this.conf = conf;
			orientation = Orientation.VERTICAL;
			expand = true;

			git = new Git (conf);
			
			/* Style */
			editor_style = new SourceStyleSchemeManager();
			editor_style.set_search_path (get_styles_search_path ());

			// view
			view = new EditorView ();
			view.wrap_mode = WrapMode.CHAR;
			view.set_data ("editor", (Editor*)this);
			view.tab_width = conf.get_editor_int("tab_width", 4);
			view.highlight_current_line = conf.get_editor_bool ("highlight_current_line", true);
			update_right_margin ();

			SourceStyleScheme st = editor_style.get_scheme(conf.get_editor_string ("style", "zen"));
			if (st != null) { /* Use default if not found */
					  ((SourceBuffer)view.buffer).set_style_scheme(st);
			}

			// scrolled window
			sw = new ScrolledWindow (null, null);
			sw.expand = true;
			sw.add (view);
			add (sw);
			
			on_git_gutter ();
			
			// lower information bar
			infobar = new EditorInfoBar ();
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
			
			git_branch = new Label ("");
			infobar.add (git_branch);
			
			file_external_changed = new Label ("");
			file_external_changed.margin_left = 20;
			infobar.add (file_external_changed);
			
			file_loading = new Label ("");
			file_loading.margin_left = 20;
			infobar.add (file_loading);
			
			view.notify["buffer"].connect_after (on_buffer_changed);
			on_buffer_changed ();

			view.focus_in_event.connect(() => { 
					manager.last_focused_editor = this;
					if (old_selection_start_offset >= 0 && old_selection_end_offset >= 0) {
						TextIter start, end;
						view.buffer.get_iter_at_offset (out start, old_selection_start_offset);
						view.buffer.get_iter_at_offset (out end, old_selection_end_offset);
						view.buffer.select_range (start, end);
					}
					infobar.get_style_context().remove_class ("nonfocused");
					infobar.reset_style (); // GTK+ 3.4 bug, solved in 3.6
					return false;
			});

			view.focus_out_event.connect(() => {
					update_old_selection ();
					infobar.get_style_context().add_class ("nonfocused");
					infobar.reset_style (); // GTK+ 3.4 bug, solved in 3.6
					return false;
			});
			
			restart_monitor ();
		}

		void restart_monitor () {
			if (monitor != null) {
				monitor.changed.disconnect (on_external_changed);
				monitor = null;
			}
			if (file != null) {
				/* XXX: use FileMonitorFlags.WATCH_HARD_LINKS with valac >= 0.20.2 */
				file.set_data<TimeVal?> ("editing_mtime", get_mtime ());
				try {
					monitor = file.monitor (FileMonitorFlags.NONE);
					monitor.changed.connect (on_external_changed);
				} catch (Error e) {
					manager.set_status_error (e.message);
				}
			}
		}
		
		public TimeVal? get_mtime () {
			if (file != null && file.query_exists ()) {
				try {
					var info = file.query_info (FileAttribute.TIME_MODIFIED, FileQueryInfoFlags.NONE);
					return info.get_modification_time ();
				} catch (Error e) {
					return null;
				}
			}
			return null;
		}
		
		public void update_old_selection () {
			TextIter old_selection_start, old_selection_end;
			view.buffer.get_selection_bounds (out old_selection_start,
							  out old_selection_end);
			old_selection_start_offset = old_selection_start.get_offset ();
			old_selection_end_offset = old_selection_end.get_offset ();
		}

		public bool is_externally_changed () {
			return file_external_changed.label != "";
		}
		
		public void reset_external_changed () {
			file_external_changed.set_label ("");
			file.set_data<TimeVal?> ("editing_mtime", get_mtime ());
			restart_monitor ();
		}
		
		public override void grab_focus () {
			view.grab_focus ();
			manager.save_session (this); // changed focused 
			manager.last_focused_editor = this;
		}

		public string get_editor_name () {
			if (file == null) {
				return "*scratch*";
			} else {
				return file.get_path();
			}
		}

		public EditorContainer editor_container {
			get {
				return get_parent() as EditorContainer;
			}
		}

		public void reset_language () {
			bool uncertain;
			var content_type = ContentType.guess (file.get_path (), null, out uncertain);
			if (uncertain) {
				content_type = null;
			}
			var default_lang = SourceLanguageManager.get_default().guess_language (file.get_path (), content_type);
			var lang_id = conf.get_file_string (file, "language", default_lang != null ? default_lang.id : null);
			if (lang_id != null) {
				var lang = SourceLanguageManager.get_default().get_language (lang_id);
				((SourceBuffer) view.buffer).set_language (lang);
			}
		}

		public Location get_location () {
			TextIter iter;
			view.buffer.get_iter_at_mark (out iter, view.buffer.get_insert ());
			var loc = new Location (file,
						iter.get_line (),
						iter.get_line_offset ());
			return loc;
		}
		
		// Returns true if location changed
		public bool set_location (Location location) {
			// set specific location
			var buf = view.buffer;

			TextIter start_iter;
			if (location.start_line >= 0) {
				var mark = get_start_mark_for_location (location, buf);
				buf.get_iter_at_mark (out start_iter, mark);
			} else {
				return false;
			}

			TextIter end_iter;
			var mark = get_end_mark_for_location (location, buf);
			buf.get_iter_at_mark (out end_iter, mark);
			buf.select_range (start_iter, end_iter);

			update_old_selection ();
			
			return true;
		}

		Cancellable? loading_cancellable = null;
		
		public async void replace_contents (InputStream is, bool undoable = false, owned Cancellable? cancellable = null) throws Error {
			if (cancellable == null) {
				cancellable = new Cancellable ();
			}
			if (loading_cancellable != null) {
				loading_cancellable.cancel ();
			}
			loading_cancellable = cancellable;
			
			file_loaded = false;
			
			var buf = (SourceBuffer) view.buffer;
			reset_language ();
			buf.set_text ("", -1);
			buf.set_modified (false);
			reset_external_changed ();
			
			file_loading.set_markup ("<i>loading...</i>");
			
			TextIter cursor;
			buf.get_iter_at_mark (out cursor, buf.get_insert ());
			var cursor_offset = cursor.get_offset ();
			try {
				var data = new uint8[4096];
				string? default_charset = null;
				while (true) {
					// keep the cursor at the beginning, or honor any user movement
					int old_offset = cursor_offset;
					buf.get_iter_at_mark (out cursor, buf.get_insert ());
					cursor_offset = cursor.get_offset ();
					TextIter iter;
					view.buffer.get_end_iter (out iter);
					
					if (iter.equal (cursor)) {
						// reset cursor
						buf.get_iter_at_offset (out cursor, old_offset);
						view.buffer.place_cursor (cursor);
					}
					
					var r = yield is.read_async (data, Priority.LOW, cancellable);
					if (r == 0) {
						break;
					}
					data.length = (int)r;
					data = convert_to_utf8 (data, ref default_charset, null, null);
					
					// write
					if (!undoable) {
						buf.begin_not_undoable_action ();
					}
					var old_modified = buf.get_modified ();
					buf.insert (ref iter, (string) data, (int) r);
					if (!undoable) {
						buf.set_modified (old_modified);
						buf.end_not_undoable_action ();
					}
				}
			} finally {
				file_loading.set_markup ("");
				file_loaded = true;
				update_show_branch ();
				on_git_gutter ();
			}
		}
		
		public void update_show_branch () {
			if (conf.get_editor_bool ("show_branch", false)) {
				git.current_branch.begin (file, null, (s, r) => {
						string bname;
						try {
							bname = git.current_branch.end (r);
						} catch (IOError.CANCELLED e) {
							return;
						} catch (Error e) {
							manager.set_status_error (e.message, "show-branch");
							return;
						}
						
						if (bname != null) {
							git_branch.margin_left = 20;
							git_branch.label = "git:" + bname;
						} else {
							git_branch.margin_left = 0;
							git_branch.label = "";
						}
				});
			} else {
				git_branch.margin_left = 0;
				git_branch.label = "";
			}
		}
		
		public void update_right_margin () {
			if (conf.get_editor_bool ("right_margin", false)) {
				var col = conf.get_editor_int ("right_margin_column", 80);
				view.right_margin_position = col;
				view.show_right_margin = true;
			} else {
				view.show_right_margin = false;
			}
		}
		
		/* events */

		void on_buffer_changed () {
			if (!(view.buffer is SourceBuffer)) {
				// very weird, done on textview disposal
				return;
			}
			
			var buf = (SourceBuffer) view.buffer;
			buf.mark_set.connect (on_file_count);
			buf.changed.connect (on_file_count);
			buf.changed.connect (on_git_gutter);
			buf.modified_changed.connect (on_modified_changed);
			on_file_count ();
		}

		public void on_git_gutter () {
			if (!conf.get_editor_bool("git_gutter", true)) {
				if (gutter != null) {
					gutter.remove (gutter_renderer);
					gutter = null;
					gutter_renderer = null;
				}
				return;
			}
			
			if (gutter == null) {
				gutter = view.get_gutter (TextWindowType.LEFT);
				gutter_renderer = new GitGutterRenderer ();
				gutter.insert (gutter_renderer, 0);
			}
			
			if (file_loaded) {
				if (diff_timer > 0) {
					Source.remove (diff_timer);
				}
				
				// this is needed to limit the number of spawned processes
				diff_timer = Timeout.add (100, () => {
						diff_timer = 0;
						
						if (diff_cancellable != null) {
							diff_cancellable.cancel ();
						}
						
						var cancellable = diff_cancellable = new Cancellable ();
						git.diff_buffer.begin (file, view.buffer.text.data, cancellable, (obj, res) => {
								HashTable<int, DiffType> table;
								try {
									table = git.diff_buffer.end (res);
								} catch (IOError.CANCELLED e) {
									return;
								} catch (Error e) {
									manager.set_status_error (e.message, "git-gutter");
									return;
								}
								
								diff_cancellable = null;
								gutter_renderer.table = table;
								gutter.queue_draw ();
						});
						
						return false;
				});
			}
		}
		
		void on_file_count () {
			TextIter insert;
			var buf = view.buffer;
			buf.get_iter_at_mark (out insert, buf.get_insert ());
			int line = insert.get_line ();
			
			// we count tabs as tab_width
			TextIter iter;
			buf.get_iter_at_line (out iter, line);
			int column = 0;
			while (iter.get_offset () < insert.get_offset ()) {
				if (iter.get_char () == '\t') {
					column += (int) view.tab_width;
				} else {
					column++;
				}
				iter.forward_char ();
			}

			file_count.set_label ("(%d, %d)".printf (line+1, column+1));
			
			// update current location, use a timer to reduce the number of disk writes
			if (save_session_timer > 0) {
				Source.remove (save_session_timer);
			}
			save_session_timer = Timeout.add (100, () => {
					save_session_timer = 0;
					manager.save_session (this);
					return false;
			});
		}

		void on_modified_changed () {
			var buf = view.buffer;
			file_status.set_label (buf.get_modified () ? "modified" : "");
		}
		
		void on_external_changed () {
			var cur = get_mtime ();
			var editing = file.get_data<TimeVal?> ("editing_mtime");
			if (editing == null) {
				file.set_data<TimeVal?> ("editing_mtime", cur);
				return;
			}
			
			if (cur != editing) {
				file_external_changed.set_markup ("<span fgcolor='black' bgcolor='red'> <b>file has changed</b> </span>");
			}
			restart_monitor ();
		}
	}
}
