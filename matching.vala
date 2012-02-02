namespace Vanubi {
	// returns a ranking, lower is better (0 = perfect match)
	public int pattern_match (string pattern, string haystack) {
		int rank = 0;
		int n = pattern.length;
		int m = haystack.length;
		int j = 0;
		for (int i=0; i < n; i++) {
			char c = pattern[i];
			bool found = false;
			for (; j < m; j++) {
				if (c == haystack[j]) {
					found = true;
					break;
				}
				rank++;
			}
			if (!found) {
				// no match
				return -1;
			}
			j++;
		}
		rank += m-j;
		return rank;
	}

	class MatchWorker {
		AsyncQueue<string?> queue = new AsyncQueue<string?> ();
		SourceFunc resume;
		string[] matches;
		int[] match_values;
		string pattern; // should be volatile
		Cancellable cancellable;

		public MatchWorker (Cancellable cancellable) {
			this.cancellable = cancellable;
			matches = new string[0];
			match_values = new int[0];
			IOSchedulerJob.push (work, Priority.DEFAULT, cancellable);
		}

		public void set_pattern (string pattern) {
			this.pattern = pattern;
		}

		public void terminate () {
			string* foo = (string*)0x1beef;
			queue.push ((owned)foo);
		}

		static int compare_func (int* a, int* b) {
			return (*a & 0xFFFF) - (*b & 0xFFFF);
		}

		public async string[] get_result () throws Error {
			this.resume = get_result.callback;
			string* foo = (string*)0x0dead;
			queue.push ((owned)foo);
			yield;
			cancellable.set_error_if_cancelled ();

			qsort_with_data<int> (match_values, sizeof (int), (CompareDataFunc<int>) compare_func);
			var result = new string[matches.length];
			for (int i=0; i < matches.length; i++) {
				var pos = (match_values[i] >> 16) & 0xFFFF;
				result[i] = (owned) matches[pos];
			}
			matches.length = 0;
			match_values.length = 0;
			return result;
		}

		public void enqueue (owned string s) {
			queue.push ((owned) s);
		}

		bool work (IOSchedulerJob job, Cancellable? cancellable) {
			while (true) {
				string* item = queue.pop ();
				if ((int)(long)item == 0x0dead) {
					// partial result
					job.send_to_mainloop_async ((owned) resume);
					continue;
				} else if ((int)(long)item == 0x1beef) {
					// job complete
					break;
				}
				if (cancellable.is_cancelled ()) {
					job.send_to_mainloop_async ((owned) resume);
					break;
				}
				string haystack = (owned) item;
				int match = pattern_match (pattern, haystack);
				if (match >= 0) {
					match_values += match | (matches.length << 16);
					matches += (owned) haystack;
				}
			}
			return false;
		}
	}
}
