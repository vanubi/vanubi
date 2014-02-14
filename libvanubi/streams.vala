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

		public override async ssize_t read_async ([CCode (array_length_cname = "count", array_length_pos = 1.5, array_length_type = "gsize")] uint8[] buffer, int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.IOError {
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

	public class BinaryInputStream : FilterInputStream {
		public BinaryInputStream (InputStream base_stream) {
			Object (base_stream: base_stream, close_base_stream: false);
		}

		public override bool close (Cancellable? cancellable = null) throws IOError {
			return base_stream.close (cancellable);
		}

		public override async bool close_async (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError {
			return yield base_stream.close_async (io_priority, cancellable);
		}

		public override ssize_t read ([CCode (array_length_type = "gsize")] uint8[] buffer, GLib.Cancellable? cancellable = null) throws GLib.IOError {
			return base_stream.read (buffer, cancellable);
		}

		public override async ssize_t read_async ([CCode (array_length_cname = "count", array_length_pos = 1.5, array_length_type = "gsize")] uint8[] buffer, int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.IOError {
			return yield base_stream.read_async (buffer, io_priority, cancellable);
		}

		public int read_int32 (Cancellable? cancellable = null) throws GLib.IOError {
			int32 val = 0;
			ssize_t rsize = 0;

			while (rsize < sizeof(int32)) {
				int32* ptr = &val;
				uint8* ptr8 = (uint8*) ptr;
				unowned uint8[] buf = (uint8[]) (ptr+rsize);
				buf.length = (int) sizeof (int32);
				rsize += read (buf, cancellable);
			}
			return val;
		}
		
		public async int read_int32_async (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws GLib.IOError {
			int32 val = 0;
			ssize_t rsize = 0;

			while (rsize < sizeof(int32)) {
				int32* ptr = &val;
				uint8* ptr8 = (uint8*) ptr;
				unowned uint8[] buf = (uint8[]) (ptr+rsize);
				buf.length = (int) sizeof (int32);
				rsize += yield read_async (buf, io_priority, cancellable);
			}
			return val;
		}
	}

	public class BufferInputStream : FilterInputStream {
		uint8[] buffer = null;
		
		public BufferInputStream (InputStream base_stream) {
			Object (base_stream: base_stream, close_base_stream: false);
			buffer = new uint8[1024*8];
			buffer.length = 0;
		}

		public override bool close (Cancellable? cancellable = null) throws IOError {
			return base_stream.close (cancellable);
		}

		public override async bool close_async (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws IOError {
			return yield base_stream.close_async (io_priority, cancellable);
		}

		public size_t fill (size_t count, GLib.Cancellable? cancellable) throws GLib.IOError {
			if (buffer.length > count) {
				return 0;
			}

			size_t total = 0;
			while (count > 0) {
				var cnt = int.min ((int) count-buffer.length, 1024*8-buffer.length);
				if (cnt == 0) {
					break;
				}
				
				uint8* ptr = buffer;
				unowned uint8[] cur = (uint8[]) (ptr+buffer.length);
				cur.length = cnt;
				var ret = base_stream.read (cur, cancellable);
				if (ret == 0) {
					break;
				}

				count -= ret;
				total += ret;
				buffer.length += (int) ret;
			}

			return total;
		}
		
		public async size_t fill_async (size_t count, int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable) throws GLib.IOError {
			if (buffer.length > count) {
				return 0;
			}

			size_t total = 0;
			while (count > 0) {
				var cnt = int.min ((int)count-buffer.length, 1024*8-buffer.length);
				if (cnt == 0) {
					break;
				}
				
				uint8* ptr = buffer;
				unowned uint8[] cur = (uint8[]) (ptr+buffer.length);
				cur.length = cnt;
				var ret = yield base_stream.read_async (cur, io_priority, cancellable);
				if (ret == 0) {
					break;
				}
				
				count -= ret;
				total += ret;
			}

			return total;
		}

		public override ssize_t read ([CCode (array_length_type = "gsize")] uint8[] buffer, GLib.Cancellable? cancellable = null) throws GLib.IOError {
			fill (buffer.length, cancellable);
			var ret = int.min (this.buffer.length, buffer.length);
			uint8* ptr = (uint8*) this.buffer;
			ptr += ret;

			// slide buffer
			var rest = this.buffer.length - ret;
			Posix.memmove ((void*) this.buffer, (void*) ptr, rest);
			this.buffer.length = rest;

			return ret;
		}

		public override async ssize_t read_async ([CCode (array_length_cname = "count", array_length_pos = 1.5, array_length_type = "gsize")] uint8[] buffer, int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.IOError {
			yield fill_async (buffer.length, io_priority, cancellable);
			var ret = int.min (this.buffer.length, buffer.length);
			Posix.memcpy ((void*) buffer, (void*) this.buffer, ret);

			slide (ret);
			return ret;
		}

		void slide (int cnt) {
			// slide buffer
			uint8* ptr = (uint8*) this.buffer;
			ptr += cnt;

			var rest = this.buffer.length - cnt;
			Posix.memmove ((void*) this.buffer, (void*) ptr, rest);
			this.buffer.length = rest;
		}

		// FIXME: we could go OOM here
		public string? read_line (Cancellable? cancellable = null) throws GLib.IOError {
			var b = new StringBuilder ();

			while (true) {
				fill (1024*8, cancellable);
				if (buffer.length == 0) {
					return null;
				}
				
				for (var i=0; i < buffer.length; i++) {
					if (buffer[i] == '\n') {
						b.append_len ((string) buffer, i);
						slide (i+1);
						return (owned) b.str;
					}
				}
				b.append_len ((string) buffer, buffer.length);
				slide (buffer.length);
			}
		}

		// FIXME: we could go OOM here
		public async string? read_line_async (int io_priority = GLib.Priority.DEFAULT, Cancellable? cancellable = null) throws GLib.IOError {
			var b = new StringBuilder ();
			
			while (true) {
				fill_async (1024*8, io_priority, cancellable);
				if (buffer.length == 0) {
					return null;
				}
				for (var i=0; i < buffer.length; i++) {
					if (buffer[i] == '\n') {
						b.append_len ((string) buffer, i);
						slide (i+1);
						return (owned) b.str;
					}
				}
				b.append_len ((string) buffer, buffer.length);
				slide (buffer.length);
			}
		}
	}
}
