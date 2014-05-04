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

	public struct Key {
		uint keyval;
		uint modifiers;

		public Key (uint keyval, uint modifiers) {
			this.keyval = keyval;
			this.modifiers = modifiers;
		}

		public uint hash () {
			return keyval | (modifiers << 16);
		}

		public bool equal (Key? other) {
			return keyval == other.keyval && modifiers == other.modifiers;
		}
	}

	// Tree of keys for handling keybinding combos
	class KeyNode {
		internal weak KeyNode parent;
		internal string command;
		internal Key key;
		internal HashTable<Key?, KeyNode> children = new HashTable<Key?, KeyNode> (Key.hash, Key.equal);

		public KeyNode get_child (Key key, bool create) {
			KeyNode child = children.get (key);
			if (create && child == null) {
				child = new KeyNode ();
				child.parent = this;
				child.key = key;
				children[key] = child;
			}
			return child;
		}

		public bool has_children () {
			return children.size() > 0;
		}
	}

	public class KeyManager {
		KeyNode key_root = new KeyNode ();
		KeyNode current_key;
		uint key_timeout = 0;

		public signal void execute_command (Object subject, string command, bool use_old_state);
		
		public int timeout { get; set; default = 400; }

		public KeyManager (Configuration conf) {
			this.timeout = conf.get_global_int ("key_timeout", 400);
			current_key = key_root;
		}

		public void reset () {
			if (key_timeout != 0) {
				Source.remove (key_timeout);
				key_timeout = 0;
			}
			current_key = key_root;
		}

		public void bind_command (Key[] keyseq, string cmd) {
			KeyNode cur = key_root;
			foreach (var key in keyseq) {
				cur = cur.get_child (key, true);
			}
			cur.command = cmd;
		}
		
		public void rebind_command (Key[] keyseq, string cmd) {
			remove_binding (cmd);
			bind_command (keyseq, cmd);
		}
		
		public void remove_binding (string cmd) {
			var node = find_node (key_root, cmd);
			if (node == null) {
				return;
			}
			
			var parent = node.parent;
			if (parent != null) {
				parent.children.remove (node.key);
			}
			node = parent;
			
			while (node != null && node.command == null) {
				// clear empty keystrokes
				parent = node.parent;
				if (parent != null) {
					parent.children.remove (node.key);
				}
				node = parent;
			}
		}

		KeyNode? find_node (KeyNode node, string command) {
			if (node.command == command) {
				return node;
			}
			foreach (var child in node.children.get_values ()) {
				var n = find_node (child, command);
				if (n != null) {
					return n;
				}
			}
			return null;
		}
		
		bool get_binding_helper (GenericArray<Key?> res, KeyNode node, string command) {
			if (node.command == command) {
				res.add (node.key);
				return true;
			}
			foreach (var child in node.children.get_values ()) {
				if (get_binding_helper (res, child, command)) {
					if (node != key_root) {
						res.add (node.key);
					}
					return true;
				}
			}
			return false;
		}

		public Key[]? get_binding (string command) {
			var arr = new GenericArray<Key?> ();
			get_binding_helper (arr, key_root, command);
			if (arr.data.length == 0) {
				return null;
			}
			var res = new Key[arr.length];
			// reverse array
			for (var i=0; i < arr.length; i++) {
				res[arr.length-i-1] = arr[i];
			}
			return res;
		}

		public void flush (Object subject) {
			// force running the pending command
			if (key_timeout != 0) {
				Source.remove (key_timeout);
				key_timeout = 0;
			}
			
			if (current_key != null && current_key.command != null) {
				execute_command (subject, current_key.command, true);
			}
			current_key = key_root;
		}
		
		public bool key_press (Object subject, Key pressed) {
			if (key_timeout != 0) {
				Source.remove (key_timeout);
				key_timeout = 0;
			}

			var old_key = current_key;
			current_key = current_key.get_child (pressed, false);
			if (current_key == null) {
				// no match
				var handled = false;
				current_key = key_root;
				if (old_key != null && old_key.command != null) {
					execute_command (subject, old_key.command, true);
				}
				if (old_key != key_root) {
					// this might be a new command, retry from root
					handled = key_press (subject, pressed);
				}
				return handled;
			}

			if (current_key.has_children ()) {
				if (current_key.command != null) {
					// wait for further keys
					key_timeout = Timeout.add (timeout, () => {
							key_timeout = 0;
							unowned string command = current_key.command;
							current_key = key_root;
							execute_command (subject, command, true);
							return false;
						});
				}
			} else {
				unowned string command = current_key.command;
				current_key = key_root;
				execute_command (subject, command, false);
			}
			return true;
		}
	}
}