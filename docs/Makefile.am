if HAVE_ASCIIDOC

all: manual.html manual-stripped.html

manual.html: manual.asciidoc manual.conf
	$(ASCIIDOC) -f manual.conf -b html5 -o manual.html manual.asciidoc

manual-stripped.html: manual.asciidoc manual.conf
	$(ASCIIDOC) -s -f manual.conf -b html5 -o manual-stripped.html manual.asciidoc

CLEANFILES = manual.html manual-stripped.html

else

all:

endif