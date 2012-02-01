VALAC=valac

all: vanubi

vanubi: vanubi.vala
	$(VALAC) -g --save-temps --pkg gtk+-3.0 --pkg gtksourceview-3.0 vanubi.vala -o vanubi

run: vanubi
	./vanubi
