/*
 *  Copyright © 2014-2016 Luca Bruno
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
	public class ErrorLocations {
		weak State state;
		List<Location<string>> list = new List<Location> ();
		unowned List<Location<string>> current = null;

		public ErrorLocations (State state) {
			this.state = state;
		}

		public void add (Location loc) {
			list.append (loc);
			state.status.set ("Found %u errors".printf (list.length ()), "errors");
		}

		public void reset () {
			list = new List<Location> ();
			current = null;
			state.status.clear ("errors");
		}
		
		public Location? next_error () {
			if (list == null) {
				return null;
			}
			
			if (list.length() == 1 || current == null) {
				current = list;
				return current.data;
			}

			if (current.next != null) {
				current = current.next;
				return current.data;
			}

			return null;
		}

		public Location? prev_error () {
			if (list == null) {
				return null;
			}
			
			if (list.length() == 1 || current == null) {
				current = list;
				return current.data;
			}

			if (current.prev != null) {
				current = current.prev;
				return current.data;
			}

			return null;
		}
	}
}