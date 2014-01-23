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
			this.remote = (owned) remote;
			this.conn = (owned) conn;
		}
		
		~RemoteChannel () {
			remote.release (conn);
		}
	}
			
	public class RemoteConnection {
		public string ident { get; private set; }
		List<SocketConnection> pool = new List<SocketConnection> ();
		AsyncMutex mutex = new AsyncMutex ();
		
		public RemoteConnection (owned string ident) {
			this.ident = (owned) ident;
		}
		
		public void add_connection (owned SocketConnection conn) {
			conn.set_data ("acquired", false);
			pool.append ((owned) conn);
			// maybe unblock some blocked operation with this fresh connection
			mutex.release ();
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

	public class RemoteInputStream : InputStream {
		RemoteChannel chan; // keep alive until done
		AsyncDataInputStream stream;
		int cursize = -1;
		
		public class RemoteInputStream (owned RemoteChannel chan, owned AsyncDataInputStream stream) {
			this.chan = (owned) chan;
			this.stream = (owned) stream;
		}
		
		public override bool close (Cancellable? cancellable = null) throws IOError {
			// FIXME: we should cleanup the channel, because the endpoint is still writing
			chan = null;
			return true;
		}
		
		public override async bool close_async (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError {
			// FIXME: we should cleanup the channel, because the endpoint is still writing
			chan = null;
			return true;
		}

		public override ssize_t read ([CCode (array_length_type = "gsize")] uint8[] buffer, GLib.Cancellable? cancellable = null) throws IOError {
			if (cursize < 0) {
				var strsize = stream.read_line (cancellable);
				if (strsize == "error") {
					var error = stream.read_line (cancellable);
					throw new IOError.FAILED ("Remote error: %s".printf (error));
				}
				cursize = int.parse (strsize);
			}
			if (cursize == 0) {
				// done
				return 0;
			}
			
			unowned uint8[] tmp = buffer;
			tmp.length = int.min (buffer.length, cursize);
			var read = stream.read (buffer, cancellable);
			cursize -= (int) read;
			if (cursize == 0 && read > 0) {
				cursize = -1;
			}
			
			return read;
		}

		public override async ssize_t read_async ([CCode (array_length_cname = "count", array_length_pos = 1.5, array_length_type = "gsize")] uint8[] buffer, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError {
			if (cursize < 0) {
				var strsize = yield stream.read_line_async (io_priority, cancellable);
				if (strsize == "error") {
					var error = yield stream.read_line_async (io_priority, cancellable);
					throw new IOError.FAILED ("Remote error: %s".printf (error));
				}
				cursize = int.parse (strsize);
			}
			if (cursize == 0) {
				// done
				return 0;
			}
			
			unowned uint8[] tmp = buffer;
			tmp.length = int.min (buffer.length, cursize);
			var read = yield stream.read_async (tmp, io_priority, cancellable);
			cursize -= (int) read;
			if (cursize == 0 && read > 0) {
				cursize = -1;
			}
			
			return read;
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
			var chan = yield remote.acquire ();
			var os = chan.conn.output_stream;
			var cmd = "read\n%s\n".printf (local_path);
			yield os.write_async (cmd.data, io_priority, cancellable);
			yield os.flush_async (io_priority, cancellable);
			
			return new RemoteInputStream (chan, new AsyncDataInputStream (chan.conn.input_stream));
			
		}
		
		public override async bool exists (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			var chan = yield remote.acquire ();
			var os = chan.conn.output_stream;
			var cmd = "exists\n%s\n".printf (local_path);
			yield os.write_async (cmd.data, io_priority, cancellable);
			yield os.flush_async (io_priority, cancellable);
			
			var is = new AsyncDataInputStream (chan.conn.input_stream);
			var res = yield is.read_line_async (io_priority, cancellable);
			if (res == "true") {
				return true;
			} else if (res == "false") {
				return false;
			} else {
				throw new IOError.INVALID_ARGUMENT ("Invalid reply: %s", res);
			}
		}
		
		public override async TimeVal? get_mtime (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) {
			return null;
		}
		
		public override async void monitor (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
		}
		
		public override async void write (uint8[] data, int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
		}
		
		public override async bool is_directory (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
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
			return local.hash () + remote.ident.hash ();
		}
		
		public override bool equal (DataSource? s) {
			if (this == s) {
				return true;
			}
			var f = s as RemoteFileSource;
			return f != null && local.equal (f.local) && remote.ident == f.remote.ident;
		}
		
		public override string to_string () {
			return remote.ident+":"+local.get_path ();
		}
	}
	
	public class RemoteIdent {
		public InetAddress address { get; private set; }
		public string ident { get; private set; }
		uint _hash;
		
		public RemoteIdent (owned InetAddress address, owned string ident) {
			_hash = (address.to_string()+" "+ident).hash ();
			this.address = (owned) address;
			this.ident = (owned) ident;
		}
		
		public uint hash () {
			return _hash;
		}
		
		public bool equal (RemoteIdent ind) {
			if (this == ind) {
				return true;
			}
			
			return address.equal (ind.address) && ident == ind.ident;
		}
	}
		
	public class RemoteFileServer : SocketService {
		HashTable<RemoteIdent, RemoteConnection> conns = new HashTable<RemoteIdent, RemoteConnection> (RemoteIdent.hash, RemoteIdent.equal);
		Configuration conf;
		
		public signal void open_file (RemoteFileSource file);
		
		public RemoteFileServer (owned Configuration conf) throws Error {
			add_inet_port ((uint16) conf.get_global_int ("remote_service_port", 62518), null);
			this.conf = (owned) conf;
		}

		async string read_version (owned SocketConnection conn, owned AsyncDataInputStream is) throws Error {
			var ver = yield is.read_line_async ();
			if (ver == null || ver == "") {
				throw new IOError.PARTIAL_INPUT ("Expected protocol version");
			}
			return ver;
		}
		
		async string read_ident (owned SocketConnection conn, owned AsyncDataInputStream is, out bool is_main) throws Error {
			var cmd = yield is.read_line_async ();
			if (cmd == null) {
				throw new IOError.PARTIAL_INPUT ("Expected main or ident command");
			}
			
			if (cmd == "main") {
				is_main = true;
				cmd = yield is.read_line_async ();
				if (cmd == null) {
					throw new IOError.PARTIAL_INPUT ("Expected ident command");
				}
			} else {
				is_main = false;
			}
			
			if (cmd == "ident") {
				var ident = yield is.read_line_async ();
				if (ident != null) {
					return ident;
				}
			}
			
			throw new IOError.INVALID_ARGUMENT ("Expected ident command, got: %s", cmd);
		}
		
		async void handle_client_wrapper (owned SocketConnection conn) {
			try {
				yield handle_client (conn);
			} catch (Error e) {
				warning ("Closing connection due to error: %s", e.message);
				try {
					yield conn.close_async ();
				} catch (Error e) {
					warning ("Error while closing: %s", e.message);
				}
			}
		}
		
		async void handle_client (owned SocketConnection conn) throws Error {
			var is = new AsyncDataInputStream (conn.input_stream);
			string version = yield read_version (conn, is);
			bool is_main;
			string ident = yield read_ident (conn, is, out is_main);
			
			var inet = ((InetSocketAddress) conn.get_remote_address()).address;
			var remote_ident = new RemoteIdent (inet, ident);
			var remote_connection = conns[remote_ident];
			if (remote_connection == null) {
				remote_connection = new RemoteConnection (ident);
				conns[remote_ident] = remote_connection;
			}
			
			if (is_main) {
				// use this connection to handle remote requests
				yield handle_remote_requests (remote_connection, conn, is);
			} else {
				// add connection to the pool for handling user requests
				remote_connection.add_connection (conn);
			}
		}
		
		async void handle_remote_requests (owned RemoteConnection remote, owned SocketConnection conn, owned AsyncDataInputStream is) throws Error {
			while (true) {
				var cmd = yield is.read_line_async ();
				if (cmd == null) {
					// end
					return;
				}
					
				switch (cmd) {
				case "open":
					yield handle_open (remote, is);
					break;
				default:
					throw new IOError.INVALID_ARGUMENT ("Unknown command: "+cmd);
				}
			}
		}
		
		async void handle_open (owned RemoteConnection remote, owned AsyncDataInputStream is) throws Error {
			var path = yield is.read_line_async ();
			var file = new RemoteFileSource (path, remote);
			open_file (file);
		}
		
		public override bool incoming (SocketConnection conn, Object? source) {
			handle_client_wrapper.begin (conn);
			return false;
		}
	}
}