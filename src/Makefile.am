NULL =

AM_CPPFLAGS = \
	-I$(top_srcdir) \
	$(VANUBI_CFLAGS) \
	$(NULL)

BUILT_SOURCES = vanubi.vala.stamp

bin_PROGRAMS = \
	vanubi \
	$(NULL)

vanubi_VALASOURCES = \
	bar.vala \
	editor.vala \
	filecompletion.vala \
	matching.vala \
	search.vala \
	shell.vala \
	vanubi.vala \
	$(NULL)

vanubi_SOURCES = \
	vanubi.vala.stamp \
	$(vanubi_VALASOURCES:.vala=.c) \
	$(NULL)

vanubi.vala.stamp: $(vanubi_VALASOURCES)
	$(VALA_V)$(VALAC) $(VANUBI_VALAFLAGS) -C $^
	@touch $@

vanubi_LDADD = \
	$(VANUBI_LIBS) \
	$(NULL)

EXTRA_DIST = $(vanubi_VALASOURCES) vanubi.vala.stamp

MAINTAINERCLEANFILES = \
	$(vanubi_VALASOURCES:.vala=.c) \
	$(NULL)

VALA_V = $(VALA_V_$(V))
VALA_V_ = $(VALA_V_$(AM_DEFAULT_VERBOSITY))
VALA_V_0 = @echo "  VALAC " $^;
