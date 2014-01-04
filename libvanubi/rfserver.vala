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
	public errordomain RemoteFileError {
		UNKNOWN_COMMAND
	}
	
	public class RemoteFileServer : SocketService {
		public RemoteFileServer () {
			add_inet_port (62518, null);
		}
		
		public signal void open_file (File file);
		
		async void handle_client (SocketConnection conn) {
			try {
				var is = new AsyncDataInputStream (conn.input_stream);
				var cmd = yield is.read_line_async ();
				switch (cmd) {
				case "open":
					yield handle_open (is);
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
		
		async void handle_open (AsyncDataInputStream is) throws Error {
			var path = yield is.read_zero_terminated_string ();
			message (path);
		}
		
		public override bool incoming (SocketConnection conn, Object? source) {
			handle_client.begin (conn);
			return false;
		}
	}
}
