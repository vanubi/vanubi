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
	 
	public class ChunkedInputStream : BinaryInputStream {
		int chunk_size = 0;
		OutputStream os;
		unowned Object refobj = null;
		Object cancel_ref = null;
		bool ask_continue = false;
		
		public ChunkedInputStream (InputStream is, OutputStream os, Object? refobj) {
			base (is);
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

			if (ask_continue) {
				// we wrongly assume that write does not require cancellation
				os.write_all ("continue\n".data, null);
			}
			ask_continue = true;
	
			ulong cancel_id = 0;
			var sem = Mutex ();
			sem.lock ();

			var ctx = MainContext.default();

			bool ctx_iteration = ctx.is_owner ();
			bool ctx_blocked = true;

			if (chunk_size == 0) {
				// wait new chunk

				if (cancellable != null) {
					cancel_id = cancellable.connect (() => {
							Idle.add (() => {
									cancellable.disconnect (cancel_id);
									cancel_id = 0;
									if (ctx_iteration) {
										ctx_blocked = false;
									} else {
										sem.unlock ();
									}
									return false;
							});
					});
				}
				
				read_int32_async.begin (Priority.DEFAULT, null, (s,r) => {
						chunk_size = read_int32_async.end (r);
						if (ctx_iteration) {
							ctx_blocked = false;
						} else {
							sem.unlock ();
						}
				});

				// block until cancelled or data available
				if (ctx_iteration) {
					ctx_blocked = true;
					while (ctx_blocked) {
						ctx.iteration (true);
					}
				} else {
					sem.lock ();
				}
				
				if (cancellable != null && cancel_id > 0) {
					cancellable.disconnect (cancel_id);
				}
				cancel_id = 0;

				if (cancellable != null && cancellable.is_cancelled ()) {
					consume_and_cancel.begin ();
					cancellable.set_error_if_cancelled ();
				}
			}

			ssize_t ret = 0;
			unowned uint8[] buf = buffer;
			buf.length = int.min ((int) chunk_size, buffer.length);

			if (cancellable != null) {
				cancel_id = cancellable.connect (() => {
						Idle.add (() => {
								cancellable.disconnect (cancel_id);
								cancel_id = 0;
								if (ctx_iteration) {
									ctx_blocked = false;
								} else {
									sem.unlock ();
								}
								return false;
						});
				});
			}
			
			base_stream.read_async.begin (buf, Priority.DEFAULT, null, (s, r) => {
					ret = base_stream.read_async.end (r);
					chunk_size -= (int) ret;
					if (ctx_iteration) {
						ctx_blocked = false;
					} else {
						sem.unlock ();
					}
			});

			// block until cancelled or data available
			if (ctx_iteration) {
				ctx_blocked = true;
				while (ctx_blocked) {
					ctx.iteration (true);
				}
			} else {
				sem.lock ();
			}
			
			if (cancellable != null && cancel_id > 0) {
				cancellable.disconnect (cancel_id);
			}
			cancel_id = 0;

			if (cancellable != null && cancellable.is_cancelled ()) {
				consume_and_cancel.begin ();
				cancellable.set_error_if_cancelled ();
			}
			
			return ret;
		}
		
		public override async ssize_t read_async ([CCode (array_length_type = "gsize")] uint8[] buffer, int io_priority = Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.IOError {
			cancellable.set_error_if_cancelled ();
			clear_pending();
			
			if (ask_continue) {
				// we wrongly assume that write does not block and does not require cancellation
				os.write_all ("continue\n".data, null);
			}
			ask_continue = true;

			ulong cancel_id = 0;
			SourceFunc? resume = null;

			if (chunk_size == 0) {
				// wait new chunk
				resume = read_async.callback;

				if (cancellable != null) {
					cancel_id = cancellable.connect (() => {
							Idle.add (() => {
									cancellable.disconnect (cancel_id);
									cancel_id = 0;
									if (resume != null) {
										resume ();
									}
									return false;
							});
					});
				}
				message("wewe");
				read_int32_async.begin (Priority.DEFAULT, null, (s,r) => {
						chunk_size = read_int32_async.end (r);
						if (resume != null) {
							resume ();
						}
				});

				yield; // wait until cancelled or data available
				resume = null;
				if (cancellable != null && cancel_id > 0) {
					cancellable.disconnect (cancel_id);
				}

				if (cancellable != null && cancellable.is_cancelled ()) {
					consume_and_cancel.begin ();
					cancellable.set_error_if_cancelled ();
				}
			}

			ssize_t ret = 0;
			unowned uint8[] buf = buffer;
			buf.length = int.min ((int) chunk_size, buffer.length);
			resume = read_async.callback;

			cancel_id = 0;
			if (cancellable != null) {
				cancel_id = cancellable.connect (() => {
						Idle.add (() => {
								cancellable.disconnect (cancel_id);
								cancel_id = 0;
								if (resume != null) {
									resume ();
								}
								return false;
						});
				});
			}
			
			base_stream.read_async.begin (buf, Priority.DEFAULT, null, (s, r) => {
					ret = base_stream.read_async.end (r);
					chunk_size -= (int) ret;
					if (resume != null) {
						resume ();
					}
			});

			yield; // wait until cancelled or data available
			resume = null;
			if (cancellable != null && cancel_id > 0) {
				cancellable.disconnect (cancel_id);
			}

			if (cancellable != null && cancellable.is_cancelled ()) {
				consume_and_cancel.begin ();
				cancellable.set_error_if_cancelled ();
			}
			return ret;
		}

		public override bool close (Cancellable? cancellable = null) {
			consume_and_cancel.begin ();
			cancellable.set_error_if_cancelled ();
			return true;
		}
	}
}
