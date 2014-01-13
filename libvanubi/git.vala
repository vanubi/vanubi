/*
 *  Copyright © 2014 Luca Bruno
 *  Copyright © 2014 Rocco Folino
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

namespace Vanubi {
	public enum DiffType {
		ADD,
		DEL,
		MOD
	}

	public class Git {
		unowned Configuration config;
		
		public Git (Configuration config) {
			this.config = config;
		}
		
		/* Returns the git directory that contains this file */
		public File? get_repo (File? file) {
			if (file == null) {
				return null;
			}
			var git_command = config.get_global_string ("git_command", "git");
			string stdout;
			string stderr;
			int status;
			try {
				string[] argv;
				Shell.parse_argv (@"$git_command rev-parse --show-cdup", out argv);
				if (!Process.spawn_sync (file.get_parent().get_path(),
										 argv, null, SpawnFlags.SEARCH_PATH,
										 null, out stdout, out stderr, out status)) {
					return null;
				}
				if (stderr.strip() != "") {
					return null;
				}
				if (status != 0) {
					return null;
				}
				return file.get_parent().get_child (stdout.strip ());
			} catch (Error e) {
				return null;
			}
		}
		
		public void grep () {
			/* TODO */
		}
		
		/* Based on https://github.com/jisaacks/GitGutter/blob/master/git_gutter_handler.py#L116 */
		private void parse_diff (uint8[] diff_buffer, ref HashTable<int, DiffType> table) {
			Regex hr = new Regex ("^@@ -(\\d+),?(\\d*) \\+(\\d+),?(\\d*) @@");
			string[] lines = ((string)diff_buffer).split ("\n");
			for (var i=0; i<lines.length; i++) {
				MatchInfo hunks;
				if (hr.match (lines[i], 0, out hunks)) {
					int start = int.parse (hunks.fetch (3));
					int old_size = (hunks.fetch (2) == "") ? 1 : int.parse (hunks.fetch (2));
					int new_size = (hunks.fetch (4) == "") ? 1 : int.parse (hunks.fetch (4));
					
					if (old_size == 0) {
						for (var j=start; j<(start + new_size); j++) {
							table.insert (j, DiffType.ADD);
						}
					} else if (new_size == 0) {
						table.insert (start + 1, DiffType.DEL);
					} else {
						for (var j=start; j<(start + new_size); j++) {
							table.insert (j, DiffType.MOD);
						}
					}
				}
			}
		}
		
		public async HashTable<int, DiffType> diff_buffer (File file, uint8[] input) {
			HashTable<int, DiffType> table = new HashTable<int, DiffType> (null, null);
			var repo = get_repo (file);
			if (repo == null) {
				return table;
			}
			var git_command = config.get_global_string ("git_command", "git");
			var filename = repo.get_relative_path (file);
			
			try {
				string cmdline =@"diff -d -U0 <($git_command show HEAD:$filename) -";
				var output = yield execute_shell_async (repo, cmdline, input);
				parse_diff (output, ref table);
				return table;
			} catch (Error e) {
				return table;
			}
		}
	}
}
