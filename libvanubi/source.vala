/*
 *  Copyright © 2011-2014 Luca Bruno
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
	public abstract class DataSource : Object {
		public signal void changed ();
		
		public abstract DataSource? parent { owned get; }

		public abstract async bool exists (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError.CANCELLED;
		public abstract async InputStream read (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error;
		
		public abstract async void write (uint8[] data, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error;
		
		public abstract async TimeVal? get_mtime (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null);
		public abstract async void monitor (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError.CANCELLED;
		
		public abstract async bool is_directory (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError.CANCELLED;

		public abstract DataSource child (string path);
		
		public abstract uint hash ();
		public abstract bool equal (DataSource? s);		
		public abstract string to_string ();
		
		public int compare (DataSource? s) {
			if (equal (s)) {
				return 0;
			} else {
				return -1;
			}
		}
		
		public static DataSource new_from_string (string path) {
			if (path == "*scratch*") {
				return ScratchSource.instance;
			} else if (path.has_prefix ("file://")) {
				return new LocalFileSource (File.new_for_uri (path));
			} else {
				return new LocalFileSource (File.new_for_path (path));
			}
		}
	}
	
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
			throw new IOError.NOT_SUPPORTED ("*scratch* is not readable");
		}
		
		public override DataSource child (string path) {
			return this;
		}
		
		public override async bool is_directory (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError.CANCELLED {
			return false;
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
	
	public abstract class FileSource : DataSource {
		public abstract string basename { owned get; }
		
		public string get_relative_path (FileSource other) {
			// FIXME:
			return File.new_for_path (to_string()).get_relative_path (File.new_for_path (other.to_string ()));
		}
		
		public string? extension {
			owned get {
				var bn = basename;
				var idx = bn.last_index_of (".");
				if (idx < 0) {
					return null;
				}
				
				return bn.substring (idx+1);
			}
		}
	}
	
	public class LocalFileSource : FileSource {
		public File file { get; private set; }
		FileMonitor _monitor;
		
		public LocalFileSource (owned File file) {
			this.file = (owned) file;
			
		}
		
		public override DataSource? parent {
			owned get {
				var parent = file.get_parent ();
				if (parent != null) {
					return new LocalFileSource (parent);
				}
				// we are at the root of the file system
				return null;
			}
		}
	
		public override string basename {
			owned get {
				return file.get_basename ();
			}
		}

		public override async InputStream read (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			return yield file.read_async (io_priority, cancellable);
		}
		
		public override async bool exists (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError.CANCELLED {
			try {
				yield file.query_info_async (FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE, io_priority, cancellable);
				return true;
			} catch (IOError.CANCELLED e) {
				throw e;
			} catch (Error e) {
				return false;
			}
		}

		public override async TimeVal? get_mtime (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) {
			try {
				var info = yield file.query_info_async (FileAttribute.TIME_MODIFIED, FileQueryInfoFlags.NONE);
				return info.get_modification_time ();
			} catch (Error e) {
				return null;
			}
		}
		
		async void restart_monitor () throws IOError.CANCELLED {
			if (_monitor != null) {
				_monitor.changed.disconnect (on_monitor);
				_monitor = null;
				yield monitor ();
			}
		}
		
		public override async void monitor (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError.CANCELLED {
			if (_monitor != null) {
				// already monitoring
				return;
			}
			
			try {
				_monitor = file.monitor (FileMonitorFlags.NONE, cancellable);
				_monitor.changed.connect (on_monitor);
			} catch (IOError.CANCELLED e) {
				throw e;
			} catch (Error e) {
			}
		}
		
		public override async void write (uint8[] data, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			yield file.replace_contents_async (data, null, true, FileCreateFlags.NONE, cancellable, null);
		}

		public override async bool is_directory (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError.CANCELLED {
			try {
				var info = yield file.query_info_async (FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE, io_priority, cancellable);
				return info.get_file_type () == FileType.DIRECTORY;
			} catch (IOError.CANCELLED e) {
				throw e;
			} catch (Error e) {
				return false;
			}
		}
		
		public override DataSource child (string path) {
			return new LocalFileSource (file.get_child (path));
		}
		
		public void on_monitor () {
			restart_monitor.begin ();
		}
		
		public override uint hash () {
			return file.hash ();
		}
		
		public override bool equal (DataSource? s) {
			if (this == s) {
				return true;
			}
			var f = s as LocalFileSource;
			return f != null && file.equal (f.file);
		}
		
		public override string to_string () {
			return file.get_path ();
		}
	}
}