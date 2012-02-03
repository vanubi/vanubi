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

			bind_command ({ Key (Gdk.Key.s, Gdk.ModifierType.CONTROL_MASK) }, "search-forward");
			execute_command["search-forward"].connect (on_search_forward);

			// setup empty buffer
			var ed = get_available_editor (null);
			add (ed);
			focus_editor (ed);
		}

		public void add_overlay (Widget widget) {
			add (widget);
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
			if (f != null && f.equal (file)) {
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
					TextIter start;
					buf.get_start_iter (out start);
					buf.place_cursor (start);
					replace_widget (editor, ed);
					focus_editor (ed);
				});
		}

		public void abort (Editor editor) {
			current_key = key_root;
			foreach (unowned Widget w in get_children ()) {
				if (!(w is Editor) && !(w is Paned)) {
					remove (w);
				}
			}
			focus_editor (editor);
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
			if (modifiers == 0 && keyval != Gdk.Key.Tab && current_key == key_root) {
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
			var bar = new FileBar ();
			bar.activate.connect ((f) => {
					abort (editor);
					open_file (editor, f);
				});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
		}

		void on_save_file (Editor editor) {
			if (editor.file != null) {
				var buf = editor.view.buffer;
				TextIter start, end;
				buf.get_start_iter (out start);
				buf.get_end_iter (out end);
				string text = buf.get_text (start, end, false);
				editor.file.replace_contents_async.begin (text.data, null, true, FileCreateFlags.NONE, null, (s,r) => {
						try {
							editor.file.replace_contents_async.end (r, null);
						} catch (Error e) {
							message (e.message);
						}
						text = null;
					});
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
					unowned Editor ed = get_available_editor (file);
					replace_widget (editor, ed);
					focus_editor (ed);
				});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
		}

		void on_split (Editor editor, string command) {
			Allocation alloc;
			editor.get_allocation (out alloc);
			var parent = (Container) editor.get_parent ();
			parent.remove (editor);
			var paned = new Paned (command == "split-add-right" ? Orientation.HORIZONTAL : Orientation.VERTICAL);
			paned.expand = true;
			paned.position = command == "split-add-right" ? alloc.width/2 : alloc.height/2;
			parent.add (paned);

			paned.pack1 (editor, true, false);
			focus_editor (editor);

			var ed = get_available_editor (editor.file);
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
			var bar = new SearchBar (editor);
			add_overlay (bar);
			bar.show ();
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

	public class Editor : Grid {
		public File file { get; private set; }
		public SourceView view { get; private set; }
		ScrolledWindow sw;
		TextTag in_string_tag = null;

		public Editor (File? file) {
			this.file = file;
			orientation = Orientation.VERTICAL;
			expand = true;

			var vala = SourceLanguageManager.get_default().get_language ("vala");
			var buf = new SourceBuffer.with_language (vala);
			view = new SourceView.with_buffer (buf);
			view.wrap_mode = WrapMode.CHAR;
			view.set_data ("editor", (Editor*)this);

			sw = new ScrolledWindow (null, null);
			sw.expand = true;
			sw.add (view);
			add (sw);
			if (file == null) {
				add (new Label ("*scratch*"));
			} else {
				add (new Label (file.get_basename ()));
			}

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

		public string get_editor_name () {
			if (file == null) {
				return "*scratch*";
			} else {
				return file.get_basename ();
			}
		}

		public bool is_in_string (TextIter iter) {
			var tags = iter.get_tags ();
			return tags == null || tags.data.foreground_gdk.equal (in_string_tag.foreground_gdk);
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

			buf.delete (ref start, ref iter);
			var tab_width = view.tab_width;
			buf.insert (ref start, string.nfill(indent/tab_width, '\t')+string.nfill(indent-(indent/tab_width)*tab_width, ' '), -1);

			// reset cursor, textbuffer bug?
			buf.get_iter_at_mark (out iter, buf.get_insert ());
			buf.place_cursor (iter);
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
	}

	public class Bar : Grid {
		protected Entry entry;

		public new signal void activate (string s);
		public signal void aborted ();

		public Bar () {
			expand = false;
			entry = new Entry ();
			entry.set_activates_default (true);
			entry.expand = true;
			entry.activate.connect (on_activate);
			entry.key_press_event.connect (on_key_press_event);
			add (entry);
			show_all ();

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
		TextIter original_insert;
		TextIter original_bound;

		public SearchBar (Editor editor) {
			this.editor = editor;
			entry.changed.connect (on_changed);

			var buf = editor.view.buffer;
			buf.get_iter_at_mark (out original_insert, buf.get_insert ());
			buf.get_iter_at_mark (out original_bound, buf.get_insert ());
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
					break;
				}
				iter.forward_char ();
			}
		}

		protected override bool on_key_press_event (Gdk.EventKey e) {
			if (e.keyval == Gdk.Key.Escape || (e.keyval == Gdk.Key.g && Gdk.ModifierType.CONTROL_MASK in e.state)) {
				// abort
				editor.view.buffer.select_range (original_insert, original_bound);
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
			}
			return base.on_key_press_event (e);
		}
	}
}

int main (string[] args) {
	Gtk.init (ref args);

	var win = new Window ();
	win.delete_event.connect (() => { Gtk.main_quit (); return false; });
	win.set_default_size (800, 600);

	win.add (new Vanubi.Manager ());

	win.show_all ();
	Gtk.main ();

	return 0;
}
