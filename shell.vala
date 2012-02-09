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
