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
	public class RemoteFileSource : FileSource {
		SocketConnection control;
		File local;
		string remote_addr;
		
		public RemoteFileSource (string local_path, owned string remote_addr, owned SocketConnection control) {
			this.local = File.new_for_path (local_path);
			this.control = (owned) control;
			this.remote_addr = (owned) remote_addr;
		}
		
		public override DataSource? parent {
			owned get {
				var parent = local.get_parent ();
				if (parent != null) {
					return new RemoteFileSource (parent.get_path(), remote_addr, control);
				}
				// we are at the root of the file system
				return null;
			}
		}
		
		public override string basename {
			owned get {
				return local.get_basename ();
			}
		}
		
		public override string local_path {
			owned get {
				return local.get_path ();
			}
		}
		
		public override async InputStream read (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			return null;
		}
		
		public override async bool exists (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError.CANCELLED {
			return false;
		}
		
		public override async TimeVal? get_mtime (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) {
			return null;
		}
		
		public override async void monitor (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError.CANCELLED {
		}
		
		public override async void write (uint8[] data, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
		}
		
		public override async bool is_directory (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError.CANCELLED {
			return false;
		}
		
		public override async uint8[] execute_shell (string command_line, uint8[]? input = null, out uint8[] errors = null, out int status = null, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			return null;
		}
		
		public override DataSource child (string path) {
			return new RemoteFileSource (local.get_child(path).get_path(), remote_addr, control);
		}
		
		public override SourceIterator iterate_children (Cancellable? cancellable = null) throws Error {
			return null;
		}
		
		public override uint hash () {
			return local.hash () + remote_addr.hash ();
		}
		
		public override bool equal (DataSource? s) {
			if (this == s) {
				return true;
			}
			var f = s as RemoteFileSource;
			return f != null && local.equal (f.local) && remote_addr == f.remote_addr;
		}
		
		public override string to_string () {
			return remote_addr+":"+local.get_path ();
		}
	}
	
		public errordomain RemoteFileError {
		UNKNOWN_COMMAND
	}
	
	public class RemoteFileServer : SocketService {
		public RemoteFileServer () throws Error {
			add_inet_port (62518, null);
		}
		
		public signal void open_file (File file);
		
		async void handle_client (SocketConnection conn) {
			var is = new AsyncDataInputStream (conn.input_stream);
			string ident = null;
			try {
				var cmd = yield is.read_line_async ();
				switch (cmd) {
				case "ident":
					ident = yield is.read_line_async ();
					message("identified %s", ident);
					break;
				case "open":
					yield handle_open (is, ident);
					break;
				default:
					throw new RemoteFileError.UNKNOWN_COMMAND ("Unknown command "+cmd);
				}
			} catch (Error e) {
				warning ("Got error "+e.message+", disconnecting.");
				try {
					yield conn.close_async ();
				} catch (Error e) {
					warning ("Error while closing connection: "+e.message);
				}
			}
		}
		
		async void handle_open (AsyncDataInputStream is, string ident) throws Error {
			var path = yield is.read_zero_terminated_string ();
			message ("%s: %s", ident, path);
		}
		
		public override bool incoming (SocketConnection conn, Object? source) {
			handle_client.begin (conn);
			return false;
		}
	}
}