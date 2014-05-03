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
	public class EditorBuffer : SourceBuffer {
		public AbbrevCompletion abbrevs { get; private set; default = new AbbrevCompletion (); }
		uint abbrev_timeout = 0;

		public EditorBuffer () {
		}

		~EditorBuffer () {
			if (abbrev_timeout > 0) {
				Source.remove (abbrev_timeout);
			}
		}

		public override void changed () {
			base.changed ();

			/* queue_update_abbrevs (); */
		}

		public void queue_update_abbrevs () {
			if (abbrev_timeout > 0) {
				return;
			}

			Timeout.add_seconds (1, () => {
					abbrev_timeout = 0;
					update_abbrevs ();
					return false;
			});
		}

		void update_abbrevs () {
			TextIter start, end;
			get_start_iter (out start);
			get_end_iter (out end);
			var text = get_text (start, end, false);
			run_in_thread.begin<void*> (() => { abbrevs.index_text (text); return null; });
		}
	}

	public class EditorView : SourceView {
#if 0
		TextTag caret_text_tag;
		int caret_offset = 0;
#endif

		construct {
			tab_width = 4;
			buffer = new EditorBuffer ();
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
		public LRU<DataSource> lru = new LRU<DataSource> (DataSource.compare);

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
				lru.used (editor.source);
			}
			base.remove (w);
		}

		/* Get sources in lru order */
		public DataSource[] get_sources () {
			DataSource[] res = null;
			foreach (var source in lru.list ()) {
				res += source;
			}
			return res;
		}
	}

	public class Editor : Grid {
		public weak Manager manager;
		Configuration conf;
		public weak DataSource source { get; private set; }
		public SourceView view { get; private set; }
		public SourceStyleSchemeManager editor_style { get; private set; }
		public DataSource? moved_to;
		ScrolledWindow sw;
		Label file_count;
		Label file_status;
		Label file_external_changed;
		Label git_branch;
		Label file_loading;
		Label file_read_only;
		Label endline_status;
		EditorInfoBar infobar;
		int old_selection_start_offset = -1;
		int old_selection_end_offset = -1;
		SourceGutter? gutter = null;
		GitGutterRenderer? gutter_renderer = null;
		bool file_loaded = false;
		Cancellable diff_cancellable = null;
		uint diff_timer = 0;
		uint save_session_timer = 0;
		Git git;
		TrailingSpaces? trailsp = null;

		public Editor (Manager manager, Configuration conf, DataSource source) {
			this.manager = manager;
			this.source = source;
			this.conf = conf;
			orientation = Orientation.VERTICAL;
			expand = true;

			git = new Git (conf);

			// view
			view = new EditorView ();
			view.wrap_mode = WrapMode.CHAR;
			view.set_data ("editor", (Editor*)this);
			view.tab_width = conf.get_file_int(source, "tab_width", 4);
			view.highlight_current_line = conf.get_editor_bool ("highlight_current_line", true);
			update_show_tabs();
			update_right_margin ();

			// set the font according to the user/system configuration
			var system_size = view.style.font_desc.get_size () / Pango.SCALE;
			view.override_font (Pango.FontDescription.from_string ("Monospace %d".printf (conf.get_editor_int ("font_size", system_size))));

			/* Style */
			var style_manager = SourceStyleSchemeManager.get_default ();
			var st = style_manager.get_scheme (conf.get_global_string ("theme", "zen"));
			if (st != null) {
				/* Use default if not found */
				((SourceBuffer)view.buffer).set_style_scheme (st);
			}

			// scrolled window
			sw = new ScrolledWindow (null, null);
			sw.expand = true;
			sw.add (view);
			add (sw);

			on_git_gutter ();
			on_trailing_spaces ();

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

			file_read_only = new Label ("");
			file_read_only.margin_left = 0;
			infobar.add (file_read_only);

			endline_status = new Label("");
			endline_status.margin_left = 0;
			infobar.add (endline_status);

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

			((SourceBuffer)view.buffer).undo.connect_after (on_trailing_spaces);
			((SourceBuffer)view.buffer).redo.connect_after (on_trailing_spaces);
			view.buffer.insert_text.connect_after (on_insert_text);
			view.notify["buffer"].connect_after (on_buffer_changed);
			on_buffer_changed ();

			view.focus_in_event.connect(() => {
					parent_layout.last_focused_editor = this;
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

			source.changed.connect (on_external_changed);
			source.monitor.begin ();

			git.special_file_changed.connect ((repo, refname) => {
					on_git_gutter ();
					if (refname == "HEAD") {
						// branch changed, monitor new ref
						update_show_branch ();
						monitor_git_head.begin ();
					}
			});
			monitor_git_head.begin ();
		}

		async void monitor_git_head () {
			var file = source as FileSource;
			if (file == null) {
				return;
			}
			var parent = (FileSource) file.parent;
			
			var branch = yield git.current_branch (parent);
			if (branch == null) {
				return;
			}

			yield git.monitor_special_file (parent, "HEAD");
			yield git.monitor_special_file (parent, "refs/heads/"+branch);
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

		public async void reset_external_changed () {
			file_external_changed.set_label ("");
			moved_to = null;
			var mtime = yield source.get_mtime ();
			source.set_data<TimeVal?> ("editing_mtime", mtime);
		}

		public override void grab_focus () {
			view.grab_focus ();
			manager.save_session (this); // changed focused
			parent_layout.last_focused_editor = this;
		}

		public string get_editor_name () {
			return source.to_string ();
		}

		public EditorContainer editor_container {
			get {
				return get_parent() as EditorContainer;
			}
		}

		public Layout parent_layout {
			get {
				var cur = get_parent ();
				while (cur != null && !(cur is Layout)) {
					cur = cur.get_parent ();
				}
				return (Layout) cur;
			}
		}

		public void reset_language () {
			var file = source as FileSource;

			// get the first 1k from the buffer
			var buf = view.buffer;
			Gtk.TextIter start, end;
			buf.get_start_iter (out start);
			end = start;
			end.forward_chars (1024);
			var first1k = buf.get_text (start, end, false);

			bool uncertain;
			var content_type = ContentType.guess (file != null ? file.local_path : null, first1k.data, out uncertain);
			if (uncertain) {
				content_type = null;
			}

			var default_lang = SourceLanguageManager.get_default().guess_language (file != null ? file.local_path : null, content_type);
			if (default_lang == null && file != null && (file.local_path.has_suffix ("/COMMIT_EDITMSG") || file.local_path.has_suffix ("/MERGE_EDITMSG") || file.local_path.has_suffix ("/COMMIT_MSG") || file.local_path.has_suffix ("/MERGE_MSG"))) {
				default_lang = SourceLanguageManager.get_default().get_language ("generic_comment");
			}

			string lang_id = null;
			if (file != null) {
				lang_id = conf.get_file_string (file, "language", default_lang != null ? default_lang.id : null);
				if (lang_id == "commit message") {
					// old, update but not urgent to queue a config save right now
					conf.set_file_string (file, "language", "generic_comment");
				}
			} else if (default_lang != null) {
				lang_id = default_lang.id;
			}

			if (lang_id != null) {
				var lang = SourceLanguageManager.get_default().get_language (lang_id);
				((SourceBuffer) view.buffer).set_language (lang);
			}
		}

		public Location get_location () {
			TextIter iter;
			view.buffer.get_iter_at_mark (out iter, view.buffer.get_insert ());
			var loc = new Location (source,
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

		public async void replace_contents (InputStream is, bool undoable = false, int io_priority = GLib.Priority.LOW, owned Cancellable? cancellable = null) throws Error {
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
			yield reset_external_changed ();
			if (cancellable.is_cancelled ()) {
				return;
			}

			file_loading.set_markup ("<i>loading...</i>");

			TextIter cursor;
			buf.get_iter_at_mark (out cursor, buf.get_insert ());
			var cursor_offset = cursor.get_offset ();
			var first_data = true;

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

					data.length = 4096;
					var r = yield is.read_async (data, io_priority, cancellable);
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

					view.buffer.get_end_iter (out iter);
					buf.insert (ref iter, (string) data, (int) r);

					if (!undoable) {
						buf.set_modified (old_modified);
						buf.end_not_undoable_action ();
					}

					if (first_data) {
						// try to guess from first data
						first_data = false;
						reset_language ();
					}
				}
			} catch (IOError.CANCELLED e) {
			} finally {
				// check cancellable to avoid race with other replace_contents
				if (cancellable == loading_cancellable) {
					file_loading.set_markup ("");
					file_loaded = true;
					update_show_branch ();
					on_git_gutter ();
					on_trailing_spaces ();
					update_read_only ();

					loading_cancellable = null;
				}
			}
		}

		public async void update_read_only () {
			bool read_only;
			try {
				read_only = yield source.read_only ();
			} catch {
				return;
			}

			if (read_only) {
				file_read_only.margin_left = 20;
				file_read_only.label = "ro";
			} else {
				file_read_only.margin_left = 0;
				file_read_only.label = "";
			}
		}

		public void update_show_branch () {
			if (!(source is FileSource)) {
				return;
			}

			if (conf.get_editor_bool ("show_branch", true)) {
				git.current_branch.begin ((FileSource) source, Priority.DEFAULT, null, (s, r) => {
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

		public void update_show_tabs () {
			if (conf.get_editor_bool ("show_tabs", false)) {
				view.draw_spaces = SourceDrawSpacesFlags.TAB;
			} else {
				view.draw_spaces = 0;
			}
		}

		public void on_trailing_spaces () {
			if (!conf.get_editor_bool ("trailing_spaces", true)) {
				if (trailsp != null) {
					trailsp.cleanup_buffer ();
					trailsp = null;
				}
				return;
			}

			if (trailsp == null) {
				trailsp = new TrailingSpaces (view);
			}

			if (file_loaded) {
				trailsp.check_buffer ();
			}
		}

		public void clean_trailing_spaces (TextIter start, TextIter end) {
			if (trailsp == null) {
				/* Not enabled */
				return;
			}

			if (start.equal (end)) {
				/* No selection */
				trailsp.untrail_buffer ();
			} else {
				trailsp.untrail_region (start.get_line (), end.get_line ());
			}
		}

		/* events */

		void on_insert_text (ref TextIter pos, string new_text, int new_text_length) {
			if (trailsp != null) {
				var untrail = conf.get_editor_bool ("auto_clean_trailing_spaces", true);
				trailsp.check_inserted_text (ref pos, new_text, untrail);
			}
		}

		void on_buffer_changed () {
			if (!(view.buffer is SourceBuffer)) {
				// very weird, done on textview disposal
				return;
			}

			var buf = (SourceBuffer) view.buffer;
			buf.mark_set.connect (on_file_count);
			buf.changed.connect (on_file_count);
			buf.changed.connect (on_git_gutter);
			buf.changed.connect (on_check_endline);
			new UI.Buffer (view).indent_mode = conf.get_file_enum (source, "indent_mode", IndentMode.TABS);
			buf.modified_changed.connect (on_modified_changed);
			on_file_count ();
			on_check_endline();
		}

		void on_check_endline () {
			if (!file_loaded) {
				return;
			}
			
			var buf = view.buffer;
			TextIter iter;

			buf.get_end_iter (out iter);

			if (iter.get_chars_in_line () == 0) {
				endline_status.set_label ("");
				endline_status.margin_left = 0;
			} else {
				endline_status.set_label ("nonl");
				endline_status.margin_left = 20;
			}
		}

		public void on_git_gutter () {
			if (!conf.get_editor_bool("git_gutter", true) || !(source is FileSource)) {
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
						git.diff_buffer.begin ((FileSource) source, view.buffer.text.data, Priority.DEFAULT, cancellable, (obj, res) => {
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
			// flush pending keys
			Idle.add_full (Priority.HIGH, () => { manager.keymanager.flush (this); return false; });
			
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

			if (trailsp != null) {
				trailsp.check_cursor_line ();
			}
		}

		void on_modified_changed () {
			var buf = view.buffer;
			file_status.set_label (buf.get_modified () ? "modified" : "");
		}

		void on_external_changed (DataSource? moved_to) {
			this.moved_to = moved_to;
			external_changed.begin ();
		}

		async void external_changed () {
			var cur = yield source.get_mtime ();
			var editing = source.get_data<TimeVal?> ("editing_mtime");
			if (editing == null) {
				// we didn't track the mtime yet
				source.set_data<TimeVal?> ("editing_mtime", cur);
				return;
			}

			if (cur != editing) {
				file_external_changed.set_markup ("<span fgcolor='black' bgcolor='red'> <b>file has changed</b> </span>");
			}
		}
	}
}
