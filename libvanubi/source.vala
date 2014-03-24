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
	public class SourceInfo {
		public DataSource source { get; private set; }
		public bool is_directory { get; private set; }
		
		public SourceInfo (DataSource source, bool is_directory) {
			this.source = source;
			this.is_directory = is_directory;
		}
	}
			
	public abstract class SourceIterator {
		public abstract SourceInfo? next (Cancellable? cancellable = null) throws Error;
	}
	
	public abstract class DataSource : Object {
		public signal void changed (DataSource? moved_to);
		
		public abstract DataSource? parent { owned get; }

		public abstract async bool exists (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error;
		public abstract async bool read_only (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error;
		public abstract async InputStream read (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error;
		
		public abstract async void write (uint8[] data, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error;
		
		public abstract async TimeVal? get_mtime (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null);
		public abstract async void monitor (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error;
		
		public abstract async bool is_directory (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error;
		public abstract async uint8[] execute_shell (string command_line, uint8[]? input = null, out uint8[] errors = null, out int status = null, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error;

		public abstract DataSource child (string path);
		public abstract SourceIterator iterate_children (Cancellable? cancellable = null) throws Error;
		
		public abstract uint hash ();
		public abstract bool equal (DataSource? s);
		public abstract string to_string ();

		public DataSource root {
			owned get {
				var cur = this;
				// hope this does not loop infinitely :S
				while (true) {
					var parent = cur.parent;
					if (parent == null) {
						return cur;
					}
					cur = parent;
				}
			}
		}
		
		public bool exists_sync (Cancellable? cancellable = null) throws Error {
			Error? err = null;
			bool ret = false;
			var complete = false;

			Mutex mutex = Mutex ();
			Cond cond = Cond ();
			mutex.lock ();
			
			Idle.add (() => {
					exists.begin (Priority.DEFAULT, cancellable, (s,r) => {
							try {
								ret = exists.end (r);
							} catch (Error e) {
								err = e;
							} finally {
								mutex.lock ();
								complete = true;
								cond.signal ();
								mutex.unlock ();
							}
					});
					return false;
			});

			while (!complete) {
				cond.wait (mutex);
			}
			mutex.unlock ();

			if (err != null) {
				throw err;
			}
			return ret;
		}

		public bool is_directory_sync (Cancellable? cancellable = null) throws Error {
			Error? err = null;
			bool ret = false;
			var complete = false;

			Mutex mutex = Mutex ();
			Cond cond = Cond ();
			mutex.lock ();
			
			Idle.add (() => {
					is_directory.begin (Priority.DEFAULT, cancellable, (s,r) => {
							try {
								ret = is_directory.end (r);
							} catch (Error e) {
								err = e;
							} finally {
								mutex.lock ();
								complete = true;
								cond.signal ();
								mutex.unlock ();
							}
					});
					return false;
			});

			while (!complete) {
				cond.wait (mutex);
			}
			mutex.unlock ();

			if (err != null) {
				throw err;
			}
			return ret;
		}
		
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
	
	public abstract class FileSource : DataSource {
		public abstract string basename { owned get; }
		public abstract string local_path { owned get; }
		
		public string get_relative_path (FileSource other) {
			return File.new_for_path (local_path).get_relative_path (File.new_for_path (other.local_path));
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
}