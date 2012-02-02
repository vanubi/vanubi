VALAC=valac

all: vanubi

vanubi: vanubi.vala matching.vala filecompletion.vala
	$(VALAC) -g --save-temps --pkg gtk+-3.0 --pkg gtksourceview-3.0 -o vanubi vanubi.vala matching.vala filecompletion.vala

run: vanubi
	./vanubi
