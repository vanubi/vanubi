/*
 *  Copyright © 2011-2012 Luca Bruno
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

	public class Configuration {
		KeyFile backend;
		File file;
		Cancellable saving_cancellable;
		string saving_data;

		public Configuration () {
			var home = Environment.get_home_dir ();
			var filename = Path.build_filename (home, ".vanubi");
			backend = new KeyFile ();
			file = File.new_for_path (filename);
			if (file.query_exists ()) {
				backend.load_from_file (filename, KeyFileFlags.NONE);
			}
		}

		public int get_integer (string group, string key, int default) {
			if (backend.has_group (group) && backend.has_key (group, key)) {
				return backend.get_integer (group, key);
			}
			return default;
		}

		public void set_font_size (int size) {
			backend.set_integer ("Editor", "font_size", size);
		}

		public int get_font_size (int default) {
			// the default value here depends on the widget
			return get_integer ("Editor", "font_size", default);
		}

		public async void save () {
			/* We save the file asynchronously (including the backup),
			   so that the user does not experience any UI lag. */
			var saving_data = backend.to_data ();
			if (saving_cancellable != null && !saving_cancellable.is_cancelled ()) {
				// Cancel any previous save() operation 
				saving_cancellable.cancel ();
			}
			saving_cancellable = new Cancellable ();
			try {
				yield file.replace_contents_async (saving_data.data, null, true, FileCreateFlags.PRIVATE, saving_cancellable, null);
			} catch (IOError.CANCELLED e) { }
		}
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

		/* List of files opened. Work on unique File instances. */
		HashTable<File, File> files = new HashTable<File, File> (File.hash, File.equal);
		/* List of buffers for *scratch* */
		GenericArray<Editor> scratch_editors = new GenericArray<Editor> ();

		KeyNode key_root = new KeyNode ();
		KeyNode current_key;
		uint key_timeout = 0;

		string last_search_string = "";
		string last_command_string = "make";

		[Signal (detailed = true)]
		public signal void execute_command (Editor editor, string command);

		public Configuration conf;

		public Manager () {
			conf = new Configuration ();

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

			bind_command ({ Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK) }, "cut");
			execute_command["cut"].connect (on_cut);

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

			bind_command ({ Key (Gdk.Key.n, Gdk.ModifierType.CONTROL_MASK) }, "forward-line");
			execute_command["forward-line"].connect (on_forward_backward_line);

			bind_command ({	Key (Gdk.Key.p, Gdk.ModifierType.CONTROL_MASK) }, "backward-line");
			execute_command["backward-line"].connect (on_forward_backward_line);

			bind_command ({ Key (Gdk.Key.s, Gdk.ModifierType.CONTROL_MASK) }, "search-forward");
			execute_command["search-forward"].connect (on_search_forward);

			bind_command ({ Key (Gdk.Key.k, Gdk.ModifierType.CONTROL_MASK) }, "kill-line");
			execute_command["kill-line"].connect (on_kill_line);

			bind_command ({ Key (Gdk.Key.space, Gdk.ModifierType.CONTROL_MASK) }, "select-all");
			execute_command["select-all"].connect (on_select_all);

			bind_command ({ Key (Gdk.Key.e, Gdk.ModifierType.CONTROL_MASK) }, "end-line");
			execute_command["end-line"].connect (on_end_line);
			
			bind_command ({ Key (Gdk.Key.F9, 0) }, "compile");
			execute_command["compile"].connect (on_compile);

			// setup empty buffer
			unowned Editor ed = get_available_editor (null);
			add (ed);
			ed.grab_focus ();
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
				ed.grab_focus ();
				return;
			}

			// if the file doesn't exist, don't try to read it
			if (!file.query_exists ()) {
				unowned Editor ed = get_available_editor (file);
				replace_widget (editor, ed);
				ed.grab_focus ();
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
					buf.set_modified (false);
					buf.end_not_undoable_action ();
					TextIter start;
					buf.get_start_iter (out start);
					buf.place_cursor (start);
					replace_widget (editor, ed);
					ed.grab_focus ();
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
			editor.grab_focus ();
			self = null;
		}

		void set_loading () {
		}

		void unset_loading () {
		}

		/* Returns an Editor for the given file */
		unowned Editor get_available_editor (File? file) {
			// list of editors for the file
			unowned GenericArray<Editor> editors;
			if (file == null) {
				// file == null means *scratch*
				editors = scratch_editors;
			} else {
				// map to the unique file instance
				var f = files[file];
				if (f == null) {
					// this is a new file
					files[file] = file;
					var etors = new GenericArray<Editor> ();
					editors = etors;
					// store editors in the File itself
					file.set_data ("editors", (owned) etors);
				} else {
					// get the editors of the file
					editors = file.get_data ("editors");
				}
			}

			// first find an editor that is not visible, so we can reuse it
			foreach (unowned Editor ed in editors.data) {
				if (!ed.visible) {
					return ed;
				}
			}
			// no editor reusable, so create one
			var ed = new Editor (file);
			// set the font according to the user/system configuration
			var system_size = ed.view.style.font_desc.get_size () / Pango.SCALE;
			ed.view.override_font (Pango.FontDescription.from_string ("Monospace %d".printf (conf.get_font_size (system_size))));
			ed.view.key_press_event.connect (on_key_press_event);
			ed.view.scroll_event.connect (on_scroll_event);
			if (editors.length > 0) {
				// share TextBuffer with an existing editor for this file,
				// so that they display the same content
				ed.view.buffer = editors[0].view.buffer;
			} else if (file != null) {
				// if it's not *scratch*, guess the content-type to set the syntax highlight
				bool uncertain;
				var content_type = ContentType.guess (file.get_path (), null, out uncertain);
				if (uncertain) {
					content_type = null;
				}
				var lang = SourceLanguageManager.get_default().guess_language (file.get_path (), content_type);
				((SourceBuffer) ed.view.buffer).set_language (lang);
			}
			// let the Manager own the reference to the editor
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

			var old_key = current_key;
			current_key = current_key.get_child (Key (keyval, modifiers), false);
			if (current_key == null) {
				// no match
				if (old_key != null && old_key.command != null) {
					unowned string command = old_key.command;
					current_key = key_root;
					abort (editor);
					execute_command[command] (editor, command);
				} else {
					current_key = key_root;
				}
				return false;
			}

			if (current_key.has_children ()) {
				if (current_key.command != null) {
					// wait for further keys
					key_timeout = Timeout.add (300, () => {
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

		bool on_scroll_event (Widget w, Gdk.EventScroll ev) {
			if (Gdk.ModifierType.CONTROL_MASK in ev.state) {
				var sv = (SourceView) w;
				var font = sv.get_style_context().get_font (StateFlags.NORMAL);
				var size = font.get_size()/Pango.SCALE;
				if (ev.direction == Gdk.ScrollDirection.UP || (ev.direction == Gdk.ScrollDirection.SMOOTH && ev.delta_y < 0)) {
					size++;
				} else if (ev.direction == Gdk.ScrollDirection.DOWN || (ev.direction == Gdk.ScrollDirection.SMOOTH && ev.delta_y > 0)) {
					size--;
				}
				sv.override_font (Pango.FontDescription.from_string ("Monospace %d".printf (size)));
				conf.set_font_size (size);
				conf.save.begin ();
				return true;
			}
			return false;
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
			bar.grab_focus ();
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
			ed.grab_focus ();
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
					bar.grab_focus ();
				} else {
					kill_buffer (editor, editors, next_file);
				}
			} else {
				unowned Editor ed = get_available_editor (next_file);
				replace_widget (editor, ed);
				ed.grab_focus ();
			}
		}

		void on_quit () {
			Gtk.main_quit ();
		}

		void on_cut (Editor ed) {
			ed.view.cut_clipboard ();
		}

		void on_select_all (Editor ed) {
			ed.view.select_all(true);
		}

		void on_end_line(Editor ed) {
			ed.view.move_cursor (MovementStep.DISPLAY_LINE_ENDS, 1, false);
		}

		void on_kill_line (Editor ed) {
			var buf = ed.view.buffer;

			TextIter start;
			buf.get_iter_at_mark (out start, buf.get_insert ());
			TextIter end = start;
			var start_line = start.get_line ();
			end.forward_to_line_end ();
			var end_line = end.get_line ();
			if (start_line != end_line) {
				end.set_line_offset (0);
			}
			buf.begin_user_action ();
			buf.delete (ref start, ref end);
			buf.end_user_action ();
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
					ed.grab_focus ();
				});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
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
			editor.grab_focus ();

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
			editor.grab_focus ();
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
			editor.grab_focus ();
		}

		void on_search_forward (Editor editor) {
			var bar = new SearchBar (editor, last_search_string);
			bar.activate.connect ((s) => {
				abort (editor);
				last_search_string = s;
			});
			bar.aborted.connect (() => {
				abort (editor);
			});
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
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
			bar.grab_focus ();
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
