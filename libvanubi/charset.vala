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
	public errordomain CharsetError {
		DETECT
	}
	
	void check_icu_error (Icu.ErrorCode err) throws CharsetError {
		if (err.failure) {
			throw new CharsetError.DETECT (err.to_string ());
		}
	}
	
	public unowned string? detect_charset (uint8[] text) throws CharsetError {
		Icu.ErrorCode err;
		var detector = new Icu.CharsetDetector (out err);
		check_icu_error (err);
		
		detector.set_text (text, out err);
		check_icu_error (err);
		
		unowned Icu.CharsetMatch match = detector.detect (out err);
		check_icu_error (err);
		
		if (match != null) {
			unowned string result = match.get_name (out err);
			check_icu_error (err);
			return result;
		}
		return null;
	}
}