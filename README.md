Vanubi Programming Editor
==========================

"All editors suck. This one just sucks less." -mutt, circa 1995

Ideas
-----
 - Simple, complete, keyboard based, intelligent, unobtrusive, well integrated
 - Implement what you really use, not what you don't use
 - Implement what you expect, not what other editors do
 - Implement what you really need, not what you think you need
 - Monolithic, no plugins, things must just work and be consistent
 - Must be complete, yet fast to open a single file for editing
 - File/directory-based settings, not project-based
 - Intelligent defaults based on the current opened file context
 - Easy to use contextual help... we can't remember all the keybindings
 - Semantic support for languages similar to eclipse but much less invasive, and faster
 - Integrate with libinfinity for real-time collaborative editing

Key Bindings
-------------

| Combo | Action |
| ------------- |-------------|
|C-x C-c|          Quit vanubi  
|C-g     |         Abort  
|ESC      |        Abort  
|C-x C-f   |       Open file  
|C-x C-s    |      Save file  
|C-x b       |     Switch buffer  
|C-x k        |    Kill buffer  
|C-x 1         |   Join all the splits  
|C-x C-1|          Join the current split only  
|C-x 2   |         Split vertically (one editor up, one down)  
|C-x 3    |        split horizontally (one editor left, one right)  
|TAB       |       Indent current line  
|F9         |      Run compile command  
|C-c C-c     |     Comment a region [not implemented yet!]  
|C-x C-x      |    Exec shell command [not implemented yet!]  
|C-n           |   Go to next line  
|C-p            |  Go to previous line  
|C-k    |          Kill line  
|C-e     |         Go to the end of line  
|C-a      |        Go to the head of line  
|C-space   |       Select all text  
|C-l        |      Iterate the editors on the right  
|C-j         |     Iterate the editors on the left  
|C-s          |    Search forward  
|C-r           |   Search backward  
|Alt+down       |  Swap current row with the row below  
|Alt+up          | Swap current row with the row above    
|C-h|			   Search commands and configure the editor
  
Mouse Bindings
----------------

| Combo | Action |
| ----- | ------ |
|C-scroll  |       Increase/decrease the font size

TODO
----
 - Improve indentation support for vala and c
 - Improve opening and saving file
 - Try the gtksourceview search API
 - Make caret bg/fg color configurable for different styles
 - Mimic emacs minibar for matching files and buffers
 - Code fold / Comment fold
 - Support GDB, Hexdump, GPG, Patch/Diff, Git, Git-bz, Pastebin
