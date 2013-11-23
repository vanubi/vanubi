NULL =

AM_CPPFLAGS = \
	-I$(top_srcdir) \
	$(LIBVANUBI_CFLAGS) \
	$(NULL)

BUILT_SOURCES = .libvanubi.vala.stamp

lib_LTLIBRARIES = libvanubi@PACKAGE_SUFFIX@.la

libvanubi_la_VALASOURCES = \
	config.vala \
	files.vala	\
	indent.vala	\
	matching.vala 	\
	search.vala 	\
	$(NULL)

libvanubi@PACKAGE_SUFFIX@_la_SOURCES = \
	.libvanubi.vala.stamp \
	$(libvanubi_la_VALASOURCES:.vala=.c) \
	$(NULL)

.libvanubi.vala.stamp: $(libvanubi_la_VALASOURCES)
	$(VALA_V)$(VALAC) $(LIBVANUBI_VALAFLAGS) -C -H vanubi.h --library vanubi $^
	@touch $@

libvanubi@PACKAGE_SUFFIX@_la_LIBADD = \
	$(LIBVANUBI_LIBS) \
	$(NULL)

EXTRA_DIST = $(libvanubi_la_VALASOURCES)

MAINTAINERCLEANFILES = \
	$(libvanubi_la_VALASOURCES:.vala=.c) \
	$(NULL)

VALA_V = $(VALA_V_$(V))
VALA_V_ = $(VALA_V_$(AM_DEFAULT_VERBOSITY))
VALA_V_0 = @echo "  VALAC " $^;
