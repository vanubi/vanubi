using Gtk;

TextTag in_string_tag = null;

bool is_in_string (TextIter iter) {
	var tags = iter.get_tags ();
	return tags == null || tags.data.foreground_gdk.equal (in_string_tag.foreground_gdk);
}

public string lcs (string x, string y, out int len) {
	int m = x.length;
	int n = y.length;
	int[,] c = new int[m+1,n+1];
	for (int i=0; i < m; i++) {
		for (int j=0; j < n; j++) {
			if (x[i] == y[j]) {
				c[i+1,j+1] = c[i,j]+1;
			} else {
				c[i+1,j+1] = int.max (c[i+1,j], c[i,j+1]);
			}
		}
	}
	len = c[m,n];

	StringBuilder b = new StringBuilder ();
	int i=m-1, j=n-1;
	while (i >= 0 && j >= 0) {
		if (x[i] == y[j]) {
			b.prepend_c (x[i]);
			i--; j--;
		} else if (c[i+1, j] > c[i, j+1]) {
			j--;
		} else {
			i--;
		}
	}
	return (owned) b.str;
}

int match_pattern (string pattern, string haystack) {
	int rank = 0;
	int n = pattern.length;
	int m = haystack.length;
	int j = 0;
	for (int i=0; i < n; i++) {
		char c = pattern[i];
		bool found = false;
		for (; j < m; j++) {
			if (c == haystack[j]) {
				found = true;
				break;
			}
			rank++;
		}
		if (!found) {
			// no match
			return -1;
		}
		j++;
	}
	rank += m-j;
	return rank;
}

class EntryOverlay : Grid {
	Entry entry;

	public new signal void activate (string s);

	public EntryOverlay (string initial, bool file) {
		orientation = Orientation.VERTICAL;
		expand = false;
		halign = Align.FILL;
		valign = Align.END;

		if (file) {
			entry = new FileEntry ();
		} else {
			entry = new Gtk.Entry ();
		}
		entry.set_activates_default (true);
		entry.set_text (initial);
		entry.expand = true;
		entry.activate.connect (() => { activate (entry.get_text ()); });
		ulong conn = 0;
		conn = entry.show.connect (() => {
				entry.grab_focus ();
				entry.disconnect (conn);
			});
		add (entry);
	}
}

class MatchWorker {
	AsyncQueue<string?> queue = new AsyncQueue<string?> ();
	SourceFunc resume;
	string[] matches;
	int[] match_values;
	string pattern; // should be volatile
	Cancellable cancellable;

	public MatchWorker (Cancellable cancellable) {
		this.cancellable = cancellable;
		matches = new string[0];
		match_values = new int[0];
		IOSchedulerJob.push (work, Priority.DEFAULT, cancellable);
	}

	public void set_pattern (string pattern) {
		this.pattern = pattern;
	}

	public void terminate () {
		string* foo = (string*)0x1beef;
		queue.push ((owned)foo);
	}

	static int compare_func (int* a, int* b) {
		return (*a & 0xFFFF) - (*b & 0xFFFF);
	}

	public async string[] get_result () throws Error {
		this.resume = get_result.callback;
		string* foo = (string*)0x0dead;
		queue.push ((owned)foo);
		yield;
		cancellable.set_error_if_cancelled ();

		qsort_with_data<int> (match_values, sizeof (int), (CompareDataFunc<int>) compare_func);
		var result = new string[matches.length];
		for (int i=0; i < matches.length; i++) {
			var pos = (match_values[i] >> 16) & 0xFFFF;
			result[i] = (owned) matches[pos];
		}
		matches.length = 0;
		match_values.length = 0;
		return result;
	}

	public void enqueue (string s) {
		queue.push (s);
	}

