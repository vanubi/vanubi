desktopdir = $(datadir)/applications
desktop_DATA = vanubi.desktop

cssdir = $(datadir)/vanubi/css
css_DATA = css/zen.css css/tango.css

logodir = $(datadir)/vanubi/logo
logo_DATA = vanubi.png

langdir = $(datadir)/vanubi/languages
lang_DATA = \
			languages/asm-intel.lang \
			languages/i386asm.lang \
			languages/asciidoc.lang \
			languages/generic_comment.lang \
			languages/nix.lang \
			languages/rpmspec.lang \
			languages/dts.lang

styledir = $(datadir)/vanubi/styles
style_DATA = styles/zen.xml styles/zen-grep.xml styles/tango.xml

EXTRA_DIST = vanubi.desktop.in vanubi.css vanubi.png languages/asm-intel.lang \
             languages/i386asm.lang languages/asciidoc.lang languages/generic_comment.lang styles/zen.xml

CLEANFILES = $(desktop_DATA)
DISTCLEANFILES = $(desktop_DATA)
