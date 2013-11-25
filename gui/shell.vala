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
	public class ShellBar : Bar {
		Terminal term;
		Configuration config;

		public ShellBar (Configuration config, File? base_file) {
			this.config = config;
			expand = true;
			term = base_file.get_data ("shell");
			if (term == null) {
				term = create_new_term (base_file);
				base_file.set_data ("shell", term);
			}
			Pid pid = term.get_data ("pid");
			term.expand = true;
			term.key_press_event.connect (on_key_press_event);
			if (base_file != null) {
				term.commit.connect (() => {
						var buf = new char[1024];
						var olddir = config.get_file_string (base_file, "shell_cwd", get_base_directory (base_file));
						if (Posix.readlink (@"/proc/$(pid)/cwd", buf) > 0) {
							var curdir = (string) buf;
							if (olddir != curdir) {
								config.set_file_string (base_file, "shell_cwd", curdir);
								config.save.begin ();
							}
						}
					});
			}
			add (term);
			show_all ();
		}

		Terminal create_new_term (File? base_file) {
			var term = new Terminal ();
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
				term.feed_child ("make -k", -1);

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
			if ((e.keyval == Gdk.Key.g && Gdk.ModifierType.CONTROL_MASK in e.state)) {
				aborted ();
				return true;
			}
			return false;
		}
	}
}
