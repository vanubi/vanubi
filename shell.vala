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
	public class ShellBar : Grid {
		Terminal term;

		public ShellBar (string command, File? base_file) {
			expand = true;
			term = new Terminal ();
			term.expand = true;
			var shell = Vte.get_user_shell ();
			if (shell == null) {
				shell = "/bin/sh";
			}
			try {
				string[] argv;
				Shell.parse_argv (command, out argv);
				var workdir = get_base_directory (base_file);
				term.fork_command_full (PtyFlags.DEFAULT, workdir, argv, null, SpawnFlags.SEARCH_PATH, null, null);
			} catch (Error e) {
				message (e.message);
			}
			add (term);
			show_all ();
		}		
	}
}
