/*
 *  Copyright © 2011-2013 Luca Bruno
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
		internal string command;
		internal Key key;
		internal HashTable<Key?, KeyNode> children = new HashTable<Key?, KeyNode> (Key.hash, Key.equal);

		public KeyNode get_child (Key key, bool create) {
			KeyNode child = children.get (key);
			if (create && child == null) {
				child = new KeyNode ();
				child.key = key;
				children[key] = child;
			}
			return child;
		}

		public bool has_children () {
			return children.size() > 0;
		}
	}

	public delegate void KeyDelegate<G> (G subject, string command);

	public class KeyManager<G> {
		KeyNode key_root = new KeyNode ();
		KeyNode current_key;
		uint key_timeout = 0;
		KeyDelegate<G> deleg = null;

		public int timeout { get; set; default = 400; }

		public KeyManager (Configuration conf, owned KeyDelegate<G> deleg) {
			this.deleg = (owned) deleg;
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

		public Key?[]? get_binding (string command) {
			var arr = new GenericArray<Key?> ();
			get_binding_helper (arr, key_root, command);
			if (arr.data.length == 0) {
				return null;
			}
			var res = (owned) arr.data;
			arr.data.length = 0; // bug that has been recently fixed in vala
			// reverse array
			for (int i=0; i <= (res.length-1)/2; i++) {
				var tmp = res[i];
				res[i] = res[res.length-1-i];
				res[res.length-1-i] = tmp;
			}
			return res;
		}

		public bool key_press (G subject, Key pressed) {
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
					deleg (subject, old_key.command);
					if (old_key != key_root) {
						// this might be a new command, retry from root
						handled = key_press (subject, pressed);
					}
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
							deleg (subject, command);
							return false;
						});
				}
			} else {
				unowned string command = current_key.command;
				current_key = key_root;
				deleg (subject, command);
			}
			return true;
		}
	}
}