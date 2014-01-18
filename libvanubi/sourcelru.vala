/*
 *  Copyright © 2013-2014 Luca Bruno
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
	// last recently used
	public class SourceLRU {
		List<DataSource> lru = new List<DataSource> ();

		public void append (DataSource? f) {
			unowned List<DataSource> link = lru.find_custom (f, (CompareFunc) DataSource.equal);
			// ensure we have no duplicates
			if (link == null) {
				lru.append (f);
			}
		}
		
		public void used (DataSource s) {
			// bring to head
			unowned List<DataSource> link = lru.find_custom (s, (CompareFunc) DataSource.equal);
			if (link != null) {
				lru.delete_link (link);
				lru.prepend (s);
			}
		}
		
		public void remove (DataSource? f) {
			unowned List<DataSource> link = lru.find_custom (f, (CompareFunc) DataSource.equal);
			if (link != null) {
				lru.delete_link (link);
			}
		}
		
		public unowned List<DataSource> list () {
			return lru;
		}
		
		public SourceLRU copy () {
			var res = new SourceLRU ();
			res.lru = lru.copy ();
			return res;
		}
	}
}
