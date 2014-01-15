/*
 *  Copyright © 2013-2014 Luca Bruno
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
	public class FileCluster {
		unowned Configuration config;
		List<File> opened_files;

		public FileCluster (Configuration config) {
			this.config = config;
		}
		
		public void opened_file (File f) {
			unowned List<File> link = opened_files.find_custom (f, (CompareFunc) File.equal);
			// ensure we have no duplicates
			if (link == null) {
				opened_files.append (f);
			}
		}
		
		public void closed_file (File f) {
			unowned List<File> link = opened_files.find_custom (f, (CompareFunc) File.equal);
			if (link != null) {
				opened_files.delete_link (link);
			}
		}
		
		bool each_file (Operation<File?> op) {
			var files = config.get_files ();
			foreach (var other in files) {
				if (!op (other)) {
					return false;
				}
			}
			return true;
		}
		
		bool each_sibling (File file, Operation<File?> op) {
			var parent = file.get_parent ();
			return each_file ((other) => {
					if (parent.equal (other.get_parent ()) && !op (other)) {
						return false;
					}
					return true;
			});
		}
		
		bool each_same_extension (File file, Operation<File?> op) {
			var ext = get_file_extension (file);
			if (ext == null) {
				return true;
			}
			
			return each_file ((other) => {
					if (get_file_extension (file) == ext && !op (other)) {
						return false;
					}
					return true;
			});
		}
		
		// Returns a similar file, or itself, for a given configuration key
		public File get_similar_file (File file, string key, bool has_default) {
			if (key == "language" && has_default) {
				// use the default language, do not look further if we have a default value
				return file;
			}

			File? similar = null;
			each_sibling (file, (f) => {
					if (config.has_file_key (f, key)) {
						similar = f;
						return false;
					}
					return true;
			});
			if (similar != null) {
				return similar;
			}

			if (key == "language") {
				each_same_extension (file, (f) => {
						if (config.has_file_key (f, key)) {
							similar = f;
							return false;
						}
						return true;
				});
				if (similar != null) {
					return similar;
				}
			}
			
			return file;
		}
	}
}