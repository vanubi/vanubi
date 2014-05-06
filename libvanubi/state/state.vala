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
	public class State {
		public Configuration config { get; private set; }
		public Status status { get; private set; }
		public StringSearchIndex command_index { get; private set; default = new StringSearchIndex (); }
		public StringSearchIndex lang_index { get; private set; default = new StringSearchIndex (); }
		public int next_stream_id { get; set; default = 1; }
		public string[] theme_styles_search_path { get; private set; }

		Theme[] default_themes;
		
		public State (Configuration config) {
			this.config = config;
			this.status = new Status (this);

			default_themes = new Theme[]{
				new Theme (this, "zen", "Zen (dark)"),
				new Theme (this, "tango", "Tango (light)")
			};
			
			theme_styles_search_path = new string[]{ absolute_path("", "~/.local/share/vanubi/styles/"), "./data/styles/", config.get_compile_datadir() + "/vanubi/styles/" };
		}

		public string new_stdin_stream_name () {
			return "*stdin %d*".printf (next_stream_id++);
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
					var theme = new Theme (this, themeid, themeid);
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
}