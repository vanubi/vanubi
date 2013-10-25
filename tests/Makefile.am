include $(top_srcdir)/build-aux/glib-tap.mk

AM_CFLAGS = -g $(LIBVANUBI_CFLAGS)
LDADD = $(VANUBI_LIBS) $(top_builddir)/libvanubi/libvanubi@PACKAGE_SUFFIX@.la
AM_CPPFLAGS = \
	-DG_LOG_DOMAIN=\"Vanubi\" \
	-I$(top_srcdir)	\
	-I$(top_srcdir)/libvanubi \
	$(NULL)
AM_VALAFLAGS = \
	--pkg vanubi \
	--vapidir $(top_srcdir)/libvanubi \
	$(NULL)

test_programs = \
	match			\
	$(NULL)

match_SOURCES = match.vala