	bool work (IOSchedulerJob job, Cancellable? cancellable) {
		while (true) {
			string* item = queue.pop ();
			if ((int)(long)item == 0x0dead) {
				// partial result
				job.send_to_mainloop_async ((owned) resume);
				continue;
			} else if ((int)(long)item == 0x1beef) {
				// job complete
				break;
			}
			if (cancellable.is_cancelled ()) {
				job.send_to_mainloop_async ((owned) resume);
				break;
			}
			string haystack = (owned) item;
			int match = match_pattern (pattern, haystack);
			if (match >= 0) {
				match_values += match | (matches.length << 16);
				matches += (owned) haystack;
			}
		}
		return false;
	}
}

async string[] file_complete_pattern (MatchWorker worker, File file, int index, string[] pattern, Cancellable cancellable) throws Error {
	File child = file.get_child (pattern[index]);
	if (index < pattern.length-1 && child.query_exists ()) {
		// perfect directory match
		return yield file_complete_pattern (worker, child, index+1, pattern, cancellable);
	}

	try {
		var enumerator = yield file.enumerate_children_async (FileAttribute.STANDARD_NAME+","+FileAttribute.STANDARD_TYPE, FileQueryInfoFlags.NONE, Priority.DEFAULT, cancellable);
		cancellable.set_error_if_cancelled ();
		worker.set_pattern (pattern[index]);
		while (true) {
			var infos = yield enumerator.next_files_async (1000, Priority.DEFAULT, cancellable);
			cancellable.set_error_if_cancelled ();

			foreach (var info in infos) {
				if (info.get_file_type () == FileType.DIRECTORY) {
					worker.enqueue (info.get_name ()+"/");
				} else {
					worker.enqueue (info.get_name ());
				}
			}
			if (infos.length () < 1000) {
				break;
			}
		}
	} catch (Error e) {
	}

	string[] matches = yield worker.get_result ();
	cancellable.set_error_if_cancelled ();
	if (index >= pattern.length-1) {
		return matches;
	}
	string[] result = new string[0];
	// compute next index
	while (index < pattern.length-1 && pattern[++index] == null);
	foreach (unowned string match in matches) {
		bool is_directory = match[match.length-1] == '/';
		if (!is_directory) {
			result += match;
			continue;
		}
		match.data[match.length-1] = '\0';
		File cfile = file.get_child (match);
		string[] children = yield file_complete_pattern (worker, cfile, index, pattern, cancellable);
		cancellable.set_error_if_cancelled ();
		if (children.length > 0) {
			foreach (unowned string cmatch in children) {
				result += match+"/"+cmatch;
			}
		}
	}
	return result;
}

async string[] file_complete (owned string path, Cancellable cancellable) throws Error {
	path = File.new_for_path(".").get_path ()+"/"+path;
	int abs = path.last_index_of ("//");
	int home = path.last_index_of ("~/");
	if (abs > home) {
		path = path.substring (abs+1);
	} else if (home > abs) {
		path = Path.build_filename (Environment.get_home_dir (), path.substring (home+1));
	}
	string[] comps = path.split ("/");
	comps[0] = null; // empty group before the first separator

	// resolve ../ beforehand
	for (int i=1; i < comps.length; i++) {
		if (comps[i][0] == '.' && comps[i][1] == '.' && comps[i][2] == 0) {
			comps[i] = null;
			for (int j=i-1; j >= 0; j--) {
				if (comps[j] != null) {
					comps[j] = null;
					break;
				}
			}
		}
	}
	// remove trailing nulls
	while (comps.length > 0 && comps[comps.length-1] == null) {
		comps.length--;
	}
	if (comps.length == 0) {
		// TODO: root
		return new string[0];
	}
	int index = 0;
	while (comps[index] == null) {
		index++;
	}

	var worker = new MatchWorker (cancellable);
	File file = File.new_for_path ("/");
	string[] result = yield file_complete_pattern (worker, file, index, comps, cancellable);
	worker.terminate ();
	cancellable.set_error_if_cancelled ();
	return result;
}

class ChoiceBox : Grid {
	string[] choices;
	int index = 0;

	public ChoiceBox (string[] choices) {
		orientation = Orientation.HORIZONTAL;
		column_spacing = 10;
		this.choices = choices;
		for (int i=0; i < 5 && i < choices.length; i++) {
			if (i > 0) {
				add (new Separator (Orientation.VERTICAL));
			}
			var l = new Label (choices[i]);
			l.ellipsize = Pango.EllipsizeMode.MIDDLE;
			add (l);
		}
		show_all ();
	}

