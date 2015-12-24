/*
 *  Copyright © 2014-2016 Luca Bruno
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

/* Sorry, but we do not like glib using GTask, thus defeating pollable sources with
 * a thread pool */
 
namespace Vanubi {
	public class ChannelInputStream : InputStream {
		IOChannel chan;
		bool readable = false;
		IOSource source;
		SourceFunc resume = null;

		public ChannelInputStream (IOChannel chan) {
			this.chan = chan;
			chan.set_encoding (null); // always assume binary
			source = chan.create_watch (IOCondition.IN);
			source.set_callback ((source, condition) => {
					if (condition == IOCondition.IN || condition == IOCondition.PRI) {
						readable = true;
						if (resume != null) {
							resume ();
						}
						return true;
					} else {
						close ();
						return false;
					}
			});
		}

		public ChannelInputStream.for_unix_fd (int fd) {
			this (new IOChannel.unix_new (fd));
		}

		public ChannelInputStream.for_file (string filename, string mode) {
			this (new IOChannel.file (filename, mode));
		}

		~ChannelInputStream () {
			source.destroy ();
		}

		public override ssize_t read ([CCode (array_length_type = "gsize")] uint8[] buffer, GLib.Cancellable? cancellable = null) throws GLib.IOError {
			if (has_pending ()) {
				throw new IOError.PENDING ("Stream operation pending");
			}
			set_pending ();

			try {
				cancellable.set_error_if_cancelled ();
				var sem = Mutex ();
				sem.lock ();
				if (!readable) {
					resume = () => { sem.unlock (); return false; };
					sem.lock ();
					resume = null;
				}
				
				cancellable.set_error_if_cancelled ();
				
				if (!readable) {
					throw new IOError.BROKEN_PIPE ("Broken pipe");
				} else {
					size_t ret;
					chan.read_chars ((char[]) buffer, out ret);
					readable = false;
					
					return (ssize_t) ret;
				}
			} finally {
				clear_pending ();
			}
		}

