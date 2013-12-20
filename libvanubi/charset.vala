/*
 *  Copyright © 2013 Luca Bruno
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
	static const string[] detected_charsets = { "ISO-8859-1" };
	
	/* Try to guess the charset and return the converted data along with the number of bytes read.
	 * If no charset can be detected, returns latin1 converted to utf-8 with fallbacks */
	public uint8[]? convert_to_utf8 (uint8[] text, ref string? charset, out int read, out int fallbacks) throws Error {
		read = 0;
		fallbacks = 0;
		if (text.length == 0) {
			return text;
		}
		
		var default_charset = charset ?? "UTF-8";
		var buf = new uint8[text.length*4];
		buf.length--; // space for trailing zero
		uint8[] bestbuf = null;
		charset = null;
		
		// first try the default charset
		var conv = new CharsetConverter ("UTF-8", default_charset);
		size_t sread, written;
		try {
			conv.convert (text, buf, ConverterFlags.NONE, out sread, out written);
			var newread = (int) sread;
			charset = default_charset;
			bestbuf = buf;
			bestbuf.length = (int) written;
			read = newread;
		} catch (IOError.PARTIAL_INPUT e) {
			var newread = (int) sread;
			charset = default_charset;
			bestbuf = buf;
			bestbuf.length = (int) written;
			read = newread;
		} catch (Error e) {
			// invalid byte sequence
		}
		
		foreach (unowned string cset in detected_charsets) {
			if (cset == default_charset) {
				continue;
			}
			
			conv = new CharsetConverter ("UTF-8", cset);
			try {
				conv.convert (text, buf, ConverterFlags.NONE, out sread, out written);
				var newread = (int) sread;
				if (newread > read) { // FIXME: check readable chars
					charset = cset;
					bestbuf = buf;
					bestbuf.length = (int) written;
					read = newread;
				}
			} catch (IOError.PARTIAL_INPUT e) {
				var newread = (int) sread;
				if (newread > read) { // FIXME: check reaable chars
					charset = cset;
					bestbuf = buf;
					bestbuf.length = (int) written;
					read = newread;
				}
			} catch (Error e) {
				// invalid byte sequence
			}
		}

		if (bestbuf == null) {
			// assume latin1 with fallbacks
			conv = new CharsetConverter ("UTF-8", "ISO-8859-1");
			conv.use_fallback = true;
			conv.convert (text, bestbuf, ConverterFlags.NONE, out sread, out written);
			read = (int) read;
			bestbuf.length = (int) written;
			charset = "ISO-8859-1";
			fallbacks = (int) conv.get_num_fallbacks ();
		}

		bestbuf[bestbuf.length] = '\0';
		return bestbuf;
	}
}