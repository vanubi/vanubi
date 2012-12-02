VALAC=valac
CC=cc
PKGCONFIG=pkg-config
PKGS=vte-2.90 gtk+-3.0 gtksourceview-3.0 glib-2.0 gobject-2.0
SRCS=vanubi.vala bar.vala editor.vala matching.vala filecompletion.vala shell.vala

COBJS=$(patsubst %.vala,%.c,$(SRCS))
OBJS=$(patsubst %.c,%.o,$(COBJS))
VALAPKGS=$(patsubst %,--pkg %,$(PKGS))

all: vanubi

.valastamp: $(SRCS)
	$(VALAC) -C -g $(VALAPKGS) $+
	touch .valastamp

$(COBJS): .valastamp ;

%.o: %.c
	$(CC) `pkg-config $(PKGS) --cflags` $(CFLAGS) -ggdb -fPIC -c -o $@ $<

vanubi: $(OBJS)
	$(CC)  -fPIC -o $@ $+ `pkg-config $(PKGS) --libs` $(LDFLAGS)

clean:
	rm -f $(OBJS)
	rm -f $(COBJS)
	rm -f vanubi
	rm -f .valastamp
	rm -f *~

run: vanubi
	./vanubi