	public void next () {
		if (index < choices.length-1) {
			remove (get_child_at (index*2, 0));
			remove (get_child_at (index*2+1, 0));
			index++;
			if (index+4 < choices.length) {
				add (new Separator (Orientation.VERTICAL));
				var l = new Label (choices[index+4]);
				l.ellipsize = Pango.EllipsizeMode.MIDDLE;
				add (l);
				show_all ();
			}
		}
	}

	public void back () {
		if (index > 0) {
			var c1 = get_child_at ((index+4)*2, 0);
			var c2 = get_child_at ((index+4)*2-1, 0);
			if (c1 != null) {
				remove (c1);
			}
			if (c2 != null) {
				remove (c2);
			}
			index--;
			attach (new Separator (Orientation.VERTICAL), index*2+1, 0, 1, 1);
			var l = new Label (choices[index]);
			l.ellipsize = Pango.EllipsizeMode.MIDDLE;
			attach (l, index*2, 0, 1, 1);
			show_all ();
		}
	}

	public unowned string get_choice () {
		return ((Label) get_child_at (index*2, 0)).get_label ();
	}

	public unowned string[] get_choices () {
		return choices;
	}
}

class FileEntry : Entry {
	ChoiceBox choices_box;
	Cancellable current_completion;
	string original_pattern;
	int64 last_tab_time = 0;
	bool navigated = false;

	public FileEntry () {
		changed.connect (complete);
		complete ();
	}

	void complete () {
		original_pattern = get_text ();
		navigated = false;
		if (current_completion != null) {
			current_completion.cancel ();
		}
		var cancellable = current_completion = new Cancellable ();
		file_complete (original_pattern, cancellable, (s,r) => {
				try {
					cancellable.set_error_if_cancelled ();
					var result = file_complete.end (r);
					cancellable = null;
					if (choices_box != null) {
						choices_box.destroy ();
					}
					choices_box = new ChoiceBox (result);
					var grid = (Grid) get_parent ();
					grid.attach_next_to (choices_box, this, PositionType.TOP, 1, 1);
				} catch (Error e) {
					message (e.message);
				}
			});
	}

	int count (string haystack, unichar c) {
		int cnt = 0;
		int idx = 0;
		while (true) {
			idx = haystack.index_of_char (c, idx);
			if (idx < 0) {
				break;
			}
			cnt++;
			idx++;
		}
		return cnt;
	}

	string get_relative_pattern (string choice) {
		int choice_seps = count (choice, '/');
		int pattern_seps = count (original_pattern, '/');
		if (choice[choice.length-1] == '/' && original_pattern[original_pattern.length-1] != '/') {
			// automatically added to determine a directory
			choice_seps--;
		}
		int keep_seps = pattern_seps - choice_seps;

		int idx = 0;
		for (int i=0; i < keep_seps; i++) {
			idx = original_pattern.index_of_char ('/', idx);
			idx++;
		}
		return original_pattern.substring (0, idx)+choice;
	}

	void set_choice () {
		unowned string choice = choices_box.get_choice ();
		set_text (get_relative_pattern (choice));
		move_cursor (MovementStep.BUFFER_ENDS, 1, false);
	}

	public override bool key_press_event (Gdk.EventKey e) {
		if (e.keyval == Gdk.Key.Escape || (e.keyval == Gdk.Key.g && Gdk.ModifierType.CONTROL_MASK in e.state)) {
			Idle.add (() => { get_parent().destroy (); return false; });
			return true;
		} else if (e.keyval == Gdk.Key.Up) {
			choices_box.back ();
			navigated = true;
			return true;
		} else if (e.keyval == Gdk.Key.Down) {
			choices_box.next ();
			navigated = true;
			return true;
		} else if (e.keyval == Gdk.Key.Tab) {
			if (choices_box.get_choices().length > 0) {
				if (navigated || choices_box.get_choices().length == 1) {
					set_choice ();
				} else {
					int64 time = get_monotonic_time ();
					if (time - last_tab_time < 300000) {
						set_choice ();
					}
					last_tab_time = time;
				}
			}
			return true;
		}
		return base.key_press_event (e);
	}
}

