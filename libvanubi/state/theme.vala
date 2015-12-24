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

namespace Vanubi {
	public class ThemeManager {
		public weak State state;
		public string[] styles_search_path { get; private set; }

		Theme[] default_themes;

		public ThemeManager (State state) {
			this.state = state;

			default_themes = new Theme[]{
				new Theme (state, "zen", "Zen (dark)"),
				new Theme (state, "tango", "Tango (light)")
			};
			
			styles_search_path = new string[]{ absolute_path("", "~/.local/share/vanubi/styles/"), "./data/styles/", state.config.get_compile_datadir() + "/vanubi/styles/" };
		}

		public Annotated<Theme>[] get_themes () {
			Annotated<Theme>[] themes = null;
			foreach (unowned Theme theme in default_themes) {
				themes += new Annotated<Theme> (theme.name, theme);
			}
			
			Dir dir;
			try {
				dir = Dir.open ("~/.local/share/vanubi/css");
			} catch {
				return themes;
			}
			
			unowned string filename = null;
			while ((filename = dir.read_name ()) != null) {
				if (filename.has_suffix (".css")) {
					var themeid = filename.substring (0, filename.length-4);
					var theme = new Theme (state, themeid, themeid);
					themes += new Annotated<Theme> (themeid, theme);
				}
			}
			return themes;
		}

		public Theme? get_theme (string id) {
			var themes = get_themes ();
			foreach (unowned Annotated<Theme> theme in themes) {
				if (theme.obj.id == id) {
					return theme.obj;
				}
			}
			
			return null;
		}
	}
	
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
