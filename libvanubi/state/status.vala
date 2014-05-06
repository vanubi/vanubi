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
	public class Status : Object {
		public enum Type {
			NORMAL,
			ERROR
		}
		
		public weak State state;

		[CCode (notify = false)]
		public string text { get; private set; default = ""; }
		[CCode (notify = false)]
		public string context { get; private set; default = null; }
		[CCode (notify = false)]
		public Type status_type { get; private set; default = Type.NORMAL; }

		public signal void changed ();

		uint timeout = 0;

		public Status (State state) {
			this.state = state;
		}
		
		public void clear (string? context = null) {
			if (context == null || context == this.context) {
				this.text = "";
			}
			this.context = null;
			this.status_type = Type.NORMAL;
			stop_timeout ();

			changed ();
		}

		public void set (string text, string? context = null, Type type = Type.NORMAL) {
			this.context = context;
			this.text = text;
			this.status_type = type;
			stop_timeout ();

			changed ();
		}

		public void start_timeout () {
			if (timeout == 0) {
				timeout = Timeout.add_seconds (state.config.get_global_int ("status_timeout", 2), () => {
						timeout = 0;
						clear ();
						return false;
				});
			}
		}

		void stop_timeout () {
			if (timeout > 0) {
				Source.remove (timeout);
				timeout = 0;
			}
		}
	}
}
