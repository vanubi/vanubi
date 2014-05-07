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
	public class LayoutManager : Object {
		public Layout current_layout { get; set; }
		
		List<Layout> layouts = new List<Layout> ();
		Layout single_layout = null;

		public void initialize (Layout single_layout) {
			this.single_layout = single_layout;
			watch_layout (single_layout);
		}

		void watch_layout (Layout layout) {
			layout.notify["container"].connect (on_container_changed);
		}

		void on_container_changed (Object obj, ParamSpec param) {
			var layout = (Layout) obj;
			if (layout.container is SplitContainer && layout == single_layout) {
				// ensure there's always a single-editor layout
				single_layout = new Layout (null);
				var container = new EditorContainer (single_layout);
				single_layout.container = container;
				container.editor = new Editor (layout.last_focused_editor.buffer);
				// share buffer
				single_layout.last_focused_editor = container.editor;
				
				layouts.append (single_layout);
				watch_layout (single_layout);
			} else if (layout.container is EditorContainer && layout != single_layout) {
				// remove the existing single-editor layout
				layouts.remove (single_layout);
				single_layout = layout;
			}
		}
	}

	public class Layout : Object {
		/* Parent of root layout is null */
		public weak SplitContainer? parent { get; private set; }
		public LayoutContainer container { get; set; }
		public Editor last_focused_editor { get; set; }

		public Layout (SplitContainer? parent) {
			this.parent = parent;
		}
	}

	/* May be replaced in the parent by another layout container */
	public abstract class LayoutContainer : Object {
		public weak Layout parent { get; private set; }

		public LayoutContainer (Layout parent) {
			this.parent = parent;
		}
	}

	public class EditorContainer : LayoutContainer {
		public Editor editor { get; set; }

		public EditorContainer (Layout parent) {
			base (parent);
		}
	}

	public class SplitContainer : LayoutContainer {
		public Layout layout1 { get; set; }
		public Layout layout2 { get; set; }

		public SplitContainer (Layout parent) {
			base (parent);
		}
	}
}
