VALAC=valac

all: vanubi

vanubi: vanubi.vala matching.vala filecompletion.vala shell.vala
	$(VALAC) -g --save-temps --pkg vte-2.90 --pkg gtk+-3.0 --pkg gtksourceview-3.0 -o vanubi vanubi.vala matching.vala filecompletion.vala shell.vala

run: vanubi
	./vanubi
