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
		
		const OptionEntry[] options = {
			{ "version", 0, 0, OptionArg.NONE, ref arg_version, "Show Vanubi's version", null },
			{ null }
		};
		
		public Application () {
			Object (application_id: "org.vanubi", flags: ApplicationFlags.HANDLES_COMMAND_LINE);
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

		protected override void activate () {
			new_window ();
		}
		
		private string[] clone_args (string[] args) {
			string*[] new_args = new string[args.length];
			for (int i = 0; i < args.length; i++) {
				new_args[i] = args[i];
			}
			return new_args;
		}
		
		private int _command_line (ApplicationCommandLine command_line) {
			/*
			 * We have to make an extra copy of the array, since .parse assumes
			 * that it can remove strings from the array without freeing them.
			 */
			string[] args = command_line.get_arguments ();
			string*[] new_args = clone_args (args);

			try {
				var opt_context = new OptionContext ("[FILE]");
				opt_context.set_help_enabled (true);
				opt_context.set_description ("Please report comments, suggestions and bugs to: \n\t\t" + Configuration.VANUBI_BUGREPORT_URL);
				opt_context.add_main_entries (options, null);
				unowned string[] tmp = new_args;
				opt_context.parse (ref tmp);
			} catch (OptionError e) {
				command_line.print ("Unknown option %s\n", e.message);
				command_line.print ("Run '%s --help' to see a full list of available command line options.\n", args[0]);
				return 1;
			}

			if (arg_version) {
				command_line.print ("Vanubi " + Configuration.VANUBI_VERSION + "\n");
				return 0;
			}

			var win = get_active_window ();
			if (win == null) {
				win = new_window ();
			}

			if (new_args.length > 1) {
				var manager = (Manager) win.get_child ();
				/* Load only the first file. */
				/* XXX: to load all passed files we must resolve first the SorceView bug */
				manager.open_file.begin (manager.get_first_visible_editor (), File.new_for_path (args[1]));
				win.present ();
			}

			return 0;
		}

		public override int command_line (ApplicationCommandLine command_line) {
			this.hold ();
			int res = _command_line (command_line);
			this.release ();
			return res;
		}
	}

	public static int main (string[] args) {
		Gdk.threads_init ();
		var app = new Application ();
		return app.run (args);
	}
}
