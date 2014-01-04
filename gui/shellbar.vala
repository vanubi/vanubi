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

using Vte;
using Gtk;

namespace Vanubi {
	public class ShellBar : Bar {
		unowned Manager manager;
		Terminal term;
		Configuration config;
		Editor editor;
		bool is_first_line = true;
		
		static Regex error_regex = null;
		static Regex dir_regex = null;
		
		static construct {
			try {
				// vala style
				var	vala_error = """^(?<f>.+?):(?<sl>\d+)\.(?<sc>\d+)-(?<el>\d+)\.(?<ec>\d+):.*?error:(?<msg>.+)$""";
				// c style
				var	c_error = """^(?<f>.+?):(?<sl>\d+):(?<sc>\d+):.*?error:(?<msg>.+)$""";
				// php style
				var php_error = """^(?<msg>.+)error:.* in (?<f>.+) on line (?<sl>\d+)\s*$""";
				// sh style
				var sh_error = """^(?<f>.+?):.*?(?<sl>\d+?):.*?:(?<msg>.*? error):""";
				error_regex = new Regex (@"(?:$(vala_error))|(?:$(php_error))|(?:$(c_error))|(?:$(sh_error))", RegexCompileFlags.CASELESS|RegexCompileFlags.OPTIMIZE|RegexCompileFlags.DUPNAMES);
				
				// enter directory
				var make_dir = """^.*Entering directory `(.+?)'.*$""";
				dir_regex = new Regex (@"(?:$(make_dir))", RegexCompileFlags.CASELESS|RegexCompileFlags.OPTIMIZE|RegexCompileFlags.DUPNAMES);
			} catch (Error e) {
				error (e.message);
			}
		}
		
		public ShellBar (Manager manager, Editor editor) {
			this.manager = manager;
			this.editor = editor;
			this.config = manager.conf;
			
			var base_file = editor.file;
			
			expand = true;
			term = base_file != null ? base_file.get_data<Terminal> ("shell") : null;
			var is_new = false;
			if (term == null) {
				is_new = true;
				term = create_new_term (base_file);
				if (base_file != null) {
					base_file.set_data ("shell", term.ref ());
				}
			}
			term.expand = true;
			term.key_press_event.connect (on_key_press_event);
				
			term.commit.connect ((bin, size) => {				
					var text = bin.substring (0, size);

					// if user executed any other command, clear errors
					if ("\n" in text || "\r" in text) {
						manager.error_locations = new List<Location> ();
						manager.current_error = null;
						manager.clear_status ("errors");
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
		
		Terminal create_new_term (File? base_file) {
			var term = new Terminal ();
			term.scrollback_lines = config.get_global_int ("shell_scrollback", 65535);
			var shell = Vte.get_user_shell ();
			if (shell == null) {
				shell = "/bin/bash";
			}
			try {
				string[] argv;
				Shell.parse_argv (shell, out argv);
				var workdir = config.get_file_string (base_file, "shell_cwd", get_base_directory (base_file));

				Pid pid;
				term.fork_command_full (PtyFlags.DEFAULT, workdir, {shell}, null, SpawnFlags.SEARCH_PATH, null, out pid);
				term.set_data ("pid", pid);
				read_sh.begin (term.pty_object.fd);

				mouse_match (term, """^.+error:""");
				mouse_match (term, """^.+warning:""");
				mouse_match (term, """^.+info:""");

			} catch (Error e) {
				warning (e.message);
			}
			return term;
		}

		async void read_sh (int fd) {
			try {
				var is = new UnixInputStream (fd, true);
				var buf = new uint8[1024];
				var b = new StringBuilder ();
				var curdir = editor.file != null ? editor.file.get_parent().get_path () : ".";
				
				while (true) {
					var r = yield is.read_async (buf);
					if (r <= 0) {
						// eof
						break;
					}
					
					unowned uint8[] cur = buf;
					cur.length = (int) r;
					term.feed (cur);
					
					if (is_first_line) {
						is_first_line = false;
						Idle.add (() => { term.feed_child ("make -j", -1); return false; });
					}
					
					for (var i=0; i < cur.length; i++) {
						if (cur[i] != '\r' && cur[i] != '\n') {
							b.append_c ((char) cur[i]);
						} else {
							// new line, match error or directory change
							MatchInfo info;
							if (dir_regex.match (b.str, 0, out info)) {
								curdir = info.fetch (1);
							} else if (error_regex.match (b.str, 0, out info)) {
								var filename = info.fetch_named ("f");
								var start_line_str = info.fetch_named ("sl");
								var start_column_str = info.fetch_named ("sc");
								var end_line_str = info.fetch_named ("el");
								var end_column_str = info.fetch_named ("ec");
								
								int start_line = -1;
								int start_column = -1;
								int end_line = -1;
								int end_column = -1;
								if (start_line_str.length > 0) {
									start_line = int.parse (start_line_str)-1;
									if (start_column_str.length > 0) {
										start_column = int.parse (start_column_str);
									}
									if (end_line_str.length > 0) {
										end_line = int.parse (end_line_str)-1;
										if (end_column_str.length > 0) {
											end_column = int.parse (end_column_str);
										}
									}
								}
								
								File file;
								if (filename[0] != '/') {
									file = File.new_for_path (curdir+"/"+filename);
								} else {
									file = File.new_for_path (filename);
								}
								
								var msg = info.fetch_named ("msg").strip ();
								var loc = new Location (file, start_line, start_column, end_line, end_column);
								loc.set_data ("error-message", (owned) msg);
								get_start_mark_for_location (loc, editor.view.buffer); // create a TextMark
								get_end_mark_for_location (loc, editor.view.buffer); // create a TextMark
								manager.error_locations.append (loc);
								manager.set_status ("Found %u errors".printf (manager.error_locations.length ()), "errors");
							}
							
							b.truncate ();
						}
					}
				}
			} catch (Error e) {
				warning(e.message);
			}
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
			if (e.keyval == 'C' && Gdk.ModifierType.CONTROL_MASK in e.state) {
				term.copy_clipboard ();
				return true;
			}
			if (e.keyval == 'V' && Gdk.ModifierType.CONTROL_MASK in e.state) {
				term.paste_clipboard ();
				return true;
			}
			if (e.keyval == '\'' && Gdk.ModifierType.CONTROL_MASK in e.state) {
				return editor.view.key_press_event (e);
			}
			return false;
		}
	}
}
