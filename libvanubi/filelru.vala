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
	// well not really lru :S it's queue
	public class FileLRU {
		List<File> lru = new List<File> ();
		
		static int filecmp (File? f1, File? f2) {
			if (f1 == f2) {
				return 0;
			}
			if (f1 != null && f1.equal (f2)) {
				return 0;
			}
			return -1;
		}

		public void append (File? f) {
			unowned List<File> link = lru.find_custom (f, filecmp);
			// ensure we have no duplicates
			if (link == null) {
				lru.append (f);
			}
		}
		
		public void used (File? f) {
			// bring to head
			unowned List<File> link = lru.find_custom (f, filecmp);
			if (link != null) {
				lru.delete_link (link);
				lru.prepend (f);
			}
		}
		
		public void remove (File? f) {
			unowned List<File> link = lru.find_custom (f, filecmp);
			if (link != null) {
				lru.delete_link (link);
			}
		}
		
		public unowned List<File> list () {
			return lru;
		}
		
		public FileLRU copy () {
			var res = new FileLRU ();
			res.lru = lru.copy ();
			return res;
		}
	}
}
