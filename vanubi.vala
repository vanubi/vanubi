using Gtk;

namespace Vanubi {
	public struct Key {
		uint keyval;
		Gdk.ModifierType modifiers;

		public Key (uint keyval, Gdk.ModifierType modifiers) {
			this.keyval = keyval;
			this.modifiers = modifiers;
		}

		public uint hash () {
			return keyval | (modifiers << 16);
		}

		public bool equal (Key? other) {
			return keyval == other.keyval && modifiers == other.modifiers;
		}
	}

	public static void focus_editor (Editor editor) {
		editor.view.grab_focus ();
		editor.view.map.connect (() => { editor.view.grab_focus (); });
		Idle.add (() => { editor.view.grab_focus (); return false; });
	}

	public class Manager : Grid {
		class KeyNode {
			public string command;
			Key key;
			HashTable<Key?, KeyNode> children = new HashTable<Key?, KeyNode> (Key.hash, Key.equal);

			public KeyNode get_child (Key key, bool create) {
				KeyNode child = children.get (key);
				if (create && child == null) {
					child = new KeyNode ();
					child.key = key;
					children[key] = child;
				}
				return child;
			}

			public bool has_children () {
				return children.size() > 0;
			}
		}

		HashTable<File, File> files = new HashTable<File, File> (File.hash, File.equal);
		GenericArray<Editor> scratch_editors = new GenericArray<Editor> ();

		KeyNode key_root = new KeyNode ();
		KeyNode current_key;
		uint key_timeout = 0;

		string last_search_string = "";
		string last_command_string = "make";

		[Signal (detailed = true)]
		public signal void execute_command (Editor editor, string command);

