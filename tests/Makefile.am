include $(top_srcdir)/build-aux/glib-tap.mk

AM_CFLAGS = -g $(VANUBI_CFLAGS)
LDADD = $(VANUBI_LIBS)  # $(top_builddir)/libvanubi/libvanubi-0.1.la
AM_CPPFLAGS = \
	-DG_LOG_DOMAIN=\"Vanubi\" \
	-I$(top_srcdir)	\
	-I$(top_srcdir)/libvanubi \
	$(NULL)

test_programs = \
	dummy			\
	$(NULL)

dummy_SOURCES = dummy.vala
