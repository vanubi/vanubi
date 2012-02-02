namespace Vanubi {
	async string[] file_complete_pattern (MatchWorker worker, File file, int index, string[] pattern, Cancellable cancellable) throws Error {
		File child = file.get_child (pattern[index]);
		if (index < pattern.length-1 && child.query_exists ()) {
			// perfect directory match
			return yield file_complete_pattern (worker, child, index+1, pattern, cancellable);
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
					} else {
						worker.enqueue (info.get_name ());
					}
				}
				if (infos.length () < 1000) {
					break;
				}
			}
		} catch (Error e) {
		}

		string[] matches = yield worker.get_result ();
		cancellable.set_error_if_cancelled ();
		if (index >= pattern.length-1) {
			return matches;
		}
		string[] result = new string[0];
		// compute next index
		while (index < pattern.length-1 && pattern[++index] == null);
		foreach (unowned string match in matches) {
			bool is_directory = match[match.length-1] == '/';
			if (!is_directory) {
				result += match;
				continue;
			}
			match.data[match.length-1] = '\0';
			File cfile = file.get_child (match);
			string[] children = yield file_complete_pattern (worker, cfile, index, pattern, cancellable);
			cancellable.set_error_if_cancelled ();
			if (children.length > 0) {
				foreach (unowned string cmatch in children) {
					result += match+"/"+cmatch;
				}
			}
		}
		return result;
	}

	async string[] file_complete (owned string path, Cancellable cancellable) throws Error {
		path = File.new_for_path(".").get_path ()+"/"+path;
		int abs = path.last_index_of ("//");
		int home = path.last_index_of ("~/");
		if (abs > home) {
			path = path.substring (abs+1);
		} else if (home > abs) {
			path = Path.build_filename (Environment.get_home_dir (), path.substring (home+1));
		}
		string[] comps = path.split ("/");
		comps[0] = null; // empty group before the first separator

		// resolve ../ beforehand
		for (int i=1; i < comps.length; i++) {
			if (comps[i][0] == '.' && comps[i][1] == '.' && comps[i][2] == 0) {
				comps[i] = null;
				for (int j=i-1; j >= 0; j--) {
					if (comps[j] != null) {
						comps[j] = null;
						break;
					}
				}
			}
		}
		// skip trailing nulls
		while (comps.length > 0 && comps[comps.length-1] == null) {
			comps.length--;
		}
		if (comps.length == 0) {
			return new string[0];
		}
		// skip leading nulls
		int index = 0;
		while (comps[index] == null) {
			index++;
		}

		var worker = new MatchWorker (cancellable);
		File file = File.new_for_path ("/");
		string[] result = null;
		try {
			result = yield file_complete_pattern (worker, file, index, comps, cancellable);
		} finally {
			worker.terminate ();
		}
		cancellable.set_error_if_cancelled ();
		return result;
	}

	class FileBar : Bar {
		protected override async string[]? complete (string pattern, Cancellable cancellable) {
			try {
				return yield file_complete (pattern, cancellable);
			} catch (Error e) {
				return null;
			}
		}

		protected override string get_pattern_from_choice (string original_pattern, string choice) {
			int choice_seps = count (choice, '/');
			int pattern_seps = count (original_pattern, '/');
			if (choice[choice.length-1] == '/' && original_pattern[original_pattern.length-1] != '/') {
				// automatically added to determine a directory
				choice_seps--;
			}
			int keep_seps = pattern_seps - choice_seps;

			int idx = 0;
			for (int i=0; i < keep_seps; i++) {
				idx = original_pattern.index_of_char ('/', idx);
				idx++;
			}
			return original_pattern.substring (0, idx)+choice;
		}

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
	}
}
