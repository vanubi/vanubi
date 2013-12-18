[CCode (cprefix = "U")]
namespace Icu {
	[Compact]
	[CCode (cheader_filename = "unicode/ucsdet.h", free_function = "ucsdet_close", has_type_id = false)]
	public class CharsetDetector {
		[CCode (cname = "ucsdet_open")]
		public CharsetDetector (out ErrorCode status);
		
		[CCode (cname = "ucsdet_setText")]
		public void set_text (uint8[] text, out ErrorCode status);
		
		[CCode (cname = "ucsdet_detect")]
		public unowned CharsetMatch detect (out ErrorCode status);
		
		[CCode (cname = "ucsdet_detectAll", array_length_pos=1.1)]
		public unowned CharsetMatch*[] detect_all (out ErrorCode status);
		
		[CCode (cname = "ucsdet_setDeclaredEncoding")]
		public void set_declared_encoding (uint8[] encoding, out ErrorCode status);
	}
	
	[SimpleType]
	[CCode (cheader_filename = "unicode/utypes.h", has_type_id = false)]
	public struct ErrorCode {
		public bool failure {
			[CCode (cname = "U_FAILURE")]
			get;
		}
		
		[CCode (cname = "u_errorName")]
		public unowned string to_string ();
	}
	
	[Compact]
	[CCode (has_type_id = false)]
	public class CharsetMatch {
		[CCode (cname = "ucsdet_getName")]
		public unowned string get_name (out ErrorCode status);
	}
}
