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
	 public class MarkManager {
		 List<Location> stack = null;
		 unowned List<Location> current = null;
		 
		 public void mark (Location loc) {
			 if (current == null) {
				 stack.append (loc);
			 } else {
				 if (current.next == null) {
					 stack.append (loc);
					 current = null;
				 } else {
					 current = current.next;
					 stack.insert_before (current, loc);
				 }
			 }
		 }
		 
		 public Location? prev_mark () {
			 if (stack == null) {
				 return null;
			 }
			 
			 if (current != null && current.prev == null) {
				 return null;
			 }
			 
			 if (current == null) {
				 current = stack.last ();
			 } else {
				 current = current.prev;
			 }
			 
			 if (current == null) {
				 return null;
			 }
			 return current.data;
		 }
		 
		 public Location? next_mark () {
			 if (stack == null || current == null) {
				 return null;
			 }
			 
			 current = current.next;
			 if (current == null) {
				 return null;
			 }
			 return current.data;
		 }
	 }
 }