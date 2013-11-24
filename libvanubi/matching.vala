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
	// returns a ranking, lower is better, 0 for perfect match, -1 for no match
	public int pattern_match (string pattern, string haystack) {
		int rank = 0;
		int n = pattern.length;
		int m = haystack.length;
		int j = 0;
		for (int i=0; i < n; i++) {
			char c = pattern[i];
			bool found = false;
			for (; j < m; j++) {
				if (c.tolower () == haystack[j].tolower ()) {
					found = true;
					break;
				}
				rank += j+100;
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

	public int count (string haystack, unichar c) {
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

	public class MatchWorker {
		AsyncQueue<string?> queue = new AsyncQueue<string?> ();
		SourceFunc resume;
		string[] matches;
		int[] match_values;
		string[] unmatched;
		string pattern; // should be volatile
		string common_prefix; // should be volatile
		Cancellable cancellable;

		public MatchWorker (Cancellable cancellable) {
			this.cancellable = cancellable;
			matches = new string[0];
			match_values = new int[0];
			IOSchedulerJob.push (work, Priority.DEFAULT, cancellable);
		}

		public void set_pattern (string pattern) {
			this.pattern = pattern;
			this.common_prefix = null;
			matches.length = 0;
			match_values.length = 0;
			unmatched.length = 0;
		}

		public void terminate () {
			string* foo = (string*)0x1beef;
			queue.push ((owned)foo);
		}

		static int compare_func (int* a, int* b) {
			return (*a & 0xFFFF) - (*b & 0xFFFF);
		}

		public async string[] get_result (out string? common_prefix) throws Error {
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
			common_prefix = null;
			var common_prefix_down = this.common_prefix != null ? this.common_prefix.down () : null;
			if (common_prefix_down != null && common_prefix_down.has_prefix (pattern.down ())) {
				bool unmatched_match = false;
				foreach (unowned string unmatch in unmatched) {
					// unmatched string must not match against the common prefix
					if (unmatch.down().has_prefix (common_prefix_down)) {
						unmatched_match = true;
						break;
					}
				}
				if (!unmatched_match) {
					common_prefix = this.common_prefix;
				}
			}

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
					// common prefix
					if (common_prefix == null) {
						common_prefix = haystack;
					} else {
						var cpl = common_prefix.length;
						var l = int.min (haystack.length, cpl);
						if (l >= cpl) {
							common_prefix.data[l] = '\0';
						}
						common_prefix.data[l] = '\0';
						for (int i=0; i < l; i++) {
							if (common_prefix[i].tolower() != haystack[i].tolower()) {
								common_prefix.data[i] = '\0';
								break;
							}
						}
					}
					// store match
					match_values += match | (matches.length << 16);
					matches += (owned) haystack;
				} else {
					// no match
					unmatched += (owned) haystack;
				}
			}
			return false;
		}
	}
}
