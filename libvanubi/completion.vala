/*
 *  Copyright © 2014 Luca Bruno
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
	public class AbbrevCompletion {
		LRU<string> lru = new LRU<string> (strcmp);
		Annotated<string>[] tags = null;
		Regex regex;

		public AbbrevCompletion () {
			try {
				regex = new Regex ("\\w+", RegexCompileFlags.MULTILINE | RegexCompileFlags.OPTIMIZE);
			} catch (Error e) {
				warning (e.message);
			}
		}

		public void index_text (string text) {
			lock (tags) {
				lru.clear ();
				tags = null;
			}

			MatchInfo info;
			regex.match (text, 0, out info);

			while (info.matches ()) {
				var tag = info.fetch (0);
				
				lock (tags) {
					lru.append (tag);
					tags += new Annotated<string> (tag, tag);
				}
				
				info.next ();
			}
		}

		// First result is always the first string in the lru
		public async string[]? complete (string pattern, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			if (tags.length == 0) {
				return null;
			}
			
			Annotated<string>[] tags = null;
			string first = null;
			
			lock (this.tags) {
				tags = this.tags; // make a copy to avoid lock contention
				if (lru.list() != null) {
					first = lru.list().data;
				}
			}
			
			GenericArray<Annotated<string>> matches;
			try {
				matches = yield run_in_thread (() => { return pattern_match_many<string> (pattern, tags, true, cancellable); });
			} catch (IOError.CANCELLED e) {
				return null;
			}

			// show lru head first
			string[] res = null;
			if (first != null) {
				res += first;
			}
			
			foreach (unowned Annotated<string> an in matches.data) {
				if (an.obj == first) {
					continue;
				}
				res += an.obj;
			}

			return res;
		}

		public void used (string tag) {
			lock (tags) {
				lru.used (tag);
			}
		}
	}
}