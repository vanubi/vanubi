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
		public GenericArray<Location> locations = new GenericArray<Location> ();
		public Location? focused_location;
	}
	
	public class Configuration {
		KeyFile backend;
		File? file;
		Cancellable saving_cancellable;
		public FileCluster cluster;
		bool save_queued = false;
		string last_saved_data = null;
		
		const int SAVE_TIMEOUT = 500;
		const int LATEST_CONFIG_VERSION = 3;

		[CCode (cname = "VERSION", cheader_filename = "config.h")]
		public extern const string VANUBI_VERSION;
		
		[CCode (cname = "PACKAGE_URL", cheader_filename = "config.h")]
		public extern const string VANUBI_WEBSITE;
		
		[CCode (cname = "PACKAGE_BUGREPORT", cheader_filename = "config.h")]
		public extern const string VANUBI_BUGREPORT_URL;
		
		[CCode (cname = "DATADIR", cheader_filename = "config.h")]
		public extern const string VANUBI_DATADIR;

		public Configuration () {
			cluster = new FileCluster (this);
			
			var home = Environment.get_home_dir ();
			var filename = Path.build_filename (home, ".vanubi");
			backend = new KeyFile ();
			file = File.new_for_path (filename);
			if (file.query_exists ()) {
				try {
					backend.load_from_file (filename, KeyFileFlags.NONE);
				} catch (Error e) {
					warning ("Could not load configuration: %s".printf (e.message));
				}
				check_config ();
			} else {
				// last config version
				set_global_int ("config_version", LATEST_CONFIG_VERSION);
			}
		}

		public void check_config () {
			try {
				var version = get_global_int ("config_version", 0);
				if (!migrate (version)) {
					// no migration happened
					return;
				}
				// successful, write the new config, synchronously
				
				// first write to a temp file
				var saving_data = backend.to_data ();
				var tmp = File.new_for_path (file.get_path()+".tmp");
				tmp.replace_contents (saving_data.data, null, true, FileCreateFlags.PRIVATE, null);
				// rename temp to file
				tmp.move (file, FileCopyFlags.OVERWRITE);

				message ("Configuration has been migrated successfully");
			} catch (Error e) {
				warning ("Could not migrate configuration. Your original configuration will not be overwritten. Error: %s".printf (e.message));
				file = null;
			}
		}
		
		public bool migrate (int from_version) throws Error {
			var version = from_version;
			if (version == 0) {
				// backup, synchronous
				var bak = File.new_for_path (file.get_path()+".bak."+version.to_string());
				file.copy (bak, FileCopyFlags.OVERWRITE);
				
				var groups = backend.get_groups ();
				foreach (unowned string group in groups) {
					if (group.has_prefix ("file://")) {
						// convert file settings to source settings
						var newgroup = "source:"+group.substring ("file://".length);
						foreach (unowned string key in backend.get_keys (group)) {
							backend.set_value (newgroup, key, backend.get_value (group, key));
						}
						backend.remove_group (group);
					} else if (group.has_prefix ("session:")) {
						// convert session focused_file to focused_source
						if (has_group_key (group, "focused_file")) {
							var val = backend.get_value (group, "focused_file");
							if (val.has_prefix ("file://")) {
								val = val.substring ("file://".length);
							}
							backend.set_value (group, "focused_source", val);
							backend.remove_key (group, "focused_file");
						}
						foreach (unowned string key in backend.get_keys (group)) {
							if (key.has_prefix ("file")) {
								var val = backend.get_value (group, key);
								if (val.has_prefix ("file://")) {
									val = val.substring ("file://".length);
								}
								backend.set_value (group, "source"+key.substring ("file".length), val);
								backend.remove_key (group, key);
							}
						}
					}
				}

				version++;
			}

			if (version == 1) {
				// backup, synchronous
				var bak = File.new_for_path (file.get_path()+".bak."+version.to_string());
				file.copy (bak, FileCopyFlags.OVERWRITE);

				if (has_group_key ("Editor", "style")) {
					var val = backend.get_value ("Editor", "style");
					backend.set_value ("Global", "theme", val);
					backend.remove_key ("Editor", "style");
				}

				version++;
			}

			if (version == 2) {
				// backup, synchronous
				var bak = File.new_for_path (file.get_path()+".bak."+version.to_string());
				file.copy (bak, FileCopyFlags.OVERWRITE);
				
				var groups = backend.get_groups ();
				foreach (unowned string group in groups) {
					if (group.has_prefix ("session:")) {
						// convert sources to locations
						if (has_group_key (group, "focused_source")) {
							var val = backend.get_value (group, "focused_source");
							backend.set_value (group, "focused_location", val);
							backend.remove_key (group, "focused_source");
							backend.remove_key (group, "focused_line");
							backend.remove_key (group, "focused_column");
						}
						
						foreach (unowned string key in backend.get_keys (group)) {
							if (key.has_prefix ("source")) {
								var val = backend.get_value (group, key);
								backend.set_value (group, "location"+key.substring ("source".length), val);
								backend.remove_key (group, key);
							}
						}
					}
				}

				version++;
			}

			if (version > from_version) {
				set_global_int ("config_version", version);
				return true;
			} else {
				return false;
			}
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

		public void set_global_string (string key, string value) {
			set_group_string ("Global", key, value);
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
			if (session.focused_location != null && session.focused_location.source is LocalFileSource) {
				set_group_string (group, "focused_location", session.focused_location.to_cli_arg ());
			}
			for (var i=0; i < session.locations.length; i++) {
				unowned Location loc = session.locations[i];
				if (loc.source is LocalFileSource) {
					set_group_string (group, "location"+(i+1).to_string(), loc.to_cli_arg ());
				}
			}
		}
		
		public Session get_session (string name = "default") {
			var group = "session:"+name;
			var session = new Session ();
			if (backend.has_group (group)) {
				if (has_group_key (group, "focused_location")) {
					session.focused_location = new Location.from_cli_arg (get_group_string (group, "focused_location"));
				}
				foreach (var key in get_group_keys (group)) {
					if (key.has_prefix ("location")) {
						session.locations.add (new Location.from_cli_arg (get_group_string (group, key)));
					}
				}
			}
			return session;
		}
		
		public void delete_session (string name) {
			var group = "session:"+name;
			remove_group (group);
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
		
		public void set_editor_bool (string key, bool value) {
			set_group_bool ("Editor", key, value);
		}

		/* Shortcuts */
		public string get_shortcut (string command, string context = "editor") {
			return get_group_string ("keys:"+context, command);
		}
		
		public void set_shortcut (string command, string shortcut, string context = "editor") {
			set_group_string ("keys:"+context, command, shortcut);
		}
		
		public void remove_shortcut (string command, string context = "editor") {
			remove_group_key ("keys:"+context, command);
		}
		
		/* File */
		// get files except *scratch*
		public FileSource[] get_files () {
			FileSource[] res = null;
			var groups = backend.get_groups ();
			foreach (unowned string group in groups) {
				if (group.has_prefix ("file://")) {
					res += (FileSource) DataSource.new_from_string (group);
				}
			}
			return res;
		}
		
		public string? get_file_string (DataSource file, string key, string? default = null) {
			var group = "source:"+file.to_string ();
			if (!has_group_key (group, key)) {
				// look into a similar file
				if (file is FileSource) {
					var similar = cluster.get_similar_file ((FileSource) file, key, default != null);
					group = "source:"+similar.to_string ();
				}
			}
			return get_group_string (group, key, get_editor_string (key, default));
		}
		
		public void set_file_string (DataSource file, string key, string value) {
			var group = "source:"+file.to_string ();
			backend.set_string (group, key, value);
		}
		
		public void remove_file_key (DataSource file, string key) {
			var group = "source:"+file.to_string ();
			remove_group_key (group, key);
		}
		
		public bool has_file_key (DataSource file, string key) {
			var group = "source:"+file.to_string ();
			return has_group_key (group, key);
		}

		int64 last_time_saved = 0; // seconds
		uint save_timeout = 0;

		public void save () {
			if (file == null) {
				return;
			}
			
			// save the config at most 1 time every SAVE_TIMEOUT milliseconds
			var cur_time = get_monotonic_time () / 1000;
			if (cur_time - last_time_saved >= SAVE_TIMEOUT) {
				last_time_saved = cur_time;
				save_immediate.begin ();
			} else {
				// too early to save, enqueue
				if (save_timeout > 0) {
					// some already enqueued
					return;
				}
				
				save_timeout = Timeout.add_seconds (1, () => {
						last_time_saved = get_monotonic_time () / 1000;
						save_timeout = 0;
						save_immediate.begin ();
						return false;
				});
			}
		}
		
		public async void save_immediate () {
			if (file == null) {
				return;
			}
			
			if (save_queued) {
				return;
			}
			
			if (saving_cancellable != null) {
				// Cancel any previous save() operation 
				saving_cancellable.cancel ();
				// Wait until it's effectively cancelled
				save_queued = true;
				// Yes, spin lock
				Timeout.add (10, () => {
						if (saving_cancellable == null) {
							Idle.add (save_immediate.callback);
							return false;
						} else {
							return true;
						}
				});
				yield;
			}
			
			save_queued = false;
			var saving_data = backend.to_data ();
			if (last_saved_data == saving_data) {
				return;
			}
			saving_cancellable = new Cancellable ();
			
			try {
				// create a backup
				var exists = yield new LocalFileSource (file).exists ();
				if (exists) {
					// if configuration exists, do a backup
					var bak = File.new_for_path (file.get_path()+".bak");
					yield file.copy_async (bak, FileCopyFlags.OVERWRITE, Priority.DEFAULT, saving_cancellable, null);
				}
				// write to a temp file
				var tmp = File.new_for_path (file.get_path()+".tmp");
				yield tmp.replace_contents_async (saving_data.data, null, true, FileCreateFlags.PRIVATE, saving_cancellable, null);
				// rename temp to file
				tmp.move (file, FileCopyFlags.OVERWRITE, saving_cancellable, null);
				
				last_saved_data = saving_data;
			} catch (IOError.CANCELLED e) {
			} catch (Error e) {
				// TODO: display error message
				warning ("Could not save configuration: %s", e.message);
			} finally {
				saving_cancellable = null;
			}
		}
	}
}
