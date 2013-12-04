NULL =

AM_CPPFLAGS = \
	-I$(top_srcdir) \
	-I$(top_srcdir)/libvanubi \
	$(VANUBI_CFLAGS) \
	$(NULL)

BUILT_SOURCES = .vanubi.vala.stamp

bin_PROGRAMS = \
	vanubi \
	$(NULL)

vanubi_VALASOURCES = \
	bar.vala \
	completionbar.vala \
	editor.vala \
	filebar.vala \
	grepbar.vala \
	helpbar.vala \
	indent.vala \
	main.vala \
	searchbar.vala \
	shellbar.vala \
	$(NULL)

vanubi_SOURCES = \
	.vanubi.vala.stamp \
	$(vanubi_VALASOURCES:.vala=.c) \
	$(NULL)

.vanubi.vala.stamp: $(vanubi_VALASOURCES)
	$(VALA_V)$(VALAC) $(VANUBI_VALAFLAGS) -C --pkg vanubi --vapidir $(top_srcdir)/libvanubi $^
	@touch $@

vanubi_LDADD = \
	../libvanubi/libvanubi@PACKAGE_SUFFIX@.la \
	$(VANUBI_LIBS) \
	$(NULL)

EXTRA_DIST = $(vanubi_VALASOURCES)

MAINTAINERCLEANFILES = \
	$(vanubi_VALASOURCES:.vala=.c) \
	$(NULL)

VALA_V = $(VALA_V_$(V))
VALA_V_ = $(VALA_V_$(AM_DEFAULT_VERBOSITY))
VALA_V_0 = @echo "  VALAC " $^;
