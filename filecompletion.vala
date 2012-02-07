namespace Vanubi {
	static int count (string haystack, unichar c) {
		int cnt = 0;
		int idx = 0;
		while (true) {
			idx = haystack.index_of_char (c, idx);
			if (idx < 0) {
				break;
			}
			cnt++;
			idx++;
		}
		return cnt;
	}

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

	string absolutize_path (string base_directory, string path) {
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

	async string[]? file_complete (string base_directory, string pattern_path, out string? common_choice, Cancellable cancellable) throws Error {
		common_choice = null;
		var pattern = absolutize_path (base_directory, pattern_path);
		string[] comps = pattern.split ("/");
		if (comps.length == 0) {
			return null;
		}
		message("%s %s", base_directory, pattern_path);

		var worker = new MatchWorker (cancellable);
		File file = File.new_for_path ("/");
		string[] result = null;
		var common_prefixes = new string[comps.length];
		try {
			result = yield file_complete_pattern (worker, file, 1, comps, common_prefixes, cancellable);
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

	class FileBar : CompletionBar {
		string base_directory;

		public FileBar (File? base_file) {
			base (true);
			if (base_file != null) {
				var parent = base_file.get_parent ();
				if (parent != null) {
					base_directory = parent.get_path()+"/";
				}
			}
			if (base_directory == null) {message("goo");
				base_directory = Environment.get_current_dir()+"/";
			}
		}

		protected override async string[]? complete (string pattern, out string? common_choice, Cancellable cancellable) {
			try {
				return yield file_complete (base_directory, pattern, out common_choice, cancellable);
			} catch (Error e) {
				return null;
			}
		}

		protected override string get_pattern_from_choice (string original_pattern, string choice) {
			string absolute_pattern = absolutize_path (base_directory, original_pattern);
			int choice_seps = count (choice, '/');
			int pattern_seps = count (absolute_pattern, '/');
			if (choice[choice.length-1] == '/') {
				choice_seps--;
			}
			if (absolute_pattern[absolute_pattern.length-1] == '/') {
				pattern_seps--;
			}
			int keep_seps = pattern_seps - choice_seps;

			int idx = 0;
			for (int i=0; i < keep_seps; i++) {
				idx = absolute_pattern.index_of_char ('/', idx);
				idx++;
			}
			string new_absolute_pattern = absolute_pattern.substring (0, idx)+choice;
			if (original_pattern[0] == '/') {
				// absolute path
				return new_absolute_pattern;
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
				return relative;
			}
		}
	}
}
