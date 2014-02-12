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
	 
	public class ChunkedInputStream : AsyncDataInputStream {
		int chunk_size = 0;
		OutputStream os;
		unowned Object refobj = null;
		Object cancel_ref = null;
		bool ask_continue = false;
		
		public ChunkedInputStream (IOStream stream, Object refobj) {
			base (stream.input_stream);
			os = stream.output_stream;
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
		
		// DANGER: this breaks a lot of assumptions, code must necessarily run in a thread different than the main thread
		public override ssize_t read ([CCode (array_length_type = "gsize")] uint8[] buffer, GLib.Cancellable? cancellable = null) throws GLib.IOError {
			cancellable.set_error_if_cancelled ();

			if (ask_continue) {
				// we wrongly assume that write does not require cancellation
				os.write_all ("continue\n".data, null);
			}
			ask_continue = true;

			ulong cancel_id = 0;
			var sem = Mutex ();
			sem.lock ();

			if (chunk_size == 0) {
				// wait new chunk

				cancel_id = cancellable.cancelled.connect (() => {
						Idle.add (() => {
								cancellable.disconnect (cancel_id);
								cancel_id = 0;
								sem.unlock ();
								return false;
						});
				});
				
				read_int_async.begin (Priority.DEFAULT, null, (s,r) => {
						chunk_size = read_int_async.end (r);
						sem.unlock ();
				});
				
				sem.lock (); // block until cancelled or data available
				if (cancel_id > 0) {
					cancellable.disconnect (cancel_id);
				}

				if (cancellable.is_cancelled ()) {
					consume_and_cancel ();
					cancellable.set_error_if_cancelled ();
				}
			}

			ssize_t ret = 0;
			unowned uint8[] buf = buffer;
			buf.length = int.min ((int) chunk_size, buffer.length);
			
			cancel_id = cancellable.cancelled.connect (() => {
					Idle.add (() => {
							cancellable.disconnect (cancel_id);
							cancel_id = 0;
							sem.unlock ();
							return false;
					});
			});
			
			read_async.begin (buf, Priority.DEFAULT, null, (s, r) => {
					ret = read_async.end (r);
					chunk_size -= (int) ret;
					sem.unlock ();
			});

			sem.lock (); // block until cancelled or data available
			if (cancel_id > 0) {
				cancellable.disconnect (cancel_id);
			}

			if (cancellable.is_cancelled ()) {
				consume_and_cancel ();
				cancellable.set_error_if_cancelled ();
			}
			
			return ret;
		}
		
		// DANGER: this breaks a lot of assumptions, code must necessarily run in a thread different than the main thread
		public override async ssize_t read_async ([CCode (array_length_type = "gsize")] uint8[] buffer, int io_priority = Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.IOError {
			cancellable.set_error_if_cancelled ();

			if (ask_continue) {
				// we wrongly assume that write does not block and does not require cancellation
				os.write_all ("continue\n".data, null);
			}
			ask_continue = true;

			ulong cancel_id = 0;
			SourceFunc? resume = null;

			if (chunk_size == 0) {
				// wait new chunk

				cancel_id = cancellable.cancelled.connect (() => {
						Idle.add (() => {
								cancellable.disconnect (cancel_id);
								cancel_id = 0;
								if (resume != null) {
									resume ();
								}
								return false;
						});
				});
				
				read_int_async.begin (Priority.DEFAULT, null, (s,r) => {
						chunk_size = read_int_async.end (r);
						if (resume != null) {
							resume ();
						}
				});

				resume = read_async.callback;
				yield; // wait until cancelled or data available
				resume = null;
				if (cancel_id > 0) {
					cancellable.disconnect (cancel_id);
				}

				if (cancellable.is_cancelled ()) {
					consume_and_cancel ();
					cancellable.set_error_if_cancelled ();
				}
			}

			ssize_t ret = 0;
			unowned uint8[] buf = buffer;
			buf.length = int.min ((int) chunk_size, buffer.length);
			
			cancel_id = cancellable.cancelled.connect (() => {
					Idle.add (() => {
							cancellable.disconnect (cancel_id);
							cancel_id = 0;
							if (resume != null) {
								resume ();
							}
							return false;
					});
			});
			
			read_async.begin (buf, Priority.DEFAULT, null, (s, r) => {
					ret = read_async.end (r);
					chunk_size -= (int) ret;
					if (resume != null) {
						resume ();
					}
			});

			resume = read_async.callback;
			yield; // wait until cancelled or data available
			resume = null;
			if (cancel_id > 0) {
				cancellable.disconnect (cancel_id);
			}

			if (cancellable.is_cancelled ()) {
				consume_and_cancel ();
				cancellable.set_error_if_cancelled ();
			}
			return ret;
		}

		public override bool close (Cancellable? cancellable = null) {
			consume_and_cancel ();
			cancellable.set_error_if_cancelled ();
			return true;
		}
		
		public async string? read_line_async (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			var buf = new uint8[1];
			var b = new StringBuilder ();
			while (true) {
				var read = yield read_async (buf, io_priority, cancellable);
				if (read <= 0) {
					throw new IOError.CLOSED ("Stream is closed");
				}
				if (buf[0] == '\n') {
					return b.str.strip();
				}
				b.append_c ((char) buf[0]);
			}
		}
		
		public string? read_line (Cancellable? cancellable = null) throws Error {
			var buf = new uint8[1];
			var b = new StringBuilder ();
			while (true) {
				var r = read (buf, cancellable);
				if (r <= 0) {
					throw new IOError.CLOSED ("Stream is closed");
				}
				if (buf[0] == '\n') {
					return b.str.strip ();
				}
				b.append_c ((char) buf[0]);
			}
		}
	}
}
