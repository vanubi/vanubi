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
	public class Manager : Grid {

		/* List of files opened. Work on unique File instances. */
		HashTable<File, File> files = new HashTable<File, File> (File.hash, File.equal);
		/* List of buffers for *scratch* */
		GenericArray<Editor> scratch_editors = new GenericArray<Editor> ();

		internal KeyManager<Editor> keymanager;
		string last_search_string = "";

		[Signal (detailed = true)]
		public signal void execute_command (Editor editor, string command);

		public signal void quit ();

		public Configuration conf;
		public StringSearchIndex index;

		public Manager () {
			conf = new Configuration ();
			orientation = Orientation.VERTICAL;
			keymanager = new KeyManager<Editor> (on_command);

			// setup search index synonyms
			index = new StringSearchIndex ();
			index.synonyms["exit"] = "quit";
			index.synonyms["kill"] = "close";
			index.synonyms["buffer"] = "file";
			index.synonyms["editor"] = "file";
			index.synonyms["switch"] = "change";

			// setup commands
			bind_command ({
					Key (Gdk.Key.h, Gdk.ModifierType.CONTROL_MASK)},
				"help");
			execute_command["help"].connect (on_help);

			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.f, Gdk.ModifierType.CONTROL_MASK) },
				"open-file");
			index_command ("open-file", "Open file for reading in the current buffer, or for creating a new file", "create");
			execute_command["open-file"].connect (on_open_file);

			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.s, Gdk.ModifierType.CONTROL_MASK) },
				"save-file");
			index_command ("save-file", "Save or create the file of the current buffer");
			execute_command["save-file"].connect (on_save_file);

			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.k, 0)},
				"kill-buffer");
			index_command ("kill-buffer", "Kill the current buffer");
			execute_command["kill-buffer"].connect (on_kill_buffer);

			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.c, Gdk.ModifierType.CONTROL_MASK) },
				"quit");
			index_command ("quit", "Quit vanubi", "close");
			execute_command["quit"].connect (on_quit);

			bind_command ({ Key (Gdk.Key.d, Gdk.ModifierType.CONTROL_MASK) }, "delete-char-forward");
			index_command ("delete-char-forward", "Delete the char next to the cursor");
			execute_command["delete-char-forward"].connect (on_delete_char_forward);

			bind_command ({ Key (Gdk.Key.Tab, 0) }, "indent");
			index_command ("indent", "Indent the current line");
			execute_command["indent"].connect (on_indent);

			bind_command ({ Key (Gdk.Key.Return, 0) }, "return");
			bind_command ({ Key (Gdk.Key.Return, Gdk.ModifierType.SHIFT_MASK) }, "return");
			execute_command["return"].connect (on_return);

			bind_command ({ Key ('}', Gdk.ModifierType.SHIFT_MASK) }, "close-curly-brace");
			execute_command["close-curly-brace"].connect (on_close_curly_brace);

			bind_command ({ Key (']', Gdk.ModifierType.SHIFT_MASK) }, "close-square-brace");
			execute_command["close-square-brace"].connect (on_close_square_brace);

			bind_command ({ Key (')', Gdk.ModifierType.SHIFT_MASK) }, "close-paren");
			execute_command["close-paren"].connect (on_close_paren);

			bind_command ({ Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK) }, "cut");
			index_command ("cut", "Cut text to clipboard");
			execute_command["cut"].connect (on_cut);

			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.b, 0)},
				"switch-buffer");
			index_command ("switch-buffer", "Switch current buffer with another buffer");
			execute_command["switch-buffer"].connect (on_switch_buffer);

			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.@3, 0)},
				"split-add-right");
			index_command ("split-add-right", "Split buffer on left and right buffers");
			execute_command["split-add-right"].connect (on_split);

			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.@2, 0)},
				"split-add-down");
			index_command ("split-add-down", "Split buffer on top and down buffers");
			execute_command["split-add-down"].connect (on_split);

			bind_command ({ 
				Key (Gdk.Key.l, Gdk.ModifierType.CONTROL_MASK) }, "next-editor");
			index_command ("next-editor", "Move to the next buffer", "cycle");
			execute_command["next-editor"].connect (on_switch_editor);

			bind_command ({ 
				Key (Gdk.Key.j, Gdk.ModifierType.CONTROL_MASK) }, "prev-editor");
			index_command ("prev-editor", "Move to the previous buffer", "cycle");
			execute_command["prev-editor"].connect (on_switch_editor);

			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.@1, 0)},
				"join-all");
			index_command ("join-all", "Collapse all the buffers into one", "join");
			execute_command["join-all"].connect (on_join_all);

			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.@1, Gdk.ModifierType.CONTROL_MASK)},
				"join");
			index_command ("join", "Collapse two buffers into one", "join");
			execute_command["join"].connect (on_join);

			bind_command ({ Key (Gdk.Key.n, Gdk.ModifierType.CONTROL_MASK) }, "forward-line");
			execute_command["forward-line"].connect (on_forward_backward_line);

			bind_command ({	Key (Gdk.Key.p, Gdk.ModifierType.CONTROL_MASK) }, "backward-line");
			execute_command["backward-line"].connect (on_forward_backward_line);

			bind_command ({ Key (Gdk.Key.s, Gdk.ModifierType.CONTROL_MASK) }, "search-forward");
			index_command ("search-forward", "Search text forward incrementally", "incremental");
			execute_command["search-forward"].connect (on_search_forward);

			bind_command ({ Key (Gdk.Key.r, Gdk.ModifierType.CONTROL_MASK) }, "search-backward");
			index_command ("search-backward", "Search text backward incrementally", "incremental");
			execute_command["search-backward"].connect (on_search_backward);

			bind_command ({ Key (Gdk.Key.k, Gdk.ModifierType.CONTROL_MASK) }, "kill-line");
			index_command ("kill-line", "Delete the current line");
			execute_command["kill-line"].connect (on_kill_line);

			bind_command ({ Key (Gdk.Key.space, Gdk.ModifierType.CONTROL_MASK) }, "select-all");
			index_command ("select-all", "Select all the text");
			execute_command["select-all"].connect (on_select_all);

			bind_command ({ Key (Gdk.Key.e, Gdk.ModifierType.CONTROL_MASK) }, "end-line");
			execute_command["end-line"].connect (on_end_line);

			bind_command ({ Key (Gdk.Key.a, Gdk.ModifierType.CONTROL_MASK) }, "start-line");
			bind_command ({ Key (Gdk.Key.Home, 0) }, "start-line");
			execute_command["start-line"].connect (on_start_line);
			
			bind_command ({ Key (Gdk.Key.Down, Gdk.ModifierType.CONTROL_MASK) }, "move-block-down");
			execute_command["move-block-down"].connect (on_move_block);

			bind_command ({ Key (Gdk.Key.Up, Gdk.ModifierType.CONTROL_MASK) }, "move-block-up");
			execute_command["move-block-up"].connect (on_move_block);

			bind_command ({ Key (Gdk.Key.F9, 0) }, "compile");
			index_command ("compile", "Compile code", "build shell");
			execute_command["compile"].connect (on_compile);

			bind_command ({ Key (Gdk.Key.y, Gdk.ModifierType.CONTROL_MASK) }, "redo");
			index_command ("redo", "Redo action");
			execute_command["redo"].connect (on_redo);

			index_command ("set-tab-width", "Tab width expressed in number of spaces, also used for indentation");
			execute_command["set-tab-width"].connect (on_set_tab_width);

			index_command ("set-shell-scrollback", "Maximum number of scrollback lines used by the terminal");
			execute_command["set-shell-scrollback"].connect (on_set_shell_scrollback);
			
			// setup empty buffer
			unowned Editor ed = get_available_editor (null);
			add (ed);
			ed.grab_focus ();
		}
		
		public void on_command (Editor ed, string command) {
			abort (ed);
			execute_command[command] (ed, command);
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

		// TODO: show keybinding for this command
		public void index_command (string command, string description, string? keywords = null) {
			StringSearchDocument doc;
			if (keywords != null) {
				doc = new StringSearchDocument (command, {description, keywords});
			} else {
				doc = new StringSearchDocument (command, {description});
			}
			index.index_document (doc);
		}

		public void bind_command (Key[] keyseq, string cmd) {
			keymanager.bind_command (keyseq, cmd);
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

		public Editor get_first_visible_editor () {
			// start from scratch_editors
			foreach (unowned Editor ed in scratch_editors.data) {
				if (ed.visible) {
					return ed;
				}
			}

			foreach (unowned File file in files.get_keys ()) {
				unowned GenericArray<Editor> editors = file.get_data ("editors");
				foreach (unowned Editor ed in editors.data) {
					if (ed.visible) {
						return ed;
					}
				}
			}

			assert_not_reached ();
		}

		public void open_file (Editor editor, File file) {
			set_loading ();

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
			file.load_contents_async.begin (null, (s,r) => {
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
			keymanager.reset ();
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
			var ed = new Editor (conf, file);
			// set the font according to the user/system configuration
			var system_size = ed.view.style.font_desc.get_size () / Pango.SCALE;
			ed.view.override_font (Pango.FontDescription.from_string ("Monospace %d".printf (conf.get_editor_int ("font_size", system_size))));
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
				ret += file.get_path ();
			}
			return ret;
		}

		/* events */

		bool on_key_press_event (Widget w, Gdk.EventKey e) {
			var sv = (SourceView) w;
			Editor editor = sv.get_data ("editor");
			var keyval = e.keyval;
			var modifiers = e.state;
			modifiers &= Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK;
			if (keyval == Gdk.Key.Escape || (keyval == Gdk.Key.g && modifiers == Gdk.ModifierType.CONTROL_MASK)) {
				// abort
				abort (editor);
				return true;
			}

			return keymanager.key_press (editor, Key (keyval, modifiers));
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
				conf.set_editor_int ("font_size", size);
				conf.save.begin ();
				return true;
			}
			return false;
		}

		void on_help (Editor editor) {
			var bar = new HelpBar (this);
			bar.activate.connect ((cmd) => {
					abort (editor);
					execute_command[cmd] (editor, cmd);
				});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
		}

		void on_open_file (Editor editor) {
			var bar = new FileBar (editor.file);
			bar.activate.connect ((f) => {
					abort (editor);
					open_file (editor, File.new_for_path (f));
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
					var bar = new EntryBar ("Your changes will be lost. Confirm?");
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

		void on_set_tab_width (Editor editor) {
			var val = conf.get_editor_int("tab_width", 4);
			var bar = new EntryBar (val.to_string());
			bar.activate.connect ((text) => {
					abort (editor);
					conf.set_editor_int("tab_width", int.parse(text));
					conf.save();
			});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
		}

		void on_set_shell_scrollback (Editor editor) {
			var val = conf.get_global_int ("shell_scrollback", 65535);
			var bar = new EntryBar (val.to_string());
			bar.activate.connect ((text) => {
					abort (editor);
					conf.set_global_int("shell_scrollback", int.parse(text));
					conf.save();
			});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
		}
		
		void on_quit () {
			quit ();
		}

		void on_cut (Editor ed) {
			ed.view.cut_clipboard ();
		}

		void on_select_all (Editor ed) {
			ed.view.select_all(true);
		}

		void on_move_block(Editor ed, string command) {
			var buf = ed.view.buffer;
			string line = null;
			TextIter start;
			bool is_down = command == "move-block-down";
			int direction = is_down ? 1 : -1;

			buf.get_iter_at_mark (out start, buf.get_insert ());

			do {
				if ((is_down && !start.forward_line()) || (!is_down && !start.backward_line ())) {
					break;
				}

				TextIter end = start;
				var start_line = start.get_line ();
				end.forward_to_line_end ();
				var end_line = end.get_line ();
				if (start_line != end_line) {
					end.set_line_offset (0);
				}
				
				line = start.get_text(end);

				// move between logical lines, not display lines
				while (true) {
					TextIter iter;
					buf.get_iter_at_mark (out iter, buf.get_insert ());
					var old_line = iter.get_line ();
					ed.view.move_cursor (MovementStep.DISPLAY_LINES, direction, false);
					buf.get_iter_at_mark (out iter, buf.get_insert ());
					var new_line = iter.get_line ();
					if (old_line != new_line) {
						break;
					}
				}
			} while (line.strip() != "");
		}

		void on_start_line(Editor ed) {
			bool forward = false;
			var buf = ed.view.buffer;
			TextIter start;
			buf.get_iter_at_mark (out start, buf.get_insert ());

			while (!start.starts_line()) {
				start.backward_char();
				ed.view.move_cursor (MovementStep.VISUAL_POSITIONS, -1, false);

				if (!forward && !start.get_char().isspace()) {
					forward = true;
				}
			}

			if (forward) {
				while (start.get_char().isspace()) {
					start.forward_char();
					ed.view.move_cursor (MovementStep.VISUAL_POSITIONS, 1, false);
				}
			}
		}

		void on_end_line(Editor ed) {
			/* Put the cursor at the end of line */
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

		void on_return (Editor ed) {
			var buf = ed.view.buffer;
			buf.begin_user_action ();		
			buf.delete_selection (true, true);
			buf.insert_at_cursor ("\n", -1);
			ed.view.scroll_mark_onscreen (buf.get_insert ());
			execute_command["indent"] (ed, "indent");
			buf.end_user_action ();
		}

		void on_close_curly_brace (Editor ed) {
			var buf = ed.view.buffer;
			buf.begin_user_action ();		
			buf.delete_selection (true, true);
			buf.insert_at_cursor ("}", -1);
			ed.view.scroll_mark_onscreen (buf.get_insert ());
			execute_command["indent"] (ed, "indent");
			buf.end_user_action ();
		}

		void on_close_square_brace (Editor ed) {
			var buf = ed.view.buffer;
			buf.begin_user_action ();		
			buf.delete_selection (true, true);
			buf.insert_at_cursor ("]", -1);
			ed.view.scroll_mark_onscreen (buf.get_insert ());
			execute_command["indent"] (ed, "indent");
			buf.end_user_action ();
		}

		void on_close_paren (Editor ed) {
			var buf = ed.view.buffer;
			buf.begin_user_action ();		
			buf.delete_selection (true, true);
			buf.insert_at_cursor (")", -1);
			ed.view.scroll_mark_onscreen (buf.get_insert ());
			execute_command["indent"] (ed, "indent");
			buf.end_user_action ();
		}

		void on_delete_char_forward (Editor ed) {
			TextIter insert_iter;
			var buf = (SourceBuffer) ed.view.buffer;
			buf.get_iter_at_mark (out insert_iter, buf.get_insert ());
			
			var next_iter = insert_iter;
			next_iter.forward_char ();
			buf.delete (ref insert_iter, ref next_iter);
		}
		
		void on_indent (Editor ed) {
			TextIter insert_iter;
			var buf = (SourceBuffer) ed.view.buffer;
			buf.get_iter_at_mark (out insert_iter, buf.get_insert ());
			
			var vbuf = new UI.Buffer ((SourceView) ed.view);
			var viter = new UI.BufferIter (vbuf, insert_iter);
			
			Indent indent_engine;
			var langname = buf.language != null ? buf.language.name : "";
			switch (langname) {
				case "Assembly (Intel)":
				case "i386 Assembly":
					indent_engine = new Indent_Asm (vbuf);
					break;
				default:
					indent_engine = new Indent_C (vbuf);
					break;
			}
			
			indent_engine.indent (viter);
		}

		void on_switch_buffer (Editor editor) {
			var sp = short_paths (get_file_names ());
			var bar = new SwitchBufferBar (sp);
			bar.activate.connect ((res) => {
					abort (editor);
					if (res == "") {
						return;
					}
					File file = null;
					if (res != "*scratch*") {
						foreach (unowned File f in files.get_keys ()) {
							if (f.get_path().has_suffix (res)) {
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

		static void find_editor(Widget node, bool dir_up, bool dir_left, bool forward)
		{
			if (node is Paned) {

				var p = (Paned) node;

				if (dir_up) {
					if (dir_left) {

						if (forward) {
							/* Goto right node */
							find_editor((Widget)p.get_child2(), false, false, forward);
						} else {
							/* Goto the parent */
							
							var parent = p.get_parent() as Paned;
							
							if (parent == null) {
								/* Reached the root node! */
								return;
							} else {
								
								var lchild = parent.get_child1() as Paned;
								
								if (lchild != null && lchild == p) { /* Left child */
									find_editor((Widget)parent, true, true, forward);
								} else { /* Right child */
									find_editor((Widget)parent, true, false, forward);
								}
							}
						}

					} else { /* Right */

						if (forward) {
							/* Goto the parent */
							
							var parent = p.get_parent() as Paned;
							
							if (parent == null) {
								/* Reached the root node! */
								return;
							} else {
								
								var lchild = parent.get_child1() as Paned;
								
								if (lchild != null && lchild == p) { /* Left child */
									find_editor((Widget)parent, true, true, forward);
								} else { /* Right child */
									find_editor((Widget)parent, true, false, forward);
								}
							}
						} else { /* Backward */
							
							/* Goto left node */
							find_editor((Widget)p.get_child1(), false, true, forward);
						}
					}
				} else { /* Down */
					
					if (forward) {
						/* Goto left node */
						find_editor((Widget)p.get_child1(), false, true, forward);
					} else {
						/* Goto right node */
						find_editor((Widget)p.get_child2(), false, false, forward);
					}
				}

			} else if (node is Editor) {

				var e = (Editor)node;

				if (!dir_up) {
					/* Focus the editor */
					e.grab_focus();
				}
			}
		}

		void on_switch_editor(Editor ed, string command)
		{
			var paned = ed.get_parent() as Paned;
			bool fwd = (command == "next-editor") ? true : false;

			if (paned == null) { 
				/* The curr editor is the root node! */
				return;
			}

			var lchild = paned.get_child1() as Editor;

			if (lchild != null && ed == lchild) { /* Left child */
				find_editor((Widget)paned, true, true, fwd);
			} else { /* Right child */
				find_editor((Widget)paned, true, false, fwd);
			}
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
			var bar = new SearchBar (editor, last_search_string, SearchBar.Mode.FORWARD);
			bar.activate.connect (() => {
				last_search_string = bar.text;
				abort (editor);
			});
			bar.aborted.connect (() => {
				last_search_string = bar.text;
				abort (editor);
			});
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
		}
		
		void on_search_backward (Editor editor) {
			var bar = new SearchBar (editor, last_search_string, SearchBar.Mode.BACKWARD);
			bar.activate.connect (() => {
				last_search_string = bar.text;
				abort (editor);
			});
			bar.aborted.connect (() => {
				last_search_string = bar.text;
				abort (editor);
			});
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
		}


		void on_compile (Editor editor) {
			var bar = new ShellBar (conf, editor.file);
			bar.aborted.connect (() => {
					abort (editor);
				});
			add_overlay (bar, true);
			bar.show ();
			bar.grab_focus ();
		}

		void on_redo (Editor editor) {
			editor.view.redo ();
		}
		
		void on_forward_backward_line (Editor ed, string command) {
			if (command == "forward-line") {
				ed.view.move_cursor (MovementStep.DISPLAY_LINES, 1, false);
			} else {
				ed.view.move_cursor (MovementStep.DISPLAY_LINES, -1, false);
			}
		}
	}

	public class Application : Gtk.Application {
		public Application () {
			Object(application_id: "org.vanubi", flags: ApplicationFlags.HANDLES_OPEN);
		}

		Window new_window () {
			var is_main_window = get_active_window () == null;
			var provider = new CssProvider ();
			
			var slm = SourceLanguageManager.get_default();
			var search_path = slm.get_search_path();
			search_path += "./data/languages/";	     
			slm.set_search_path (search_path);
			
			try {
				provider.load_from_path ("./data/vanubi.css");
			} catch (Error e) {
				warning ("Could not load vanubi css: %s", e.message);
			}
			StyleContext.add_provider_for_screen (Gdk.Screen.get_default(), provider, STYLE_PROVIDER_PRIORITY_USER);

			var manager = new Vanubi.Manager ();

			var win = new ApplicationWindow (this);
			win.title = "Vanubi";
			win.delete_event.connect (() => { manager.execute_command (manager.get_first_visible_editor (), "quit"); return false; });
			// restore geometry like one of the main window
			win.move (manager.conf.get_global_int ("window_x"),
					  manager.conf.get_global_int ("window_y"));
			win.set_default_size (manager.conf.get_global_int ("window_width", 800),
								  manager.conf.get_global_int ("window_height", 600));
			if (is_main_window) {
				// store geometry only from main window
				win.check_resize.connect (() => {
						int w, h;
						win.get_size (out w, out h);
						manager.conf.set_global_int ("window_width", w);
						manager.conf.set_global_int ("window_height", h);
						manager.conf.save.begin ();
				});
				win.configure_event.connect (() => {
						int x, y;
						win.get_position (out x, out y);
						manager.conf.set_global_int ("window_x", x);
						manager.conf.set_global_int ("window_y", y);
						manager.conf.save.begin ();
						return false;
				});
			} 
			try {
				win.icon = new Gdk.Pixbuf.from_file("./data/vanubi.png");
			} catch (Error e) {
				warning ("Could not load vanubi icon: %s", e.message);
			}

			manager.quit.connect (() => { remove_window (win); win.destroy (); });
			win.add (manager);

			win.show_all ();
			add_window (win);

			return win;
		}

		public override void open (File[] files, string hint) {
			var win = get_active_window ();
			if (win == null) {
				win = new_window ();
			}
			var manager = (Manager) win.get_child ();
			manager.open_file (manager.get_first_visible_editor (), files[0]);
			win.present ();
		}

		protected override void activate () {
			new_window ();
		}
	}

	public static int main (string[] args) {
		var app = new Application ();
		return app.run (args);
	}
}
