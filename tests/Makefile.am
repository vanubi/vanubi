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
	--target-glib 2.32 \
	$(NULL)

test_programs = \
	testbuffer 	\
	testcharset	\
	testchunked \
	testfiles	\
	testindent	\
	testcomment	\
	testmarks	\
	testmatch	\
	testsearch	\
	teststreams \
	testvade	\
	$(NULL)

testbuffer_SOURCES = testbuffer.vala
testcharset_SOURCES = testcharset.vala
testchunked_SOURCES = testchunked.vala
testfiles_SOURCES = testfiles.vala
testindent_SOURCES = testindent.vala
testcomment_SOURCES = testcomment.vala
testmarks_SOURCES = testmarks.vala
testmatch_SOURCES = testmatch.vala
testsearch_SOURCES = testsearch.vala
teststreams_SOURCES = teststreams.vala
testvade_SOURCES = testvade.vala