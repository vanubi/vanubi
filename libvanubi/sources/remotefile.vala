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
	public class RemoteChannel {
		public RemoteConnection remote { get; private set; }
		public SocketConnection conn { get; private set; }
		
		public RemoteChannel (owned RemoteConnection remote, owned SocketConnection conn) {
			this.remote = remote;
			this.conn = conn;
		}
		
		~RemoteChannel () {
			remote.release (conn);
		}
	}
			
	public class RemoteConnection {
		public string addr { get; private set; }
		List<SocketConnection> pool = new List<SocketConnection> ();
		AsyncMutex mutex = new AsyncMutex ();
		
		public RemoteConnection (owned string addr) {
			this.addr = (owned) addr;
		}
		
		public void add_connection (owned SocketConnection conn) {
			pool.append ((owned) conn);
			conn.set_data ("acquired", false);
		}
		
		public async RemoteChannel acquire () {
			while (true) {
				foreach (unowned SocketConnection conn in pool) {
					bool acquired = conn.get_data ("acquired");
					if (!acquired) {
						conn.set_data ("acquired", true);
						return new RemoteChannel (this, conn);
					}
				}
			
				yield mutex.acquire ();
			}
		}
		
		internal void release (SocketConnection conn) {
			conn.set_data ("acquired", false);
			mutex.release ();
		}
	}
	
	public class RemoteFileSource : FileSource {
		RemoteConnection remote;
		File local;
		
		public RemoteFileSource (string local_path, owned RemoteConnection remote) {
			this.local = File.new_for_path (local_path);
			this.remote = (owned) remote;
		}
		
		public override DataSource? parent {
			owned get {
				var parent = local.get_parent ();
				if (parent != null) {
					return new RemoteFileSource (parent.get_path(), remote);
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
			return new RemoteFileSource (local.get_child(path).get_path(), remote);
		}
		
		public override SourceIterator iterate_children (Cancellable? cancellable = null) throws Error {
			return null;
		}
		
		public override uint hash () {
			return local.hash () + remote.addr.hash ();
		}
		
		public override bool equal (DataSource? s) {
			if (this == s) {
				return true;
			}
			var f = s as RemoteFileSource;
			return f != null && local.equal (f.local) && remote.addr == f.remote.addr;
		}
		
		public override string to_string () {
			return remote.addr+":"+local.get_path ();
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
			
			while (true) {
				try {
					var cmd = yield is.read_line_async ();
					if (cmd == null) {
						return;
					}
					
					switch (cmd) {
					case "ident":
						ident = yield is.read_line_async ();
						if (ident == null) {
							return;
						}
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
					return;
				}
			}
		}
		
		async void handle_open (AsyncDataInputStream is, string ident) throws Error {
			var path = yield is.read_zero_terminated_string ();
			message ("%s: %s", ident, path);
		}
		
		public override bool incoming (SocketConnection conn, Object? source) {
			message("connected");
			handle_client.begin (conn);
			return false;
		}
	}
}