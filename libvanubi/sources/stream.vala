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
	public class StreamSource : DataSource {
		string name;
		InputStream stream;
		DataSource base_source;
		void* ptr;
		
		public StreamSource (string name, InputStream stream, DataSource base_source) {
			this.name = name;
			this.stream = stream;
			this.base_source = base_source;
			
			this.ptr = stream;
		}
		
		public override DataSource? parent {
			owned get {
				return base_source;
			}
		}

		public override async bool exists (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError.CANCELLED {
			return true;
		}
		
		public override async bool read_only (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError.CANCELLED {
			return false;
		}

		public override async InputStream read (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			if (stream == null) {
				throw new IOError.NOT_SUPPORTED ("Cannot re-read the stream");
			}
			
			var is = stream;
			stream = null;
			return is;
		}
		
		public override async TimeVal? get_mtime (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) {
			return null;
		}
		
		public override async void monitor (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError.CANCELLED {
		}
		
		public override async void write (uint8[] data, bool atomic, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			throw new IOError.NOT_SUPPORTED ("Stream is not writable");
		}
		
		public override DataSource child (string path) {
			return base_source.child (path);
		}
		
		public override async bool is_directory (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError.CANCELLED {
			return false;
		}
		
		public override async uint8[] execute_shell (string command_line, uint8[]? input = null, out uint8[] errors = null, out int status = null, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			throw new IOError.INVALID_ARGUMENT ("Commands must be executed in a directory");
		}
		
		public override SourceIterator iterate_children (Cancellable? cancellable = null) throws Error {
			throw new IOError.NOT_SUPPORTED ("Children can be iterated only in a directory");
		}
		
		public override uint hash () {
			return (uint)(void*) ptr;
		}
		
		public override bool equal (DataSource? s) {
			if (this == s) {
				return true;
			}
			var st = s as StreamSource;
			return st != null && ptr == st.ptr;
		}
		
		public override string to_string () {
			return name;
		}
	}
}