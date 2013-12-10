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

using Vte;
using Gtk;

namespace Vanubi {
	public class ShellData {
		public long last_col;
		public long last_row;
	}
	
	public class ShellBar : Bar {
		Terminal term;
		Configuration config;
		Editor editor;
		
		static Regex error_regex_vala = null;
		static Regex error_regex_php = null;
		
		static construct {
			try {
				// vala style
				error_regex_vala = new Regex ("""^(.+?):(\d+)\.(\d+)-(\d+)\.(\d+):.+?error:""", RegexCompileFlags.CASELESS|RegexCompileFlags.OPTIMIZE);
				// php style
				error_regex_php = new Regex ("""^.*error:.* in (.+) on line (\d+)""", RegexCompileFlags.CASELESS|RegexCompileFlags.OPTIMIZE);
			} catch (Error e) {
				error (e.message);
			}
		}
		
		public ShellBar (Manager manager, Editor editor) {
			this.editor = editor;
			this.config = manager.conf;
			
			var base_file = editor.file;
			
			expand = true;
			term = base_file.get_data ("shell");
			var is_new = false;
			if (term == null) {
				is_new = true;
				term = create_new_term (base_file);
				base_file.set_data ("shell", term.ref ());
				term.set_data ("shell_data", new ShellData ());
			}
			term.expand = true;
			term.key_press_event.connect (on_key_press_event);
				
			term.commit.connect ((bin, size) => {
					var text = bin.substring (0, size);

					// if user executed any other command, clear errors
					if ("\n" in text || "\r" in text) {
						manager.error_locations = new List<Location> ();
					}
					
					// store cwd in config file
					if (base_file != null) {
						var curdir = get_cwd ();
						if (curdir != null) {
							var olddir = config.get_file_string (base_file, "shell_cwd", get_base_directory (base_file));
							if (absolute_path ("", olddir) != absolute_path ("", curdir)) {
								config.set_file_string (base_file, "shell_cwd", curdir);
								config.save.begin ();
							}
						}
					}
			});
			
			term.contents_changed.connect (() => {
					// grep for errors
					long col, row;
					term.get_cursor_position (out col, out row);
					ShellData data = term.get_data ("shell_data");
					
					for (var i=data.last_row; i < row; i++) {
						var text = term.get_text_range (i, 0, i, term.get_column_count(), null, null);
						var loc = match_error_regex (text);
						if (loc != null) {
							manager.error_locations.append (loc);
						}
					}
					
					data.last_col = long.max(col, data.last_col);
					data.last_row = long.max(row, data.last_row);
			});
			
			if (!is_new) {
				term.feed_child ("\033[B\033[A", -1);
			}

			add (term);
			show_all ();
		}
		
		string? get_cwd () {
			Pid pid = term.get_data ("pid");
			var buf = new char[1024];
			if (Posix.readlink (@"/proc/$(pid)/cwd", buf) > 0) {
				return (string) buf;
			} else {
				return null;
			}
		}
		
		Location? match_error_vala (string text) {
			MatchInfo info;
			if (error_regex_vala.match (text, 0, out info)) {
				var filename = info.fetch(1);
				var start_line = int.parse (info.fetch (2));
				var start_column = int.parse (info.fetch (3));
				var end_line = int.parse (info.fetch (4));
				var end_column = int.parse (info.fetch (5));
					
				var file = File.new_for_path (filename);
				if (editor.file != null && filename[0] != '/') {
					file = editor.file.get_parent().get_child (filename);
				}
				
				var loc = new Location (file, start_line-1, start_column, end_line-1, end_column);
				return loc;
			}
			return null;
		}
		
		Location? match_error_php (string text) {
			MatchInfo info;
			if (error_regex_php.match (text, 0, out info)) {
				var filename = info.fetch(1);
				var start_line = int.parse (info.fetch (2));

				var file = File.new_for_path (filename);
				if (editor.file != null && filename[0] != '/') {
					file = editor.file.get_parent().get_child (filename);
				}
				
				var loc = new Location (file, start_line-1);
				return loc;
			}
			return null;
		}
		
		Location? match_error_regex (string text) {
			var loc = (match_error_vala (text) ??
					   match_error_php (text));
			return loc;
		}
		
		Terminal create_new_term (File? base_file) {
			var term = new Terminal ();
			term.scrollback_lines = config.get_global_int ("shell_scrollback", 65535);
			var shell = Vte.get_user_shell ();
			if (shell == null) {
				shell = "/bin/sh";
			}
			try {
				string[] argv;
				Shell.parse_argv (shell, out argv);
				var workdir = config.get_file_string (base_file, "shell_cwd", get_base_directory (base_file));

				Pid pid;
				term.fork_command_full (PtyFlags.DEFAULT, workdir, argv, null, SpawnFlags.SEARCH_PATH, null, out pid);
				term.set_data ("pid", pid);
				term.feed_child ("make", -1);

				mouse_match (term, """^.+error:""");
				mouse_match (term, """^.+warning:""");
				mouse_match (term, """^.+info:""");

			} catch (Error e) {
				warning (e.message);
			}
			return term;
		}

		private void mouse_match (Terminal t, string str) {
			try {
				var regex = new Regex (str);
				int id = t.match_add_gregex (regex, 0);
				t.match_set_cursor_type (id, Gdk.CursorType.HAND2);
			} catch (RegexError e) {
				warning (e.message);
			}
		}

		public override void grab_focus () {
			term.grab_focus ();
		}
		
		protected override bool on_key_press_event (Gdk.EventKey e) {
			if (e.keyval == Gdk.Key.g && Gdk.ModifierType.CONTROL_MASK in e.state) {
				aborted ();
				return true;
			}
			if (e.keyval == '\'' && Gdk.ModifierType.CONTROL_MASK in e.state) {
				return editor.view.key_press_event (e);
			}
			return false;
		}
	}
}
