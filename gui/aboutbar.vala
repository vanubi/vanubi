/*
 *  Copyright © 2014-2016 Rocco Folino
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

using Gtk;

namespace Vanubi.UI {
	private class AboutView : SourceView {
		public AboutView () {
			set_editable (false);
			expand = true;
			cursor_visible = false;
			var system_size = style.font_desc.get_size () / Pango.SCALE;
			override_font (Pango.FontDescription.from_string ("Monospace %d".printf (system_size)));
		}

		/* TODO: get color from the style */
		public void colorize_text () {
			TextTag white_tag = buffer.create_tag("fg_white", foreground: "#FFFFFF");
			TextTag green_tag = buffer.create_tag("fg_green", foreground: "#00CC00");
			TextIter green_start, green_end;
			TextIter white_start, white_end;

			for (var i=0; i<buffer.get_line_count (); i++) {

				buffer.get_iter_at_line_offset (out white_start, i, 0);
				white_end = white_start;

				while (white_end.get_char () != '|') {
					white_end.forward_char ();
					if (white_end.ends_line ()) {
						break;
					}
				}

				if (white_end.ends_line ()) {
					buffer.apply_tag (white_tag, white_start, white_end);
					continue;
				}

				white_end.forward_char (); /* Skip '|' */
				buffer.apply_tag (white_tag, white_start, white_end);

				/* Go to the end of line */
				green_start = white_end;
				green_end = green_start;
				while (!green_end.ends_line ()) {
					green_end.forward_char ();
				}

				buffer.apply_tag (green_tag, green_start, green_end);
			}
		}
	}

	public class AboutBar : Bar {
		AboutView view;

		string text = """

                                                                              |                          :o/
                                                                              |                        :soss  `//
                                                                              |                      `+sody/ -ss+
                                                                              |                      ooommy:-shs-
                                                                              |                     /s+mmmy+shho
                                                                              |                    .s+ymmmyshmy:
                                                                              |                    /s/mmmmdhmds
                      --[ Vanubi Programming editor ]--                       |                    +o+mmmmmmmho
                                                                              |                    +oommmmmmmy/
     "All editors suck. This one just sucks less." -mutt like, circa 1995     |                  -oo+ymmmmmmmyo.
                                                                              |               `:oooymNNNNNNNNmdyo.
                                                                              |             `/soohNNNNNNNNNNNNNNdy/`
                                                                              |           `/sosdNNNNNNNNNNNNNNNNNNdy/`
                                                                              |         `/sosmNNNNNNNNNNNNNNNNNNNNNNdyo:.
                                                                              |       `/sosmNNNNNNNNNNNmmmmmmmmmNNNNNNmdhs/.
                                                                              |     `/sosmNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNNds:
                                                                              |    .ooomNNNNNNNNNNNNNNNNNNNmmddmmNNNNNNmdhs:`
                                                                              |    :s+shmNNNNNNNNNNNNNNNNNy+:---/+osooo/-.
                                                                              |     `:ooooosyhdmNNNNNNNNNms`
                                                                              |         .-:/+ooooshmNMMMMds`
                  ** Vanubi is licensed under GPLv3+ **                       |                `-/oooyNMMds`
                                                                              |                    -+o+hMds`
                                                                              |                      :sosho
                                                                              |                       `oos/
                                                                              |                         /o`
   v%s --- %s
""".printf (Configuration.VANUBI_VERSION, Configuration.VANUBI_WEBSITE);

		public AboutBar () {
			expand = true;
			view = new AboutView();
			view.buffer.text = text;
			view.key_press_event.connect ((e) => {
					aborted ();
					return true;
			});
			view.button_press_event.connect ((e) => {
					aborted ();
					return true;
			});
			view.colorize_text ();
			add (view);
			show_all ();
		}

		public override void grab_focus () {
			view.grab_focus ();
		}
	}
}