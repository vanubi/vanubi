using Vanubi;

void test_marks () {
	var loc1 = new Location<void*> (null);
	var loc2 = new Location<void*> (null);
	var loc3 = new Location<void*> (null);
	var loc4 = new Location<void*> (null);
	
	var marks = new MarkManager ();
	assert (marks.prev_mark () == null);
	assert (marks.next_mark () == null);
	
	// single element must always be available
	marks.mark (loc1);
	assert (marks.next_mark () == loc1);
	assert (marks.prev_mark () == loc1);
	assert (marks.prev_mark () == loc1);
	assert (marks.next_mark () == loc1);
	
	marks.mark (loc2);
	assert (marks.next_mark () == null);
	assert (marks.prev_mark () == loc2);
	assert (marks.prev_mark () == loc1);
	assert (marks.next_mark () == loc2);
	
	marks.mark (loc3);
	assert (marks.next_mark () == null);
	assert (marks.prev_mark () == loc3);
	assert (marks.prev_mark () == loc2);
	
	marks.mark (loc4);
	assert (marks.prev_mark () == loc4);
	assert (marks.next_mark () == loc3);
	assert (marks.prev_mark () == loc4);
	assert (marks.prev_mark () == loc2);
}

int main (string[] args) {
	Test.init (ref args);

	Test.add_func ("/marks", test_marks);

	return Test.run ();
}