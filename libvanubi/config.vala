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
	public class Session {
		public GenericArray<File> files = new GenericArray<File> ();
		public Location? location;
	}
	
	public class Configuration {
		KeyFile backend;
		File file;
		Cancellable saving_cancellable;
		public FileCluster cluster;

		[CCode (cname = "VERSION", cheader_filename = "config.h")]
		public extern const string VANUBI_VERSION;
		
		[CCode (cname = "PACKAGE_URL", cheader_filename = "config.h")]
		public extern const string VANUBI_WEBSITE;
		
		[CCode (cname = "PACKAGE_BUGREPORT", cheader_filename = "config.h")]
		public extern const string VANUBI_BUGREPORT_URL;
		
		public Configuration () {
			cluster = new FileCluster (this);
			
			var home = Environment.get_home_dir ();
			var filename = Path.build_filename (home, ".vanubi");
			backend = new KeyFile ();
			file = File.new_for_path (filename);
			if (file.query_exists ()) {
				try {
					backend.load_from_file (filename, KeyFileFlags.NONE);
					check_config ();
				} catch (Error e) {
					warning ("Could not load vanubi configuration: %s", e.message);
				}
			}
		}

		public void check_config () {
			var version = get_global_int ("config_version", 0);
			migrate (version);
		}
		
		public void migrate (int from_version) {
		}
		
		public int get_group_int (string group, string key, int default = 0) {
			try {
				if (backend.has_group (group) && backend.has_key (group, key)) {
					return backend.get_integer (group, key);
				}
				return default;
			} catch (Error e) {
				return default;
			}
		}

		public void set_group_int (string group, string key, int value) {
			backend.set_integer (group, key, value);
		}

		public string? get_group_string (string group, string key, string? default = null) {
			try {
				if (backend.has_group (group) && backend.has_key (group, key)) {
					return backend.get_string (group, key);
				}
				return default;
			} catch (Error e) {
				return default;
			}
		}
		
		public bool get_group_bool (string group, string key, bool default) {
			try {
				if (backend.has_group (group) && backend.has_key (group, key)) {
					return backend.get_boolean (group, key);
				}
				return default;
			} catch (Error e) {
				return default;
			}
		}
		
		public void set_group_bool (string group, string key, bool value) {
			backend.set_boolean (group, key, value);
		}
		
		public void remove_group_key (string group, string key) {
			try {
				backend.remove_key (group, key);
			} catch (Error e) {
			}
		}

		public void set_group_string (string group, string key, string value) {
			backend.set_string (group, key, value);
		}
		
		public bool has_group_key (string group, string key) {
			try {
				return backend.has_key (group, key);
			} catch (Error e) {
				return false;
			}
		}
		
		public string[]? get_group_keys (string group) {
			try {
				return backend.get_keys (group);
			} catch (Error e) {
				return null;
			}
		}

		public void remove_group (string group) {
			try {
				backend.remove_group (group);
			} catch (Error e) {
			}
		}
		
		/* Global */
		public string get_global_string (string key, string? default = null) {
			return get_group_string ("Global", key, default);
		}
		
		public int get_global_int (string key, int default = 0) {
			return get_group_int ("Global", key, default);
		}
		
		public void set_global_int (string key, int value) {
			set_group_int ("Global", key, value);
		}
		
		public bool get_global_bool (string key, bool default = false) {
			return get_group_bool ("Global", key, default);
		}
		
		public void set_global_bool (string key, bool value) {
			set_group_bool ("Global", key, value);
		}

		/* Session */
		public void save_session (Session session, string name = "default") {
			var group = "session:"+name;
			remove_group (group);
			if (session.location != null && session.location.file != null) {
				set_group_string (group, "focused_file", session.location.file.get_uri ());
				set_group_int (group, "focused_line", session.location.start_line);
				set_group_int (group, "focused_column", session.location.start_column);
			}
			for (var i=0; i < session.files.length; i++) {
				set_group_string (group, "file"+(i+1).to_string(), session.files[i].get_uri ());
			}
		}
		
		public Session get_session (string name = "default") {
			var group = "session:"+name;
			var session = new Session ();
			if (backend.has_group (group)) {
				if (has_group_key (group, "focused_file")) {
					var file = File.new_for_uri (get_group_string (group, "focused_file"));
					session.location = new Location (file,
													 get_group_int (group, "focused_line"),
													 get_group_int (group, "focused_column"));
				}
				foreach (var key in get_group_keys (group)) {
					if (key.has_prefix ("file")) {
						session.files.add (File.new_for_uri (get_group_string (group, key)));
					}
				}
			}
			return session;
		}
		
		public string[] get_sessions () {
			// return with "default" session as first session
			var res = new string[]{"default"};
			var groups = backend.get_groups ();
			foreach (unowned string group in groups) {
				if (group != "session:default" && group.has_prefix ("session:")) {
					res += group.substring ("session:".length);
				}
			}
			
			return res;
		}
		
		/* Editor */
		public int get_editor_int (string key, int default = 0) {
			return get_group_int ("Editor", key, default);
		}
		
		public void set_editor_int (string key, int value) {
			set_group_int ("Editor", key, value);
		}

		public string? get_editor_string (string key, string? default = null) {
			return get_group_string ("Editor", key, default);
		}

		public bool get_editor_bool (string key, bool default = false) {
			return get_group_bool ("Editor", key, default);
		}
		
		/* File */
		// get files except *scratch*
		public File[] get_files () {
			File[] res = null;
			var groups = backend.get_groups ();
			foreach (unowned string group in groups) {
				if (group.has_prefix ("file://")) {
					res += File.new_for_uri (group);
				}
			}
			return res;
		}
		
		public string? get_file_string (File? file, string key, string? default = null) {
			var group = file != null ? file.get_uri () : "*scratch*";
			if (file != null && !has_group_key (group, key)) {
				// look into a similar file
				group = cluster.get_similar_file(file, key, default != null).get_uri ();
			}
			return get_group_string (group, key, get_editor_string (key, default));
		}
		
		public void set_file_string (File? file, string key, string value) {
			var group = file != null ? file.get_uri () : "*scratch*";
			backend.set_string (group, key, value);
		}
		
		public void remove_file_key (File? file, string key) {
			var group = file != null ? file.get_uri () : "*scratch*";
			remove_group_key (group, key);
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
				// create a backup
				var bak = File.new_for_path (file.get_path()+".bak");
				yield file.copy_async (bak, FileCopyFlags.OVERWRITE, Priority.DEFAULT, saving_cancellable, null);
				// write to a temp file
				var tmp = File.new_for_path (file.get_path()+".tmp");
				yield tmp.replace_contents_async (saving_data.data, null, true, FileCreateFlags.PRIVATE, saving_cancellable, null);
				// rename temp to file
				tmp.move (file, FileCopyFlags.OVERWRITE, saving_cancellable, null);
			} catch (IOError.CANCELLED e) {
			} catch (Error e) {
				// TODO: display error message
				warning ("Could not save configuration: %s", e.message);
			}
		}
	}
}
