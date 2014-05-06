NULL =

AM_CPPFLAGS = \
	-I$(top_srcdir) \
	$(LIBVANUBI_CFLAGS) \
	-DDATADIR=\""$(datadir)"\" \
	$(NULL)

BUILT_SOURCES = .libvanubi.vala.stamp

lib_LTLIBRARIES = libvanubi@PACKAGE_SUFFIX@.la

libvanubi_la_VALASOURCES = \
	buffer.vala 		\
	charset.vala 		\
	chunked.vala		\
	config.vala 		\
	comment.vala 		\
	completion.vala		\
	filecluster.vala 	\
	files.vala			\
	git.vala			\
	history.vala		\
	indent.vala			\
	keys.vala 			\
	search.vala 		\
	source.vala			\
	lru.vala	 		\
	marks.vala			\
	matching.vala 		\
	sources/localfile.vala	\
	sources/remotefile.vala	\
	sources/scratch.vala	\
	sources/stream.vala		\
	state/state.vala	\
	state/status.vala	\
	state/theme.vala	\
	streams.vala		\
	util.vala			\
	vade/ast.vala		\
	vade/eval.vala		\
	vade/lexer.vala		\
	vade/parser.vala	\
	vade/runtime.vala	\
	vade/scope.vala		\
	$(NULL)

libvanubi@PACKAGE_SUFFIX@_la_SOURCES = \
	.libvanubi.vala.stamp \
	$(libvanubi_la_VALASOURCES:.vala=.c) \
	gspawn/vanubi_gspawn.c	\
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
