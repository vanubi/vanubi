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
	public class LocalFileIterator : SourceIterator {
		LocalFileSource parent;
		FileEnumerator enumerator;
		
		public LocalFileIterator (LocalFileSource parent, FileEnumerator enumerator) {
			this.parent = parent;
			this.enumerator = enumerator;
		}
		
		public override SourceInfo? next (Cancellable? cancellable = null) throws Error {
			var info = enumerator.next_file (cancellable);
			if (info == null) {
				return null;
			}
			var sinfo = new SourceInfo (parent.child (info.get_name ()), info.get_type() == FileType.DIRECTORY);
			return sinfo;
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
		
		public override string local_path {
			owned get {
				return file.get_path ();
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

		public override async bool read_only (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError.CANCELLED {
			try {
				var info = yield file.query_info_async (FileAttribute.ACCESS_CAN_WRITE, FileQueryInfoFlags.NONE, io_priority, cancellable);
				return !info.get_attribute_boolean (FileAttribute.ACCESS_CAN_WRITE);
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
		
		async void restart_monitor () throws Error {
			if (_monitor != null) {
				_monitor.changed.disconnect (on_monitor);
				_monitor = null;
				yield monitor ();
			}
		}
		
		public override async void monitor (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			if (_monitor != null) {
				// already monitoring
				return;
			}
			
			try {
				_monitor = file.monitor (FileMonitorFlags.SEND_MOVED, cancellable);
				_monitor.changed.connect (on_monitor);
			} catch (IOError.CANCELLED e) {
				throw e;
			} catch (Error e) {
			}
		}
		
		public override async void write (uint8[] data, bool atomic, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			if (atomic) {
				// write to a temp file
				var tmp = File.new_for_path (file.get_path()+"#van.new");
				yield tmp.replace_contents_async (data, null, true, FileCreateFlags.PRIVATE, cancellable, null);
				
				// backup
				var exists = yield exists (io_priority, cancellable);
				if (exists) {
					try {
						file.copy_attributes (tmp, FileCopyFlags.ALL_METADATA, cancellable);
					} catch (Error e) {
						warning ("Could not copy attributes of %s: %s", file.get_path(), e.message);
					}

					// set mod time
					TimeVal tv = TimeVal ();
					FileInfo info = new FileInfo ();
					info.set_modification_time (tv);
					yield tmp.set_attributes_async (info, FileQueryInfoFlags.NONE, io_priority, cancellable, null);
					
					var bak = File.new_for_path (file.get_path()+"~");
					file.move (bak, FileCopyFlags.OVERWRITE, cancellable, null);
				}
				
				// rename temp to file
				tmp.move (file, FileCopyFlags.OVERWRITE, cancellable, null);
			} else {
				yield file.replace_contents_async (data, null, true, FileCreateFlags.NONE, cancellable, null);
			}
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
		
		public override async uint8[] execute_shell (string command_line, uint8[]? input = null, out uint8[] errors = null, out int status = null, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			string[] argv = {"bash", "-c", command_line};
			int stdin, stdout, stderr;
			Pid child_pid;
			yield spawn_async_with_pipes (to_string (), argv, null, SpawnFlags.SEARCH_PATH | SpawnFlags.DO_NOT_REAP_CHILD, null, Priority.DEFAULT, cancellable, out child_pid, out stdin, out stdout, out stderr);
			
			int st = 0xdead;
			bool requires_resume = false;
			ChildWatch.add (child_pid, (pid, sta) => {
					// Triggered when the child indicated by child_pid exits
					Process.close_pid (pid);
					st = sta;
					if (requires_resume) {
						execute_shell.callback ();
					}
			}, io_priority);
			
			var os = new UnixOutputStream (stdin, true);
			if (input != null) {
				yield os.write_async (input, io_priority, cancellable);
			}
			os.close ();
			
			var is = new UnixInputStream (stdout, true);
			var res = yield read_all_async (is, io_priority, cancellable);
			
			var eis = new UnixInputStream (stderr, true);
			errors = yield read_all_async (is, io_priority, cancellable);
			
			is.close ();
			eis.close ();
			
			if (st == 0xdead) {
				requires_resume = true;
				// wait till child watch
				yield;
			}
			status = st;
			return res;
		}
		
		
		public override DataSource child (string path) {
			return new LocalFileSource (file.get_child (path));
		}
		
		public override SourceIterator iterate_children (Cancellable? cancellable = null) throws Error {
			var enumerator = file.enumerate_children (FileAttribute.STANDARD_NAME+","+FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE, cancellable);
			var iterator = new LocalFileIterator (this, enumerator);
			return iterator;
		}
		
		public void on_monitor (File file, File? other_file, FileMonitorEvent event) {
			restart_monitor.begin ();
			if (FileMonitorEvent.MOVED in event) {
				changed (new LocalFileSource (other_file));
			} else {
				changed (null);
			}
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