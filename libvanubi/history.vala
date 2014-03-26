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
	public class History<G> {
		GenericArray<G> hist;
		EqualFunc<G> eqfunc;
		int limit;

		public History (owned EqualFunc<G> eqfunc, int limit) {
			init ();
			this.eqfunc = (owned) eqfunc;
			this.limit = limit;
		}

		public void init () {
			hist = new GenericArray<G> ();
		}

		public void add (owned G g) {
			unowned G? last = get (0);
			if (last != null && eqfunc (g, last)) {
				return;
			}
			
			hist.add ((owned) g);
			if (length > limit) {
				hist.remove_index (0);
			}
		}

		public unowned G? get (int n) {
			int i = hist.length-n-1;
			if (i < 0 || i >= hist.length) {
				return null;
			}
			return hist[i];
		}

		public int length { get { return hist.length; } }
	}
}