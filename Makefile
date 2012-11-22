VALAC=valac
CC=cc
PKGCONFIG=pkg-config
PKGS=vte-2.90 gtk+-3.0 gtksourceview-3.0
SRCS=vanubi.vala matching.vala filecompletion.vala shell.vala

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
	$(CC) `pkg-config $(PKGS) --libs` $(LDFLAGS) -fPIC -o $@ $+

clean:
	rm -f $(OBJS)
	rm -f $(COBJS)
	rm -f vanubi
	rm -f .valastamp

run: vanubi
	./vanubi
