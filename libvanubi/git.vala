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
		static Regex hunk_regex;
		
		static construct {
			try {
				hunk_regex = new Regex ("^@@ -(\\d+),?(\\d*) \\+(\\d+),?(\\d*) @@");
			} catch (Error e) {
				warning (e.message);
			}
		}
		
		public Git (Configuration config) {
			this.config = config;
		}
		
		/* Returns the git directory that contains this file */
		public async FileSource? get_repo (FileSource dir, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) {
			var git_command = config.get_global_string ("git_command", "git");

			int status;
			var cmd = @"$git_command rev-parse --show-cdup";
			var stdout = (string) yield dir.execute_shell (cmd, null, null, out status, io_priority, cancellable);
			if (status != 0 || stdout == null) {
				return null;
			}
			return (FileSource) dir.child (stdout.strip ());
		}

		public async bool file_in_repo (FileSource file, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			var git_command = config.get_global_string ("git_command", "git");
			int status;
			var escaped = Shell.quote (file.local_path);
			var cmd = @"$git_command ls-files --error-unmatch $escaped";
			yield file.parent.execute_shell (cmd, null, null, out status, io_priority, cancellable);
			return status == 0;
		}

		public void grep () {
			/* TODO */
		}
		
		public async string? current_branch (FileSource source, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			var git_command = config.get_global_string ("git_command", "git");
			
			string cmdline = @"$git_command rev-parse --abbrev-ref HEAD";
			int status;
			var output = (string) yield source.parent.execute_shell (cmdline, null, null, out status, io_priority, cancellable);
			
			if (status != 0 || output == null || output.strip () == "") {
				return null;
			}
			
			return output.strip ();
		}
		
		/* Based on https://github.com/jisaacks/GitGutter/blob/master/git_gutter_handler.py#L116 */
		private HashTable<int, DiffType>? parse_diff (uint8[] diff_buffer, Cancellable cancellable) {
			var table = new HashTable<int, DiffType> (null, null);
			string[] lines = ((string)diff_buffer).split ("\n");
			
			for (var i=0; i<lines.length; i++) {
				if (cancellable.is_cancelled ()) {
					return null;
				}
				
				MatchInfo hunks;
				if (hunk_regex.match (lines[i], 0, out hunks)) {
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
			
			return table;
		}
		
		public async HashTable<int, DiffType>? diff_buffer (FileSource file, owned uint8[] input, int io_priority = GLib.Priority.DEFAULT, Cancellable cancellable) throws Error {
			var in_repo = yield file_in_repo (file, io_priority, cancellable);
			if (!in_repo) {
				return null;
			}
			
			var repo = yield get_repo ((FileSource) file.parent, io_priority, cancellable);
			if (repo == null) {
				return null;
			}
			var git_command = config.get_global_string ("git_command", "git");
			var filename = repo.get_relative_path (file);
			
			string cmdline = @"diff -d -U0 <($git_command show HEAD:$filename) -";
			var output = yield repo.execute_shell (cmdline, input, null, null, io_priority, cancellable);
			cancellable.set_error_if_cancelled ();
			
			var table = yield run_in_thread<HashTable<int, DiffType>> (() => { return parse_diff (output, cancellable); });
			cancellable.set_error_if_cancelled ();
			
			return table;
		}
	}
}
