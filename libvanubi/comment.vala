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
	public abstract class Comment {
		public abstract void comment (BufferIter iter);
	}
	
	public class Comment_Default : Comment {
		
		Buffer buf;

		public Comment_Default (Buffer buf) {
			this.buf = buf;
		}
		
		public override void comment (BufferIter iter) {
			if (buf.empty_line (iter.line)) {
				return;
			}
			var start_iter = buf.line_start (iter.line);
			start_iter.forward_spaces ();
			buf.insert (start_iter, "/* ");
			var end_iter = buf.line_end (start_iter.line);
			buf.insert (end_iter, " */");
		}
	}
	
	public class Comment_Hash : Comment {
		
		Buffer buf;

		public Comment_Hash (Buffer buf) {
			this.buf = buf;
		}
		
		public override void comment (BufferIter iter) {
			var start_iter = buf.line_start (iter.line);
			start_iter.forward_spaces ();
			buf.insert (start_iter, "# ");
		}
	}
	
	public class Comment_Asm : Comment {
		
		Buffer buf;

		public Comment_Asm (Buffer buf) {
			this.buf = buf;
		}
		
		public override void comment (BufferIter iter) {
			var start_iter = buf.line_start (iter.line);
			start_iter.forward_spaces ();
			buf.insert (start_iter, "; ");
		}
	}
}