class ProgressOverlay : Spinner {
	public ProgressOverlay () {
		set_size_request (20, 20);
	}
}

class Editor : SourceView {
	public Grid grid;
	public ProgressOverlay progress;
	public weak EntryOverlay overlay;

	void unset_overlay () {
		if (this.overlay != null) {
			this.overlay.destroy ();
		}
	}

	void set_progress_overlay () {
		if (progress != null) {
			return;
		}
		progress = new ProgressOverlay ();
		grid.add (progress);
		progress.show_all ();
	}

	void unset_progress_overlay () {
		if (progress != null) {
			progress.destroy ();
		}
	}

	void set_overlay (EntryOverlay overlay) {
		unset_overlay ();
		this.overlay = overlay;
		overlay.destroy.connect (overlay_destroyed);
		grid.add (overlay);
		overlay.show_all ();
	}

	void overlay_destroyed () {
		overlay = null;
		grab_focus ();
	}

	void set_line_indentation (int line, int indent) {
		indent = int.max (indent, 0);

		TextIter start;
		var buf = buffer;
		buf.get_iter_at_line (out start, line);

		var iter = start;
		while (iter.get_char().isspace() && !iter.ends_line () && !iter.is_end ()) {
			iter.forward_char ();
		}

		buf.delete (ref start, ref iter);
		var tab_width = this.tab_width;
		buf.insert (ref start, string.nfill(indent/tab_width, '\t')+string.nfill(indent-(indent/tab_width)*tab_width, ' '), -1);

		// reset cursor, textbuffer bug?
		buf.get_iter_at_mark (out iter, buf.get_insert ());
		buf.place_cursor (iter);
	}

	int get_line_indentation (int line) {
		uint tab_width = this.tab_width;
		uint indent = 0;

		TextIter iter;
		var buf = buffer;
		buf.get_iter_at_line (out iter, line);

		while (iter.get_char().isspace () && !iter.ends_line () && !iter.is_end ()) {
			if (iter.get_char() == '\t') {
				indent += tab_width;
			} else {
				indent++;
			}
			iter.forward_char ();
		}
		return (int)indent;
	}

	void open_file (string name) {
		set_progress_overlay ();
		var file = File.new_for_path (name);
		file.load_contents_async (null, (s,r) => {
				uint8[] content;
				try {
					file.load_contents_async.end (r, out content, null);
					var buf = (SourceBuffer) buffer;
					buf.begin_not_undoable_action ();
					buf.set_text ((string) content, -1);
					buf.end_not_undoable_action ();
					grab_focus ();
					TextIter start;
					buf.get_start_iter (out start);
					buf.place_cursor (start);
					current_filename = file.get_path ();
				} catch (Error e) {
					message (e.message);
				} finally {
					unset_progress_overlay ();
				}
			});
	}

	uint ctrl_x_source = 0;
	string current_filename = null;

	void do_cut () {
		unowned Clipboard c = Clipboard.get (Gdk.SELECTION_CLIPBOARD);
		buffer.cut_clipboard (c, true);
	}

