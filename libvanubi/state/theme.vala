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
	public class Theme {
		public weak State state;
		public string id;
		public string name;

		public Theme (State state, string id, string name) {
			this.state = state;
			this.id = id;
			this.name = name;
		}

		public string? get_css_file () {
			// TODO: check readable rather than existing
			
			var filename = "~/.local/share/vanubi/css/%s.css";
			if (FileUtils.test (filename, FileTest.EXISTS)) {
				return filename;
			}

			filename = "./data/css/%s.css".printf (id);
			if (FileUtils.test (filename, FileTest.EXISTS)) {
				return filename;
			}
			
			filename = state.config.get_compile_datadir () + "/vanubi/css/%s.css".printf (id);
			if (FileUtils.test (filename, FileTest.EXISTS)) {
				return filename;
			}

			return null;
		}
	}
}
