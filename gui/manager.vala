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
	public class Manager : Grid {
		public State state;
		
		/* List of data sources opened. Work on unique DataSource instances. */
		HashTable<DataSource, DataSource> sources = new HashTable<DataSource, DataSource> (DataSource.hash, DataSource.equal);

		internal KeyManager keymanager;
		internal KeyHandler keyhandler;
		// Editor selection before calling a command
		int selection_start;
		int selection_end;

		bool saving_on_quit = false;

		[Signal (detailed = true)]
		public signal void execute_command (Editor editor, string command);

		public signal void quit ();

		public Configuration conf;
		public Vade.Scope base_scope; // Scope for user global variables
		public List<Location<string>> error_locations = new List<Location> ();
		public unowned List<Location<string>> current_error = null;
		EventBox main_box;
		public Layout current_layout;
		EventBox layout_wrapper;
		StatusBar statusbar;
		MarkManager marks = new MarkManager ();
		RemoteFileServer remote = null;
		CssProvider current_css = null;

		Session last_session;

		class KeysWrapper {
			public Key[] keys;

			public KeysWrapper (Key[] keys) {
				this.keys = keys;
			}
		}

		HashTable<string, KeysWrapper> default_shortcuts = new HashTable<string, KeysWrapper> (str_hash, str_equal);

		HashTable<string, History> entry_history_map = new HashTable<string, History> (str_hash, str_equal);

		List<Layout> layouts = null;
		
		public Manager () {
			conf = new Configuration ();
			state = new State (conf);
			state.status.changed.connect (on_status_changed);
			
			orientation = Orientation.VERTICAL;
			
			keymanager = new KeyManager (conf);
			keymanager.execute_command.connect (on_command);
			keyhandler = new KeyHandler (keymanager);
			
			base_scope = Vade.create_base_scope ();
			last_session = conf.get_session ();
			var style_manager = SourceStyleSchemeManager.get_default ();
			style_manager.set_search_path (get_styles_search_path ());
			set_theme (conf.get_global_string ("theme", "zen"));

			// placeholder for the editors grid
			main_box = new EventBox();
			main_box.expand = true;
			add (main_box);

			// status bar
			statusbar = new StatusBar ();
			statusbar.margin_left = 10;
			statusbar.expand = false;
			statusbar.set_alignment (0.0f, 0.5f);
			var statusbox = new EventBox ();
			statusbox.expand = false;
			statusbox.add (statusbar);
			add (statusbox);

			// setup languages index
			var lang_manager = SourceLanguageManager.get_default ();
			foreach (unowned string lang_id in lang_manager.language_ids) {
				var lang = lang_manager.get_language (lang_id);
				state.lang_index.index_document (new StringSearchDocument (lang_id, {lang.name, lang.section}));
			}

			// setup search index synonyms
			state.command_index.synonyms["exit"] = "quit";
			state.command_index.synonyms["buffer"] = "file";
			state.command_index.synonyms["editor"] = "file";
			state.command_index.synonyms["switch"] = "change";
			state.command_index.synonyms["search"] = "find";
			state.command_index.synonyms["toggle"] = "enable";
			state.command_index.synonyms["toggle"] = "disable";
			state.command_index.synonyms["layout"] = "splits";

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

			bind_command (null, "open-file-right");
			index_command ("open-file-right", "Split buffer and open file for reading in right view");
			execute_command["open-file-right"].connect (on_open_file);

			bind_command (null, "open-file-down");
			index_command ("open-file-down", "Split buffer and open file for reading in bottom view");
			execute_command["open-file-down"].connect (on_open_file);

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

			bind_command ({ Key (Gdk.Key.d, Gdk.ModifierType.MOD1_MASK) }, "delete-word-forward");
			index_command ("delete-word-forward", "Delete the word next to the cursor");
			execute_command["delete-word-forward"].connect (on_delete_word_forward);

			bind_command ({ Key (Gdk.Key.BackSpace, Gdk.ModifierType.SHIFT_MASK) }, "delete-white-backward");
			index_command ("delete-white-backward", "Delete whitespaces and empty lines backwards");
			execute_command["delete-white-backward"].connect (on_delete_white_backward);
			
			bind_command ({ Key (Gdk.Key.Tab, 0) }, "indent");
			index_command ("indent", "Indent the current line");
			execute_command["indent"].connect (on_indent);

			bind_command ({
					Key (Gdk.Key.c, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.c, Gdk.ModifierType.CONTROL_MASK) },
				"comment-lines");
			bind_command ({
					Key (Gdk.Key.c, Gdk.ModifierType.CONTROL_MASK),
						Key (Gdk.Key.Return, Gdk.ModifierType.CONTROL_MASK) },
				"comment-lines");
			index_command ("comment-lines", "Comment selected lines");
			execute_command["comment-lines"].connect (on_comment_lines);

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

			bind_command ({ Key (Gdk.Key.v, Gdk.ModifierType.CONTROL_MASK) }, "paste");
			index_command ("paste", "Paste text from clipboard");
			execute_command["paste"].connect (on_paste);

			index_command ("set-theme", "Switch color style of the editor");
			execute_command["set-theme"].connect (on_set_theme);
			
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
					Key (Gdk.Key.l, Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK) }, "next-layout");
			index_command ("next-layout", "Move to the next layout", "cycle right splits");
			execute_command["next-layout"].connect (on_switch_layout);

			bind_command ({
					Key (Gdk.Key.j, Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK) }, "prev-layout");
			index_command ("prev-layout", "Move to the previous layout", "cycle right splits");
			execute_command["prev-layout"].connect (on_switch_layout);

			bind_command ({
					Key (Gdk.Key.k, Gdk.ModifierType.SHIFT_MASK | Gdk.ModifierType.CONTROL_MASK) }, "kill-layout");
			index_command ("kill-layout", "Kill the current layout");
			execute_command["kill-layout"].connect (on_kill_layout);
			
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

			bind_command ({ Key (Gdk.Key.n, Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.SHIFT_MASK) }, "forward-line-select");
			index_command ("forward-line-select", "Select text from the cursor to one line forward");
			execute_command["forward-line-select"].connect (on_forward_backward_line);

			bind_command ({	Key (Gdk.Key.p, Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.SHIFT_MASK) }, "backward-line-select");
			index_command ("backward-line-select", "Select text from the cursor to one line backward");
			execute_command["backward-line-select"].connect (on_forward_backward_line);

			bind_command ({ Key (Gdk.Key.f, Gdk.ModifierType.CONTROL_MASK) }, "forward-char");
			index_command ("forward-char", "Move the cursor one character forward");
			execute_command["forward-char"].connect (on_forward_backward_char);

			bind_command ({ Key (Gdk.Key.b, Gdk.ModifierType.CONTROL_MASK) }, "backward-char");
			index_command ("backward-char", "Move the cursor one character backward");
			execute_command["backward-char"].connect (on_forward_backward_char);

			bind_command ({ Key (Gdk.Key.f, Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.SHIFT_MASK) }, "forward-char-select");
			index_command ("forward-char-select", "Select the char next to the cursor");
			execute_command["forward-char-select"].connect (on_forward_backward_char);

			bind_command ({ Key (Gdk.Key.b, Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.SHIFT_MASK) }, "backward-char-select");
			index_command ("backward-char-select", "Select the char before the cursor");
			execute_command["backward-char-select"].connect (on_forward_backward_char);

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

			bind_command ({ Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
							Key (Gdk.Key.a, 0) }, "select-all");
			index_command ("select-all", "Select all the text");
			execute_command["select-all"].connect (on_select_all);

			bind_command ({ Key (Gdk.Key.space, Gdk.ModifierType.CONTROL_MASK) }, "abbrev-complete");
			index_command ("abbrev-complete", "Complete the current text based on words in the buffer");
			execute_command["abbrev-complete"].connect (on_abbrev_complete);

			bind_command ({ Key (Gdk.Key.e, Gdk.ModifierType.CONTROL_MASK) }, "end-line");
			bind_command ({ Key (Gdk.Key.End, 0) }, "end-line");
			index_command ("end-line", "Move the cursor to the end of the line");
			execute_command["end-line"].connect (on_end_line);
			
			bind_command ({ Key (Gdk.Key.e, Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.SHIFT_MASK) }, "end-line-select");
			bind_command ({ Key (Gdk.Key.End, Gdk.ModifierType.SHIFT_MASK) }, "end-line-select");
			index_command ("end-line-select", "Move the cursor to the end of the line, extending the selection");
			execute_command["end-line-select"].connect (on_end_line);

			bind_command ({ Key (Gdk.Key.a, Gdk.ModifierType.CONTROL_MASK) }, "start-line");
			bind_command ({ Key (Gdk.Key.Home, 0) }, "start-line");
			index_command ("start-line", "Move the cursor to the start of the line");
			execute_command["start-line"].connect (on_start_line);

			bind_command ({ Key (Gdk.Key.a, Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.SHIFT_MASK) }, "start-line-select");
			bind_command ({ Key (Gdk.Key.Home, Gdk.ModifierType.SHIFT_MASK) }, "start-line-select");
			index_command ("start-line-select", "Move the cursor to the start of the line, extending the selection");
			execute_command["start-line-select"].connect (on_start_line);
			
			bind_command ({ Key (Gdk.Key.f, Gdk.ModifierType.MOD1_MASK) }, "forward-word");
			execute_command["forward-word"].connect (on_move_word);

			bind_command ({ Key (Gdk.Key.b, Gdk.ModifierType.MOD1_MASK) }, "backward-word");
			execute_command["backward-word"].connect (on_move_word);
			
			bind_command ({ Key (Gdk.Key.f, Gdk.ModifierType.MOD1_MASK|Gdk.ModifierType.SHIFT_MASK) }, "forward-word-select");
			execute_command["forward-word-select"].connect (on_move_word);

			bind_command ({ Key (Gdk.Key.b, Gdk.ModifierType.MOD1_MASK|Gdk.ModifierType.SHIFT_MASK) }, "backward-word-select");
			execute_command["backward-word-select"].connect (on_move_word);

			bind_command ({ Key (Gdk.Key.Down, Gdk.ModifierType.CONTROL_MASK) }, "move-block-down");
			bind_command ({ Key (Gdk.Key.n, Gdk.ModifierType.MOD1_MASK) }, "move-block-down");
			execute_command["move-block-down"].connect (on_move_block);

			bind_command ({ Key (Gdk.Key.Up, Gdk.ModifierType.CONTROL_MASK) }, "move-block-up");
			bind_command ({ Key (Gdk.Key.p, Gdk.ModifierType.MOD1_MASK) }, "move-block-up");
			execute_command["move-block-up"].connect (on_move_block);

			bind_command ({ Key (Gdk.Key.Down, Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.SHIFT_MASK) }, "select-block-down");
			bind_command ({ Key (Gdk.Key.n, Gdk.ModifierType.MOD1_MASK|Gdk.ModifierType.SHIFT_MASK) }, "select-block-down");
			execute_command["select-block-down"].connect (on_move_block);

			bind_command ({ Key (Gdk.Key.Up, Gdk.ModifierType.CONTROL_MASK|Gdk.ModifierType.SHIFT_MASK) }, "select-block-up");
			bind_command ({ Key (Gdk.Key.p, Gdk.ModifierType.MOD1_MASK|Gdk.ModifierType.SHIFT_MASK) }, "select-block-up");
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
			index_command ("set-tab-width", "Tab width for this file, expressed in number of spaces, also used for indentation");
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

			bind_command (null, "reload-all-files");
			index_command ("reload-all-files", "Reopen all the files that have been changed");
			execute_command["reload-all-files"].connect (on_reload_all_files);

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

			bind_command ({ Key (Gdk.Key.u, Gdk.ModifierType.CONTROL_MASK) }, "copy-line-up");
			index_command ("copy-line-up", "Duplicate the current line above");
			execute_command["copy-line-up"].connect (on_copy_line);

			bind_command ({ Key (Gdk.Key.x, Gdk.ModifierType.CONTROL_MASK),
							Key (Gdk.Key.u, Gdk.ModifierType.CONTROL_MASK) }, "copy-line-down");
			index_command ("copy-line-down", "Duplicate the current line below");
			execute_command["copy-line-down"].connect (on_copy_line);

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

			bind_command (null, "toggle-auto-add-endline");
			index_command ("toggle-auto-add-endline", "Auto add a newline at the end of the text");
			execute_command["toggle-auto-add-endline"].connect (on_toggle_auto_add_endline);

			bind_command (null, "toggle-atomic-save");
			index_command ("toggle-atomic-save", "Whether to save files atomically");
			execute_command["toggle-atomic-save"].connect (on_toggle_atomic_save);

			bind_command (null, "toggle-indent-mode");
			index_command ("toggle-indent-mode", "Use spaces or tabs for indentation in this file");
			execute_command["toggle-indent-mode"].connect (on_toggle_indent_mode);

			bind_command (null, "about");
			index_command ("about", "About");
			execute_command["about"].connect (on_about);

			bind_command (null, "toggle-git-gutter");
			index_command ("toggle-git-gutter", "Git diff left sidebar");
			execute_command["toggle-git-gutter"].connect (on_toggle_git_gutter);

			bind_command (null, "toggle-show-branch");
			index_command ("toggle-show-branch", "Show the repository branch in the file info bar");
			execute_command["toggle-show-branch"].connect (on_toggle_show_branch);

			bind_command (null, "toggle-right-margin");
			index_command ("toggle-right-margin", "Show the columns limit delimiter");
			execute_command["toggle-right-margin"].connect (on_toggle_right_margin);

			bind_command (null, "set-right-margin-column");
			index_command ("set-right-margin-column", "Set right margin column size");
			execute_command["set-right-margin-column"].connect (on_set_right_margin_column);

			bind_command (null, "toggle-trailing-spaces");
			index_command ("toggle-trailing-spaces", "Show trailing spaces");
			execute_command["toggle-trailing-spaces"].connect (on_toggle_trailing_spaces);

			bind_command (null, "toggle-auto-clean-trailing-spaces");
			index_command ("toggle-auto-clean-trailing-spaces", "Automatically clean trailing spaces while editing");
			execute_command["toggle-auto-clean-trailing-spaces"].connect (on_toggle_auto_clean_trailing_spaces);

			bind_command (null, "clean-trailing-spaces");
			index_command ("clean-trailing-spaces", "Clean trailing spaces in the selection/buffer");
			execute_command["clean-trailing-spaces"].connect (on_clean_trailing_spaces);

			bind_command (null, "toggle-remote-file-server");
			index_command ("toggle-remote-file-server", "Service for opening files remotely with vsh and van");
			execute_command["toggle-remote-file-server"].connect (on_toggle_remote_file_server);

			bind_command (null, "toggle-show-tabs");
			index_command ("toggle-show-tabs", "Toggle show tab in the editor");
			execute_command["toggle-show-tabs"].connect (on_toggle_show_tabs);

			current_layout = new Layout ();
			layouts.append (current_layout);
			layout_wrapper = new EventBox ();
			layout_wrapper.expand = true;
			layout_wrapper.add (current_layout);

			// setup empty buffer
			unowned Editor ed = get_available_editor (ScratchSource.instance);
			var container = new EditorContainer (ed);
			container.lru.append (ScratchSource.instance);

			// main layout
			current_layout.add (container);
			current_layout.views = 1;
			current_layout.last_focused_editor = ed;
			main_box.add (layout_wrapper);

			container.grab_focus ();

			// remote file server
			try {
				remote = new RemoteFileServer (conf);
				remote.stop ();
			} catch (Error e) {
				state.status.set ("Could not start the remote server: "+e.message, "remote", Status.Type.ERROR);
			}

			check_remote_file_server ();
		}

		public string new_stdin_stream_name () {
			return "*stdin %d*".printf (state.next_stream_id++);
		}

		void check_remote_file_server () {
			var flag = conf.get_global_bool ("remote_file_server", true);
			if (flag && remote == null) {
				try {
					remote = new RemoteFileServer (conf);
					remote.open_file.connect (on_remote_open_file);
					remote.start ();
				} catch (Error e) {
					state.status.set ("Could not start the remote server: "+e.message, "remote", Status.Type.ERROR);
				}
			} else if (!flag && remote != null) {
				remote.stop ();
				remote = null;
			}
		}

		public void on_status_changed () {
			statusbar.set_markup (state.status.text);
			if (state.status.status_type == Status.Type.NORMAL) {
				statusbar.get_style_context().remove_class ("error");
			} else {
				statusbar.get_style_context().add_class ("error");
			}
		}

		public Annotated<string>[] get_themes () {
			Annotated<string>[] themes = { new Annotated<string> ("zen", "zen"),
										   new Annotated<string> ("tango", "tango") };
			Dir dir;
			try {
				dir = Dir.open ("~/.local/share/vanubi/css");
			} catch {
				return themes;
			}
			
			unowned string filename = null;
			while ((filename = dir.read_name ()) != null) {
				if (filename.has_suffix (".css")) {
					var theme = filename.substring (0, filename.length-4);
					themes += new Annotated<string> (theme, theme);
				}
			}
			return themes;
		}
		
		public bool set_theme (string theme) {
			/* css */
			var provider = new CssProvider ();
			try {
				provider.load_from_path ("~/.local/share/vanubi/css/%s.css".printf (theme));
			} catch (Error e) {
				try {
					provider.load_from_path ("./data/css/%s.css".printf (theme));
				} catch (Error e) {
					try {
						provider.load_from_path (Configuration.VANUBI_DATADIR + "/vanubi/css/%s.css".printf (theme));
					} catch (Error e) {
						state.status.set ("Could not load %s css: %s".printf (theme, e.message), "theme", Status.Type.ERROR);
						return false;
					}
				}
			}

			/* source style */
			var style_manager = SourceStyleSchemeManager.get_default ();
			var source_style = style_manager.get_scheme (theme);
			if (source_style == null) {
				state.status.set ("Sourceview style %s not found".printf (theme), "theme", Status.Type.ERROR);
				return false;
			}

			/* apply css */
			if (current_css != null) {
				StyleContext.remove_provider_for_screen (Gdk.Screen.get_default(), current_css);
			}

			StyleContext.add_provider_for_screen (Gdk.Screen.get_default(), provider, STYLE_PROVIDER_PRIORITY_APPLICATION);
			current_css = provider;

			/* apply sourceview style */
			each_editor ((ed) => {
					((SourceBuffer)ed.view.buffer).style_scheme = source_style;
					return true;
			});

			StyleContext.reset_widgets (Gdk.Screen.get_default());
			return true;
		}
		
		public void update_selection (Editor ed) {
			var buf = ed.view.buffer;
			TextIter start, end;
			buf.get_selection_bounds (out start, out end);
			selection_start = start.get_offset ();
			selection_end = end.get_offset ();
		}

		public void on_command (Object subject, string command, bool use_old_state) {
			var ed = (Editor) subject;
			
			if (!use_old_state) {
				update_selection (ed);
			}
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

			main_box.remove (layout_wrapper);
			if (mode == OverlayMode.PANE_BOTTOM) {
				var p = new Paned (Orientation.VERTICAL);
				p.expand = true;
				p.pack1 (layout_wrapper, true, false);
				p.pack2 (widget, true, false);
				p.position = alloc.height*2/3;
				main_box.add (p);
				p.show_all ();
			} else if (mode == OverlayMode.PANE_LEFT) {
				var p = new Paned (Orientation.HORIZONTAL);
				p.expand = true;
				p.pack1 (widget, true, false);
				p.pack2 (layout_wrapper, true, false);
				p.position = alloc.width/2;
				main_box.add (p);
				p.show_all ();
			} else if (mode == OverlayMode.PANE_RIGHT) {
				var p = new Paned (Orientation.HORIZONTAL);
				p.expand = true;
				p.pack1 (layout_wrapper, true, false);
				p.pack2 (widget, true, false);
				p.position = alloc.width/2;
				main_box.add (p);
				p.show_all ();
			} else {
				var grid = new Grid ();
				grid.orientation = Orientation.VERTICAL;
				grid.add (layout_wrapper);
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
			state.command_index.index_document (doc);
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
					state.status.set (e.message, null, Status.Type.ERROR);
				}
			}

			// bother only if there's actually a shortcut for the command
			if (keyseq.length > 0) {
				keymanager.bind_command (keyseq, cmd);
			}
		}

		public History<string> get_entry_history (string name) {
			History<string>? hist = entry_history_map[name];
			if (hist == null) {
				hist = new History<string> (str_equal, conf.get_global_int ("entry_history_limit", 1000));
				entry_history_map[name] = hist;
			}
			return hist;
		}			
		
		public void attach_entry_history (Entry entry, History<string> hist) {
			new EntryHistory (hist, entry);
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

		public async void replace_editor_contents (Editor ed, InputStream is, bool undoable = false, int io_priority = GLib.Priority.LOW, owned Cancellable? cancellable = null) throws Error {
			yield ed.replace_contents (is, undoable, io_priority, cancellable);

			// reload user marks
			Idle.add (() => {
					foreach (var loc in marks.list ()) {
						if (loc.source != null) {
							each_source_editor (loc.source, (e) => {
									loc.set_data ("start-mark", null);
									loc.set_data ("end-mark", null);
									get_start_mark_for_location (loc, e.view.buffer);
									get_end_mark_for_location (loc, e.view.buffer);
									return false; // the first editor is enough
							});
						}
					}
					return false;
			});
		}

		public async void open_source (Editor editor, owned DataSource source, bool focus = true) {
			yield open_location (editor, new Location (source), focus);
		}

		public async void open_location (Editor editor, owned Location location, bool focus = true) {
			var source = location.source;

			// first search already opened sources
			var s = sources[source];
			if (s != null) {
				source = s; // normalize

				unowned Editor ed;
				if (source != editor.source) {
					ed = get_available_editor (source);
					if (focus) {
						replace_widget (editor, ed);
					}
				} else {
					ed = editor;
				}

				if (ed.set_location (location)) {
					var prio = focus ? Priority.HIGH : Priority.DEFAULT;
					Idle.add_full (prio, () => { ed.view.scroll_to_mark (ed.view.buffer.get_insert (), 0, true, 0.5, 0.5); return false; });
				}

				if (focus) {
					ed.grab_focus ();
				}
				return;
			}

			// if the source is unreadable, don't try to read it
			try {
				var exists = yield source.exists ();
				if (!exists) {
					unowned Editor ed = get_available_editor (source);
					if (focus) {
						replace_widget (editor, ed);
						ed.grab_focus ();
					}
					return;
				}
			} catch (IOError.CANCELLED e) {
				return;
			} catch (Error e) {
				state.status.set (e.message, null, Status.Type.ERROR);
				return;
			}

			// existing source, read it
			try {
				var is = yield source.read ();
				var ed = get_available_editor (source);
				if (focus) {
					replace_widget (editor, ed);
					ed.grab_focus ();
				}

				yield replace_editor_contents (ed, is);
				is.close ();

				var buf = ed.view.buffer;
				if (location.start_line < 0) {
					location.start_line = location.start_column = 0;
				}
				if (!(location.start_line == 0 && location.start_column == 0)) {
					if (ed.set_location (location)) {
						var prio = focus ? Priority.HIGH : Priority.DEFAULT;
						Idle.add_full (prio, () => { ed.view.scroll_to_mark (buf.get_insert (), 0, true, 0.5, 0.5); return false; });
					}
				}
			} catch (IOError.CANCELLED e) {
			} catch (Error e) {
				state.status.set (e.message, null, Status.Type.ERROR);
			}
		}

		public void abort (Editor editor) {
			keymanager.reset ();
			if (main_box.get_child() == layout_wrapper) {
				return;
			}
			state.status.clear ();

			var parent = (Container) layout_wrapper.get_parent();
			parent.remove (layout_wrapper);
			main_box.remove (main_box.get_child ());
			main_box.add (layout_wrapper);
			editor.grab_focus ();
		}

		/* File/Editor/etc. COMBINATORS */

		// iterate all data sources and perform the given operation on each of them
		public bool each_source (Operation<DataSource> op, bool include_scratch = true) {
			foreach (var source in sources.get_keys ()) {
				if (source is ScratchSource) {
					if (include_scratch) {
						if (!op (source)) {
							return false;
						}
					}
				} else if (!op (source)) {
					return false;
				}
			}
			return true;
		}

		public bool each_file (Operation<FileSource> op) {
			return each_source ((s) => {
					if (s is FileSource && !op ((FileSource) s)) {
						return false;
					}
					return true;
			});
		}

		// iterate all editors of a given source and perform the given operation on each of them
		public bool each_source_editor (DataSource source, Operation<Editor> op) {
			unowned GenericArray<Editor> editors;
			source = sources[source]; // normalize
			if (source == null) {
				return true;
			}

			editors = source.get_data ("editors");
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
			return each_source ((s) => {
					return each_source_editor (s, (ed) => {
							return op (ed);
					});
			}, include_scratch);
		}

		// iterate all editor containers and perform the given operation on each of them
		public bool each_editor_container (Operation<EditorContainer> op) {
			var looked = new EditorContainer[0];
			return each_editor ((ed) => {
					var container = ed.get_parent() as EditorContainer;
					if (container != null && !(container in looked)) {
						if (!op (container)) {
							return false;
						}
						looked += container;
					}
					return true;
			});
		}

		// iterate lru of all EditorContainer and perform the given operation on each of them
		public bool each_lru (Operation<LRU<DataSource>> op) {
			return each_editor_container ((c) => {
					return op (c.lru);
			});
		}

		/* Returns an Editor for the given file */
		unowned Editor get_available_editor (DataSource source, Layout? in_layout = null) {
			if (in_layout == null) {
				in_layout = current_layout;
			}
			
			// list of editors for the file
			unowned GenericArray<Editor> editors;
			var s = sources[source];
			if (s == null) {
				// update lru of all existing containers
				each_lru ((lru) => { lru.append (source); return true; });

				// this is a new source
				sources[source] = source;
				if (source is FileSource) {
					conf.cluster.opened_file ((FileSource) source);
				}
				var etors = new GenericArray<Editor> ();
				editors = etors;
				// store editors in the Source itself
				source.set_data ("editors", (owned) etors);
			} else {
				// get the editors of the source
				source = s; // normalize
				editors = source.get_data ("editors");
			}

			// first find an editor that is not visible in the current layout, so we can reuse it
			foreach (unowned Editor ed in editors.data) {
				if (!ed.visible && in_layout == ed.parent_layout) {
					return ed;
				}
			}

			// no editor reusable, so create one
			var ed = new Editor (this, conf, source);
			ed.parent_layout = in_layout;
			ed.view.key_press_event.connect (on_key_press_event);
			ed.view.scroll_event.connect (on_scroll_event);
			if (editors.length > 0) {
				// share TextBuffer with an existing editor for this file,
				// so that they display the same content
				ed.view.buffer = editors[0].view.buffer;
			} else {
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
					Location loc = null;
					each_source_editor (f, (ed) => {
							loc = ed.get_location ();
							// just take the first editor
							return false;
					});
					session.locations.add (loc);
					return true;
			});
			session.focused_location = ed.get_location ();
			conf.save_session (session, name);
			conf.save ();
		}

		/* events */

		const uint[] skip_keyvals = {Gdk.Key.Control_L, Gdk.Key.Control_R,
									 Gdk.Key.Shift_L, Gdk.Key.Shift_R,
									 Gdk.Key.Alt_L, Gdk.Key.Alt_R};
		bool on_key_press_event (Widget w, Gdk.EventKey e) {
			state.status.start_timeout ();

			var sv = (SourceView) w;
			Editor editor = sv.get_data ("editor");
			update_selection (editor);

			bool is_abort;
			var res = keyhandler.key_press_event (editor, e, out is_abort);
			if (is_abort) {
				state.status.clear ();
				abort (editor);
				return true;
			}
			return res;
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
				conf.save ();
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
						state.status.set ("Session %s saved".printf (name), "sessions");
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
				state.status.set ("Session not found", "sessions");
			} else {
				/* Load the first file */
				FileSource? focused_file = null;
				if (session.focused_location != null) {
					focused_file = session.focused_location.source as FileSource;
					yield open_location (editor, session.focused_location);
				}

				foreach (unowned Location loc in session.locations.data) {
					if (focused_file == null || !loc.source.equal (focused_file)) {
						open_location.begin (editor, loc, false);
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
						conf.save ();
						state.status.set ("Session %s deleted".printf (name), "sessions");
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
			state.status.set ("Mark saved", "marks");
		}

		void on_unmark (Editor editor) {
			if (!marks.unmark ()) {
				state.status.set ("No mark to be deleted", "marks");
			} else {
				state.status.set ("Mark deleted", "marks");
			}
		}

		void on_clear_marks (Editor editor) {
			marks.clear ();
			state.status.set ("Marks cleared", "marks");
		}

		void on_goto_mark (Editor editor, string command) {
			Location? loc;
			if (command == "next-mark") {
				loc = marks.next_mark ();
			} else {
				loc = marks.prev_mark ();
			}

			if (loc == null) {
				state.status.set ("No more marks", "marks");
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
						unowned GenericArray<Editor> editors = editor.source.get_data("editors");
						foreach (unowned Editor ed in editors.data) {
							((SourceBuffer) ed.view.buffer).set_language (lang);
						}
						if (editor.source is FileSource) {
							conf.set_file_string ((FileSource) editor.source, "language", lang_id);
						}
					} else {
						if (editor.source is FileSource) {
							conf.remove_file_key ((FileSource) editor.source, "language");
						}
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
			var old_offset = selection_start;
			try {
				var exists = yield editor.source.exists ();
				if (!exists && editor.moved_to != null) {
					var loc = editor.get_location ();
					loc.source = editor.moved_to;
					kill_source (editor.source);
					var focused = current_layout.last_focused_editor;
					yield open_location (focused, loc);
				} else {
					var is = yield editor.source.read ();
					yield replace_editor_contents (editor, is);
					is.close ();
					
					TextIter iter;
					var buf = editor.view.buffer;
					buf.get_iter_at_offset (out iter, old_offset);
					buf.place_cursor (iter);
					editor.view.scroll_mark_onscreen (buf.get_insert ());
					
					// in case of splitted editors
					each_source_editor (editor.source, (ed) => {
							ed.reset_external_changed.begin ();
							return true;
					});
				}
			} catch (IOError.CANCELLED e) {
			} catch (IOError.NOT_SUPPORTED e) {
			} catch (Error e) {
				state.status.set (e.message, null, Status.Type.ERROR);
			}
		}

		void on_reload_all_files (Editor editor) {
			each_source ((s) => {
					each_source_editor (s, (ed) => {
							// only the first editor, the buffer is shared
							if (ed.is_externally_changed ()) {
								reload_file.begin (ed);
							}
							return false;
					});
					return true;
			}, false);
		}

		void on_open_file (Editor editor, string command) {
			var base_source = editor.source.parent as FileSource;
			if (base_source == null) {
				return;
			}

			var bar = new FileBar (base_source);
			bar.activate.connect ((p) => {
					abort (editor);
					var source = base_source.root.child (absolute_path (base_source.local_path, p));
					if (command == "open-file-right") {
						var ed = split_views (editor, Orientation.HORIZONTAL);
						open_source.begin (ed, source);
					} else if (command == "open-file-down") {
						var ed = split_views (editor, Orientation.VERTICAL);
						open_source.begin (ed, source);
					} else {
						open_source.begin (editor, source);
					}
				});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
		}

		void on_save_file (Editor editor) {
			if (editor.source is ScratchSource) {
				// save scratch buffer to another file
				execute_command["save-as-file-and-open"] (editor, "save-as-file-and-open");
			} else {
				save_file.begin (editor);
			}
		}

		void on_save_as_file (Editor editor, string command) {
			var base_source = editor.source.parent as FileSource;
			if (base_source == null) {
				return;
			}
			
			var bar = new FileBar (base_source);
			bar.activate.connect ((f) => {
					abort (editor);
					var source = base_source.root.child (absolute_path (base_source.local_path, f));
					save_file.begin (editor, source, command == "save-as-file-and-open");
			});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
		}

		async void save_file (Editor editor, DataSource? as_source = null, bool open_as_source = false) {
			var buf = editor.view.buffer;
			if (as_source == null) {
				as_source = editor.source;
			}

			if (as_source == null) {
				return;
			}

			if (!(buf.get_modified () || !as_source.equal (editor.source))) {
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
				yield as_source.write (text.data, conf.get_global_bool ("atomic_file_save", true));
				if (as_source.equal (editor.source)) {
					buf.set_modified (false);
					yield editor.reset_external_changed ();
				} else {
					state.status.set ("Saved as %s".printf (as_source.to_string ()));
					if (open_as_source) {
						yield open_source (editor, as_source);
					}
				}
			} catch (Error e) {
				state.status.set (e.message, null, Status.Type.ERROR);
			}
		}

		// Destroy this source from vanubi
		void kill_source (DataSource source) {
			if (source is ScratchSource) {
				return;
			}
			
			GenericArray<Editor> editors = source.get_data ("editors");
			foreach (var ed in editors.data) {
				if (ed.visible) {
					execute_command["kill-buffer"](ed, "kill-buffer");
				}
			}
		}
		
		/* Kill a buffer. The file of this buffer must not have any other editors visible. */
		void kill_buffer (Editor editor, GenericArray<Editor> editors, owned DataSource next_source) {
			var source = editor.source; // keep alive
			if (!(source is ScratchSource)) { // scratch never dies
				// update all editor containers
				each_lru ((lru) => { lru.remove (source); return true; });
				sources.remove (source);
				if (source is FileSource) {
					conf.cluster.closed_file ((FileSource) source);
				}
			}

			if (source == next_source) {
				// *scratch* again, no other opened files
				return;
			}

			var container = editor.editor_container;

			unowned Editor ed = get_available_editor (next_source);
			replace_widget (editor, ed);
			ed.grab_focus ();
			foreach (unowned Editor old_ed in editors.data) {
				((Container) old_ed.get_parent ()).remove (old_ed);
			}

			unowned List<DataSource> lru_head = container.lru.list();
			if (lru_head != null && lru_head.data != null && lru_head.next != null) {
				if (lru_head.data == next_source || (next_source != null && lru_head.data.equal (next_source))) {
					// the next source in the lru is next_source, give precedence to the second file in the lru
					container.lru.used (lru_head.next.data);
				}
			}
		}

		void on_kill_buffer (Editor editor) {
			var sources = editor.editor_container.get_sources ();
			// get next lru file
			unowned DataSource next_source = sources[0];

			GenericArray<Editor> editors;
			editors = editor.source.get_data ("editors");

			bool other_visible = false;
			foreach (unowned Editor ed in editors.data) {
				if (editor != ed && (ed.visible || current_layout != ed.parent_layout)) {
					other_visible = true;
					break;
				}
			}

			if (!other_visible) {
				if (editor.view.buffer.get_modified ()) {
					/* Ask user */
					var bar = new MessageBar ("<b>Your changes will be lost. Confirm? (y/n)</b>");
					bar.key_pressed.connect ((e) => {
							if (e.keyval == Gdk.Key.n) {
								abort (editor);
								return true;
							} else if (e.keyval == Gdk.Key.y || e.keyval == Gdk.Key.Return) {
								abort (editor);
								kill_buffer (editor, editors, next_source);
								return true;
							}
							return false;
					});
					bar.aborted.connect (() => {
							abort (editor);
					});
					add_overlay (bar);
					bar.show ();
					bar.grab_focus ();
				} else {
					kill_buffer (editor, editors, next_source);
				}
			} else {
				unowned Editor ed = get_available_editor (next_source);
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
			if (editor is ScratchSource) {
				return;
			}
			
			var val = conf.get_file_int(editor.source, "tab_width", 4);
			var bar = new EntryBar (val.to_string());
			bar.activate.connect ((text) => {
					abort (editor);
					int newval = int.parse (text);
					conf.set_file_int(editor.source, "tab_width", newval);
					conf.save ();
					((SourceView) editor.view).tab_width = newval;
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
					conf.save ();
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
			if (modified.length > 0) {
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
					var bar = new MessageBar ("<b>s = save, n = discard, ! = save-all, q = discard all</b>");
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
			}

			// hide the window to fool the user, but we want to wait for writing the configuration bits
			hide ();
			yield conf.save_immediate ();
			quit ();
		}

		void on_quit (Editor ed) {
			ask_save_modified_editors.begin (ed);
		}

		void on_copy (Editor ed) {
			TextIter start, end;
			ed.view.buffer.get_iter_at_offset (out start, selection_start);
			ed.view.buffer.get_iter_at_offset (out end, selection_end);
			
			var text = ed.view.buffer.get_text (start, end, false);
			Clipboard clip = Clipboard.get (Gdk.SELECTION_CLIPBOARD);
			clip.set_text (text, -1);
		}

		void on_cut (Editor ed) {
			on_copy (ed);

			TextIter start, end;
			ed.view.buffer.get_iter_at_offset (out start, selection_start);
			ed.view.buffer.get_iter_at_offset (out end, selection_end);
			ed.view.buffer.delete (ref start, ref end);
		}

		void on_paste (Editor ed) {
			ed.view.paste_clipboard ();
		}

		void on_select_all (Editor ed) {
			ed.view.select_all(true);
		}

		void on_abbrev_complete (Editor ed) {
			var buf = (EditorBuffer) ed.view.buffer;
			// get current word
			TextIter start;
			buf.get_iter_at_mark (out start, buf.get_insert ());
			// backward
			while (!start.is_start() && (start.get_char().isalnum() || start.get_char() == '_')) start.backward_char ();
			start.forward_char();

			var end = start;
			// forward
			while (!end.is_end() && (end.get_char().isalnum() || end.get_char() == '_')) end.forward_char ();

			var word = buf.get_text (start, end, false);
			if (word == "") {
				return;
			}

			buf.abbrevs.complete.begin (word, Priority.DEFAULT, null, (s,r) => {
					try {
						var res = buf.abbrevs.complete.end (r);
						if (res.length > 0) {
							message (res[0]);
						}
					} catch (IOError.CANCELLED e) {
					} catch (Error e) {
						state.status.set (e.message, null, Status.Type.ERROR);
					}
			});
		}

		void on_pipe_shell_clipboard (Editor ed) {
			pipe_shell.begin (ed, (s,r) => {
					try {
						var output = (string) pipe_shell.end (r);
						var clipboard = Clipboard.get (Gdk.SELECTION_CLIPBOARD);
						clipboard.set_text (output, -1);
						state.status.set ("Output of command has been copied to clipboard");
					} catch (Error e) {
						state.status.set (e.message, null, Status.Type.ERROR);
					}
			});
		}

		void on_pipe_shell_replace (Editor ed) {
			pipe_shell_replace.begin (ed);
		}

		async void pipe_shell_replace (Editor ed) {
			var old_offset = selection_start;
			try {
				var output = yield pipe_shell (ed);

				var stream = new MemoryInputStream.from_data ((owned) output, GLib.free);

				var buf = ed.view.buffer;
				yield replace_editor_contents (ed, stream, true);
				stream.close ();

				TextIter iter;
				buf.get_iter_at_offset (out iter, old_offset);
				buf.place_cursor (iter);
				ed.view.scroll_mark_onscreen (buf.get_insert ());

				state.status.set ("Output of command has been replaced into the editor");
			} catch (IOError.CANCELLED e) {
			} catch (Error e) {
				state.status.set (e.message, null, Status.Type.ERROR);
			}
		}

		async uint8[] pipe_shell (Editor ed) throws Error {
			// get text
			TextIter start, end;
			ed.view.buffer.get_iter_at_offset (out start, selection_start);
			ed.view.buffer.get_iter_at_offset (out end, selection_end);
			
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
			var pipe_hist = get_entry_history ("pipe");
			var bar = new EntryBar (pipe_hist.get(0) ?? "");
			attach_entry_history (bar.entry, pipe_hist);

			bar.activate.connect ((command) => {
					pipe_hist.add (command);
					abort (ed);
					var filename = ed.source != null ? ed.source.to_string() : "*scratch*";
					var cmd = command.replace("%f", Shell.quote(filename)).replace("%s", start.get_offset().to_string()).replace("%e", end.get_offset().to_string());
					var base_file = ed.source.parent as FileSource;
					var dir = base_file != null ? base_file : (FileSource) ScratchSource.instance.parent;
					dir.execute_shell.begin (cmd, text.data, Priority.DEFAULT, null, (s,r) => {
							try {
								output = dir.execute_shell.end (r);
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

		void on_move_word (Editor ed, string command) {
			int direction = "forward" in command ? 1 : -1;
			bool is_select = "select" in command;
			ed.view.move_cursor (MovementStep.WORDS, direction, is_select);
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

			bool do_indent = true;
			// check if this is the first non-white char of the line
			TextIter iter;
			buf.get_iter_at_mark (out iter, buf.get_insert ());
			while (!iter.starts_line () && iter.backward_char() && iter.get_char().isspace ());
			if (!iter.starts_line ()) {
				do_indent = false;
			}
			
			if (command == "return") {
				buf.insert_at_cursor ("\n", -1);
				do_indent = true;
			} else if (command == "close-paren") {
				buf.insert_at_cursor (")", -1);
			} else if (command == "close-curly-brace") {
				buf.insert_at_cursor ("}", -1);
			} else if (command == "close-square-brace") {
				buf.insert_at_cursor ("]", -1);
			} else if (command == "tab") {
				buf.insert_at_cursor ("\t", -1);
				do_indent = false;
			}

			ed.view.scroll_mark_onscreen (buf.get_insert ());
			update_selection (ed);

			var indent_engine = get_indent_engine (ed);
			// only auto indent on return for python
			if (indent_engine is Indent_Python && command != "return") {
				do_indent = false;
			}
			if (indent_engine != null && do_indent) {
				execute_command["indent"] (ed, "indent");
			}

			buf.end_user_action ();
		}

		void on_copy_line (Editor ed, string command) {
			var buf = ed.view.buffer;
			buf.begin_user_action ();

			TextIter iter;
			buf.get_iter_at_mark (out iter, buf.get_insert ());

			var vbuf = new UI.Buffer (ed.view);
			if (command == "copy-line-up") {
				var viter = vbuf.line_start (iter.get_line ());
				vbuf.insert (viter, vbuf.line_text (viter.line)+"\n");
			} else {
				// insert mark has right gravity, ensure we keep the cursor to stay
				var mark = buf.create_mark (null, iter, true);

				var viter = vbuf.line_end (iter.get_line ());
				vbuf.insert (viter, "\n"+vbuf.line_text (viter.line));

				buf.get_iter_at_mark (out iter, mark);
				buf.place_cursor (iter);
			}

			update_selection (ed);
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

		void on_delete_word_forward (Editor ed) {
			// first unselect any currently selected text
			TextIter insert;
			var buf = ed.view.buffer;
			buf.get_iter_at_mark (out insert, buf.get_insert ());
			buf.place_cursor (insert);

			// select the next word and delete
			ed.view.move_cursor (MovementStep.WORDS, 1, true);
			buf.delete_selection (false, false);
		}

		void on_delete_white_backward (Editor ed) {
			TextIter end_iter;
			var buf = ed.view.buffer;
			buf.get_iter_at_mark (out end_iter, buf.get_insert ());
			
			TextIter start_iter = end_iter;
			while (start_iter.backward_char() && start_iter.get_char().isspace());
			if (!start_iter.get_char().isspace()) {
				start_iter.forward_char ();
			}
			buf.delete (ref start_iter, ref end_iter);
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
				case "python":
					return new Indent_Python (vbuf);
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

			buf.begin_user_action ();

			// indent every selected line
			TextIter start, end;
			ed.view.buffer.get_iter_at_offset (out start, selection_start);
			ed.view.buffer.get_iter_at_offset (out end, selection_end);
			
			var min_line = int.min (start.get_line(), end.get_line());
			var max_line = int.max (start.get_line(), end.get_line());
			
			var is_python = indent_engine is Indent_Python;
			/* Auto indent of each line in python simply does not work.
			 * We therefore indent the first line, remember the indent variation, and adjust the following
			 * lines by this variation. */
			int indent_diff = 0;
			
			for (var line=min_line; line <= max_line; line++) {
				TextIter iter;
				buf.get_iter_at_line (out iter, line);
				
				if (indent_engine == null) {
					buf.insert_text (ref iter, "\t", 1);
				} else if (is_python) {
					var old_indent = indent_engine.buffer.get_indent (line);
					if (line == min_line) {
						// indent the first line
						var viter = new UI.BufferIter (indent_engine.buffer, iter);
						indent_engine.indent (viter);
						indent_diff = indent_engine.buffer.get_indent (line) - old_indent;
					} else {
						indent_engine.buffer.set_indent (line, old_indent + indent_diff);
					}
				} else {
					var viter = new UI.BufferIter (indent_engine.buffer, iter);
					indent_engine.indent (viter);
				}
			}

			buf.end_user_action ();
		}

		void on_comment_lines (Editor ed) {
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
				case "ruby":
				case "generic_comment":
				case "nix":
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
				TextIter start, end;
				ed.view.buffer.get_iter_at_offset (out start, selection_start);
				ed.view.buffer.get_iter_at_offset (out end, selection_end);
				
				var iter_start = vbuf.line_at_char (start.get_line (),
													start.get_line_offset ());
				var iter_end = vbuf.line_at_char (end.get_line (),
												  end.get_line_offset ());
				ed.view.buffer.begin_user_action ();
				comment_engine.toggle_comment (iter_start, iter_end);
				ed.view.buffer.end_user_action ();
			}
		}

		void on_set_theme (Editor editor) {
			var themes = get_themes ();
			
			var bar = new SimpleCompletionBar<string> ((owned) themes);
			bar.activate.connect (() => {
					abort (editor);
					var theme = bar.get_choice();
					if (set_theme (theme)) {
						conf.set_global_string ("theme", theme);
					}
			});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
		}
		
		void on_switch_buffer (Editor editor) {
			var sp = short_paths (editor.editor_container.get_sources ());
			var bar = new SwitchBufferBar ((owned) sp);
			bar.activate.connect (() => {
					abort (editor);
					var source = bar.get_choice();
					if (source == editor.source) {
						// no-op
						return;
					}
					unowned Editor ed = get_available_editor (source);
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
					var text = val.to_string ();
					var clipboard = Clipboard.get (Gdk.SELECTION_CLIPBOARD);
					clipboard.set_text (text, -1);
					state.status.set (text, "eval");
				} else {
					state.status.clear ("eval");
				}
			} catch (Error e) {
				state.status.set (e.message, "eval", Status.Type.ERROR);
			}
		}

		void on_eval_expression (Editor editor) {
			var vade_hist = get_entry_history ("pipe");
			var bar = new EntryBar (vade_hist.get(0) ?? "");
			attach_entry_history (bar.entry, vade_hist);

			bar.activate.connect ((code) => {
					vade_hist.add (code);
					abort (editor);
					eval_expression.begin (editor, code);
			});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
		}

		void on_goto_error (Editor editor, string cmd) {
			goto_error.begin (editor, cmd);
		}

		async void goto_error (Editor editor, string cmd) {
			bool no_more_errors = true;
			if (error_locations != null) {
				if (error_locations.length() == 1) {
					current_error = error_locations;
					no_more_errors = false;
				} else if (current_error == null) {
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
				state.status.set ("No more errors");
			} else {
				var loc = current_error.data;
				try {
					var exists = yield loc.source.exists ();
					if (exists) {
						open_location.begin (editor, loc);
						state.status.set (Markup.escape_text (loc.get_data ("error-message")), null, Status.Type.ERROR);
					} else {
						state.status.set ("Source %s not found".printf (loc.source.to_string ()), null, Status.Type.ERROR);
					}
				} catch (Error e) {
				}
			}
		}

		void on_repo_grep (Editor editor) {
			repo_grep.begin (editor);
		}

		async void repo_grep (Editor editor) {
			if (!(editor.source is FileSource)) {
				return;
			}

			Git git = new Git (conf);
			FileSource repo_dir = null;
			try {
				repo_dir = yield git.get_repo ((FileSource) editor.source.parent);
			} catch (Error e) {
			}

			if (repo_dir == null) {
				state.status.set ("Not in git repository");
				return;
			}

			InputStream? stream = null;

			var grep_hist = get_entry_history ("grep");
			var bar = new GrepBar (state, repo_dir, grep_hist.get(0) ?? "");
			attach_entry_history (bar.entry, grep_hist);
			bar.activate.connect (() => {
					grep_hist.add (bar.text);
					abort (editor);
					var loc = bar.location;
					if (loc != null && loc.source != null) {
						open_location.begin (editor, loc);
					}
			});
			bar.changed.connect ((pat) => {
					state.status.clear ("repo-grep");

					if (stream != null) {
						try {
							stream.close ();
						} catch (Error e) {
						}
					}

					if (pat == "") {
						return;
					}

					git.grep.begin (repo_dir, pat, (errors) => {
							state.status.set (errors, "repo-grep", Status.Type.ERROR);
					}, Priority.DEFAULT, null, (s,r) => {
						try {
							stream = git.grep.end (r);
							bar.stream = stream;
						} catch (Error e) {
							state.status.set (e.message, "repo-grep", Status.Type.ERROR);
						}
					});
			});
			bar.aborted.connect (() => {
					grep_hist.add (bar.text);
					abort (editor);
			});
			add_overlay (bar, OverlayMode.PANE_BOTTOM);
			bar.show ();
			bar.grab_focus ();
		}

		void on_repo_open_file (Editor editor) {
			repo_open_file.begin (editor);
		}

		async void repo_open_file (Editor editor, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) {
			var parent = editor.source.parent as FileSource;
			if (parent == null) {
				return;
			}

			Git git = new Git (conf);
			FileSource repo_dir = null;
			try {
				repo_dir = yield git.get_repo (parent);
			} catch (Error e) {
			}

			if (repo_dir == null) {
				state.status.set ("Not in git repository");
				return;
			}

			var git_command = conf.get_global_string ("git_command", "git");

			string res;
			try {
				res = (string) yield repo_dir.execute_shell (@"$(git_command) ls-files");
			} catch (Error e) {
				state.status.set (e.message, "repo-open-file", Status.Type.ERROR);
				return;
			}

			var file_names = res.split ("\n");
			var annotated = new Annotated<DataSource>[file_names.length];
			for (var i=0; i < file_names.length; i++) {
				annotated[i] = new Annotated<DataSource> (file_names[i], repo_dir.child (file_names[i]));
			}

			var bar = new SimpleCompletionBar<DataSource> ((owned) annotated);
			bar.activate.connect (() => {
					abort (editor);
					var file = bar.get_choice();
					if (file == editor.source) {
						// no-op
						return;
					}
					open_source.begin (editor, file);
			});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
		}


		void on_split (Editor editor, string command) {
			split_views (editor, command == "split-add-right" ? Orientation.HORIZONTAL : Orientation.VERTICAL);
		}

		void single_layout_invariant (Editor editor) {
			var ed_layout = editor.parent_layout;
			if (ed_layout.views == 1) {
				// remove other single layouts
				foreach (var layout in layouts) {
					if (layout != ed_layout && layout.views == 1) {
						layouts.remove (layout);
					}
				}
				return;
			} else {
				// check if there's a single layout
				foreach (var layout in layouts) {
					if (layout.views == 1) {
						return;
					}
				}
			}

			debug ("Creating new single layout for invariant");
			var layout = new Layout ();
			var newed = get_available_editor (editor.source, layout);
			if (newed.get_parent() != null) {
				// ensure the new editor is unparented
				((Container) newed.get_parent ()).remove (newed);
			}
			// create a new container
			var newcontainer = new EditorContainer (newed);
			// inherit lru from existing editor
			newcontainer.lru = editor.editor_container.lru.copy ();

			layout.add (newcontainer);
			layout.views = 1;
			layout.last_focused_editor = newed;
			layout.show_all ();

			var index = layouts.index (ed_layout);
			layouts.insert (layout, index);
		}
		
		// Returns the new editor on the splitted view
		Editor split_views (Editor editor, Orientation orient) {
			// get bounding box of the editor
			Allocation alloc;
			editor.get_allocation (out alloc);
			// unparent the editor container
			var container = editor.editor_container;

			// create the GUI split
			var paned = new Paned (orient);
			paned.expand = true;
			// set the position of the split at half of the editor width/height
			paned.position = orient == Orientation.HORIZONTAL ? alloc.width/2 : alloc.height/2;
			replace_widget (container, paned);

			// get an editor for the same file
			var ed = get_available_editor (editor.source);
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

			current_layout.views++;
			// new layout created
			single_layout_invariant (editor);
			
			return ed;
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

		void on_switch_layout (Editor ed, string command) {
			int step = (command == "next-layout") ? 1 : -1;
			var layout = ed.parent_layout;
			var index = layouts.index (layout);
			var len = (int) layouts.length ();

			index = index+step;
			if (index < 0) {
				index = len-1;
			} else if (index >= len) {
				index = 0;
			}
			current_layout = layouts.nth_data (index);
			layout_wrapper.remove (layout_wrapper.get_child ());
			layout_wrapper.add (current_layout);

			current_layout.last_focused_editor.grab_focus ();
		}

		void on_kill_layout (Editor ed) {
			var layout = ed.parent_layout;
			if (layout.views == 1) {
				return;
			}
			
			var index = layouts.index (layout);
			// get the previous layout
			if (index > 0) {
				index--;
			}
			layouts.remove (layout);

			current_layout = layouts.nth_data (index);
			layout_wrapper.remove (layout_wrapper.get_child ());
			layout_wrapper.add (current_layout);

			// reassign editors to the current layout
			each_editor ((ed) => {
					if (ed.parent_layout == layout) {
						ed.parent_layout = current_layout;
						ed.hide ();
					}
					return true;
			});

			current_layout.last_focused_editor.grab_focus ();
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

			var children = current_layout.get_children();
			foreach (Widget child in children) {
				current_layout.remove (child);
				detach_editors (child);
			}
			current_layout.add (editor_container);
			current_layout.views = 1;
			single_layout_invariant (editor);
			
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

			var layout = editor.parent_layout;
			layout.views--;
			single_layout_invariant (editor);
			
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
			
			var search_hist = get_entry_history ("search");
			var replace_hist = get_entry_history ("replace");
			var bar = new SearchBar (this, editor, mode, is_regex,
									 search_hist.get(0) ?? "",
									 replace_hist.get(0) ?? "");
			attach_entry_history (bar.entry, search_hist);
			if (command.has_prefix ("replace")) {
				attach_entry_history (bar.replace_entry, replace_hist);
			}
			
			bar.activate.connect (() => {
					search_hist.add (bar.text);
					if (command.has_prefix ("replace")) {
						replace_hist.add (bar.replace_text);
					}
					abort (editor);
			});
			bar.aborted.connect (() => {
					search_hist.add (bar.text);
					if (command.has_prefix ("replace")) {
						replace_hist.add (bar.replace_text);
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
			int direction = "forward" in command ? 1 : -1;
			bool select = "select" in command;
			ed.view.move_cursor (MovementStep.DISPLAY_LINES, direction, select);
		}
		
		void on_forward_backward_char (Editor ed, string command) {
			int direction = "forward" in command ? 1 : -1;
			bool select = "select" in command;
			ed.view.move_cursor (MovementStep.VISUAL_POSITIONS, direction, select);
		}

		void on_zen_mode (Editor editor) {
			var state = get_window().get_state ();
			if (Gdk.WindowState.FULLSCREEN in state) {
				this.get_window().unfullscreen();
			} else {
				this.get_window().fullscreen();
			}
		}

		void on_update_copyright_year (Editor editor, string command) {
			var vbuf = new UI.Buffer ((SourceView) editor.view);
			if (update_copyright_year (vbuf)) {
				state.status.set ("Copyright year has been updated");
			} else if (command != "autoupdate-copyright-year") {
				state.status.set ("No copyright year to update");
			}
		}

		void on_toggle_autoupdate_copyright_year (Editor editor) {
			var autoupdate_copyright_year = !conf.get_global_bool ("autoupdate_copyright_year");
			conf.set_global_bool ("autoupdate_copyright_year", autoupdate_copyright_year);
			conf.save ();

			state.status.set (autoupdate_copyright_year ? "Enabled" : "Disabled");
		}

		void on_toggle_auto_add_endline (Editor editor) {
			var auto_add_endline = !conf.get_editor_bool ("auto_add_endline");
			conf.set_editor_bool ("auto_add_endline", auto_add_endline);
			conf.save ();

			state.status.set (auto_add_endline ? "Enabled" : "Disabled");
		}

		void on_toggle_atomic_save (Editor editor) {
			var atomic_save = !conf.get_global_bool ("atomic_file_save", true);
			conf.set_global_bool ("atomic_file_save", atomic_save);
			conf.save ();

			state.status.set (atomic_save ? "Enabled" : "Disabled");
		}

		void on_toggle_indent_mode (Editor editor) {
			var buffer = new UI.Buffer (editor.view);
			var indent_mode = buffer.indent_mode;
			if (indent_mode == IndentMode.TABS) {
				indent_mode = IndentMode.SPACES;
			} else {
				indent_mode = IndentMode.TABS;
			}

			if (!(editor.source is ScratchSource)) {
				conf.set_file_enum<IndentMode> (editor.source, "indent_mode", indent_mode);
				conf.save ();
			}
			
			buffer.indent_mode = indent_mode;
			state.status.set (indent_mode == IndentMode.SPACES ? "Indent with spaces" : "Indent with tabs");
		}

		void on_toggle_remote_file_server (Editor editor) {
			var flag = !conf.get_global_bool ("remote_file_server", true);
			conf.set_global_bool ("remote_file_server", flag);
			state.status.set (flag ? "Enabled" : "Disabled");
			check_remote_file_server ();
		}

		void on_about (Editor editor) {
			var bar = new AboutBar ();
			bar.aborted.connect (() => {
					main_box.remove (bar);
					main_box.add (layout_wrapper);
					editor.grab_focus ();
			});
			main_box.remove (layout_wrapper);
			main_box.add (bar);
			bar.grab_focus ();
		}

		void on_toggle_git_gutter (Editor editor) {
			var val = !conf.get_editor_bool ("git_gutter", true);
			conf.set_editor_bool ("git_gutter", val);
			state.status.set (val ? "Enabled" : "Disabled");
			each_editor ((ed) => {
					ed.on_git_gutter();
					return true;
			});
		}

		void on_toggle_show_branch (Editor editor) {
			var val = !conf.get_editor_bool ("show_branch", false);
			conf.set_editor_bool ("show_branch", val);
			state.status.set (val ? "Enabled" : "Disabled");
			each_editor ((ed) => {
					ed.update_show_branch ();
					return true;
			});
		}

		void on_toggle_right_margin (Editor editor) {
			var val = !conf.get_editor_bool ("right_margin", false);
			conf.set_editor_bool ("right_margin", val);
			state.status.set (val ? "Enabled" : "Disabled");
			each_editor ((ed) => {
					ed.update_right_margin ();
					return true;
			});
		}

		void on_set_right_margin_column (Editor editor) {
			var val = conf.get_editor_int("right_margin_column", 80);
			var bar = new EntryBar (val.to_string());
			bar.activate.connect ((text) => {
					abort (editor);
					conf.set_editor_int("right_margin_column", int.parse(text));
					conf.save ();

					each_editor ((ed) => {
							ed.update_right_margin ();
							return true;
					});
			});
			bar.aborted.connect (() => { abort (editor); });
			add_overlay (bar);
			bar.show ();
			bar.grab_focus ();
		}

		void on_toggle_trailing_spaces (Editor editor) {
			var val = !conf.get_editor_bool ("trailing_spaces", true);
			conf.set_editor_bool ("trailing_spaces", val);
			state.status.set (val ? "Enabled" : "Disabled");
			each_editor ((ed) => {
					ed.on_trailing_spaces ();
					return true;
			});
		}

		void on_toggle_auto_clean_trailing_spaces (Editor editor) {
			var val = !conf.get_editor_bool ("auto_clean_trailing_spaces", true);
			conf.set_editor_bool ("auto_clean_trailing_spaces", val);
			state.status.set (val ? "Enabled" : "Disabled");
		}

		void on_clean_trailing_spaces (Editor editor) {
			TextIter start, end;
			editor.view.buffer.get_iter_at_offset (out start, selection_start);
			editor.view.buffer.get_iter_at_offset (out end, selection_end);

			editor.view.buffer.begin_user_action ();
			editor.clean_trailing_spaces (start, end);
			editor.view.buffer.end_user_action ();
		}

		void on_remote_open_file (RemoteFileSource file) {
			open_source.begin (current_layout.last_focused_editor, file);
		}

		void on_toggle_show_tabs (Editor editor) {
			var val = !conf.get_editor_bool ("show_tabs", false);
			conf.set_editor_bool ("show_tabs", val);
			state.status.set (val ? "Enabled" : "Disabled");
			each_editor ((ed) => {
					ed.update_show_tabs ();
					return true;
			});
		}
	}
}