		public virtual async ssize_t read_async ([CCode (array_length_cname = "count", array_length_pos = 1.5, array_length_type = "gsize")] uint8[] buffer, int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.IOError {
			if (has_pending ()) {
				throw new IOError.PENDING ("Stream operation pending");
			}
			set_pending ();
			source.set_priority (io_priority);

			try {
				cancellable.set_error_if_cancelled ();
				if (!readable) {
					resume = read_async.callback;
					yield;
					resume = null;
				}
				
				cancellable.set_error_if_cancelled ();
				
				if (!readable) {
					throw new IOError.BROKEN_PIPE ("Broken pipe");
				} else {
					size_t ret;
					chan.read_chars ((char[]) buffer, out ret);
					readable = false;
					
					return (ssize_t) ret;
				}
			} finally {
				clear_pending ();
			}
		}

		public override ssize_t skip (size_t count, GLib.Cancellable? cancellable = null) throws GLib.IOError {
			uint8[] buf = new uint8[1024*8];
			ssize_t total = 0;
			while (count > 0) {
				buf.length = int.min (1024*8, (int) count);
				var ret = read (buf, cancellable);
				if (ret == 0) {
					return total;
				}
				count -= ret;
				total += ret;
			}
			return total;
		}

		public override async ssize_t skip_async (size_t count, int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.IOError {
			uint8[] buf = new uint8[1024*8];
			ssize_t total = 0;
			while (count > 0) {
				buf.length = int.min (1024*8, (int) count);
				var ret = yield read_async (buf, io_priority, cancellable);
				if (ret == 0) {
					return total;
				}
				count -= ret;
				total += ret;
			}
			return total;
		}

		public override bool close (Cancellable? cancellable = null) throws IOError {
			chan.shutdown (false);
			return true;
		}

		public override async bool close_async (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError {
			chan.shutdown (false);
			return true;
		}
	}

	public class ChannelOutputStream : OutputStream {
		IOChannel chan;
		bool writable = false;
		IOSource source;
		SourceFunc resume = null;

		public ChannelOutputStream (IOChannel chan) {
			this.chan = chan;
			chan.set_encoding (null); // always assume binary
			source = chan.create_watch (IOCondition.OUT);
			source.set_callback ((source, condition) => {
					if (condition == IOCondition.OUT) {
						writable = true;
						if (resume != null) {
							resume ();
						}
						return true;
					} else {
						close ();
						return false;
					}
			});
		}

		~ChannelOutputStream () {
			source.destroy ();
		}
		
		public ChannelOutputStream.for_unix_fd (int fd) {
			this (new IOChannel.unix_new (fd));
		}

		public ChannelOutputStream.for_file (string filename, string mode) {
			this (new IOChannel.file (filename, mode));
		}

		public override ssize_t write ([CCode (array_length_type = "gsize")] uint8[] buffer, GLib.Cancellable? cancellable = null) throws GLib.IOError {
			if (has_pending ()) {
				throw new IOError.PENDING ("Stream operation pending");
			}
			set_pending ();
			
			try {
				cancellable.set_error_if_cancelled ();
				var sem = Mutex ();
				sem.lock ();
				if (!writable) {
					resume = () => { sem.unlock (); return false; };
					sem.lock ();
					resume = null;
				}
				
				cancellable.set_error_if_cancelled ();
				
				if (!writable) {
					throw new IOError.BROKEN_PIPE ("Broken pipe");
				} else {
					size_t ret;
					chan.write_chars ((char[]) buffer, out ret);
					writable = false;
					
					return (ssize_t) ret;
				}
			} finally {
				clear_pending ();
			}
		}

		public override async ssize_t write_async ([CCode (array_length_cname = "count", array_length_pos = 1.5, array_length_type = "gsize")] uint8[] buffer, int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.IOError {
			if (has_pending ()) {
				throw new IOError.PENDING ("Stream operation pending");
			}
			set_pending ();
			source.set_priority (io_priority);

			try {
				cancellable.set_error_if_cancelled ();
				if (!writable) {
					resume = write_async.callback;
					yield;
					resume = null;
				}
				
				cancellable.set_error_if_cancelled ();
				
				if (!writable) {
					throw new IOError.BROKEN_PIPE ("Broken pipe");
				} else {
					size_t ret;
					chan.write_chars ((char[]) buffer, out ret);
					writable = false;
					
					return (ssize_t) ret;
				}
			} finally {
				clear_pending ();
			}
		}

		public override bool flush (GLib.Cancellable? cancellable = null) throws GLib.Error {
			if (has_pending ()) {
				throw new IOError.PENDING ("Stream operation pending");
			}
			set_pending ();
			
			try {
				cancellable.set_error_if_cancelled ();
				var sem = Mutex ();
				sem.lock ();
				if (!writable) {
					resume = () => { sem.unlock (); return false; };
					sem.lock ();
					resume = null;
				}
				
				cancellable.set_error_if_cancelled ();
				
				if (!writable) {
					throw new IOError.BROKEN_PIPE ("Broken pipe");
				} else {
					chan.flush ();
					writable = false;
					return true;
				}
			} finally {
				clear_pending ();
			}
		}
		
		public override async bool flush_async (int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.Error {
			if (has_pending ()) {
				throw new IOError.PENDING ("Stream operation pending");
			}
			set_pending ();
			source.set_priority (io_priority);

			try {
				cancellable.set_error_if_cancelled ();
				if (!writable) {
					resume = flush_async.callback;
					yield;
					resume = null;
				}
				
				cancellable.set_error_if_cancelled ();
				
				if (!writable) {
					throw new IOError.BROKEN_PIPE ("Broken pipe");
				} else {
					chan.flush ();
					writable = false;
					return true;
				}
			} finally {
				clear_pending ();
			}
		}
		
		public override bool close (Cancellable? cancellable = null) throws IOError {
			chan.shutdown (false);
			return true;
		}

		public override async bool close_async (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError {
			chan.shutdown (false);
			return true;
		}
	}
}