[CCode (cprefix = "KEYBINDER", lower_case_cprefix = "keybinder_", cheader_filename="keybinder.h")]
namespace Keybinder {
	public delegate void Handler (string keystring);
	
	public void init ();
	public bool bind (string keystring, Handler hander);
	public void unbind (string keystring, GLib.Callback handler);
	public uint32 get_current_event_time ();
}