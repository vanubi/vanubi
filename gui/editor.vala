/*
 *  Copyright © 2011-2015 Luca Bruno
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
		public TextTag selection_tag;

		public EditorBuffer () {
			selection_tag = create_tag (null, background: "blue", foreground: "white");
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

	public class EditorSelection {
		public EditorBuffer buffer { get; private set; }
		public TextMark insert { get; private set; }
		public TextMark bound { get; private set; }
		public weak TextMark start { get; private set; }
		public weak TextMark end { get; private set; }

		public bool show {
			get {
				return _show;
			}

			set {
				if (_show != value) {
					_show = value;
					if (value) {
						add_tags ();
					} else {
						remove_tags ();
					}
				}
			}
		}

		bool _show;

		public EditorSelection (TextMark insert, TextMark bound) {
			assert (insert.get_buffer () == bound.get_buffer ());
			buffer = (EditorBuffer) insert.get_buffer ();
			this.insert = insert;
			this.bound = bound;
			
			TextIter iinsert, ibound;
			buffer.get_iter_at_mark (out iinsert, this.start);
			buffer.get_iter_at_mark (out ibound, this.end);
			if (iinsert.get_offset() < ibound.get_offset()) {
				this.start = insert;
				this.end = bound;
			} else {
				this.start = bound;
				this.end = insert;
			}
		}

		public EditorSelection.with_iters (TextIter insert, TextIter bound) {
			assert (insert.get_buffer () == bound.get_buffer ());
			buffer = (EditorBuffer) insert.get_buffer ();

			if (insert.get_offset() < bound.get_offset()) {
				this.insert = buffer.create_mark (null, insert, true);
				this.start = this.insert;
				this.bound = buffer.create_mark (null, bound, false);
				this.end = this.bound;
			} else {
				this.bound = buffer.create_mark (null, bound, true);
				this.start = this.bound;
				this.insert = buffer.create_mark (null, insert, false);
				this.end = this.insert;
			}
		}

		public EditorSelection.with_offsets (EditorBuffer buffer, int insert, int bound) {
			TextIter iinsert, ibound;
			this.buffer = buffer;
			buffer.get_iter_at_offset (out iinsert, insert);
			buffer.get_iter_at_offset (out ibound, bound);

			if (iinsert.get_offset() < ibound.get_offset()) {
				this.insert = buffer.create_mark (null, iinsert, true);
				this.start = this.insert;
				this.bound = buffer.create_mark (null, ibound, false);
				this.end = this.bound;
			} else {
				this.bound = buffer.create_mark (null, ibound, true);
				this.start = this.bound;
				this.insert = buffer.create_mark (null, iinsert, false);
				this.end = this.insert;
			}
		}

		public void get_iters (out TextIter start, out TextIter end) {
			buffer.get_iter_at_mark (out start, this.start);
			buffer.get_iter_at_mark (out end, this.end);
		}

		public void get_offsets (out int start, out int end) {
			TextIter istart, iend;
			get_iters (out istart, out iend);
			start = istart.get_offset ();
			end = iend.get_offset ();
		}

		public void get_iter_bounds (out TextIter insert, out TextIter bound) {
			buffer.get_iter_at_mark (out insert, this.insert);
			buffer.get_iter_at_mark (out bound, this.bound);
		}

		public void get_offset_bounds (out int insert, out int bound) {
			TextIter iinsert, ibound;
			get_iter_bounds (out iinsert, out ibound);
			insert = iinsert.get_offset ();
			bound = ibound.get_offset ();
		}

		public bool empty {
			get {
				int start, end;
				get_offsets (out start, out end);
				return start == end;
			}
		}
		
		public EditorSelection copy () {
			TextIter insert, bound;
			get_iter_bounds (out insert, out bound);
			return new EditorSelection.with_iters (insert, bound);
		}

		void add_tags () {
			TextIter start, end;
			get_iters (out start, out end);
			buffer.apply_tag (buffer.selection_tag, start, end);
		}

		void remove_tags () {
			TextIter start, end;
			get_iters (out start, out end);
			buffer.remove_tag (buffer.selection_tag, start, end);
		}

		public string to_string () {
			TextIter insert, bound;
			get_iter_bounds (out insert, out bound);
			return "%d.%d-%d.%d".printf (insert.get_line(), insert.get_line_offset(), bound.get_line(), bound.get_line_offset());
		}
		
		~EditorSelection() {
			if (!this.insert.get_deleted () && !this.bound.get_deleted ()) {
				show = false;
			}
			
			// delete marks if they are owned by us and by the buffer
			if (!this.insert.get_deleted () && this.insert.ref_count == 2) {
				buffer.delete_mark (this.insert);
			}

			if (!this.bound.get_deleted () && this.bound.ref_count == 2) {
				buffer.delete_mark (this.bound);
			}
		}
	}
	
	public class EditorView : SourceView {
		State state;

		public new EditorBuffer buffer {
			get {
				return (EditorBuffer) ((SourceView) this).buffer;
			}
			
			set {
				((SourceView) this).buffer = value;
			}
		}
		
		public bool overwrite_mode {
			get { return _overwrite_mode; }
			set {
				_overwrite_mode = value;
				update_block_cursor ();
			}
		}

		bool _overwrite_mode;
		
		public EditorSelection selection {
			get {
				return _selection;
			}
			
			set {
				assert (value.buffer == buffer);

				if (_selection != null) {
					_selection.show = false;
				}
				
				_selection = value;
				if (has_focus) {
					_selection.show = true;
					TextIter insert;
					buffer.get_iter_at_mark (out insert, _selection.insert);

					// nullify gtk selection
					buffer.select_range (insert, insert);
				}
			}
		}
		private EditorSelection _selection;

		public EditorView (State state, EditorBuffer? buf = null) {
			this.state = state;
			tab_width = 4;

			if (buf != null) {
				buffer = buf;
			} else {
				buffer = new EditorBuffer ();
			}

			overwrite = state.config.get_editor_bool ("block_cursor");
			
			reset_selection ();
		}

		public void draw_selection () {
			_selection.show = true;
			TextIter insert;
			buffer.get_iter_at_mark (out insert, _selection.insert);

			// nullify gtk selection
			buffer.select_range (insert, insert);
		}
		
		public void reset_selection (bool fixed_bound = false) {
			TextIter insert, bound;
			buffer.get_iter_at_mark (out insert, buffer.get_insert ());
			
			if (fixed_bound && selection != null) {
				buffer.get_iter_at_mark (out bound, selection.bound);
			} else {
				bound = insert;
			}
			
			selection = new EditorSelection.with_iters (insert, bound);
		}

		public void update_block_cursor () {
#if VALA_0_28
			overwrite = state.config.get_editor_bool ("block_cursor") ^ overwrite_mode;
#else
			var bc = state.config.get_editor_bool ("block_cursor");
			overwrite = (overwrite_mode && !bc) || (!overwrite_mode && bc);
#endif
		}

		/* events */

		public override bool focus_in_event (Gdk.EventFocus e) {
			selection.show = true;
			
			// fix cursor
			TextIter insert;
			buffer.get_iter_at_mark (out insert, selection.insert);
			buffer.select_range (insert, insert);
			
			return base.focus_in_event (e);
		}

		public override bool focus_out_event (Gdk.EventFocus e) {
			_selection.show = false;
			return base.focus_in_event (e);
		}

		bool is_key_move (Gdk.EventKey e) {
			return (e.keyval == Gdk.Key.Home ||
					e.keyval == Gdk.Key.End ||
					e.keyval == Gdk.Key.Page_Up ||
					e.keyval == Gdk.Key.KP_Page_Up ||
					e.keyval == Gdk.Key.Page_Down ||
					e.keyval == Gdk.Key.KP_Page_Down ||
					e.keyval == Gdk.Key.Up ||
					e.keyval == Gdk.Key.Left ||
					e.keyval == Gdk.Key.Down ||
					e.keyval == Gdk.Key.Right);
		}

		public override bool key_press_event (Gdk.EventKey e) {
			if (e.keyval == Gdk.Key.Insert ||
				e.keyval == Gdk.Key.KP_Insert) {
				overwrite_mode = !overwrite_mode;
				return true;
			}
			
			if (e.keyval == Gdk.Key.Return ||
				e.keyval == Gdk.Key.ISO_Enter ||
				e.keyval == Gdk.Key.KP_Enter) {
				commit_text ("\n");
				return true;
			} else if ((e.keyval == Gdk.Key.Tab ||
					e.keyval == Gdk.Key.KP_Tab ||
					e.keyval == Gdk.Key.ISO_Left_Tab) &&
			!(Gdk.ModifierType.CONTROL_MASK in e.state)) {
				commit_text ("\t");
				return true;
			}

			if (is_key_move (e)) {
				bool ret = base.key_press_event (e);
				
				reset_selection (Gdk.ModifierType.SHIFT_MASK in e.state);

				return ret;
			}

			if (e.keyval == Gdk.Key.Delete ||
				e.keyval == Gdk.Key.KP_Delete ||
				e.keyval == Gdk.Key.BackSpace) {
				return false;
			}
			
			commit_text (e.str);

			return false;
		}

		public override bool button_press_event (Gdk.EventButton e) {
			bool ret = base.button_press_event (e);
			
			reset_selection (Gdk.ModifierType.SHIFT_MASK in e.state);

			return ret;
		}

		public override bool drag_motion (Gdk.DragContext context, int x, int y, uint time) {
			message("foo");
			return true;
		}

		void commit_text (string text) {
			buffer.begin_user_action ();
			
			delete_selection ();
			insert_at_cursor (text);
			
			buffer.end_user_action ();
		}

		public void delete_text (ref TextIter start, ref TextIter end) {
			buffer.delete (ref start, ref end);

			if (has_focus) {
				draw_selection ();
			}
		}
		
		public void delete_selection () {
			TextIter start, end;
			selection.get_iters (out start, out end);

			// FIXME: fix delete_range to use ref
			if (overwrite_mode) {
				if (start.equal (end)) {
					// delete the next char
					if (end.forward_char ()) {
						delete_text (ref start, ref end);
					}
				} else {
					delete_text (ref start, ref end);
				}
			} else if (!start.equal (end)) {
				delete_text (ref start, ref end);
			}
		}
		
		public void insert_at_cursor (string text) {
			TextIter insert;
			buffer.get_iter_at_mark (out insert, selection.insert);
			buffer.insert (ref insert, text, -1);
			buffer.move_mark (selection.insert, insert);
			buffer.move_mark (selection.bound, insert);
			
			// nullify gtk selection
			buffer.select_range (insert, insert);
		}
		
		public override void move_cursor (MovementStep step, int count, bool extend_selection) {
			base.move_cursor (step, count, extend_selection);
			
			TextIter insert, bound;
			buffer.get_iter_at_mark (out insert, buffer.get_insert ());
			
			if (extend_selection) {
				buffer.get_iter_at_mark (out bound, selection.bound);
			} else {
				bound = insert;
			}
			
			selection = new EditorSelection.with_iters (insert, bound);
		}
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

		public EditorView view { get; private set; }

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
		SourceGutter? gutter = null;
		GitGutterRenderer? gutter_renderer = null;
		bool file_loaded = true;
		Cancellable diff_cancellable = null;
		uint diff_timer = 0;
		uint save_session_timer = 0;
		Git git;
		TrailingSpaces? trailsp = null;

		public Editor (Manager manager, DataSource source, EditorBuffer? buf = null) {
			this.manager = manager;
			this.source = source;
			this.conf = manager.state.config;
			orientation = Orientation.VERTICAL;
			expand = true;

			git = new Git (conf);

			// view
			view = new EditorView (manager.state, buf);
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
			view.buffer.mark_set.connect_after (on_mark_set);
			view.buffer.modified_changed.connect_after (on_modified_changed);
			view.buffer.changed.connect_after (on_content_changed);

			view.focus_in_event.connect(() => {
					parent_layout.last_focused_editor = this;
					infobar.get_style_context().remove_class ("nonfocused");
					infobar.reset_style (); // GTK+ 3.4 bug, solved in 3.6
					return false;
			});

			view.focus_out_event.connect(() => {
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
			manager.save_session (this); // changed focused editor
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

		public Layout parent_layout { get; set; }
		
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
			view.selection = new EditorSelection.with_iters (start_iter, end_iter);

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
					on_content_changed ();
					update_read_only.begin ();

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
							manager.state.status.set (e.message, "show-branch", Status.Type.ERROR);
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

		void on_content_changed () {
			on_add_endline ();
			update_file_count ();
			on_git_gutter ();
			on_check_endline ();
		}

		void on_add_endline () {
			if (!file_loaded || !conf.get_editor_bool ("auto_add_endline", false)) {
				return;
			}
			
			TextIter iter;
			view.buffer.get_end_iter (out iter);
			if (iter.backward_char () && iter.get_char() != '\n') {
				iter.forward_char ();
				
				Idle.add_full (Priority.HIGH, () => {
						var old = view.selection.copy ();
						
						view.buffer.insert (ref iter, "\n", 1);
						
						// select old range, in case the cursor was at the end
						view.selection = old;
						return false;
				});
			}
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
									manager.state.status.set (e.message, "git-gutter", Status.Type.ERROR);
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

		void on_mark_set (TextIter loc, TextMark mark) {
			if (mark == view.buffer.get_insert () && view.has_focus) {
				update_file_count ();
			}
		}
		
		void update_file_count () {
			// flush pending keys
			Idle.add_full (Priority.HIGH, () => { manager.state.global_keys.flush (this); return false; });
			
			TextIter insert;
			var buf = view.buffer;
			buf.get_iter_at_mark (out insert, view.selection.insert);

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
