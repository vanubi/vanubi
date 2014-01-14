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
	public class StatusBar : Label {
	}
	
	public class Manager : Grid {
		
		/* List of files opened. Work on unique File instances. */
		HashTable<File, File> files = new HashTable<File, File> (File.hash, File.equal);
		/* List of buffers for *scratch* */
		GenericArray<Editor> scratch_editors = new GenericArray<Editor> ();
		
		internal KeyManager<Editor> keymanager;
		string last_search_string = "";
		string last_replace_string = "";
		string last_pipe_command = "";
		string last_vade_code = "";
		// Editor selection before calling a command
		TextIter selection_start;
		TextIter selection_end;

		bool zen_mode = false;
		bool saving_on_quit = false;
		
		[Signal (detailed = true)]
		public signal void execute_command (Editor editor, string command);

		public signal void quit ();

		public Configuration conf;
		public StringSearchIndex command_index;
		public StringSearchIndex lang_index;
		public Vade.Scope base_scope; // Scope for user global variables
		public List<Location<string>> error_locations = new List<Location> ();
		public unowned List<Location<string>> current_error = null;
		EventBox main_box;
		Grid editors_grid;
		StatusBar statusbar;
		uint status_timeout;
		string status_context;
		MarkManager marks = new MarkManager ();
		string last_grep_string = "";
		
		Session last_session;
		
		class KeysWrapper {
			public Key[] keys;
			
			public KeysWrapper (Key[] keys) {
				this.keys = keys;
			}
		}
		
		HashTable<string, KeysWrapper> default_shortcuts = new HashTable<string, KeysWrapper> (str_hash, str_equal);

		public Manager () {
			conf = new Configuration ();
			orientation = Orientation.VERTICAL;
			keymanager = new KeyManager<Editor> (conf, on_command);
			base_scope = Vade.create_base_scope ();
			last_session = conf.get_session ();

			// placeholder for the editors grid
			main_box = new EventBox();
			main_box.expand = true;
			add (main_box);
			
			// grid containing the editors
			editors_grid = new Grid ();
			main_box.add (editors_grid);
			
			// status bar
			statusbar = new StatusBar ();
			statusbar.margin_left = 10;
			statusbar.expand = false;
			statusbar.set_alignment (0.0f, 0.5f);
			var statusbox = new EventBox ();
			statusbox.expand = false;
			statusbox.add (statusbar);
			add (statusbox);
			clear_status ();

			// setup languages index
			lang_index = new StringSearchIndex ();
			var lang_manager = SourceLanguageManager.get_default ();
			foreach (unowned string lang_id in lang_manager.language_ids) {
				var lang = lang_manager.get_language (lang_id);
				lang_index.index_document (new StringSearchDocument (lang_id, {lang.name, lang.section}));
			}
			
			// setup search index synonyms
			command_index = new StringSearchIndex ();
			command_index.synonyms["exit"] = "quit";
			command_index.synonyms["buffer"] = "file";
			command_index.synonyms["editor"] = "file";
			command_index.synonyms["switch"] = "change";
			command_index.synonyms["search"] = "find";

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
			
			bind_command (null, "save-as-file");
			index_command ("save-as-file", "Save the current buffer to another file but stay on this buffer");
			execute_command["save-as-file"].connect (on_save_as_file);

			index_command ("save-as-file-and-open", "Save the current buffer to another file and open the file");
			execute_command["save-as-file-and-open"].connect (on_save_as_file);

			bind_command ({
					Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.k, 0)},
				"kill-buffer");
			index_command ("kill-buffer", "Close the current editor");
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

			bind_command ({
					Key (Gdk.Key.c, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.c, Gdk.ModifierType.CONTROL_MASK) },
				"comment-region");
			bind_command ({
					Key (Gdk.Key.c, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.Return, Gdk.ModifierType.CONTROL_MASK) },
				"comment-region");
			index_command ("comment-region", "Comment region");
			execute_command["comment-region"].connect (on_comment_region);

			bind_command ({ Key (Gdk.Key.Tab, Gdk.ModifierType.CONTROL_MASK) }, "tab");
			index_command ("tab", "Insert a tab");
			execute_command["tab"].connect (on_insert_simple);

			bind_command ({ Key (Gdk.Key.Return, 0) }, "return");
			bind_command ({ Key (Gdk.Key.Return, Gdk.ModifierType.SHIFT_MASK) }, "return");
			execute_command["return"].connect (on_insert_simple);

			bind_command ({ Key ('}', Gdk.ModifierType.SHIFT_MASK) }, "close-curly-brace");
			execute_command["close-curly-brace"].connect (on_insert_simple);

			bind_command ({ Key (']', Gdk.ModifierType.SHIFT_MASK) }, "close-square-brace");
			execute_command["close-square-brace"].connect (on_insert_simple);

			bind_command ({ Key (')', Gdk.ModifierType.SHIFT_MASK) }, "close-paren");
			execute_command["close-paren"].connect (on_insert_simple);

			bind_command ({ Key (Gdk.Key.c, Gdk.ModifierType.CONTROL_MASK) }, "copy");
			index_command ("copy", "Copy text to clipboard");
			execute_command["copy"].connect (on_copy);

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
			index_command ("next-editor", "Move to the next buffer", "cycle right");
			execute_command["next-editor"].connect (on_switch_editor);

			bind_command ({ 
				Key (Gdk.Key.j, Gdk.ModifierType.CONTROL_MASK) }, "prev-editor");
			index_command ("prev-editor", "Move to the previous buffer", "cycle left");
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
			index_command ("join", "Collapse two buffers into one");
			execute_command["join"].connect (on_join);

			bind_command ({ Key (Gdk.Key.n, Gdk.ModifierType.CONTROL_MASK) }, "forward-line");
			index_command ("forward-line", "Move the cursor one line forward");
			execute_command["forward-line"].connect (on_forward_backward_line);

			bind_command ({	Key (Gdk.Key.p, Gdk.ModifierType.CONTROL_MASK) }, "backward-line");
			index_command ("backward-line", "Move the cursor one line backward");
			execute_command["backward-line"].connect (on_forward_backward_line);
			
			bind_command ({ Key (Gdk.Key.f, Gdk.ModifierType.CONTROL_MASK) }, "forward-char");
			index_command ("forward-char", "Move the cursor one character forward");
			execute_command["forward-char"].connect (on_forward_backward_char);
			
			bind_command ({ Key (Gdk.Key.b, Gdk.ModifierType.CONTROL_MASK) }, "backward-char");
			index_command ("backward-char", "Move the cursor one character backward");
			execute_command["backward-char"].connect (on_forward_backward_char);

			bind_command ({ Key (Gdk.Key.s, Gdk.ModifierType.CONTROL_MASK) }, "search-forward");
			index_command ("search-forward", "Search text forward incrementally");
			execute_command["search-forward"].connect (on_search_replace);

			bind_command (null, "search-forward-regexp");
			index_command ("search-forward-regexp", "Search text forward incrementally using a regular expression");
			execute_command["search-forward-regexp"].connect (on_search_replace);

			bind_command ({ Key (Gdk.Key.r, Gdk.ModifierType.CONTROL_MASK) }, "search-backward");
			index_command ("search-backward", "Search text backward incrementally");
			execute_command["search-backward"].connect (on_search_replace);

			index_command ("search-backward-regexp", "Search text backward incrementally using a regular expression");
			execute_command["search-backward-regexp"].connect (on_search_replace);

			bind_command ({ Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
							Key (Gdk.Key.r, 0) }, "replace-forward");
			index_command ("replace-forward", "Replace text forward incrementally");
			execute_command["replace-forward"].connect (on_search_replace);
			
			bind_command (null, "replace-backward");
			index_command ("replace-backward", "Replace text backward incrementally");
			execute_command["replace-backward"].connect (on_search_replace);
			
			bind_command (null, "replace-forward-regexp");
			index_command ("replace-forward-regexp", "Replace text forward incrementally using a regular expression");
			execute_command["replace-forward-regexp"].connect (on_search_replace);

			bind_command (null, "replace-backward-regexp");
			index_command ("replace-backward-regexp", "Replace text backward incrementally using a regular expression");
			execute_command["replace-backward-regexp"].connect (on_search_replace);

			bind_command ({ Key (Gdk.Key.k, Gdk.ModifierType.CONTROL_MASK) }, "kill-line-right");
			index_command ("kill-line-right", "Delete line contents on the right of the cursor");
			execute_command["kill-line-right"].connect (on_kill_line_right);
			
			bind_command ({ Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
							Key (Gdk.Key.k, Gdk.ModifierType.CONTROL_MASK) }, "kill-line");
			index_command ("kill-line", "Delete the current line");
			execute_command["kill-line"].connect (on_kill_line);

			bind_command ({ Key (Gdk.Key.space, Gdk.ModifierType.CONTROL_MASK) }, "select-all");
			index_command ("select-all", "Select all the text");
			execute_command["select-all"].connect (on_select_all);

			bind_command ({ Key (Gdk.Key.e, Gdk.ModifierType.CONTROL_MASK) }, "end-line");
			bind_command ({ Key (Gdk.Key.End, 0) }, "end-line");
			bind_command ({ Key (Gdk.Key.End, Gdk.ModifierType.SHIFT_MASK) }, "end-line-select");
			index_command ("end-line", "Move the cursor to the end of the line");
			index_command ("end-line-select", "Move the cursor to the end of the line, extending the selection");
			execute_command["end-line"].connect (on_end_line);
			execute_command["end-line-select"].connect (on_end_line);

			bind_command ({ Key (Gdk.Key.a, Gdk.ModifierType.CONTROL_MASK) }, "start-line");
			bind_command ({ Key (Gdk.Key.Home, 0) }, "start-line");
			bind_command ({ Key (Gdk.Key.Home, Gdk.ModifierType.SHIFT_MASK) }, "start-line-select");
			index_command ("start-line", "Move the cursor to the start of the line, extending the selection");
			execute_command["start-line"].connect (on_start_line);
			execute_command["start-line-select"].connect (on_start_line);
			
			bind_command ({ Key (Gdk.Key.Down, Gdk.ModifierType.CONTROL_MASK) }, "move-block-down");
			execute_command["move-block-down"].connect (on_move_block);

			bind_command ({ Key (Gdk.Key.Up, Gdk.ModifierType.CONTROL_MASK) }, "move-block-up");
			execute_command["move-block-up"].connect (on_move_block);

			bind_command ({ Key (Gdk.Key.Down, Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.SHIFT_MASK) }, "select-block-down");
			execute_command["select-block-down"].connect (on_move_block);

			bind_command ({ Key (Gdk.Key.Up, Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.SHIFT_MASK) }, "select-block-up");
			execute_command["select-block-up"].connect (on_move_block);

			bind_command ({ Key (Gdk.Key.F9, 0) }, "compile-shell");
			index_command ("compile-shell", "Execute a shell for compiling the code", "build");
			execute_command["compile-shell"].connect (on_compile_shell);

			bind_command ({ Key (Gdk.Key.F9, Gdk.ModifierType.SHIFT_MASK) }, "compile-shell-left");
			index_command ("compile-shell-left", "Execute a shell for compiling the code, open on the left", "build");
			execute_command["compile-shell-left"].connect (on_compile_shell);

			bind_command ({ Key (Gdk.Key.F9, Gdk.ModifierType.CONTROL_MASK) }, "compile-shell-right");
			index_command ("compile-shell-right", "Execute a shell for compiling the code", "build");
			execute_command["compile-shell-right"].connect (on_compile_shell);

			bind_command ({ Key (Gdk.Key.y, Gdk.ModifierType.CONTROL_MASK) }, "redo");
			index_command ("redo", "Redo action");
			execute_command["redo"].connect (on_redo);

			bind_command (null, "set-tab-width");
			index_command ("set-tab-width", "Tab width expressed in number of spaces, also used for indentation");
			execute_command["set-tab-width"].connect (on_set_tab_width);

			bind_command (null, "set-shell-scrollback");
			index_command ("set-shell-scrollback", "Maximum number of scrollback lines used by the terminal");
			execute_command["set-shell-scrollback"].connect (on_set_shell_scrollback);
			
			bind_command ({ Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
							Key (Gdk.Key.j, 0) }, "goto-line");
			index_command ("goto-line", "Jump to a line");
			execute_command["goto-line"].connect (on_goto_line);
	
			bind_command (null, "pipe-shell-clipboard");
			index_command ("pipe-shell-clipboard", "Pass selected or whole text to a shell command and copy the output to the clipboard");
			execute_command["pipe-shell-clipboard"].connect (on_pipe_shell_clipboard);
			
			bind_command (null, "pipe-shell-replace");
			index_command ("pipe-shell-replace", "Pass selected or whole text to a shell command and replace the buffer with the output");
			execute_command["pipe-shell-replace"].connect (on_pipe_shell_replace);
			
			bind_command (null, "set-language");
			index_command ("set-language", "Set the syntax highlight for this file");
			execute_command["set-language"].connect (on_set_language);
			
			bind_command (null, "reload-file");
			index_command ("reload-file", "Reopen the current file");
			execute_command["reload-file"].connect (on_reload_file);

			bind_command ({ Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
							Key (Gdk.Key.s, 0) }, "repo-grep");
			index_command ("repo-grep", "Search for text in repository");
			execute_command["repo-grep"].connect (on_repo_grep);
			
			bind_command ({ Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
							Key (Gdk.Key.f, 0) }, "repo-open-file");
			index_command ("repo-open-file", "Find a file in a repository");
			execute_command["repo-open-file"].connect (on_repo_open_file);
			
			index_command ("eval-expression", "Execute Vade code");
			execute_command["eval-expression"].connect (on_eval_expression);
			
			bind_command ({ Key ('\'', Gdk.ModifierType.CONTROL_MASK) }, "next-error");
			index_command ("next-error", "Jump to successive error in the compilation shell");
			execute_command["next-error"].connect (on_goto_error);

			bind_command ({ Key ('0', Gdk.ModifierType.CONTROL_MASK) }, "prev-error");
			index_command ("prev-error", "Jump to previous error in the compilation shell");
			execute_command["prev-error"].connect (on_goto_error);

			bind_command (null, "save-session");
			index_command ("save-session", "Save currently opened the files in a session for being opened later");
			execute_command["save-session"].connect (on_save_session);
			
			bind_command (null, "restore-session");
			index_command ("restore-session", "Open the files of the last session");
			execute_command["restore-session"].connect (on_restore_session);
			
			bind_command (null, "delete-session");
			index_command ("delete-session", "Remove an existing session");
			execute_command["delete-session"].connect (on_delete_session);
			
			bind_command ({ Key (Gdk.Key.m, Gdk.ModifierType.CONTROL_MASK) }, "mark");
			index_command ("mark", "Save the current location to the stack of positions");
			execute_command["mark"].connect (on_mark);
			
			bind_command (null, "clear-marks");
			index_command ("clear-marks", "Delete the stack of all marked positions");
			execute_command["clear-marks"].connect (on_clear_marks);
			
			bind_command (null, "unmark");
			index_command ("unmark", "Delete the last used mark from the stack of marked positions");
			execute_command["unmark"].connect (on_unmark);
			
			bind_command ({ Key ('.', Gdk.ModifierType.CONTROL_MASK) }, "next-mark");
			index_command ("next-mark", "Go to the next saved position");
			execute_command["next-mark"].connect (on_goto_mark);
			
			bind_command ({ Key (',', Gdk.ModifierType.CONTROL_MASK) }, "prev-mark");
			index_command ("prev-mark", "Go to the previously saved position");
			execute_command["prev-mark"].connect (on_goto_mark);
			
			bind_command ({ Key (Gdk.Key.F11, 0) }, "full-screen");
			index_command ("full-screen", "Full-screen mode");
			execute_command["full-screen"].connect (on_zen_mode);
			
			bind_command (null, "zen-mode");
			index_command ("zen-mode", "Put yourself in meditation mode");
			execute_command["zen-mode"].connect (on_zen_mode);
			
			bind_command (null, "update-copyright-year");
			index_command ("update-copyright-year", "Update copyright year of the current file");
			execute_command["update-copyright-year"].connect (on_update_copyright_year);
			
			bind_command (null, "toggle-autoupdate-copyright-year");
			index_command ("toggle-autoupdate-copyright-year", "Auto update copyright year of modified files");
			execute_command["toggle-autoupdate-copyright-year"].connect (on_toggle_autoupdate_copyright_year);
			
			bind_command (null, "about");
			index_command ("about", "About");
			execute_command["about"].connect (on_about);
			
			bind_command (null, "toggle-git-gutter");
			index_command ("toggle-git-gutter", "Toggle git-gutter");
			execute_command["toggle-git-gutter"].connect (on_toggle_git_gutter);
			
			bind_command (null, "toggle-show-branch");
			index_command ("toggle-show-branch", "Show repository branch in the file info bar");
			execute_command["toggle-show-branch"].connect (on_toggle_show_branch);

			// setup empty buffer
			unowned Editor ed = get_available_editor (null);
			var container = new EditorContainer (ed);
			container.lru.append (null); // *scratch*
			editors_grid.add (container);
			container.grab_focus ();
		}
		
		public void clear_status (string? context = null) {
			if (context == null || context == status_context) {
				statusbar.set_markup ("");
			}
			status_context = null;
		}
		
		public void set_status (string msg, string? context = null) {
			status_context = context;
			statusbar.set_markup (msg);
			if (status_timeout > 0) {
				Source.remove (status_timeout);
				status_timeout = 0;
			}
			statusbar.get_style_context().remove_class ("error");
		}
		
		public void set_status_error (string msg, string? context = null) {
			set_status (msg, context);
			statusbar.get_style_context().add_class ("error");
		}
		
		public string get_status (string? context = null) {
			if (context == null || context == status_context) {
				return statusbar.get_label ();
			}
			return "";
		}
		
		public void update_selection (Editor ed) {
			var buf = ed.view.buffer;
			buf.get_selection_bounds (out selection_start, out selection_end);
		}

		public void on_command (Editor ed, string command) {
			update_selection (ed);
			abort (ed);
			execute_command[command] (ed, command);
		}

		public enum OverlayMode {
			FIXED,
			PANE_BOTTOM,
			PANE_LEFT,
			PANE_RIGHT
		}
		
		public void add_overlay (Widget widget, OverlayMode mode = OverlayMode.FIXED) {
			Allocation alloc;
			get_allocation (out alloc);

			main_box.remove (editors_grid);
			if (mode == OverlayMode.PANE_BOTTOM) {
				var p = new Paned (Orientation.VERTICAL);
				p.expand = true;
				p.pack1 (editors_grid, true, false);
				p.pack2 (widget, true, false);
				p.position = alloc.height*2/3;
				main_box.add (p);
				p.show_all ();
			} else if (mode == OverlayMode.PANE_LEFT) {
				var p = new Paned (Orientation.HORIZONTAL);
				p.expand = true;
				p.pack1 (widget, true, false);
				p.pack2 (editors_grid, true, false);
				p.position = alloc.width/2;
				main_box.add (p);
				p.show_all ();
			} else if (mode == OverlayMode.PANE_RIGHT) {
				var p = new Paned (Orientation.HORIZONTAL);
				p.expand = true;
				p.pack1 (editors_grid, true, false);
				p.pack2 (widget, true, false);
				p.position = alloc.width/2;
				main_box.add (p);
				p.show_all ();
			} else {
				var grid = new Grid ();
				grid.orientation = Orientation.VERTICAL;
				grid.add (editors_grid);
				grid.add (widget);
				main_box.add (grid);
				grid.show_all ();
			}
		}

		public void index_command (string command, string description, string? keywords = null) {
			StringSearchDocument doc;
			if (keywords != null) {
				doc = new StringSearchDocument (command, {description, keywords});
			} else {
				doc = new StringSearchDocument (command, {description});
			}
			command_index.index_document (doc);
		}

		public void bind_command (owned Key[]? keyseq, string cmd) {
			if (keyseq.length > 0) {
				// save the default shortcut from the main method,
				// so we can easily reset the default shortcut later in the helpbar
				default_shortcuts[cmd] = new KeysWrapper (keyseq);
			}
			
			// get a customized shortcut from the config
			var keystring = conf.get_shortcut (cmd);
			if (keystring != null) {
				try {
					keyseq = parse_keys (keystring);
				} catch (Error e) {
					set_status_error (e.message);
				}
			}
			
			// bother only if there's actually a shortcut for the command
			if (keyseq.length > 0) {
				keymanager.bind_command (keyseq, cmd);
			}
		}
		
		public unowned Key[]? get_default_shortcut (string cmd) {
			var wrapped = default_shortcuts[cmd];
			if (wrapped != null) {
				return wrapped.keys;
			}
			return null;
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

		public async void open_file (Editor editor, File file, bool focus = true) {
			yield open_location (editor, new Location (file), focus);
		}
		
		public async void open_location (Editor editor, Location location, bool focus = true) {
			var file = location.file;

			// first search already opened files
			var f = files[file];
			if (f != null) {
				unowned Editor ed;
				if (f != editor.file) {
					ed = get_available_editor (f);
					if (focus) {
						replace_widget (editor, ed);
					}
				} else {
					ed = editor;
				}
				
				if (ed.set_location (location)) {
					Idle.add_full (Priority.HIGH, () => { ed.view.scroll_to_mark (ed.view.buffer.get_insert (), 0, true, 0.5, 0.5); return false; });
				}
				
				if (focus) {
					ed.grab_focus ();
				}
				return;
			}

			// if the file doesn't exist, don't try to read it
			if (!file.query_exists ()) {
				unowned Editor ed = get_available_editor (file);
				if (focus) {
					replace_widget (editor, ed);
					ed.grab_focus ();
				}
				return;
			}

			// existing file, read it
			try {
				var is = yield file.read_async ();
				var ed = get_available_editor (file);
				if (focus) {
					replace_widget (editor, ed);
					ed.grab_focus ();
				}

				yield ed.replace_contents (is);
				
				var buf = ed.view.buffer;
				if (location.start_line < 0) {
					location.start_line = location.start_column = 0;
				}
				if (!(location.start_line == 0 && location.start_column == 0)) {
					if (ed.set_location (location)) {
						Idle.add_full (Priority.HIGH, () => { ed.view.scroll_to_mark (buf.get_insert (), 0, true, 0.5, 0.5); return false; });
					}
				}
			} catch (IOError.CANCELLED e) {
			} catch (Error e) {
				set_status_error (e.message);
			}
		}

		public void abort (Editor editor) {
			keymanager.reset ();
			if (main_box.get_child() == editors_grid) {
				return;
			}
			clear_status ();
			
			var parent = (Container) editors_grid.get_parent();
			parent.remove (editors_grid);
			main_box.remove (main_box.get_child ());
			main_box.add (editors_grid);
			editor.grab_focus ();
		}

		/* File/Editor/etc. COMBINATORS */
		
		// return false to quit the loop
		public delegate bool Operation<G> (G object);
		
		// iterate all files and perform the given operation on each of them
		public bool each_file (Operation<File?> op, bool include_scratch = true) {
			if (include_scratch) {
				if (!op (null)) { // *scratch*
					return false;
				}
			}
			foreach (var file in files.get_keys ()) {
				if (!op (file)) {
					return false;
				}
			}
			return true;
		}
		
		// iterate all editors of a given file and perform the given operation on each of them
		public bool each_file_editor (File? file, Operation<Editor> op) {
			unowned GenericArray<Editor> editors;
			if (file == null) {
				editors = scratch_editors;
			} else {
				editors = file.get_data ("editors");
			}	
			if (editors == null) {
				return true;
			}
			
			foreach (unowned Editor ed in editors.data) {
				if (!op (ed)) {
					return false;
				}
			}
			return true;
		}
		
		public bool each_editor (Operation<Editor> op, bool include_scratch = true) {
			return each_file ((f) => {
					return each_file_editor (f, (ed) => {
							return op (ed);
					});
			}, include_scratch);
		}
		
		// iterate all editor containers and perform the given operation on each of them
		public bool each_editor_container (Operation<EditorContainer> op) {
			return each_editor ((ed) => {
					var container = ed.get_parent() as EditorContainer;
					if (container != null) {
						if (!op (container)) {
							return false;
						}
					}
					return true;
			});
		}
		
		// iterate lru of all EditorContainer and perform the given operation on each of them
		public bool each_lru (Operation<FileLRU> op) {
			return each_editor_container ((c) => {
					return !op (c.lru);
			});
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
					// update lru of all existing containers
					each_lru ((lru) => { lru.append (file); return true; });
					
					// this is a new file
					files[file] = file;
					conf.cluster.opened_file (file);
					var etors = new GenericArray<Editor> ();
					editors = etors;
					// store editors in the File itself
					file.set_data ("editors", (owned) etors);
					// save session for the new opened file
				} else {
					// get the editors of the file
					editors = f.get_data ("editors");
				}
			}

			// first find an editor that is not visible, so we can reuse it
			foreach (unowned Editor ed in editors.data) {
				if (!ed.visible) {
					return ed;
				}
			}
			// no editor reusable, so create one
			var ed = new Editor (this, conf, file);
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
				ed.reset_language ();
			}
			// let the Manager own the reference to the editor
			unowned Editor ret = ed;
			editors.add ((owned) ed);
			return ret;
		}

		/* Session */
		public void save_session (Editor ed, string name = "default") {
			var session = new Session ();
			each_file ((f) => {
					session.files.add (f);
					return true;
			}, false);
			session.location = ed.get_location ();
			conf.save_session (session, name);
			conf.save.begin ();
		}
		
		/* events */

		const uint[] skip_keyvals = {Gdk.Key.Control_L, Gdk.Key.Control_R, Gdk.Key.Shift_L, Gdk.Key.Shift_R};
		bool on_key_press_event (Widget w, Gdk.EventKey e) {
			if (status_timeout == 0) {
				// reset status bar
				status_timeout = Timeout.add_seconds (conf.get_global_int ("status_timeout", 2), () => {
						status_timeout = 0; clear_status (); return false;
				});
			}
			
			var sv = (SourceView) w;
			Editor editor = sv.get_data ("editor");
			var keyval = e.keyval;
			var modifiers = e.state;
			modifiers &= Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK;
			if (keyval == Gdk.Key.Escape || (keyval == Gdk.Key.g && modifiers == Gdk.ModifierType.CONTROL_MASK)) {
				// abort
				clear_status ("keybinding");
				abort (editor);
				return true;
			}
			if (keyval in skip_keyvals) {
				// skip
				return true;
			}

			var key = Key (keyval, modifiers);
			return keymanager.key_press (editor, key);
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
			var bar = new HelpBar (this, HelpBar.Type.COMMAND);
			bar.activate.connect ((cmd) => {
					abort (editor);
					execute_command[cmd] (editor, cmd);
				});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar, OverlayMode.PANE_BOTTOM);
			bar.show ();
			bar.grab_focus ();
		}

		void on_save_session (Editor editor) {
			var sessions = conf.get_sessions ();
			var annotated = new Annotated<string>[0];
			foreach (unowned string session in sessions) {
				annotated += new Annotated<string> (session, session);
			}
			
			var bar = new SessionCompletionBar ((owned) annotated);
			bar.activate.connect ((name) => {
					abort (editor);
					if (name != "") {
						save_session (editor, name);
						set_status ("Session %s saved".printf (name), "sessions");
					}
			});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar, OverlayMode.FIXED);
			bar.show ();
			bar.grab_focus ();
		}
		
		
		async void restore_session (Editor editor, string name) {
			Session session;
			if (name == "default") {
				session = last_session;
			} else {
				session = conf.get_session (name);
			}
			
			if (session == null) {
				set_status ("Session not found", "sessions");
			} else {
				/* Load the first file */
				if (session.location != null) {
					yield open_location (editor, session.location);
				}
				
				File? focused_file = session.location != null ? session.location.file : null;
				foreach (var file in session.files.data) {
					if (focused_file == null || !file.equal (focused_file)) {
						open_file.begin (editor, file, false);
					}
				}
			}
		}
		
		void on_restore_session (Editor editor) {
			var sessions = conf.get_sessions ();
			var annotated = new Annotated<string>[0];
			foreach (unowned string session in sessions) {
				annotated += new Annotated<string> (session, session);
			}
			
			var bar = new SessionCompletionBar ((owned) annotated);
			bar.activate.connect (() => {
					abort (editor);
					var name = bar.get_choice ();
					if (name != "") {
						restore_session.begin (editor, name);
					}
			});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar, OverlayMode.FIXED);
			bar.show ();
			bar.grab_focus ();
		}
		
		void on_delete_session (Editor editor) {
			var sessions = conf.get_sessions ();
			var annotated = new Annotated<string>[0];
			foreach (unowned string session in sessions) {
				annotated += new Annotated<string> (session, session);
			}
			
			var bar = new SessionCompletionBar ((owned) annotated);
			bar.activate.connect (() => {
					abort (editor);
					var name = bar.get_choice ();
					if (name != "") {
						conf.delete_session (name);
						conf.save.begin ();
						set_status ("Session %s deleted".printf (name), "sessions");
					}
			});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar, OverlayMode.FIXED);
			bar.show ();
			bar.grab_focus ();
		}
		
		void on_mark (Editor editor) {
			var loc = editor.get_location ();
			get_start_mark_for_location (loc, editor.view.buffer); // create a TextMark
			marks.mark (loc);
			set_status ("Mark saved", "marks");
		}
		
		void on_unmark (Editor editor) {
			if (!marks.unmark ()) {
				set_status ("No mark to be deleted", "marks");
			} else {
				set_status ("Mark deleted", "marks");
			}
		}
		
		void on_clear_marks (Editor editor) {
			marks.clear ();
			set_status ("Marks cleared", "marks");
		}
		
		void on_goto_mark (Editor editor, string command) {
			Location? loc;
			if (command == "next-mark") {
				loc = marks.next_mark ();
			} else {
				loc = marks.prev_mark ();
			}
			
			if (loc == null) {
				set_status ("No more marks", "marks");
			} else {
				open_location.begin (editor, loc);
			}
		}
		
		void on_set_language (Editor editor) {
			var bar = new HelpBar (this, HelpBar.Type.LANGUAGE);
			bar.activate.connect ((lang_id) => {
					abort (editor);
					var lang = SourceLanguageManager.get_default().get_language (lang_id);
					if (lang != null) {
						unowned GenericArray<Editor> editors = editor.file.get_data("editors");
						foreach (unowned Editor ed in editors.data) {
							((SourceBuffer) ed.view.buffer).set_language (lang);
						}
						conf.set_file_string (editor.file, "language", lang_id);
					} else {
						conf.remove_file_key (editor.file, "language");
					}
			});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar, OverlayMode.PANE_BOTTOM);
			bar.show ();
			bar.grab_focus ();
		}
		
		void on_reload_file (Editor editor) {
			reload_file.begin (editor);
		}
		
		async void reload_file (Editor editor) {
			if (editor.file == null) {
				return;
			}
			var old_offset = selection_start.get_offset ();
			try {
				var is = yield editor.file.read_async ();
				editor.grab_focus ();

				yield editor.replace_contents (is);

				TextIter iter;
				var buf = editor.view.buffer;
				buf.get_iter_at_offset (out iter, old_offset);
				buf.place_cursor (iter);
				editor.view.scroll_mark_onscreen (buf.get_insert ());
			} catch (IOError.CANCELLED e) {
			} catch (Error e) {
				set_status_error (e.message);
			}
		}
		
		void on_open_file (Editor editor) {
			var bar = new FileBar (editor.file);
			bar.activate.connect ((f) => {
					abort (editor);
					open_file.begin (editor, File.new_for_path (f));
				});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
		}

		void on_save_file (Editor editor) {
			if (editor.file == null) {
				// save scratch buffer to another file
				execute_command["save-as-file-and-open"] (editor, "save-as-file-and-open");
			} else {
				save_file.begin (editor);
			}
		}
		
		void on_save_as_file (Editor editor, string command) {
			var bar = new FileBar (editor.file);
			bar.activate.connect ((f) => {
					abort (editor);
					save_file.begin (editor, File.new_for_path (f), command == "save-as-file-and-open");
			});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
		}
		
		async void save_file (Editor editor, File? as_file = null, bool open_as_file = false) {
			var buf = editor.view.buffer;
			if (as_file == null) {
				as_file = editor.file;
			}
			
			if (as_file == null) {
				return;
			}
			
			if (!(buf.get_modified () || !as_file.equal (editor.file))) {
				// should not save anything
				return;
			}

			if (conf.get_global_bool ("autoupdate_copyright_year")) {
				execute_command["update-copyright-year"] (editor, "autoupdate-copyright-year");
			}
				
			TextIter start, end;
			buf.get_start_iter (out start);
			buf.get_end_iter (out end);
			string text = buf.get_text (start, end, false);
								
			try {
				yield as_file.replace_contents_async (text.data, null, true, FileCreateFlags.NONE, null, null);
				if (as_file.equal (editor.file)) {
					buf.set_modified (false);
					editor.reset_external_changed ();
				} else {
					set_status ("Saved as %s".printf (as_file.get_path ()));
					if (open_as_file) {
						yield open_file (editor, as_file);
					}
				}
			} catch (Error e) {
				set_status_error (e.message);
			}
		}

		/* Kill a buffer. The file of this buffer must not have any other editors visible. */
		void kill_buffer (Editor editor, GenericArray<Editor> editors, File? next_file) {
			if (editor.file == null) {
				scratch_editors = new GenericArray<Editor> ();
			} else {
				// removed file, update all editor containers
				each_lru ((lru) => { lru.remove (editor.file); return true; });
				files.remove (editor.file);
				conf.cluster.closed_file (editor.file);
			}
			unowned Editor ed = get_available_editor (next_file);
			replace_widget (editor, ed);
			ed.grab_focus ();
			foreach (unowned Editor old_ed in editors.data) {
				((Container) old_ed.get_parent ()).remove (old_ed);
			}
		}

		void on_kill_buffer (Editor editor) {
			var files = editor.editor_container.get_files ();
			// get next lru file
			unowned File next_file = files[0];

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

		void on_goto_line (Editor editor) {
			var bar = new EntryBar ();
			bar.activate.connect ((text) => {
					abort (editor);
					if (text != "") {
						var buf = editor.view.buffer;
						TextIter iter;
						buf.get_iter_at_line (out iter, int.parse (text)-1);
						buf.place_cursor (iter);
						editor.view.scroll_to_mark (buf.get_insert (), 0, true, 0.5, 0.5);
					}
			});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
		}
		
		void on_set_tab_width (Editor editor) {
			var val = conf.get_editor_int("tab_width", 4);
			var bar = new EntryBar (val.to_string());
			bar.activate.connect ((text) => {
					abort (editor);
					conf.set_editor_int("tab_width", int.parse(text));
					conf.save.begin ();
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
					conf.save.begin ();
			});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
		}

		GenericArray<Editor> get_modified_editors () {
			var res = new GenericArray<Editor> ();

			each_editor((ed) => {
					if (ed.view.buffer.get_modified ()) {
						res.add (ed);
					}
					return true;
			}, false);
			return res;
		}

		async void ask_save_modified_editors (Editor ed) {
			if (saving_on_quit) {
				return;
			}
			saving_on_quit = true;
			
			var modified = get_modified_editors ();
			if (modified.length == 0) {
				// faster
				quit ();
			}
			
			execute_command["join-all"](ed, "join-all");

			var save_all = false;
			foreach (unowned Editor m in modified.data) {
				if (ed.view.buffer != m.view.buffer) {
					replace_widget (ed, m);
				}
				ed = m;
				
				var discard = false;
				var aborted = false;
				var ignore_abort = false;

				SourceFunc resume = ask_save_modified_editors.callback;

				// ask user
				var bar = new MessageBar ("s = save, n = discard, ! = save-all, q = discard all");
				bar.key_pressed.connect ((e) => {
						if (e.keyval == Gdk.Key.s) {
							ignore_abort = true;
							Idle.add ((owned) resume);
							abort (ed);
							return true;
						} else if (e.keyval == Gdk.Key.n) {
							ignore_abort = true;
							discard = true;
							Idle.add ((owned) resume);
							abort (ed);
							return true;
						} else if (e.keyval == Gdk.Key.q) {
							quit();
							return true;
						} else if (e.keyval == '!') {
							ignore_abort = true;
							save_all = true;
							Idle.add ((owned) resume);
							abort (ed);
							return true;
						}
						return false;
				});
				bar.aborted.connect (() => {
						aborted = true;
						Idle.add ((owned) resume);
						abort (ed);
				});
				// ensure this coroutine does not deadlock
				bar.destroy.connect (() => {
						if (!aborted) {
							Idle.add ((owned) resume);
						}
						aborted = true;
				});						
				add_overlay (bar);
				bar.show ();
				bar.grab_focus ();
				
				yield;
				if (aborted && !ignore_abort) {
					saving_on_quit = false;
					return;
				}
				if (discard) {
					continue;
				}
				if (save_all) {
					break;
				}
				
				yield save_file (m);
			}
						
			if (save_all) {
				// get a fresh list of modified editors
				modified = get_modified_editors ();
				foreach (unowned Editor m in modified.data) {
					yield save_file (m);
				}
			}
			quit ();
		}

		void on_quit (Editor ed) {
			ask_save_modified_editors.begin (ed);
		}

		void on_copy (Editor ed) {
			ed.view.copy_clipboard ();
		}

		void on_cut (Editor ed) {
			ed.view.cut_clipboard ();
		}

		void on_select_all (Editor ed) {
			ed.view.select_all(true);
		}

		void on_pipe_shell_clipboard (Editor ed) {
			pipe_shell.begin (ed, (s,r) => {
					try {
						var output = (string) pipe_shell.end (r);
						var clipboard = Clipboard.get (Gdk.SELECTION_CLIPBOARD);
						clipboard.set_text (output, -1);
						set_status ("Output of command has been copied to clipboard");
					} catch (Error e) {
						set_status_error (e.message);
					}
			});
		}
		
		void on_pipe_shell_replace (Editor ed) {
			pipe_shell_replace.begin (ed);
		}
		
		async void pipe_shell_replace (Editor ed) {
			var old_offset = selection_start.get_offset ();
			try {
				var output = yield pipe_shell (ed);
				
				var stream = new MemoryInputStream.from_data ((owned) output, GLib.free);
				yield ed.replace_contents (stream);
				
				TextIter iter;
				var buf = ed.view.buffer;
				buf.get_iter_at_offset (out iter, old_offset);
				buf.place_cursor (iter);
				ed.view.scroll_mark_onscreen (buf.get_insert ());
				
				set_status ("Output of command has been replaced into the editor");
			} catch (IOError.CANCELLED e) {
			} catch (Error e) {
				set_status_error (e.message);
			}
		}

		async uint8[] pipe_shell (Editor ed) throws Error {
			// get text
			var start = selection_start;
			var end = selection_end;
			var buf = ed.view.buffer;
			if (start.equal(end)) { // no selection
				buf.get_start_iter (out start);
				buf.get_end_iter (out end);
			}
			var text = buf.get_text (start, end, false);
			
			SourceFunc resume = pipe_shell.callback;
			uint8[]? output = null;			
			Error? error = null;

			// prompt for shell command
			var bar = new EntryBar (last_pipe_command);
			bar.activate.connect ((command) => {
					abort (ed);
					last_pipe_command = command;
					var filename = ed.file != null ? ed.file.get_path() : "*scratch*";
					var cmd = command.replace("%f", Shell.quote(filename)).replace("%s", start.get_offset().to_string()).replace("%e", end.get_offset().to_string());
					var dir = ed.file != null ? ed.file.get_parent() : File.new_for_path (Environment.get_current_dir ());
					execute_shell_async.begin (dir, cmd, text.data, null, (s,r) => {
							try {
								output = execute_shell_async.end (r);
								Idle.add ((owned) resume);
							} catch (Error e) {
								error = e;
								Idle.add ((owned) resume);
							}
					});
			});
			bar.aborted.connect (() => { abort (ed); });
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();

			yield;
			if (error != null) {
				throw error;
			}
			return output;
		}
		
		void on_move_block (Editor ed, string command) {
			var buf = ed.view.buffer;
			string line = null;
			TextIter start;
			bool is_down = "down" in command;
			bool is_select = "select" in command;
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
					ed.view.move_cursor (MovementStep.DISPLAY_LINES, direction, is_select);
					buf.get_iter_at_mark (out iter, buf.get_insert ());
					var new_line = iter.get_line ();
					if (old_line != new_line) {
						break;
					}
				}
			} while (line.strip() != "");
		}

		void on_start_line (Editor ed, string cmd) {
			var extend_select = cmd.has_suffix ("select");
			
			/* Save the current cursor */
			var buf = ed.view.buffer;
			TextIter initial;
			buf.get_iter_at_mark (out initial, buf.get_insert ());
			
			/* Move cursor at the start of the visual line */
			ed.view.move_cursor (MovementStep.DISPLAY_LINE_ENDS, -1, extend_select);

			TextIter current;
			buf.get_iter_at_mark (out current, buf.get_insert ());
			if (initial.equal (current)) {
				/* Already at the start of the visual line */
				ed.view.move_cursor (MovementStep.PARAGRAPH_ENDS, -1, extend_select);
			}

			buf.get_iter_at_mark (out current, buf.get_insert ());
			/* Find the first non-space of the line */
			while (current.get_char().isspace ()) {
				current.forward_char ();
			}
			
			TextIter cursor;
			buf.get_iter_at_mark (out cursor, buf.get_insert ());
			if (current.get_offset() < initial.get_offset ()) {
				/* Move to the first non-space char */
				while (cursor.get_offset() < current.get_offset()) {
					ed.view.move_cursor (MovementStep.LOGICAL_POSITIONS, 1, extend_select);
					cursor.forward_char ();
				}
			}
			
			ed.view.scroll_mark_onscreen (buf.get_insert ());
		}

		void on_end_line (Editor ed, string cmd) {
			var extend_select = cmd.has_suffix ("select");
			
			/* Save the original position of the cursor */
			var buf = ed.view.buffer;
			TextIter initial;
			buf.get_iter_at_mark (out initial, buf.get_insert ());
			
			/* Move to the visual end of the line */
			ed.view.move_cursor (MovementStep.DISPLAY_LINE_ENDS, 1, extend_select);
			
			TextIter current;
			buf.get_iter_at_mark (out current, buf.get_insert ());

			/* Gtk stops at just one char :( */
			if (extend_select && !current.ends_line ()) {
				ed.view.move_cursor (MovementStep.LOGICAL_POSITIONS, 1, extend_select);
			}

			if (initial.equal (current)) {
				/* Already at the visual end, move to the logical end */
				ed.view.move_cursor (MovementStep.PARAGRAPH_ENDS, 1, extend_select);
			}
			ed.view.scroll_mark_onscreen (buf.get_insert ());
		}

		void on_kill_line (Editor ed) {
			var buf = ed.view.buffer;

			TextIter insert, start;
			buf.get_iter_at_mark (out insert, buf.get_insert ());
			var orig_line = insert.get_line ();
			var orig_line_offset = insert.get_line_offset ();
			buf.get_iter_at_line (out start, insert.get_line());
			
			var end = start;
			while (!end.is_end () && start.get_line() == end.get_line()) {
				end.forward_char ();
			}

			buf.begin_user_action ();
			buf.delete (ref start, ref end);
			
			// repositionate at the same line offset
			buf.get_iter_at_line (out start, orig_line);
			while (!start.ends_line () && start.get_line_offset () < orig_line_offset) {
				start.forward_char ();
			}
			buf.place_cursor (start);
			buf.end_user_action ();
		}
		
		void on_kill_line_right (Editor ed) {
			var buf = ed.view.buffer;

			TextIter start;
			buf.get_iter_at_mark (out start, buf.get_insert ());
			
			var end = start;
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

		void on_insert_simple (Editor ed, string command) {
			var buf = ed.view.buffer;
			buf.begin_user_action ();		
			
			buf.delete_selection (true, true);
			
			if (command == "return") {
				buf.insert_at_cursor ("\n", -1);
			} else if (command == "close-paren") {
				buf.insert_at_cursor (")", -1);
			} else if (command == "close-curly-brace") {
				buf.insert_at_cursor ("}", -1);
			} else if (command == "close-square-brace") {
				buf.insert_at_cursor ("]", -1);
			} else if (command == "tab") {
				buf.insert_at_cursor ("\t", -1);
			}
			
			ed.view.scroll_mark_onscreen (buf.get_insert ());
			update_selection (ed);
			
			var indent_engine = get_indent_engine (ed);
			if (indent_engine != null && command != "tab") {
				execute_command["indent"] (ed, "indent");
			}
			
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
		
		Indent? get_indent_engine (Editor ed) {
			var vbuf = new UI.Buffer ((SourceView) ed.view);
			var buf = (SourceBuffer) ed.view.buffer;
			var lang_id = buf.language != null ? buf.language.id : null;
			
			if (lang_id == null) {
				return null;
			} else {
				switch (lang_id) {
				case "assembly (intel)":
				case "i386 assembly":
					return new Indent_Asm (vbuf);
				case "html":
				case "xml":
					return new Indent_Markup (vbuf);
				case "lua":
					return new Indent_Lua (vbuf);
				case "haskell":
					return new Indent_Haskell (vbuf);
				case "makefile":
					return null;
				default:
					return new Indent_C (vbuf);
				}
			}
		}
		
		void on_indent (Editor ed) {
			var indent_engine = get_indent_engine (ed);
			var buf = (SourceBuffer) ed.view.buffer;

			if (indent_engine == null) {
				// insert a tab
				buf.begin_user_action ();		
				buf.delete_selection (true, true);
				buf.insert_at_cursor ("\t", -1);
				ed.view.scroll_mark_onscreen (buf.get_insert ());
				buf.end_user_action ();
			} else {
				var vbuf = indent_engine.buffer;
				// indent every selected line
				var min_line = int.min (selection_start.get_line(), selection_end.get_line());
				var max_line = int.max (selection_start.get_line(), selection_end.get_line());
				for (var line=min_line; line <= max_line; line++) {
					TextIter iter;
					buf.get_iter_at_line (out iter, line);
					var viter = new UI.BufferIter (vbuf, iter);
					indent_engine.indent (viter);
				}
			}
		}
		
		void on_comment_region (Editor ed) {
			Comment comment_engine;
			var vbuf = new UI.Buffer ((SourceView) ed.view);
			var buf = (SourceBuffer) ed.view.buffer;
			var lang_id = buf.language != null ? buf.language.id : null;
			if (lang_id == null) {
				comment_engine = null;
			} else {
				switch (lang_id) {
				case "assembly (intel)":
				case "i386 assembly":
					comment_engine = new Comment_Asm (vbuf);
					break;
				case "sh":
				case "makefile":
				case "python":
					comment_engine = new Comment_Hash (vbuf);
					break;
				case "html":
				case "xml":
					comment_engine = new Comment_Markup (vbuf);
					break;
				case "lua":
				case "haskell":
					comment_engine = new Comment_Lua (vbuf);
					break;
				default:
					comment_engine = new Comment_Default (vbuf);
					break;
				}
			}

			if (comment_engine != null) {
				var iter_start = vbuf.line_at_char (selection_start.get_line (),
								      selection_start.get_line_offset ());
				var iter_end = vbuf.line_at_char (selection_end.get_line (),
								      selection_end.get_line_offset ());
				comment_engine.toggle_comment (iter_start, iter_end);
			}
		}

		void on_switch_buffer (Editor editor) {
			var sp = short_paths (editor.editor_container.get_files ());
			var bar = new SwitchBufferBar ((owned) sp);
			bar.activate.connect (() => {
					abort (editor);
					var file = bar.get_choice();
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

		async void eval_expression (Editor editor, string code) {
			try {
				var parser = new Vade.Parser.for_string (code);
				var expr = parser.parse_expression ();
				var val = yield get_editor_scope(editor).eval (expr, new Cancellable ());
				if (val != null) {
					set_status (val.to_string (), "eval");
				} else {
					clear_status ("eval");
				}
			} catch (Error e) {
				set_status_error (e.message, "eval");
			}
		}
		
		void on_eval_expression (Editor editor) {
			var bar = new EntryBar (last_vade_code);
			bar.activate.connect ((code) => {
					abort (editor);
					last_vade_code = code;
					eval_expression.begin (editor, code);
			});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
		}

		void on_goto_error (Editor editor, string cmd) {
			bool no_more_errors = true;
			if (error_locations != null) {	
				if (current_error == null) {
					current_error = error_locations;
					no_more_errors = false;
				} else {
					if (cmd == "prev-error") {
						if (current_error.prev != null) {
							current_error = current_error.prev;
							no_more_errors = false;
						}
					} else {
						if (current_error.next != null) {
							current_error = current_error.next;
							no_more_errors = false;
						}
					}
				}
			}

			if (no_more_errors) {
				set_status ("No more errors");
			} else {
				var loc = current_error.data;
				if (loc.file.query_exists ()) {
					open_location.begin (editor, loc);
					set_status_error (loc.get_data ("error-message"));
				} else {
					set_status_error ("File %s not found".printf (loc.file.get_path ()));
				}
			}
		}
		
		void on_repo_grep (Editor editor) {
			repo_grep.begin (editor);
		}
		
		async void repo_grep (Editor editor) {
			Git git = new Git (conf);
			var repo_dir = yield git.get_repo (editor.file);
			if (repo_dir == null) {
				set_status ("Not in git repository");
				return;
			}
			
			var git_command = conf.get_global_string ("git_command", "git");
			InputStream? stream = null;
			
			var bar = new GrepBar (this, conf, repo_dir, last_grep_string);
			bar.activate.connect (() => {
					abort (editor);
					var loc = bar.location;
					if (loc != null && loc.file != null) {
						open_location.begin (editor, loc);
					}
			});
			bar.changed.connect ((pat) => {
					last_grep_string = pat;
					clear_status ("repo-grep");
					
					if (stream != null) {
						try {
							stream.close ();
						} catch (Error e) {
						}
					}
					
					if (pat == "") {
						return;
					}
					
					int stdout, stderr;
					try {
						Process.spawn_async_with_pipes (repo_dir.get_path(),
										{git_command, "grep", "-inI", "--color", pat},
										null,
										SpawnFlags.SEARCH_PATH,
										null, null, null, out stdout, out stderr);
					} catch (Error e) {
						set_status_error (e.message, "repo-grep");
						return;
					}
					stream = new UnixInputStream (stdout, true);
					bar.stream = stream;
					
					read_all_async.begin (new UnixInputStream (stderr, true), null, (s,r) => {
							try {
								var res = read_all_async.end (r);
								var err = (string) res;
								err = err.strip ();
								if (err != "") {
									set_status_error (err, "repo-grep");
								}
							} catch (Error e) {
								set_status_error (e.message, "repo-grep");
							}
					});
			});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar, OverlayMode.PANE_BOTTOM);
			bar.show ();
			bar.grab_focus ();
		}

		void on_repo_open_file (Editor editor) {
			repo_open_file.begin (editor);
		}
			
		async void repo_open_file (Editor editor) {
			Git git = new Git (conf);
			var repo_dir = yield git.get_repo (editor.file);
			if (repo_dir == null) {
				set_status ("Not in git repository");
				return;
			}
			
			var git_command = conf.get_global_string ("git_command", "git");
			
			execute_shell_async.begin (repo_dir, @"$(git_command) ls-files", null, null, (s,r) => {
					string res;
					try {
						res = (string) execute_shell_async.end (r);
					} catch (Error e) {
						set_status_error (e.message, "repo-open-file");
						return;
					}
					
					var file_names = res.split ("\n");
					var annotated = new Annotated<File>[file_names.length];
					for (var i=0; i < file_names.length; i++) {
						annotated[i] = new Annotated<File> (file_names[i], repo_dir.get_child (file_names[i]));
					}
					
					var bar = new SimpleCompletionBar<File> ((owned) annotated);
					bar.activate.connect (() => {
							abort (editor);
							var file = bar.get_choice();
							if (file == editor.file) {
								// no-op
								return;
							}
							open_file.begin (editor, file);
					});
					bar.aborted.connect (() => { abort (editor); });
					add_overlay (bar);
					bar.show ();
					bar.grab_focus ();
			});
		}

		
		void on_split (Editor editor, string command) {
			// get bounding box of the editor
			Allocation alloc;
			editor.get_allocation (out alloc);
			// unparent the editor container
			var container = editor.editor_container;

			// create the GUI split
			var paned = new Paned (command == "split-add-right" ? Orientation.HORIZONTAL : Orientation.VERTICAL);
			paned.expand = true;
			// set the position of the split at half of the editor width/height
			paned.position = command == "split-add-right" ? alloc.width/2 : alloc.height/2;
			replace_widget (container, paned);

			// get an editor for the same file
			var ed = get_available_editor (editor.file);
			if (ed.get_parent() != null) {
				// ensure the new editor is unparented
				((Container) ed.get_parent ()).remove (ed);
			}
			// create a new container
			var newcontainer = new EditorContainer (ed);
			// inherit lru from existing editor
			newcontainer.lru = editor.editor_container.lru.copy ();

			// pack the old editor container
			paned.pack1 (container, true, false);

			// pack the new editor container
			paned.pack2 (newcontainer, true, false);	

			paned.show_all ();
			editor.grab_focus ();
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

			} else if (node is EditorContainer) {

				var e = (EditorContainer)node;

				if (!dir_up) {
					/* Focus the editor */
					e.editor.grab_focus();
				}
			}
		}

		void on_switch_editor (Editor ed, string command) {
			var paned = ed.get_parent().get_parent() as Paned;
			bool fwd = (command == "next-editor") ? true : false;

			if (paned == null) { 
				/* The curr editor is the root node! */
				return;
			}

			var lchild = paned.get_child1() as EditorContainer;

			if (lchild != null && ed == lchild.editor) { /* Left child */
				find_editor((Widget)paned, true, true, fwd);
			} else { /* Right child */
				find_editor((Widget)paned, true, false, fwd);
			}
		}

		void on_join_all (Editor editor) {
			// parent of editor is an editor container
			var paned = editor.editor_container.get_parent() as Paned;
			if (paned == null) {
				// already on front
				return;
			}
			
			var editor_container = editor.editor_container;
			((Container) editor_container.get_parent()).remove (editor_container);

			var children = editors_grid.get_children ();
			foreach (var child in children) {
				editors_grid.remove (child);
				detach_editors (child);
			}
			editors_grid.add (editor_container);
			editor.grab_focus ();
		}

		void on_join (Editor editor) {
			var paned = editor.editor_container.get_parent() as Paned;
			if (paned == null) {
				// already on front
				return;
			}
			var container = editor.editor_container;
			paned.remove (container);
			detach_editors (paned);
			replace_widget (paned, container);
			editor.grab_focus ();
		}

		void on_search_replace (Editor editor, string command) {
			SearchBar.Mode mode;
			bool is_regex;
			if (command.has_prefix ("search-forward")) {
				mode = SearchBar.Mode.SEARCH_FORWARD;
			} else if (command.has_prefix ("search-backward")) {
				mode = SearchBar.Mode.SEARCH_BACKWARD;
			} else if (command.has_prefix ("replace-forward")) {
				mode = SearchBar.Mode.REPLACE_FORWARD;
			} else {
				mode = SearchBar.Mode.REPLACE_BACKWARD;
			}
			is_regex = command.has_suffix ("-regexp");
			var bar = new SearchBar (this, editor, mode, is_regex, last_search_string, last_replace_string);
			bar.activate.connect (() => {
				last_search_string = bar.text;
				if (command.has_prefix ("replace")) {
					last_replace_string = bar.replace_text;
				}
				abort (editor);
			});
			bar.aborted.connect (() => {
				last_search_string = bar.text;
				if (command.has_prefix ("replace")) {
					last_replace_string = bar.replace_text;
				}
				abort (editor);
			});
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
		}

		void on_compile_shell (Editor editor, string cmd) {
			var bar = new ShellBar (this, editor);
			bar.aborted.connect (() => {
					abort (editor);
			});
			if (cmd == "compile-shell") {
				add_overlay (bar, OverlayMode.PANE_BOTTOM);
			} else if (cmd == "compile-shell-left") {
				add_overlay (bar, OverlayMode.PANE_LEFT);
			} else if (cmd == "compile-shell-right") {
				add_overlay (bar, OverlayMode.PANE_RIGHT);
			}
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
		void on_forward_backward_char (Editor ed, string command) {
			if (command == "forward-char") {
				ed.view.move_cursor (MovementStep.VISUAL_POSITIONS, 1, false);
			} else {
				ed.view.move_cursor (MovementStep.VISUAL_POSITIONS, -1, false);
			}
		}
		
		void on_zen_mode (Editor editor) {
			if (!zen_mode) {
				zen_mode = true;
				this.get_window().fullscreen();
			} else {
				zen_mode = false;
				this.get_window().unfullscreen();
			}
		}
		
		void on_update_copyright_year (Editor editor, string command) {
			var vbuf = new UI.Buffer ((SourceView) editor.view);
			if (update_copyright_year (vbuf)) {
				set_status ("Copyright year has been updated");
			} else if (command != "autoupdate-copyright-year") {
				set_status ("No copyright year to update");
			}
		}
		
		void on_toggle_autoupdate_copyright_year (Editor editor) {
			var autoupdate_copyright_year = !conf.get_global_bool ("autoupdate_copyright_year");
			conf.set_global_bool ("autoupdate_copyright_year", autoupdate_copyright_year);
			
			set_status (autoupdate_copyright_year ? "Enabled" : "Disabled");
		}
		
		void on_about (Editor editor) {
			var bar = new AboutBar ();
			bar.aborted.connect (() => {
					main_box.remove (bar);
					main_box.add (editors_grid);
					editor.grab_focus ();
			});
			main_box.remove (editors_grid);
			main_box.add (bar);
			bar.grab_focus ();
		}
		
		void on_toggle_git_gutter (Editor editor) {
			var val = !conf.get_editor_bool ("git_gutter", true);
			conf.set_editor_bool ("git_gutter", val);
			set_status (val ? "Enabled" : "Disabled");
			each_editor ((ed) => {
					ed.on_git_gutter();
					return true;
			});
		}
		
		void on_toggle_show_branch (Editor editor) {
			var val = !conf.get_editor_bool ("show_branch", false);
			conf.set_editor_bool ("show_branch", val);
			set_status (val ? "Enabled" : "Disabled");
			each_editor ((ed) => {
					ed.update_show_branch ();
					return true;
			});
		}
	}

	public class Application : Gtk.Application {
		public Application () {
			Object (application_id: "org.vanubi", flags: ApplicationFlags.HANDLES_OPEN);
		}

		Window new_window () {
			var is_main_window = get_active_window () == null;
			var provider = new CssProvider ();
			
			var slm = SourceLanguageManager.get_default();
			var search_path = slm.get_search_path();
			search_path += "./data/languages/";	     
			search_path += Configuration.VANUBI_DATADIR + "/vanubi/languages";
			slm.set_search_path (search_path);
			
			try {
				provider.load_from_path ("./data/vanubi.css");
			} catch (Error e) {
				try {
					provider.load_from_path (Configuration.VANUBI_DATADIR + "/vanubi/css/vanubi.css");
				} catch (Error e) {
					warning ("Could not load vanubi css: %s", e.message);
				}
			}
			StyleContext.add_provider_for_screen (Gdk.Screen.get_default(), provider, STYLE_PROVIDER_PRIORITY_USER);

			var manager = new Manager ();

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
				
				// global keybinding
				Keybinder.init ();
				Keybinder.bind (manager.conf.get_global_string ("global_keybinding", "<Ctrl><Mod1>v"), () => { focus_window (win); });
			} 
			try {
				win.icon = new Gdk.Pixbuf.from_file("./data/vanubi.png");
			} catch (Error e) {
				try {
					win.icon = new Gdk.Pixbuf.from_file(Configuration.VANUBI_DATADIR + "/vanubi/logo/vanubi.png");
				} catch (Error e) {
					warning ("Could not load vanubi icon: %s", e.message);
				}
			}

			manager.quit.connect (() => { remove_window (win); win.destroy (); });
			win.add (manager);

			win.show_all ();
			add_window (win);

			return win;
		}

		void focus_window (Window w) {
			// update wnck
			var wnscreen = Wnck.Screen.get_default ();
			wnscreen.force_update ();
			
			// get wnck window
			var xid = Gdk.X11Window.get_xid (w.get_window());
			weak Wnck.Window wnw = Wnck.Window.get (xid);
			if (wnw != null) {
				wnw.get_workspace().activate (Keybinder.get_current_event_time ());
				wnw.activate (Keybinder.get_current_event_time ());
			} else {
				// fallback, we cannot switch workspace though
				w.present_with_time (Keybinder.get_current_event_time ());
			}
		}
		
		public override void open (File[] files, string hint) {
			var win = get_active_window ();
			if (win == null) {
				win = new_window ();
			}
			var manager = (Manager) win.get_child ();
			manager.open_file.begin (manager.get_first_visible_editor (), files[0]);
			win.present ();
		}

		protected override void activate () {
			new_window ();
		}
	}

	public static int main (string[] args) {
		Gdk.threads_init ();
		var app = new Application ();
		return app.run (args);
	}
}
