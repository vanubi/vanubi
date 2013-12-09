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
		public List<Location> errors;
	}
	
	public class ShellBar : Bar {
		Terminal term;
		Configuration config;
		Editor editor;
		
		static Regex error_regex = null;
		static Regex loc_regex1 = null;
		
		static construct {
			try {
				error_regex = new Regex ("^(.+?):(.+?):.+?error:", RegexCompileFlags.CASELESS|RegexCompileFlags.OPTIMIZE);
				// vala style
				loc_regex1 = new Regex ("""^(\d+)\.(\d+)-(\d+)\.(\d+)""", RegexCompileFlags.OPTIMIZE);
			} catch (Error e) {
				error (e.message);
			}
		}
		
		public ShellBar (Configuration config, Editor editor) {
			this.editor = editor;
			this.config = config;
			
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
			Pid pid = term.get_data ("pid");
			term.expand = true;
			term.key_press_event.connect (on_key_press_event);
				
			term.commit.connect ((bin, size) => {
					var text = bin.substring (0, size);

					// if user executed any other command, clear errors
					if ("\n" in text || "\r" in text) {
						ShellData data = term.get_data ("shell_data");
						data.errors = new List<Location> ();
					}
					
					// store cwd in config file
					if (base_file != null) {
						var buf = new char[1024];
						var olddir = config.get_file_string (base_file, "shell_cwd", get_base_directory (base_file));
						if (Posix.readlink (@"/proc/$(pid)/cwd", buf) > 0) {
							var curdir = (string) buf;
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
						MatchInfo info;
						if (error_regex.match (text, 0, out info)) {
							// matched an error
							var filename = info.fetch(1);
							var locstr = info.fetch(2);
							
							MatchInfo loc_info;
							if (loc_regex1.match (locstr, 0, out loc_info)) {
								// matched error location
								var start_line = int.parse (loc_info.fetch (1));
								var start_column = int.parse (loc_info.fetch (2));
								int end_line = -1;
								int end_column = -1;
								
								var end_line_str = loc_info.fetch (3);
								if (end_line_str.length > 0) {
									end_line = int.parse (end_line_str);
									end_column = int.parse (loc_info.fetch (4));
								}
								
								var file = File.new_for_path (filename);
								if (base_file != null && filename[0] != '/') {
									file = base_file.get_parent().get_child (filename);
								}
								var loc = new Location (file, start_line, start_column, end_line, end_column);
								data.errors.append (loc);
							}
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
