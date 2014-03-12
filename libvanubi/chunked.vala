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
	/* Protocol:
	 * Receive: size:uint64 chunk
	 * Send: continue\n or cancel\n
	 */
	 
	public class ChunkedInputStream : FilterInputStream {
		int chunk_size = 0;
		AsyncDataInputStream is;
		OutputStream os;
		unowned Object refobj = null;
		Object cancel_ref = null;
		bool can_ask_continue = false;
		
		public ChunkedInputStream (AsyncDataInputStream is, OutputStream os, Object? refobj) {
			Object (base_stream: is, close_base_stream: false);
			this.is = is;
			this.os = os;
			this.refobj = refobj;
		}

		async void consume_and_cancel (int io_priority = Priority.DEFAULT) {
			cancel_ref = refobj;
			try {
				while (chunk_size > 0) {
					try {
						var ret = yield skip_async (chunk_size, io_priority);
						chunk_size -= (int) ret;
					} catch (Error e) {
					// TODO:
						return;
					}
				}

				yield os.write_async ("cancel\n".data, io_priority);
			} finally {
				cancel_ref = null;
			}
		}
		
		public override ssize_t read ([CCode (array_length_type = "gsize")] uint8[] buffer, GLib.Cancellable? cancellable = null) throws GLib.IOError {
			cancellable.set_error_if_cancelled ();
			
			ulong cancel_id = 0;
			Cancellable mycancellable = null;
			SourceFunc? resume = null;

			if (chunk_size == 0) {
				if (can_ask_continue) {
					os.write_all ("continue\n".data, null);
				}
				
				// wait new chunk
				if (cancellable != null) {
					mycancellable = new Cancellable ();
					cancel_id = cancellable.connect (() => {
							cancellable.disconnect (cancel_id);
							consume_and_cancel.begin ();
							mycancellable.cancel ();
							mycancellable = null;
					});
				}
				
				chunk_size = is.read_int32 (mycancellable);
				if (cancellable != null && cancel_id > 0) {
					cancellable.disconnect (cancel_id);
					mycancellable = null;
				}
			}
			can_ask_continue = true;
			
			unowned uint8[] buf = buffer;
			buf.length = int.min ((int) chunk_size, buffer.length);

			mycancellable = null;
			if (cancellable != null) {
				mycancellable = new Cancellable ();
				cancel_id = cancellable.connect (() => {
						cancellable.disconnect (cancel_id);
						consume_and_cancel.begin ();
						mycancellable.cancel ();
						mycancellable = null;
				});
			}

			var res = is.read (buf, cancellable);
			if (cancellable != null && cancel_id > 0) {
				cancellable.disconnect (cancel_id);
				mycancellable = null;
			}
			chunk_size -= (int) res;
			
			return res;
		}
		
		public override async ssize_t read_async ([CCode (array_length_type = "gsize")] uint8[] buffer, int io_priority = Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.IOError {
			cancellable.set_error_if_cancelled ();
			
			ulong cancel_id = 0;
			Cancellable mycancellable = null;
			SourceFunc? resume = null;

			if (chunk_size == 0) {
				if (can_ask_continue) {
					yield os.write_async ("continue\n".data, io_priority, null);
				}
				
				// wait new chunk
				if (cancellable != null) {
					mycancellable = new Cancellable ();
					cancel_id = cancellable.connect (() => {
							cancellable.disconnect (cancel_id);
							consume_and_cancel.begin ();
							mycancellable.cancel ();
							mycancellable = null;
					});
				}
				
				chunk_size = yield is.read_int32_async (io_priority, mycancellable);
				if (cancellable != null && cancel_id > 0) {
					cancellable.disconnect (cancel_id);
					mycancellable = null;
				}
			}
			can_ask_continue = true;
			
			unowned uint8[] buf = buffer;
			buf.length = int.min ((int) chunk_size, buffer.length);

			mycancellable = null;
			if (cancellable != null) {
				mycancellable = new Cancellable ();
				cancel_id = cancellable.connect (() => {
						cancellable.disconnect (cancel_id);
						consume_and_cancel.begin ();
						mycancellable.cancel ();
						mycancellable = null;
				});
			}

			var res = yield is.read_async (buf, io_priority, cancellable);
			if (cancellable != null && cancel_id > 0) {
				cancellable.disconnect (cancel_id);
				mycancellable = null;
			}
			chunk_size -= (int) res;
			
			return res;
		}

		public override bool close (Cancellable? cancellable = null) {
			cancellable.set_error_if_cancelled ();
			consume_and_cancel.begin ();
			return true;
		}
	}
}
