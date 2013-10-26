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
< *  Vanubi is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with Vanubi.  If not, see <http://www.gnu.org/licenses/>.
 */

namespace Vanubi {
	async string[]? file_complete_pattern (MatchWorker worker, File file, int index, string[] pattern, string[] common_prefixes, Cancellable cancellable) throws Error {
		File child = file.get_child (pattern[index]);
		if (index < pattern.length-1 && child.query_exists ()) {
			// perfect directory match
			return yield file_complete_pattern (worker, child, index+1, pattern, common_prefixes, cancellable);
		}

		try {
			var enumerator = yield file.enumerate_children_async (FileAttribute.STANDARD_NAME+","+FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE, Priority.DEFAULT, cancellable);
			cancellable.set_error_if_cancelled ();
			worker.set_pattern (pattern[index]);
			while (true) {
				var infos = yield enumerator.next_files_async (1000, Priority.DEFAULT, cancellable);
				cancellable.set_error_if_cancelled ();

				foreach (var info in infos) {
					if (info.get_file_type () == FileType.DIRECTORY) {
						worker.enqueue (info.get_name ()+"/");
					} else if (index == pattern.length-1) {
						worker.enqueue (info.get_name ());
					}
				}
				if (infos.length () < 1000) {
					break;
				}
			}
		} catch (Error e) {
		}

		string[] matches = yield worker.get_result (out common_prefixes[index]);
		cancellable.set_error_if_cancelled ();
		if (index >= pattern.length-1) {
			return matches;
		}
		string[]? result = null;
		// compute next index
		while (index < pattern.length-1 && pattern[++index] == null);
		foreach (unowned string match in matches) {
			match.data[match.length-1] = '\0';
			File cfile = file.get_child (match);
			string[] children = yield file_complete_pattern (worker, cfile, index, pattern, common_prefixes, cancellable);
			cancellable.set_error_if_cancelled ();
			if (children.length > 0) {
				foreach (unowned string cmatch in children) {
					result += match+"/"+cmatch;
				}
			}
		}
		return result;
	}

	public string absolutize_path (string base_directory, string path) {
		string res = base_directory+path;
		int abs = res.last_index_of ("//");
		int home = res.last_index_of ("~/");
		if (abs > home) {
			res = res.substring (abs+1);
		} else if (home > abs) {
			res = Environment.get_home_dir()+res.substring (home+1);
		}
		res = File.new_for_path (res).get_path ();
		if (path[path.length-1] == '/' || path[0] == '\0') {
			res += "/";
		}
		return res;
	}

	public async string[]? file_complete (string base_directory, string pattern_path, out string? common_choice, Cancellable cancellable) throws Error {
		common_choice = null;
		var pattern = absolutize_path (base_directory, pattern_path);
		string[] comps = pattern.split ("/");
		if (comps.length == 0) {
			return null;
		}

		var worker = new MatchWorker (cancellable);
		File file = File.new_for_path ("/");
		string[] result = null;
		var common_prefixes = new string[comps.length];
		try {
			result = yield file_complete_pattern (worker, file, 1, comps, common_prefixes, cancellable);
		} catch (IOError.CANCELLED e) {
		} catch (Error e) {
			message (e.message);
			return null;
		} finally {
			worker.terminate ();
		}
		cancellable.set_error_if_cancelled ();

		common_choice = "";
		for (int i=1; i < comps.length; i++) {
			if (common_prefixes[i] != null) {
				common_choice += common_prefixes[i]+"/";
			} else {
				common_choice += comps[i]+"/";
			}
		}
		if (common_choice.length == 0) {
			common_choice = null;
		} else {
			common_choice.data[common_choice.length-1] = '\0';
		}
		return result;
	}

	public string get_base_directory (File? base_file) {
		if (base_file != null) {
			var parent = base_file.get_parent ();
			if (parent != null) {
				return parent.get_path()+"/";
			}
		}
		return Environment.get_current_dir()+"/";
	}
}