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
	class FileBar : CompletionBar<FileSource> {
		string base_directory;
		FileSource root;

		public FileBar (FileSource base_source) {
			base_directory = base_source.local_path+"/";
			root = (FileSource) base_source.root;
			entry.set_text(base_directory);
		}

		public override void grab_focus () {
			base.grab_focus ();
			if (entry.get_text () != "") {
				entry.move_cursor (MovementStep.BUFFER_ENDS, 1, false);
			}
		}
		
		protected override async Annotated<FileSource>[]? complete (string pattern, out string common_choice, Cancellable cancellable) throws Error {
			common_choice = pattern;
			var absolute_pattern = absolute_path (base_directory, pattern);
			debug("Completing file pattern %s, base dir %s, root %s, abs pattern %s", pattern, base_directory, root.to_string(), absolute_pattern);

			var files = yield run_in_thread<GenericArray<FileSource>> (() => { return (GenericArray<FileSource>) file_complete (root, absolute_pattern, cancellable); });
			debug("Got %d files", files.length);

			if (files.length == 0) {
				return null;
			}
				
			// Common base directory
			string[] common_comps = files[0].local_path.split("/");
			common_comps[common_comps.length-1] = null;
			common_comps.length--;
			for (var i=1; i < files.length; i++) {
				var comps = files[i].local_path.split("/");
				for (var j=0; j < int.min(common_comps.length, comps.length); j++) {
					if (comps[j] != common_comps[j]) {
						common_comps.length = j;
						common_comps[j] = null;
						break;
					}
				}
			}

			var common_comp_index = string.joinv ("/", common_comps).length+1;
			Annotated<FileSource>[] res = null;
			// only display the uncommon part of the files
			foreach (var file in files.data) {
				var path = file.local_path.substring(common_comp_index);
				var isdir = yield file.is_directory ();
				if (isdir) {
					// append / for hinting the user that this is a directory
					path += "/";
				}
				res += new Annotated<FileSource> (path, file);
			}

			// common choice
			// 1. compute the common prefix among all files
			common_choice = files[0].local_path;
			for (var i=1; i < files.length; i++) {
				compute_common_prefix (files[i].local_path, ref common_choice);
			}
			// 2. if the common prefix is shorter than the pattern, fill missing pieces with components from the pattern
			var pat_comps = absolute_pattern.split("/");
			var prefix_comps = common_choice.split("/");
			for (var i=0; i < prefix_comps.length; i++) {
				if (pat_comps[i].length > prefix_comps[i].length) {
					prefix_comps[i] = pat_comps[i];
				}
			}
			for (var i=prefix_comps.length; i < pat_comps.length; i++) {
				prefix_comps += pat_comps[i];
			}
			common_choice = string.joinv ("/", prefix_comps);
			return res;
		}

		protected override void set_choice_to_entry () {
			var choice = get_annotated_choice ();
			var choicestr = choice.obj.local_path;
			if (choice.str.has_suffix ("/")) {
				// directory
				choicestr += "/";
			}
			entry.set_text (get_pattern_from_choice (original_pattern, choicestr));
			entry.move_cursor (MovementStep.BUFFER_ENDS, 1, false);
		}
		
		// choice must be an absolute path
		protected override string get_pattern_from_choice (string original_pattern, string choice) {
			string absolute_pattern = absolute_path (base_directory, original_pattern);
			int choice_seps = count (choice, '/');
			int pattern_seps = count (absolute_pattern, '/');
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
			
			if (res[res.length-1] != '/' && choice[choice.length-1] == '/') {
				return res + "/";
			} else {
				return res;
			}
		}
	}
}
