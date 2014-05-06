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
		public ThemeManager theme_manager { get; private set; }
		public StringSearchIndex command_index { get; private set; default = new StringSearchIndex (); }
		public StringSearchIndex lang_index { get; private set; default = new StringSearchIndex (); }
		public int next_stream_id { get; set; default = 1; }

		
		public State (Configuration config) {
			this.config = config;
			this.status = new Status (this);
			this.theme_manager = new ThemeManager (this);
		}

		public string new_stdin_stream_name () {
			return "*stdin %d*".printf (next_stream_id++);
		}
	}
}