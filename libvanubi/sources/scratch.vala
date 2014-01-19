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
	public class ScratchSource : DataSource {
		public static ScratchSource instance {
			get {
				if (_instance == null) {
					_instance = new ScratchSource ();
				}
				return _instance;
			}
		}
		
		static ScratchSource _instance = null;
		
		private ScratchSource () {
		}
		
		public override DataSource? parent {
			owned get {
				return new LocalFileSource (File.new_for_path (Environment.get_current_dir()));
			}
		}
		
		public override async bool exists (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError.CANCELLED {
			return false;
		}
		
		public override async InputStream read (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			throw new IOError.NOT_SUPPORTED ("*scratch* is not readable");
		}
		
		public override async TimeVal? get_mtime (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) {
			return null;
		}
		
		public override async void monitor (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError.CANCELLED {
		}
		
		public override async void write (uint8[] data, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			throw new IOError.NOT_SUPPORTED ("*scratch* is not writable");
		}
		
		public override DataSource child (string path) {
			return this;
		}
		
		public override async bool is_directory (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError.CANCELLED {
			return false;
		}
		
		public override async uint8[] execute_shell (string command_line, uint8[]? input = null, out uint8[] errors = null, out int status = null, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			throw new IOError.INVALID_ARGUMENT ("Commands must be executed in a directory");
		}
		
		public override SourceIterator iterate_children (Cancellable? cancellable = null) throws Error {
			return parent.iterate_children (cancellable);
		}
		
		public override uint hash () {
			return 0;
		}
		
		public override bool equal (DataSource? s) {
			return this == s;
		}
		
		public override string to_string () {
			return "*scratch*";
		}
	}
}