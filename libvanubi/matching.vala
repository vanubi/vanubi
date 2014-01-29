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

	/* An object annotated with a string */
	public class Annotated<G> {
		public string str;
		public G? obj;

		public Annotated (owned string str, owned G? obj) {
			this.obj = (owned) obj;
			this.str = (owned) str;
		}
	}

	/* Object match with score */
	public class Match<G> {
		public G obj;
		internal int score;

		public Match (G obj, int score) {
			this.obj = obj;
			this.score = score;
		}
	}

	public int match_compare_func (Match** a, Match** b) {
		return (*a)->score - (*b)->score;
	}

	/* Matches a pattern against objects, and returns a ranking of the objects that match */
	public GenericArray<Annotated<G>> pattern_match_many<G> (string pattern, Annotated<G>[] objects, Cancellable? cancellable = null) throws Error {
		Match<Annotated<G>?>[] matches = null;
		foreach (var object in objects) {
			cancellable.set_error_if_cancelled ();
			var score = pattern_match (pattern, object.str);
			if (score >= 0) {
				matches += new Match<Annotated<G>?> ((owned) object, score);
			}
		}
		qsort_with_data<Match> (matches, sizeof (Match), (CompareDataFunc<Match>) match_compare_func);
		cancellable.set_error_if_cancelled ();

		var result = new GenericArray<Annotated<G>> ();
		foreach (var match in matches) {
			result.add ((owned) match.obj);
		}
		return result;
	}

	public void compute_common_prefix (string str, ref string prefix) {
		var l = int.min (str.length, prefix.length);
		for (var i=0; i < l; i++) {
			if (str[i] != prefix[i]) {
				prefix = str.substring (0, i);
				break;
			}
		}
	}
}
