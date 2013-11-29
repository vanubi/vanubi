/*
 *  Copyright © 2011-2013 Luca Bruno
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
	class FileBar : CompletionBar {
		string base_directory;

		public FileBar (File? base_file) {
			base (true);
			base_directory = get_base_directory (base_file);
			entry.set_text(base_directory);
		}

		protected override async Annotated<File>[]? complete (string pattern, Cancellable cancellable) {
			try {
				var files = yield run_in_thread<GenericArray<File>> ((c) => { return file_complete (pattern, c); }, cancellable);
				Annotated<File>[] res = null;
				for (var i=0; i < files.length; i++) {
					res += new Annotated<File> (files[i].get_path (), files[i]);
				}
				return res;
			} catch (Error e) {
				return null;
			}
		}

		protected override string get_pattern_from_choice (string original_pattern, string choice) {
			string absolute_pattern = absolute_path (base_directory, original_pattern);
			int choice_seps = count (choice, '/');
			int pattern_seps = count (absolute_pattern, '/');
			if (choice[0] != '/' && choice[choice.length-1] == '/') {
				// relative
				choice_seps--;
			}
			int keep_seps = pattern_seps - choice_seps;

			int idx = 0;
			for (int i=0; i < keep_seps; i++) {
				idx = absolute_pattern.index_of_char ('/', idx);
				idx++;
			}

			string new_absolute_pattern = absolute_pattern.substring (0, idx)+choice;
			string res;
			if (original_pattern[0] == '/') {
				// absolute path
				res = (owned) new_absolute_pattern;
			} else {
				int n_sep = 0;
				int last_sep = 0;
				int len = int.min (base_directory.length, new_absolute_pattern.length);
				for (int i=0; i < len; i++) {
					if (base_directory[i] != new_absolute_pattern[i]) {
						break;
					}
					if (base_directory[i] == '/') {
						last_sep = i;
						n_sep++;
					}
				}
				int base_seps = count (base_directory, '/');
				var relative = "";
				for (int i=0; i < base_seps-n_sep; i++) {
					relative += "../";
				}
				relative += new_absolute_pattern.substring (last_sep+1);
				res = (owned) relative;
			}

			if (res[res.length-1] != '/' && File.new_for_path (res).query_file_type (FileQueryInfoFlags.NONE) == FileType.DIRECTORY) {
				return res + "/";
			} else {
				return res;
			}
		}
	}
}
