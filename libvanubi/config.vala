/*
 *  Copyright © 2011-2013 Luca Bruno
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
	public class Configuration {
		KeyFile backend;
		File file;
		Cancellable saving_cancellable;

		public Configuration () {
			var home = Environment.get_home_dir ();
			var filename = Path.build_filename (home, ".vanubi");
			backend = new KeyFile ();
			file = File.new_for_path (filename);
			if (file.query_exists ()) {
				try {
					backend.load_from_file (filename, KeyFileFlags.NONE);
				} catch (Error e) {
					warning ("Could not load vanubi configuration: %s", e.message);
				}
			}
		}

		public int get_integer (string group, string key, int default) {
			try {
				if (backend.has_group (group) && backend.has_key (group, key)) {
					return backend.get_integer (group, key);
				}
				return default;
			} catch (Error e) {
				return default;
			}
		}

		public void set_font_size (int size) {
			backend.set_integer ("Editor", "font_size", size);
		}

		public int get_font_size (int default) {
			// the default value here depends on the widget
			return get_integer ("Editor", "font_size", default);
		}

		public async void save () {
			/* We save the file asynchronously (including the backup),
			   so that the user does not experience any UI lag. */
			var saving_data = backend.to_data ();
			if (saving_cancellable != null && !saving_cancellable.is_cancelled ()) {
				// Cancel any previous save() operation 
				saving_cancellable.cancel ();
			}
			saving_cancellable = new Cancellable ();
			try {
				yield file.replace_contents_async (saving_data.data, null, true, FileCreateFlags.PRIVATE, saving_cancellable, null);
			} catch (IOError.CANCELLED e) {
			} catch (Error e) {
				// TODO: display error message
				warning ("Could not save file: %s", e.message);
			}
		}
	}
}
