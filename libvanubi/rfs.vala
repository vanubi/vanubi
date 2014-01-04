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
	public class RemoteFile : Object, File {
		static int next_instance_index = 0;
		static int next_operation_index = 0;
		
		IOStream stream;
		File fake_file;
		int instance_index;
		
		public RemoteFile (IOStream stream, string path) {
			this.stream = stream;
			this.fake_file = File.new_for_path (path);
			instance_index = ++next_instance_index;
		}
		
		public GLib.FileOutputStream append_to (GLib.FileCreateFlags flags, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}	

		public bool copy (GLib.File destination, GLib.FileCopyFlags flags, GLib.Cancellable? cancellable = null, GLib.FileProgressCallback? progress_callback = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}

		public GLib.FileOutputStream create (GLib.FileCreateFlags flags, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public GLib.FileIOStream create_readwrite (GLib.FileCreateFlags flags, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}

		public bool @delete (GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}

		public async FileOutputStream append_to_async (FileCreateFlags flags, int io_priority = Priority.DEFAULT, Cancellable? cancellable = null) throws Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
			
		
		public async bool copy_async (GLib.File destination, GLib.FileCopyFlags flags, int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null, GLib.FileProgressCallback? progress_callback = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
				
		public async GLib.FileOutputStream create_async (GLib.FileCreateFlags flags, int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
				
		public async GLib.FileIOStream create_readwrite_async (GLib.FileCreateFlags flags, int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		[CCode (vfunc_name = "delete_file_async")]
		public async bool delete_async (int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public GLib.File dup () {
			return null;
		}
		
		[Deprecated (since = "2.22")]
		public async bool eject_mountable (GLib.MountUnmountFlags flags, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public async bool eject_mountable_with_operation (GLib.MountUnmountFlags flags, GLib.MountOperation? mount_operation, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public GLib.FileEnumerator enumerate_children (string attributes, GLib.FileQueryInfoFlags flags, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public async GLib.FileEnumerator enumerate_children_async (string attributes, GLib.FileQueryInfoFlags flags, int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public bool equal (GLib.File file2) {
			return false;
		}
		
		public GLib.Mount find_enclosing_mount (GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public async GLib.Mount find_enclosing_mount_async (int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public string? get_basename () {
			return null;
		}
		
		public GLib.File get_child (string name) {
			return null;
		}
		
		public GLib.File get_child_for_display_name (string display_name) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public GLib.File? get_parent () {
			return null;
		}
		
		public string get_parse_name () {
			return null;
		}
		
		public string? get_path () {
			return null;
		}
		
		public string? get_relative_path (GLib.File descendant) {
			return null;
		}
		
		public string get_uri () {
			return null;
		}
		
		public string get_uri_scheme () {
			return null;
		}
		
		public bool has_parent (GLib.File? parent) {
			return false;
		}
		
		public bool has_prefix (GLib.File file) {
			return false;
		}
		
		public bool has_uri_scheme (string uri_scheme) {
			return false;
		}
		
		public uint hash () {
			return 0;
		}
		
		public bool is_native () {
			return false;
		}
		
		public bool make_directory (GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public async bool make_directory_async (int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public bool make_symbolic_link (string symlink_value, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		#if VALA_0_22
		public bool measure_disk_usage (GLib.FileMeasureFlags flags, GLib.Cancellable? cancellable, [CCode (delegate_target_pos = 3.5)] GLib.FileMeasureProgressCallback? progress_callback, out uint64 disk_usage, out uint64 num_dirs, out uint64 num_files) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public async bool measure_disk_usage_async (GLib.FileMeasureFlags flags, int io_priority, GLib.Cancellable? cancellable, GLib.FileMeasureProgressCallback? progress_callback, out uint64 disk_usage, out uint64 num_dirs, out uint64 num_files) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		#endif
						
		public GLib.FileMonitor monitor (GLib.FileMonitorFlags flags, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}

		public GLib.FileMonitor monitor_directory (GLib.FileMonitorFlags flags, GLib.Cancellable? cancellable = null) throws GLib.IOError {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public GLib.FileMonitor monitor_file (GLib.FileMonitorFlags flags, GLib.Cancellable? cancellable = null) throws GLib.IOError {
			throw new IOError.NOT_SUPPORTED ("");
		}

		public async bool mount_enclosing_volume (GLib.MountMountFlags flags, GLib.MountOperation? mount_operation, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public async GLib.File mount_mountable (GLib.MountMountFlags flags, GLib.MountOperation? mount_operation, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public bool move (GLib.File destination, GLib.FileCopyFlags flags, GLib.Cancellable? cancellable = null, GLib.FileProgressCallback? progress_callback = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public GLib.FileIOStream open_readwrite (GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public async GLib.FileIOStream open_readwrite_async (int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}

		public async bool poll_mountable (GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}

		public bool prefix_matches (GLib.File file) {
			return false;
		}
			
		public GLib.AppInfo query_default_handler (GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public bool query_exists (GLib.Cancellable? cancellable = null) {
			return false;
		}
		
		public GLib.FileType query_file_type (GLib.FileQueryInfoFlags flags, GLib.Cancellable? cancellable = null) {
			return 0;
		}
		
		public GLib.FileInfo query_filesystem_info (string attributes, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public async GLib.FileInfo query_filesystem_info_async (string attributes, int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public GLib.FileInfo query_info (string attributes, GLib.FileQueryInfoFlags flags, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public async GLib.FileInfo query_info_async (string attributes, GLib.FileQueryInfoFlags flags, int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public GLib.FileAttributeInfoList query_settable_attributes (GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public GLib.FileAttributeInfoList query_writable_namespaces (GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
						
		public GLib.FileInputStream read (GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public async GLib.FileInputStream read_async (int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public unowned GLib.FileInputStream read_fn (GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public GLib.FileOutputStream replace (string? etag, bool make_backup, GLib.FileCreateFlags flags, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public async GLib.FileOutputStream replace_async (string? etag, bool make_backup, GLib.FileCreateFlags flags, int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}

		public GLib.FileIOStream replace_readwrite (string? etag, bool make_backup, GLib.FileCreateFlags flags, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public async GLib.FileIOStream replace_readwrite_async (string? etag, bool make_backup, GLib.FileCreateFlags flags, int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
			
		public GLib.File resolve_relative_path (string relative_path) {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public bool set_attribute (string attribute, GLib.FileAttributeType type, void* value_p, GLib.FileQueryInfoFlags flags, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public async bool set_attributes_async (GLib.FileInfo info, GLib.FileQueryInfoFlags flags, int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null, out FileInfo info_out) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public bool set_attributes_from_info (GLib.FileInfo info, GLib.FileQueryInfoFlags flags, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public GLib.File set_display_name (string display_name, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public async GLib.File set_display_name_async (string display_name, int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
			
		public async bool start_mountable (GLib.DriveStartFlags flags, GLib.MountOperation? start_operation, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public async bool stop_mountable (GLib.MountUnmountFlags flags, GLib.MountOperation? mount_operation, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public bool trash (GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public async bool trash_async (int io_priority = GLib.Priority.DEFAULT, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public async bool unmount_mountable (GLib.MountUnmountFlags flags, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
		
		public async bool unmount_mountable_with_operation (GLib.MountUnmountFlags flags, GLib.MountOperation? mount_operation, GLib.Cancellable? cancellable = null) throws GLib.Error {
			throw new IOError.NOT_SUPPORTED ("");
		}
	}
}