	public override bool key_press_event (Gdk.EventKey e) {
		var buf = this.buffer;
		bool ctrl_x_pressed = ctrl_x_source != 0;
		if (ctrl_x_pressed) {
			Source.remove (ctrl_x_source);
			ctrl_x_source = 0;
		}

		if (ctrl_x_pressed) {
			if (Gdk.ModifierType.CONTROL_MASK in e.state) {
				if (e.keyval == Gdk.Key.f) {
					// OPEN FILE
					var file = new EntryOverlay ("", true);
					file.activate.connect ((s) => {
							file.destroy ();
							open_file (s);
						});
					set_overlay (file);
					return true;
				} else if (e.keyval == Gdk.Key.s) {
					// SAVE FILE
					if (current_filename != null) {
						var f = File.new_for_path (current_filename);
						TextIter start, end;
						buffer.get_start_iter (out start);
						buffer.get_end_iter (out end);
						string text = buffer.get_text (start, end, false);
						f.replace_contents_async.begin (text.data, null, true, FileCreateFlags.NONE, null, (s,r) => {
								f.replace_contents_async.end (r, null);
								text = null;
							});
					}
				} else if (e.keyval == Gdk.Key.c) {
					// QUIT
					Gtk.main_quit ();
				}
			} else {
				do_cut ();
			}
		} else if (e.keyval == Gdk.Key.x && Gdk.ModifierType.CONTROL_MASK in e.state) {
			ctrl_x_source = Timeout.add (300, () => { do_cut (); return false; });
			return true;
		}

		if (e.keyval == Gdk.Key.Tab) {
			// TAB
			TextIter insert_iter;
			buf.get_iter_at_mark (out insert_iter, buf.get_insert ());
			int line = insert_iter.get_line ();
			if (line == 0) {
				set_line_indentation (line, 0);
			} else {
				// first non-blank prev line
				int prev_line = line-1;
				while (prev_line >= 0) {
					TextIter line_start;
					buf.get_iter_at_line (out line_start, prev_line);
					TextIter line_end = line_start;
					line_end.forward_to_line_end ();
					if (line_start.get_line () != line_end.get_line ()) {
						// empty line
						prev_line--;
						continue;
					}
					string text = buf.get_text (line_start, line_end, false);
					if (text.strip()[0] == '\0') {
						prev_line--;
					} else {
						break;
					}
				}

				if (prev_line < 0) {
					set_line_indentation (line, 0);
				} else {
					int new_indent = get_line_indentation (prev_line);
					var tab_width = (int)this.tab_width;

					// opened/closed braces
					TextIter iter;
					buf.get_iter_at_line (out iter, prev_line);
					bool first_nonspace = true;
					while (!iter.ends_line () && !iter.is_end ()) {
						var c = iter.get_char ();
						if (c == '{' && !is_in_string (iter)) {
							new_indent += tab_width;
						} else if (c == '}' && !first_nonspace && !is_in_string (iter)) {
							new_indent -= tab_width;
						}
						iter.forward_char ();
						if (!c.isspace ()) {
							first_nonspace = false;
						}
					}

					// unindent
					buf.get_iter_at_line (out iter, line);
					while (!iter.ends_line () && !iter.is_end ()) {
						unichar c = iter.get_char ();
						if (!c.isspace ()) {
							if (c == '}' && !is_in_string (iter)) {
								new_indent -= tab_width;
							}
							break;
						}
						iter.forward_char ();
					}

					set_line_indentation (line, new_indent);
				}
			}
			return true;
		}
		return base.key_press_event (e);
	}
}

int main (string[] args) {
	Gtk.init (ref args);

	var win = new Window ();
	win.delete_event.connect (() => { Gtk.main_quit (); return false; });
	win.set_default_size (800, 600);

	var vala = SourceLanguageManager.get_default().get_language ("vala");
	var buf = new SourceBuffer.with_language (vala);
	var ed = new Editor ();
	ed.buffer = buf;

	// HACK: sourceview doesn't set the style in the tags :-(
	// BRACE IN STRING
	buf.set_text ("\"foo\"", -1);
	TextIter start, end;
	buf.get_start_iter (out start);
	buf.get_end_iter (out end);
	buf.ensure_highlight (start, end);
	start.forward_char ();
	var tags = start.get_tags ();
	if (tags != null) {
		in_string_tag = tags.data;
	}

	buf.set_text ("void foo () {\n\tfoo ();\n}\n", -1);

	var s = new ScrolledWindow (null, null);
	s.expand = true;
	s.add (ed);
	var grid = new Grid ();
	grid.orientation = Orientation.VERTICAL;
	grid.add (s);
	ed.grid = grid;
	win.add (grid);

	win.show_all ();
	ed.grab_focus ();

	Gtk.main ();

	return 0;
}
