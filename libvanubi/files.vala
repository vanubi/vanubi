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
	void file_complete_pattern (FileSource source, int index, string[] pattern, GenericArray<FileSource> result, Cancellable? cancellable = null) throws Error {
		FileSource child = (FileSource) source.child (pattern[index]);
		debug("Source %s, child %s?", source.to_string(), child.to_string());

		if (index < pattern.length-1 && child.is_directory_sync ()) {
			// perfect directory match
			debug("Perfect directory match for child %s", child.to_string());

			file_complete_pattern (child, index+1, pattern, result, cancellable);
			return;
		}

		debug("Child %s not a directory, look for matches", child.to_string());

		FileSource[]? matches = null;
		try {
			var iterator = source.iterate_children (cancellable);
			Annotated<FileSource>[]? a = null;
			while (true) {
				var info = iterator.next (cancellable);
				if (info == null) {
					break;
				}
				var file = (FileSource) info.source;
				a += new Annotated<FileSource> (file.basename, file);
			}
			cancellable.set_error_if_cancelled ();
			if (pattern[index] == "") {
				// keep file order
				foreach (var an in a) {
					matches += an.obj;
				}
			} else {
				// pattern match
				var res = pattern_match_many<FileSource> (pattern[index], a, true, cancellable);
				foreach (var an in res.data) {
					matches += an.obj;
				}
			}
		} catch (IOError.CANCELLED e) {
			throw e;
		} catch (Error e) {
			// ignore errors due to file permissions
		}

		if (index >= pattern.length-1) {
			foreach (var match in matches) {
				result.add (match);
			}
			return;
		}

		// recurse into next subdirectory
		while (index < pattern.length-1 && pattern[++index] == null);
		foreach (var match in matches) {
			file_complete_pattern (match, index, pattern, result, cancellable);
			cancellable.set_error_if_cancelled ();
		}
	}

	public string absolute_path (string base_directory, string path) {
		string res;
		if (!base_directory.has_suffix ("/")) {
			res = base_directory+"/"+path;
		} else {
			res = base_directory+path;
		}

		int abs = res.last_index_of ("//");
		int home = res.last_index_of ("/~/");
		if (abs > home) {
			res = res.substring (abs+1);
		} else if (home > abs) {
			res = Environment.get_home_dir()+res.substring (home+2);
		}

		res = File.new_for_path (res).get_path ();
		if (path[path.length-1] == '/' || path[0] == '\0') {
			res += "/";
		}
		return res;
	}

	struct ShortComp {
		string comp;
		int clashes;
		DataSource source;
	}
	
	void short_path_helper (Node<ShortComp?> node, GenericArray<Annotated<DataSource>> res) {
		unowned ShortComp? shortcomp = node.data;
		if (shortcomp != null && shortcomp.clashes == 0) {
			// build path up to root
			var path = "";
			unowned Node<ShortComp?> cur = node;
			while (cur != null && cur.data != null) {
				unowned ShortComp? curshortcomp = cur.data;
				path += curshortcomp.comp+"/";
				cur = cur.parent;
			}
			path.data[path.length-1] = '\0'; // remove trailing slash
			res.add (new Annotated<DataSource> (path, shortcomp.source));
			return;
		}

		unowned Node<ShortComp?> child = node.children;
		while (child != null) {
			short_path_helper (child, res);
			child = child.next;
		}
	}
	
	public Annotated<DataSource>[] short_paths (DataSource[] sources) {
		// create a trie of file components
		var root = new Node<ShortComp?> ();
		foreach (unowned DataSource source in sources) {
			unowned Node<ShortComp?> cur = root;
			var path = source.to_string ();
			var comps = path.split("/");
			for (int i=comps.length-1; i >= 0; i--) {
				unowned string comp = comps[i];
				if (comp[0] == '\0') {
					continue;
				}
				unowned Node<ShortComp?> child = cur.children;
				while (child != null) {
					unowned ShortComp? shortcomp = child.data;
					if (shortcomp.comp == comp) {
						shortcomp.clashes++;
						cur = child;
						break;
					}
					child = child.next;
				}
				if (child == null) {
					ShortComp? shortcomp = ShortComp ();
					shortcomp.comp = comp;
					shortcomp.clashes = 0;
					shortcomp.source = source;
					var newchild = new Node<ShortComp?> ((owned) shortcomp);
					unowned Node<ShortComp?> refchild = newchild;
					cur.append ((owned) newchild);
					cur = refchild;
				}
			}
		}
		
		var work = new GenericArray<Annotated<DataSource>> ();
		// depth first search
		short_path_helper (root, work);
		var res = (owned) work.data;
		work.data.length = 0; // vala bug
		return res;
	}
	
	/* The given pattern must be absolute */
	public GenericArray<FileSource>? file_complete (FileSource root, string pattern, Cancellable? cancellable = null) throws Error requires (pattern[0] == '/') {
		string[] comps = pattern.split ("/");
		if (comps.length == 0) {
			return null;
		}

		var result = new GenericArray<FileSource> ();
		file_complete_pattern (root, 1, comps, result, cancellable);
		return result;
	}
}
