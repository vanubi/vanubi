/*
 *  Copyright © 2015 Luca Bruno
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

namespace Vanubi.UI {
	public class SelectionTree {
		GenericArray<EditorSelection> arr = new GenericArray<EditorSelection> ();

		public void add (EditorSelection sel) {
			int left, right;
			sel.get_offsets (out left, out right);

			var first = -1;
			var last = -1;
			
			// find the first selection that ovarlaps with the given selection
			var imin = 0;
			var imax = arr.length-1;
			while (imin <= imax) {
				var cur = imin + ((imax - imin) / 2);
				var s = arr[cur];
				int curleft, curright;
				s.get_offsets (out curleft, out curright);

				if (curleft <= left) {
					if (left <= curright) {
						// overlap
						if (right <= curright) {
							// inside
							return;
						} else {
							// mark for merge
							first = cur;
							break;
						}
					} else {
						// look right
						imin = cur+1;
					}
				} else {
					// look left
					imax = cur-1;
				}
			}

			// find the last selection that overlaps with the given selection
			imin = left+1;
			imax = arr.length-1;
			while (imin <= imax) {
				var cur = imin + ((imax - imin) / 2);
				var s = arr[cur];
				int curleft, curright;
				s.get_offsets (out curleft, out curright);

				if (curleft <= right) {
					if (right <= curright) {
						// overlap, mark for merge
						last = cur;
						break;
					} else {
						// look right
						imin = cur+1;
					}
				} else {
					// look left
					imax = cur-1;
				}
			}

			var left_mark = left >= 0 ? arr[left].start : sel.start;
			var right_mark = right >= 0 ? arr[right].end : sel.end;

			// remove all selections from left+1 to right inclusive, then replace left with the new selection
			right = right >= 0 ? right : arr.length-1;
			arr.remove_range (left+1, right);

			var newsel = new EditorSelection (left_mark, right_mark);
			if (left < 0) {
				// new left-most selection
				arr.insert (0, newsel);
			} else {
				arr[left] = newsel;
			}
		}
	}
}