		public Manager () {
			orientation = Orientation.VERTICAL;
			current_key = key_root;

			// setup commands
			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.f, Gdk.ModifierType.CONTROL_MASK) },
				"open-file");
			execute_command["open-file"].connect (on_open_file);

			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.s, Gdk.ModifierType.CONTROL_MASK) },
				"save-file");
			execute_command["save-file"].connect (on_save_file);

			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.k, 0)},
				"kill-buffer");
			execute_command["kill-buffer"].connect (on_kill_buffer);

			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.c, Gdk.ModifierType.CONTROL_MASK) },
				"quit");
			execute_command["quit"].connect (on_quit);

			bind_command ({ Key (Gdk.Key.Tab, 0) }, "tab");
			execute_command["tab"].connect (on_tab);

			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.b, 0)},
				"switch-buffer");
			execute_command["switch-buffer"].connect (on_switch_buffer);

			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.@3, 0)},
				"split-add-right");
			execute_command["split-add-right"].connect (on_split);

			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.@2, 0)},
				"split-add-down");
			execute_command["split-add-down"].connect (on_split);

			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.@1, 0)},
				"join-all");
			execute_command["join-all"].connect (on_join_all);

			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.@1, Gdk.ModifierType.CONTROL_MASK)},
				"join");
			execute_command["join"].connect (on_join);

			bind_command ({
					Key (Gdk.Key.n, Gdk.ModifierType.CONTROL_MASK)},
				"forward-line");
			execute_command["forward-line"].connect (on_forward_backward_line);

			bind_command ({
					Key (Gdk.Key.p, Gdk.ModifierType.CONTROL_MASK)},
				"backward-line");
			execute_command["backward-line"].connect (on_forward_backward_line);

			bind_command ({ Key (Gdk.Key.s, Gdk.ModifierType.CONTROL_MASK) }, "search-forward");
			execute_command["search-forward"].connect (on_search_forward);

			bind_command ({ Key (Gdk.Key.F9, 0) }, "compile");
			execute_command["compile"].connect (on_compile);

			// setup empty buffer
			unowned Editor ed = get_available_editor (null);
			add (ed);
			focus_editor (ed);
		}

		public void add_overlay (Widget widget, bool paned = false) {
			var self = this; // keep alive
			var parent = (Container) get_parent ();
			parent.remove (this);
			if (paned) {
				var p = new Paned (Orientation.VERTICAL);
				p.pack1 (this, true, false);
				p.pack2 (widget, true, false);
				parent.add (p);
				p.show ();
			} else {
				var grid = new Grid ();
				grid.orientation = Orientation.VERTICAL;
				grid.add (this);
				grid.add (widget);
				parent.add (grid);
				grid.show ();
			}
			self = null;
		}

		public void bind_command (Key[] keyseq, string cmd) {
			KeyNode cur = key_root;
			foreach (var key in keyseq) {
				cur = cur.get_child (key, true);
			}
			cur.command = cmd;
		}

		public void replace_widget (owned Widget old, Widget r) {
			var parent = (Container) old.get_parent ();
			var rparent = (Container) r.get_parent ();
			if (rparent != null) {
				rparent.remove (r);
			}
			if (parent is Paned) {
				var paned = (Paned) parent;
				if (old == paned.get_child1 ()) {
					paned.remove (old);
					paned.pack1 (r, true, false);
				} else {
					paned.remove (old);
					paned.pack2 (r, true, false);
				}
				paned.show_all ();
			} else {
				parent.remove (old);
				parent.add (r);
				r.show_all ();
			}
			// HACK: SourceView bug
			if (old is Editor) {
				add (old);
				old.hide ();
			}
		}

		public void detach_editors (owned Widget w) {
			if (w is Editor) {
				((Container) w.get_parent ()).remove (w);
				// HACK: SourceView bug
				add (w);
				w.hide ();
			} else if (w is Container) {
				var c = (Container) w;
				foreach (var child in c.get_children ()) {
					detach_editors (child);
				}
			}
		}

		public void open_file (Editor editor, string filename) {
			set_loading ();

			var file = File.new_for_path (filename);
			// first search already opened files
			var f = files[file];
			if (f != null) {
				if (f == editor.file) {
					// no-op
					return;
				}
				unowned Editor ed = get_available_editor (f);
				replace_widget (editor, ed);
				focus_editor (ed);
				return;
			}

			// if the file doesn't exist, don't try to read it
			if (!file.query_exists ()) {
				unowned Editor ed = get_available_editor (file);
				replace_widget (editor, ed);
				focus_editor (ed);
				return;
			}

			// existing file, read it
			file.load_contents_async (null, (s,r) => {
					uint8[] content;
					try {
						file.load_contents_async.end (r, out content, null);
					} catch (Error e) {
						message (e.message);
						return;
					} finally {
						unset_loading ();
					}

					var ed = get_available_editor (file);
					var buf = (SourceBuffer) ed.view.buffer;
					buf.begin_not_undoable_action ();
					buf.set_text ((string) content, -1);
					buf.end_not_undoable_action ();
					buf.set_modified (false);
					TextIter start;
					buf.get_start_iter (out start);
					buf.place_cursor (start);
					replace_widget (editor, ed);
					focus_editor (ed);
				});
		}

		public void abort (Editor editor) {
			current_key = key_root;
			var self = this; // keep alive
			var parent = (Container) get_parent ();
			var pparent = (Container) parent.get_parent ();
			if (pparent == null) {
				return;
			}
			parent.remove (this);
			pparent.remove (parent);
			pparent.add (this);
			focus_editor (editor);
			self = null;
		}

		void set_loading () {
		}

		void unset_loading () {
		}

		unowned Editor get_available_editor (File? file) {
			unowned GenericArray<Editor> editors;
			if (file == null) {
				editors = scratch_editors;
			} else {
				var f = files[file];
				if (f == null) {
					files[file] = file;
					var etors = new GenericArray<Editor> ();
					editors = etors;
					file.set_data ("editors", (owned) etors);
				} else {
					editors = file.get_data ("editors");
				}
			}

			foreach (unowned Editor ed in editors.data) {
				if (!ed.visible) {
					return ed;
				}
			}
			var ed = new Editor (file);
			ed.view.key_press_event.connect (on_key_press_event);
			if (editors.length > 0) {
				// share buffer
				ed.view.buffer = editors[0].view.buffer;
			} else if (file != null) {
				bool uncertain;
				var content_type = ContentType.guess (file.get_path (), null, out uncertain);
				if (uncertain) {
					content_type = null;
				}
				var lang = SourceLanguageManager.get_default().guess_language (file.get_path (), content_type);
				((SourceBuffer) ed.view.buffer).set_language (lang);
			}
			unowned Editor ret = ed;
			editors.add ((owned) ed);
			return ret;
		}

		string[] get_file_names () {
			string[] ret = {"*scratch*"};
			foreach (unowned File file in files.get_keys ()) {
				ret += file.get_basename ();
			}
			return ret;
		}

		/* events */

		bool on_key_press_event (Widget w, Gdk.EventKey e) {
			var sv = (SourceView) w;
			Editor editor = sv.get_data ("editor");
			var keyval = e.keyval;
			var modifiers = e.state;

			if (key_timeout != 0) {
				Source.remove (key_timeout);
			}
			modifiers &= Gdk.ModifierType.CONTROL_MASK;
			if (keyval == Gdk.Key.Escape || (keyval == Gdk.Key.g && modifiers == Gdk.ModifierType.CONTROL_MASK)) {
				// abort
				abort (editor);
				return true;
			}
			if (modifiers == 0 && keyval < 255 && current_key == key_root) {
				// normal key, avoid a table lookup
				return false;
			}

			current_key = current_key.get_child (Key (keyval, modifiers), false);
			if (current_key == null) {
				// no match
				current_key = key_root;
				return false;
			}

			if (current_key.has_children ()) {
				if (current_key.command != null) {
					// wait for further keys
					Timeout.add (300, () => {
							key_timeout = 0;
							unowned string command = current_key.command;
							current_key = key_root;
							abort (editor);
							execute_command[command] (editor, command);
							return false;
						});
				}
			} else {
				unowned string command = current_key.command;
				current_key = key_root;
				abort (editor);
				execute_command[command] (editor, command);
			}
			return true;
		}

		void on_open_file (Editor editor) {
			var bar = new FileBar (editor.file);
			bar.activate.connect ((f) => {
					abort (editor);
					open_file (editor, f);
				});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
		}

		void on_save_file (Editor editor) {
			var buf = editor.view.buffer;
			if (editor.file != null && buf.get_modified ()) {
				TextIter start, end;
				buf.get_start_iter (out start);
				buf.get_end_iter (out end);
				string text = buf.get_text (start, end, false);
				editor.file.replace_contents_async.begin (text.data, null, true, FileCreateFlags.NONE, null, (s,r) => {
						try {
							editor.file.replace_contents_async.end (r, null);
							buf.set_modified (false);
						} catch (Error e) {
							message (e.message);
						}
						text = null;
					});
			}
		}

		/* Kill a buffer. The file of this buffer must not have any other editors visible. */
		void kill_buffer (Editor editor, GenericArray<Editor> editors, File? next_file) {
			if (editor.file == null) {
				scratch_editors = new GenericArray<Editor> ();
			} else {
				files.remove (editor.file);
			}
			unowned Editor ed = get_available_editor (next_file);
			replace_widget (editor, ed);
			focus_editor (ed);
			foreach (unowned Editor old_ed in editors.data) {
				((Container) old_ed.get_parent ()).remove (old_ed);
			}
		}

		void on_kill_buffer (Editor editor) {
			unowned File next_file = null;
			foreach (unowned File f in files.get_keys ()) {
				if (f != editor.file) {
					next_file = f;
					break;
				}
			}
			GenericArray<Editor> editors;
			if (editor.file == null) {
				editors = scratch_editors;
			} else {
				editors = editor.file.get_data ("editors");
			}
			bool other_visible = false;
			foreach (unowned Editor ed in editors.data) {
				if (editor != ed && ed.visible) {
					other_visible = true;
					break;
				}
			}

			if (!other_visible) {
				// trash the data
				if (editor.view.buffer.get_modified ()) {
					var bar = new Bar ("Your changes will be lost. Confirm?");
					bar.activate.connect (() => {
							abort (editor);
							kill_buffer (editor, editors, next_file);
						});
					bar.aborted.connect (() => { abort (editor); });
					add_overlay (bar);
					bar.show ();
				} else {
					kill_buffer (editor, editors, next_file);
				}
			} else {
				unowned Editor ed = get_available_editor (next_file);
				replace_widget (editor, ed);
				focus_editor (ed);
			}
		}

		void on_quit () {
			Gtk.main_quit ();
		}

		void on_tab (Editor ed) {
			var buf = ed.view.buffer;

			TextIter insert_iter;
			buf.get_iter_at_mark (out insert_iter, buf.get_insert ());
			int line = insert_iter.get_line ();
			if (line == 0) {
				ed.set_line_indentation (line, 0);
				return;
			}

			// find first non-blank prev line
			int prev_line = line-1;
			while (prev_line >= 0) {
				TextIter line_start;
				buf.get_iter_at_line (out line_start, prev_line);
				TextIter line_end = line_start;
				line_end.forward_to_line_end ();
				if (line_start.get_line () != line_end.get_line ()) {
					// empty line
					prev_line--;
					continue;
				}
				string text = buf.get_text (line_start, line_end, false);
				if (text.strip()[0] == '\0') {
					prev_line--;
				} else {
					break;
				}
			}

			if (prev_line < 0) {
				ed.set_line_indentation (line, 0);
			} else {
				int new_indent = ed.get_line_indentation (prev_line);
				var tab_width = (int) ed.view.tab_width;

				// opened/closed braces
				TextIter iter;
				buf.get_iter_at_line (out iter, prev_line);
				bool first_nonspace = true;
				while (!iter.ends_line () && !iter.is_end ()) {
					var c = iter.get_char ();
					if (c == '{' && !ed.is_in_string (iter)) {
						new_indent += tab_width;
					} else if (c == '}' && !first_nonspace && !ed.is_in_string (iter)) {
						new_indent -= tab_width;
					}
					iter.forward_char ();
					if (!c.isspace ()) {
						first_nonspace = false;
					}
				}

				// unindent
				buf.get_iter_at_line (out iter, line);
				while (!iter.ends_line () && !iter.is_end ()) {
					unichar c = iter.get_char ();
					if (!c.isspace ()) {
						if (c == '}' && !ed.is_in_string (iter)) {
							new_indent -= tab_width;
						}
						break;
					}
					iter.forward_char ();
				}

				ed.set_line_indentation (line, new_indent);
			}
		}

		void on_switch_buffer (Editor editor) {
			var bar = new SwitchBufferBar (get_file_names ());
			bar.activate.connect ((res) => {
					abort (editor);
					if (res == "") {
						return;
					}
					File file = null;
					if (res != "*scratch*") {
						foreach (unowned File f in files.get_keys ()) {
							if (f.get_basename () == res) {
								file = f;
								break;
							}
						}
					}
					if (file == editor.file) {
						// no-op
						return;
					}
					unowned Editor ed = get_available_editor (file);
					replace_widget (editor, ed);
					focus_editor (ed);
				});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
		}

		void on_split (Editor editor, string command) {
			// get bounding box of the editor
			Allocation alloc;
			editor.get_allocation (out alloc);
			// unparent the editor
			var parent = (Container) editor.get_parent ();
			parent.remove (editor);
			// create the GUI split
			var paned = new Paned (command == "split-add-right" ? Orientation.HORIZONTAL : Orientation.VERTICAL);
			paned.expand = true;
			// set the position of the split at half of the editor width/height
			paned.position = command == "split-add-right" ? alloc.width/2 : alloc.height/2;
			parent.add (paned);

			// pack the old editor
			paned.pack1 (editor, true, false);
			focus_editor (editor);

			// get an editor for the same field
			var ed = get_available_editor (editor.file);
			if (ed.get_parent () != null) {
				// ensure the new editor is unparented
				((Container) ed.get_parent ()).remove (ed);
			}
			// pack the new editor
			paned.pack2 (ed, true, false);
			paned.show_all ();
		}

		void on_join_all (Editor editor) {
			var paned = editor.get_parent () as Paned;
			if (paned == null) {
				// already on front
				return;
			}
			// find the right manager child
			unowned Widget parent = editor;
			while (parent.get_parent() != this) {
				parent = parent.get_parent ();
			}
			paned.remove (editor); // avoid detach
			detach_editors (parent);
			replace_widget (parent, editor);
			focus_editor (editor);
		}

		void on_join (Editor editor) {
			var paned = (Container) editor.get_parent () as Paned;
			if (paned == null) {
				// already on front
				return;
			}
			paned.remove (editor);
			detach_editors (paned);
			replace_widget (paned, editor);
			focus_editor (editor);
		}

		void on_search_forward (Editor editor) {
			var bar = new SearchBar (editor, last_search_string);
			bar.activate.connect ((s) => {
					last_search_string = s;
				});
			bar.aborted.connect (() => {
					abort (editor);
				});
			add_overlay (bar);
			bar.show ();
		}

		void on_compile (Editor editor) {
			var bar = new Bar (last_command_string);
			bar.activate.connect ((s) => {
					abort (editor);
					last_command_string = s;
					var shell = new ShellBar (s, editor.file);
					add_overlay (shell, true);
					shell.show ();
				});
			bar.aborted.connect (() => {
					abort (editor);
				});
			add_overlay (bar);
			bar.show ();
		}

		void on_forward_backward_line (Editor ed, string command) {
			if (command == "forward-line") {
				ed.view.move_cursor (MovementStep.DISPLAY_LINES, 1, false);
			} else {
				ed.view.move_cursor (MovementStep.DISPLAY_LINES, -1, false);
			}
		}

		class SwitchBufferBar : CompletionBar {
			string[] choices;

			public SwitchBufferBar (string[] choices) {
				base (false);
				this.choices = choices;
			}

			protected override async string[]? complete (string pattern, out string? common_choice, Cancellable cancellable) {
				var worker = new MatchWorker (cancellable);
				worker.set_pattern (pattern);
				foreach (unowned string choice in choices) {
					worker.enqueue (choice);
				}
				try {
					return yield worker.get_result (out common_choice);
				} catch (Error e) {
					message (e.message);
					common_choice = null;
					return null;
				} finally {
					worker.terminate ();
				}
			}
		}
	}

	public class EditorView : SourceView {
		TextTag caret_text_tag;
		int caret_offset = 0;

		construct {
			buffer = new SourceBuffer (null);
			buffer.mark_set.connect (update_caret_position);
			buffer.changed.connect (update_caret_position);
			caret_text_tag = buffer.create_tag ("caret_text", foreground: "black");
			((SourceBuffer) buffer).highlight_matching_brackets = true;
		}

		void update_caret_position () {
			// remove previous tag
			TextIter start;
			buffer.get_iter_at_offset (out start, caret_offset);
			var end = start;
			if (end.forward_char ()) {
				buffer.remove_tag (caret_text_tag, start, end);
			}

			buffer.get_iter_at_mark (out start, buffer.get_insert ());
			caret_offset = start.get_offset ();
			end = start;
			if (end.forward_char ()) {
				// change the color of the text
				buffer.apply_tag (caret_text_tag, start, end);
			}
		}

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
			get_style_context().add_class ("caret");
			// now redraw the code clipped to the new caret, exluding the old caret
			cr.rectangle (x+1, y, width-1, height); // don't render the original cursor
			cr.clip ();
			base.draw (cr);
			// revert
			get_style_context().remove_class ("caret");

			return false;
		}
	}

	public class Editor : Grid {
		public File file { get; private set; }
		public SourceView view { get; private set; }
		public SourceStyleSchemeManager editor_style { get; private set; }
		ScrolledWindow sw;
		TextTag in_string_tag = null;
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
			var system_size = view.style.font_desc.get_size () / Pango.SCALE;
			view.modify_font (Pango.FontDescription.from_string ("Monospace %d".printf (system_size)));
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
			var info = new EditorInfoBar ();
			info.expand = false;
			info.orientation = Orientation.HORIZONTAL;
			//info.get_style_context().add_class("focused");
			add (info);

			var file_label = new Label (get_editor_name ());
			file_label.margin_left = 20;
			file_label.get_style_context().add_class("filename");
			info.add (file_label);

			file_count = new Label ("(0, 0)");
			file_count.margin_left = 20;
			info.add (file_count);

			file_status = new Label ("");
			file_status.margin_left = 20;
			info.add (file_status);

			view.notify["buffer"].connect_after (on_buffer_changed);
			on_buffer_changed ();
		}

		public string get_editor_name () {
			if (file == null) {
				return "*scratch*";
			} else {
				return file.get_basename ();
			}
		}

		public bool is_in_string (TextIter iter) {
			var tags = iter.get_tags ();
			return in_string_tag != null && tags != null && tags.data.foreground_gdk.equal (in_string_tag.foreground_gdk);
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

			while (iter.get_char().isspace () && !iter.ends_line () && !iter.is_end ()) {
				if (iter.get_char() == '\t') {
					indent += tab_width;
				} else {
					indent++;
				}
				iter.forward_char ();
			}
			return (int) indent;
		}

		/* events */

		void on_buffer_changed () {
			var buf = (SourceBuffer) view.buffer;
			buf.mark_set.connect (on_file_count);
			buf.changed.connect (on_file_count);
			buf.notify["language"].connect (on_language_changed);
			buf.modified_changed.connect (on_modified_changed);
			on_file_count ();
		}

		void on_language_changed () {
			var buf = (SourceBuffer) view.buffer;
			// HACK: sourceview doesn't set the style in the tags :-(
			buf.set_text ("\"foo\"", -1);
			TextIter start, end;
			buf.get_start_iter (out start);
			buf.get_end_iter (out end);
			buf.ensure_highlight (start, end);
			start.forward_char ();
			var tags = start.get_tags ();
			if (tags != null) {
				in_string_tag = tags.data;
			}
			buf.set_text ("", 0);
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

	public class Grid : Gtk.Grid {
		public override bool draw (Cairo.Context cr) {
			Allocation alloc;
			get_allocation (out alloc);
			get_style_context().render_background (cr, 0, 0, alloc.width, alloc.height);
			base.draw (cr);
			return false;
		}
	}

	public class Bar : Grid {
		protected Entry entry;

		public new signal void activate (string s);
		public signal void aborted ();

		public Bar (string? initial = null) {
			expand = false;
			entry = new Entry ();
			if (initial != null) {
				entry.set_text (initial);
			}
			entry.set_activates_default (true);
			entry.expand = true;
			entry.activate.connect (on_activate);
			entry.key_press_event.connect (on_key_press_event);
			add (entry);
			show_all ();

			entry.grab_focus ();
			entry.map.connect (() => { entry.grab_focus (); });
			Idle.add (() => { entry.grab_focus (); return false; });
		}

		protected virtual void on_activate () {
			activate (entry.get_text ());
		}

		protected virtual bool on_key_press_event (Gdk.EventKey e) {
			if (e.keyval == Gdk.Key.Escape || (e.keyval == Gdk.Key.g && Gdk.ModifierType.CONTROL_MASK in e.state)) {
				aborted ();
				return true;
			}
			return false;
		}
	}

	class EditorInfoBar : Grid {
	}

	class CompletionBar : Bar {
		string original_pattern;
		string? common_choice;
		CompletionBox completion_box;
		Cancellable current_completion;
		int64 last_tab_time = 0;
		bool navigated = false;
		bool allow_new_value;

		public CompletionBar (bool allow_new_value) {
			this.allow_new_value = allow_new_value;
			entry.changed.connect (on_changed);
			Idle.add (() => { on_changed (); return false; });
		}

		~Bar () {
			if (current_completion != null) {
				current_completion.cancel ();
			}
		}

		protected virtual async string[]? complete (string pattern, out string? common_choice, Cancellable cancellable) {
			common_choice = null;
			return null;
		}

		protected virtual string get_pattern_from_choice (string original_pattern, string choice) {
			return choice;
		}

		void set_choice () {
			entry.set_text (get_pattern_from_choice (original_pattern, completion_box.get_choice ()));
			entry.move_cursor (MovementStep.BUFFER_ENDS, 1, false);
		}

		void set_common_pattern () {
			if (common_choice != null) {
				entry.set_text (get_pattern_from_choice (original_pattern, common_choice));
				entry.move_cursor (MovementStep.BUFFER_ENDS, 1, false);
			}
		}

		protected override void on_activate () {
			unowned string choice = completion_box.get_choice ();
			if (allow_new_value || choice == null) {
				activate (entry.get_text ());
			} else {
				activate (choice);
			}
		}

		void on_changed () {
			original_pattern = entry.get_text ();
			common_choice = null;
			navigated = false;
			if (current_completion != null) {
				current_completion.cancel ();
			}
			var cancellable = current_completion = new Cancellable ();
			complete (entry.get_text (), cancellable, (s,r) => {
					try {
						var result = complete.end (r, out common_choice);
						cancellable.set_error_if_cancelled ();
						cancellable = null;
						if (completion_box != null) {
							remove (completion_box);
						}
						if (result != null) {
							completion_box = new CompletionBox (result);
							attach_next_to (completion_box, entry, PositionType.TOP, 1, 1);
							show_all ();
						}
					} catch (Error e) {
						message (e.message);
					}
				});
		}

		protected override bool on_key_press_event (Gdk.EventKey e) {
			if (e.keyval == Gdk.Key.Escape || (e.keyval == Gdk.Key.g && Gdk.ModifierType.CONTROL_MASK in e.state)) {
				aborted ();
				return true;
			} else if (e.keyval == Gdk.Key.Up) {
				completion_box.back ();
				navigated = true;
				return true;
			} else if (e.keyval == Gdk.Key.Down) {
				completion_box.next ();
				navigated = true;
				return true;
			} else if (e.keyval == Gdk.Key.Tab) {
				if (completion_box.get_choices().length > 0) {
					if (navigated || completion_box.get_choices().length == 1) {
						set_choice ();
					} else {
						int64 time = get_monotonic_time ();
						if (time - last_tab_time < 300000) {
							set_choice ();
						} else {
							set_common_pattern ();
						}
						last_tab_time = time;
					}
				}
				return true;
			}
			return false;
		}

		public class CompletionBox : Grid {
			string[] choices;
			int index = 0;

			public CompletionBox (string[] choices) {
				orientation = Orientation.HORIZONTAL;
				column_spacing = 10;
				this.choices = choices;
				for (int i=0; i < 5 && i < choices.length; i++) {
					if (i > 0) {
						add (new Separator (Orientation.VERTICAL));
					}
					var l = new Label (choices[i]);
					l.ellipsize = Pango.EllipsizeMode.MIDDLE;
					add (l);
				}
				show_all ();
			}

			public void next () {
				if (index < choices.length-1) {
					remove (get_child_at (index*2, 0));
					remove (get_child_at (index*2+1, 0));
					index++;
					if (index+4 < choices.length) {
						add (new Separator (Orientation.VERTICAL));
						var l = new Label (choices[index+4]);
						l.ellipsize = Pango.EllipsizeMode.MIDDLE;
						add (l);
						show_all ();
					}
				}
			}

			public void back () {
				if (index > 0) {
					var c1 = get_child_at ((index+4)*2, 0);
					var c2 = get_child_at ((index+4)*2-1, 0);
					if (c1 != null) {
						remove (c1);
					}
					if (c2 != null) {
						remove (c2);
					}
					index--;
					attach (new Separator (Orientation.VERTICAL), index*2+1, 0, 1, 1);
					var l = new Label (choices[index]);
					l.ellipsize = Pango.EllipsizeMode.MIDDLE;
					attach (l, index*2, 0, 1, 1);
					show_all ();
				}
			}

			public unowned string? get_choice () {
				if (choices.length == 0) {
					return null;
				}
				return ((Label) get_child_at (index*2, 0)).get_label ();
			}

			public unowned string[] get_choices () {
				return choices;
			}
		}
	}

	public class SearchBar : Bar {
		weak Editor editor;
		int original_insert;
		int original_bound;

		public SearchBar (Editor editor, string initial) {
			this.editor = editor;
			entry.set_text (initial);
			entry.changed.connect (on_changed);

			var buf = editor.view.buffer;
			TextIter insert, bound;
			buf.get_iter_at_mark (out insert, buf.get_insert ());
			buf.get_iter_at_mark (out bound, buf.get_insert ());
			original_insert = insert.get_offset ();
			original_bound = bound.get_offset ();
		}

		void on_changed () {
			var buf = editor.view.buffer;
			TextIter iter;
			buf.get_iter_at_mark (out iter, buf.get_insert ());
			search (iter);
		}

		void search (TextIter iter) {
			// inefficient naive implementation
			var buf = editor.view.buffer;
			var p = entry.get_text ();
			while (!iter.is_end ()) {
				var subiter = iter;
				int i = 0;
				unichar c;
				bool found = true;
				while (p.get_next_char (ref i, out c)) {
					if (subiter.get_char () != c) {
						found = false;
						break;
					}
					subiter.forward_char ();
				}
				if (found) {
					// found
					buf.select_range (iter, subiter);
					editor.view.scroll_to_mark (buf.get_insert (), 0, true, 0.5, 0.5);
					break;
				}
				iter.forward_char ();
			}
		}

		protected override bool on_key_press_event (Gdk.EventKey e) {
			if (e.keyval == Gdk.Key.Escape || (e.keyval == Gdk.Key.g && Gdk.ModifierType.CONTROL_MASK in e.state)) {
				// abort
				TextIter insert, bound;
				var buf = editor.view.buffer;
				buf.get_iter_at_offset (out insert, original_insert);
				buf.get_iter_at_offset (out bound, original_bound);
				editor.view.buffer.select_range (insert, bound);
				editor.view.scroll_to_mark (editor.view.buffer.get_insert (), 0, false, 0.5, 0.5);
				aborted ();
				return true;
			} else if (e.keyval == Gdk.Key.s && Gdk.ModifierType.CONTROL_MASK in e.state) {
				// step
				var buf = editor.view.buffer;
				TextIter iter;
				buf.get_iter_at_mark (out iter, buf.get_insert ());
				iter.forward_char ();
				search (iter);
				return true;
			} else if (e.keyval == 65293) { // enter
				// abort
				aborted ();
				return true;
			}
			return base.on_key_press_event (e);
		}
	}
}

int main (string[] args) {
	Gtk.init (ref args);

	var provider = new CssProvider ();
	provider.load_from_path ("./vanubi.css");
	StyleContext.add_provider_for_screen (Gdk.Screen.get_default(), provider, STYLE_PROVIDER_PRIORITY_USER);

	var win = new Window ();
	win.title = "Vanubi";
	win.delete_event.connect (() => { Gtk.main_quit (); return false; });
	win.set_default_size (800, 400);

	win.add (new Vanubi.Manager ());

	win.show_all ();
	Gtk.main ();

	return 0;
}
