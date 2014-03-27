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
	public class Application : Gtk.Application {
		static bool arg_version = false;
		static bool arg_standalone = false;
		static string arg_vade_expression = null;
		[CCode (array_length = false, array_null_terminated = true)]
		static string[] arg_filenames;
		
		const OptionEntry[] options = {
			{ "version", 0, 0, OptionArg.NONE, ref arg_version, "Show Vanubi's version", null },
			{ "standalone", 0, 0, OptionArg.NONE, ref arg_standalone, "Run Vanubi in a new process", null },
			{ "eval", 0, 0, OptionArg.STRING, ref arg_vade_expression, "Evaluate a Vade expression in the current opened file", "EXPR" },
			{ "", 0, 0, OptionArg.FILENAME_ARRAY, ref arg_filenames, null, "[FILE...]" },
			{ null }
		};

		static Regex file_pos_regex = null;
		
		static construct {
			try {
				var file_pos = """^(?<f>.+?)(?::(?<sl>\d+)(?::(?<sc>\d+))?)?$""";
				file_pos_regex = new Regex (file_pos, RegexCompileFlags.CASELESS|RegexCompileFlags.OPTIMIZE);
			} catch (Error e) {
				error (e.message);
			}
		}

		public Application () {
			Object (application_id: "org.vanubi", flags: ApplicationFlags.HANDLES_COMMAND_LINE);
		}

		Window new_window () {
			var is_main_window = get_active_window () == null;
			
			var slm = SourceLanguageManager.get_default();
			var search_path = slm.get_search_path();
			search_path += "./data/languages/";
			search_path += Configuration.VANUBI_DATADIR + "/vanubi/languages";
			slm.set_search_path (search_path);
			
			var manager = new Manager ();

			var win = new ApplicationWindow (this);
			win.title = "Vanubi";
			win.delete_event.connect (() => { manager.execute_command (manager.last_focused_editor, "quit"); return false; });
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
						manager.conf.save ();
				});
				win.configure_event.connect (() => {
						int x, y;
						win.get_position (out x, out y);
						manager.conf.set_global_int ("window_x", x);
						manager.conf.set_global_int ("window_y", y);
						manager.conf.save ();
						return false;
				});
				
				// global keybinding
				Keybinder.init ();
				Keybinder.bind (manager.conf.get_global_string ("global_keybinding", "<Ctrl><Mod1>v"), () => { focus_window (win, Keybinder.get_current_event_time ()); });
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

		void focus_window (Window w, uint time) {
			// update wnck
			var wnscreen = Wnck.Screen.get_default ();
			wnscreen.force_update ();
			
			// get wnck window
			var xid = Gdk.X11Window.get_xid (w.get_window());
			weak Wnck.Window wnw = Wnck.Window.get (xid);
			if (wnw != null) {
				wnw.get_workspace().activate (time);
				wnw.activate (time);
			} else {
				// fallback, we cannot switch workspace though
				w.present_with_time (time);
			}
		}

		Manager get_active_manager () {
			var win = get_active_window ();
			if (win == null) {
				win = new_window ();
			}

			var manager = (Manager) win.get_child ();
			return manager;
		}
		
		protected override void activate () {
			var win = get_active_window ();
			if (win == null) {
				win = new_window ();
			}
			
			focus_window (win, (uint)(get_monotonic_time()/1000));
			
		}
		
		void parse_options (ApplicationCommandLine? command_line, ref unowned string[] args) throws OptionError {
			try {
				var opt_context = new OptionContext ("- Vanubi");
				opt_context.set_help_enabled (command_line == null);
				opt_context.add_main_entries (options, null);
				opt_context.add_group (Gtk.get_option_group(false));
				opt_context.set_description ("Please report comments, suggestions and bugs to: \n\t" + Configuration.VANUBI_BUGREPORT_URL);
				
				unowned string[] tmp = args;
				opt_context.parse (ref tmp);
				args = tmp;
			} catch (OptionError e) {
				if (command_line != null) {
					command_line.printerr ("Unknown option %s\n", e.message);
					command_line.printerr ("Run '%s --help' to see a full list of available command line options.\n", args[0]);
				} else {
					print ("Unknown option %s\n", e.message);
					print ("Run '%s --help' to see a full list of available command line options.\n", args[0]);
				}
				throw e;
			}
		}
		
		private int _command_line (ApplicationCommandLine command_line) {
			/*
			 * We have to make an extra copy of the array, since .parse assumes
			 * that it can remove strings from the array without freeing them.
			 */
			string[] args = command_line.get_arguments ();
			string*[] new_args = (string*[]) args;
			
			try {
				unowned string[] tmp = new_args;
				parse_options (command_line, ref tmp);
			} catch (OptionError e) {
				return 1;
			}

			var manager = get_active_manager ();
			Location[]? locations = null;
			int start_line = -1;
			
			foreach (unowned string filename in arg_filenames) {
				Location loc;
				if (filename == "-") {
					loc = new Location (new StreamSource (manager.new_stdin_stream_name (), command_line.get_stdin (), DataSource.new_from_string (command_line.get_cwd ())));
				} else if (filename[0] == '+') {
					// go to line for all the files
					unowned string line = filename.offset (1);
					start_line = int.parse (line)-1;
					continue;
				} else {
					loc = new Location.from_cli_arg (filename);
					if (loc.source is LocalFileSource) {
						var fs = (LocalFileSource) loc.source;
						// replace with real filename based on calling process workdir
						loc.source = new LocalFileSource (command_line.create_file_for_arg (fs.file.get_path()));
					}
				}
				locations += loc;
			}

			// open the sources, focus the first source
			var focus = true;
			var loaded = 0;

			foreach (unowned Location loc in locations) {
				if (loc.start_line < 0) {
					loc.start_line = start_line;
				}
				manager.open_location.begin (manager.last_focused_editor, loc, focus, (s,r) => {
						manager.open_source.end (r);
						loaded++;
						if (loaded > 1 && loaded == locations.length) {
							// mark sources as used in reverse order, except the first one; this is very convenient when opening multiple files
							var lru = manager.last_focused_editor.editor_container.lru;
							lru.used (locations[0].source);
							for (var i=locations.length-1; i >= 1; i--) {
								lru.used (locations[i].source);
							}
						}
				});
				focus = false;
			}

			if (arg_vade_expression != null) {
				var scope = get_editor_scope (manager.last_focused_editor);
				scope.eval_string.begin (arg_vade_expression, null, (s,r) => {
						try {
							var val = scope.eval_string.end (r);
							var str = val.str;
							if (str != null) {
								command_line.print (val.str);
							}
						} catch (Error e) {
							command_line.printerr (e.message);
							command_line.set_exit_status (1);
						}
				});
			} else {
				activate ();
			}
			
			// cleanup
			arg_vade_expression = null;
			arg_filenames = null;

			return 0;
		}

		public override int command_line (ApplicationCommandLine command_line) {
			int res = _command_line (command_line);
			return res;
		}
		
		public override bool local_command_line ([CCode (array_length = false, array_null_terminated = true)] ref unowned string[] args, out int exit_status) {
			exit_status = 0;
			
			try {
				var copy = args;
				unowned string[] tmp = copy;
				parse_options (null, ref tmp);
				/* args = tmp; */
			} catch (OptionError e) {
				exit_status = 1;
				return true;
			}

			if (arg_version) {
				print ("Vanubi " + Configuration.VANUBI_VERSION + "\n");
				return true;
			}
			
			if (arg_standalone) {
				flags |= ApplicationFlags.NON_UNIQUE;
			}
			
			return base.local_command_line (ref args, out exit_status);
		}
	}

	public static int main (string[] args) {
		Gdk.threads_init ();
		var app = new Application ();
		return app.run (args);
	}
}
