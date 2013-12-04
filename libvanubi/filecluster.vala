/*
 *  Copyright © 2013 Luca Bruno
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
	public class FileCluster {
		unowned Configuration config;
		List<File> opened_files;

		public FileCluster (Configuration config) {
			this.config = config;
		}
		
		public void opened_file (File f) {
			unowned List<File> link = opened_files.find_custom (f, (CompareFunc) File.equal);
			// ensure we have no duplicates
			if (link == null) {
				opened_files.append (f);
			}
		}
		
		public void closed_file (File f) {
			unowned List<File> link = opened_files.find_custom (f, (CompareFunc) File.equal);
			if (link != null) {
				opened_files.delete_link (link);
			}
		}
		
		// Returns a similar file, or itself, for a given configuration key
		public File get_similar_file (File file, string key, bool has_default) {
			if (key == "language" && has_default) {
				// use the default language, do not look further
				return file;
			}
			
			var files = config.get_files ();
			foreach (var other in files) {
				if (file.get_parent().equal (other.get_parent ())) {
					return other;
				}
			}
			return file;
		}
		
		// Returns the git directory that contains this file
		public File? get_git_repo (File? file) {
			if (file == null) {
				return null;
			}
			var git_command = config.get_global_string ("git_command", "git");
			string stdout;
			int status;
			try {
				string[] argv;
				Shell.parse_argv (@"$git_command rev-parse --show-toplevel", out argv);
				if (!Process.spawn_sync (file.get_parent().get_path(),
										 {git_command, "rev-parse", "--show-toplevel"},
										 null,
										 SpawnFlags.SEARCH_PATH,
										 null, out stdout, null, out status)) {
					return null;
				}
				if (status != 0) {
					return null;
				}
				if (stdout.strip() == "") {
					return null;
				}
				return File.new_for_path (stdout.strip ());
			} catch (Error e) {
				return null;
			}
		}
	}
}