/*
 *  Copyright © 2013-2016 Luca Bruno
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
		
		bool has_same_parent (FileSource left, FileSource right) {
			var lparent = left.parent;
			var rparent = right.parent;
			if (lparent == rparent) {
				return true;
			}

			if (lparent != null && rparent != null) {
				return lparent.equal (rparent);
			}
			return false;
		}
		
		bool has_same_extension (FileSource left, FileSource right) {
			var lext = left.extension;
			if (lext == null) {
				return false;
			}

			return lext == right.extension;
		}
		
		bool has_same_name (FileSource left, FileSource right) {
			return left.basename == right.basename;
		}

		bool left_more_similar_than_right (SimilarFlags left, SimilarFlags right) {
			bool lname = SimilarFlags.SAME_NAME in left;
			bool lext = SimilarFlags.SAME_EXTENSION in left;
			bool lsibling = SimilarFlags.SIBLING in left;
			
			bool rname = SimilarFlags.SAME_NAME in right;
			bool rext = SimilarFlags.SAME_EXTENSION in right;
			bool rsibling = SimilarFlags.SIBLING in right;

			// same extension and sibling
			if (lext && lsibling) {
				return true;
			}
			if (rext && rsibling) {
				return false;
			}

			// same extension and name
			if (lext && lname) {
				return true;
			}
			if (rext && rname) {
				return false;
			}

			// same name
			if (lname) {
				return true;
			}
			if (rname) {
				return false;
			}

			// same extension
			if (lext) {
				return true;
			}
			if (rext) {
				return false;
			}

			// sibling
			if (lsibling) {
				return true;
			}
			if (rsibling) {
				return false;
			}

			return false;
		}
		
		// Returns a similar file, or itself, for a given configuration key
		public FileSource get_similar_file (FileSource file, string key, bool has_default) {
			SimilarFlags flags = keys_flags[key];
			if (flags == SimilarFlags.NONE) {
				return file;
			}
			
			if (SimilarFlags.SKIP_HAS_DEFAULT in flags && has_default) {
				// use the default value, do not look further
				return file;
			}

			FileSource? most_similar = null;
			SimilarFlags best_match = SimilarFlags.NONE;

			each_file ((f) => {
					if (!f.equal (file)) {
						SimilarFlags cur_match = SimilarFlags.NONE;
						
						if (SimilarFlags.SAME_NAME in flags && has_same_name (file, f)) {
							cur_match |= SimilarFlags.SAME_NAME;
						}

						if (SimilarFlags.SAME_EXTENSION in flags && has_same_extension (file, f)) {
							cur_match |= SimilarFlags.SAME_EXTENSION;
						}

						if (SimilarFlags.SIBLING in flags && has_same_parent (file, f)) {
							cur_match |= SimilarFlags.SIBLING;
						}

						if (cur_match != SimilarFlags.NONE && left_more_similar_than_right (cur_match, best_match)) {
							most_similar = f;
							best_match = cur_match;
						}
					}
					return true;
			});

			if (most_similar != null) {
				string[] flag_names = null;
				if (SimilarFlags.SAME_NAME in best_match) {
					flag_names += "same_name";
				}
				if (SimilarFlags.SAME_EXTENSION in best_match) {
					flag_names += "same_extension";
				}
				if (SimilarFlags.SIBLING in best_match) {
					flag_names += "sibling";
				}
				debug ("%s is similar to %s for key %s due to: %s",
					   file.to_string(), most_similar.to_string(), key, string.joinv(", ", flag_names));
				return most_similar;
			}

			return file;
		}
	}
}