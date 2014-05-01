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
	[Flags]
	public enum SimilarFlags {
		NONE,
		SAME_NAME,
		SAME_EXTENSION,
		SIBLING,
		SKIP_HAS_DEFAULT
	}

	public class FileCluster {
		unowned Configuration config;
		List<FileSource> opened_files;
		HashTable<string, SimilarFlags> keys_flags;

		public FileCluster (Configuration config) {
			this.config = config;
			this.keys_flags = new HashTable<string, SimilarFlags> (str_hash, str_equal);
			keys_flags["language"] = SimilarFlags.SAME_NAME | SimilarFlags.SAME_EXTENSION | SimilarFlags.SKIP_HAS_DEFAULT;
			keys_flags["shell_cwd"] = SimilarFlags.SIBLING;
			keys_flags["tab_width"] = SimilarFlags.SAME_NAME | SimilarFlags.SAME_EXTENSION;
			keys_flags["indent_mode"] = SimilarFlags.SAME_NAME | SimilarFlags.SAME_EXTENSION;
		}
		
		public void opened_file (FileSource f) {
			unowned List<FileSource> link = opened_files.find_custom (f, DataSource.compare);
			// ensure we have no duplicates
			if (link == null) {
				opened_files.append (f);
			}
		}
		
		public void closed_file (FileSource f) {
			unowned List<FileSource> link = opened_files.find_custom (f, DataSource.compare);
			if (link != null) {
				opened_files.delete_link (link);
			}
		}
		
		bool each_file (Operation<FileSource> op) {
			var files = config.get_files ();
			foreach (var other in files) {
				if (!op (other)) {
					return false;
				}
			}
			return true;
		}
		
		bool each_sibling (FileSource file, Operation<FileSource> op) {
			var parent = file.parent;
			return each_file ((other) => {
					if (parent.equal (other.parent) && !op (other)) {
						return false;
					}
					return true;
			});
		}
		
		bool each_same_extension (FileSource file, Operation<FileSource> op) {
			var ext = file.extension;
			if (ext == null) {
				return true;
			}
			
			return each_file ((other) => {
					if (file.extension == ext && !op (other)) {
						return false;
					}
					return true;
			});
		}

		
		bool each_same_name (FileSource file, Operation<FileSource> op) {
			return each_file ((other) => {
					if (file.basename == other.basename && !op (other)) {
						return false;
					}
					return true;
			});
		}
		
		// Returns a similar file, or itself, for a given configuration key
		public FileSource get_similar_file (FileSource file, string key, bool has_default) {
			SimilarFlags flags = keys_flags[key];
			if (flags == SimilarFlags.NONE) {
				return file;
			}
			
			if (SimilarFlags.SKIP_HAS_DEFAULT in flags && has_default) {
				// use the default language, do not look further if we have a default value
				return file;
			}

			FileSource? similar = null;

			if (SimilarFlags.SAME_NAME in flags) {
				each_same_name (file, (f) => {
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

			if (SimilarFlags.SAME_EXTENSION in flags) {
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

			if (SimilarFlags.SIBLING in flags) {
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
			}
			
			return file;
		}
	}
}