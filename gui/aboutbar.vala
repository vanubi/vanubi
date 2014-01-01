/*
 *  Copyright © 2014 Rocco Folino
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

namespace Vanubi {
	public class AboutBar : Bar {
		TextView view;
		
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
 >>> v%s | %s
""".printf (Configuration.VANUBI_VERSION, Configuration.VANUBI_WEBSITE);

		public AboutBar () {
			expand = true;
			view = new TextView();
			view.set_editable (false);
			view.buffer.text = text;
			view.expand = true;
			view.cursor_visible = false;
			view.key_press_event.connect ((e) => {
					aborted ();
					return true;
			});
			view.button_press_event.connect ((e) => {
					aborted ();
					return true;
			});
			var system_size = view.style.font_desc.get_size () / Pango.SCALE;
			view.override_font (Pango.FontDescription.from_string ("Monospace %d".printf (system_size)));
			add (view);
			show_all ();
		}
	}
}