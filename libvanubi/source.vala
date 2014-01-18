/*
 *  Copyright © 2011-2014 Luca Bruno
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
	public abstract class DataSource : Object {
		public abstract DataSource? container { owned get; }

		public abstract async bool exists ();

		public abstract uint hash ();
		public abstract bool equal (DataSource? s);		
		public abstract string to_string ();
		
		public static DataSource new_from_string (string path) {
			if (path == "*scratch*") {
				return ScratchSource.instance;
			} else {
				return new LocalFileSource (File.new_for_path (path));
			}
		}
	}
	
	public class ScratchSource : DataSource {
		public static ScratchSource instance {
			get {
				if (_instance == null) {
					_instance = new ScratchSource ();
				}
				return _instance;
			}
		}
		
		static ScratchSource _instance = null;
		
		private ScratchSource () {
		}
		
		public override DataSource? container {
			owned get {
				return new LocalFileSource (File.new_for_path (Environment.get_current_dir()));
			}
		}
		
		public override async bool exists () {
			return true;
		}
		
		public override uint hash () {
			uint ptr = (uint)(void*) this;
			return ptr;
		}
		
		public override bool equal (DataSource? s) {
			return this == s;
		}
		
		public override string to_string () {
			return "*scratch*";
		}
	}
	
	public abstract class FileSource : DataSource {
		public abstract string basename { owned get; }
		
		public string? extension {
			owned get {
				var bn = basename;
				var idx = bn.last_index_of (".");
				if (idx < 0) {
					return null;
				}
				
				return bn.substring (idx+1);
			}
		}
	}
	
	public class LocalFileSource : FileSource {
		public File file;
		
		public LocalFileSource (File file) {
			this.file = file;
		}
		
		public override DataSource? container {
			owned get {
				var parent = file.get_parent ();
				if (parent != null) {
					return new LocalFileSource (parent);
				}
				// we are at the root of the file system
				return null;
			}
		}
	
		public override string basename {
			owned get {
				return file.get_basename ();
			}
		}
		
		public override async bool exists () {
			
		}
		
		public override uint hash () {
			return file.hash ();
		}
		
		public override bool equal (DataSource? s) {
			if (this == s) {
				return true;
			}
			var f = s as LocalFileSource;
			return f != null && file.equal (f.file);
		}
		
		public override string to_string () {
			return file.get_path ();
		}
	}
}