# bump micro_version to the next even number for each point release
# bump micro_version to the next odd number after each release
m4_define([vanubi_major_version], [0])
m4_define([vanubi_minor_version], [0])
m4_define([vanubi_micro_version], [2])
m4_define([vanubi_patch_version], [2])

m4_define([vanubi_version], [vanubi_major_version.vanubi_minor_version.vanubi_micro_version.vanubi_patch_version])

AC_PREREQ([2.63])

AC_INIT([vanubi],
        [vanubi_version],
        [http://github.com/vanubi/vanubi/issues],
        [vanubi],
        [http://github.com/vanubi/vanubi])

AC_CONFIG_HEADER([config.h])
AC_CONFIG_MACRO_DIR([m4])

AM_INIT_AUTOMAKE([1.11 foreign subdir-objects])
AM_MAINTAINER_MODE([enable])

AM_SILENT_RULES([yes])
AM_PATH_GLIB_2_0
AM_PROG_CC_C_O
AC_PROG_INSTALL
AC_PROG_LIBTOOL
AM_PROG_VALAC(0.20.0)

PACKAGE_SUFFIX=-0.1
AC_SUBST(PACKAGE_SUFFIX)

LT_PREREQ([2.2.6])
LT_INIT([disable-static])

# Honor aclocal flags
ACLOCAL="$ACLOCAL $ACLOCAL_FLAGS"

dnl === Versioning ============================================================

VANUBI_MAJOR_VERSION=vanubi_major_version
VANUBI_MINOR_VERSION=vanubi_minor_version
VANUBI_MICRO_VERSION=vanubi_micro_version
VANUBI_PATCH_VERSION=vanubi_patch_version
VANUBI_VERSION=vanubi_version
AC_SUBST(VANUBI_MAJOR_VERSION)
AC_SUBST(VANUBI_MICRO_VERSION)
AC_SUBST(VANUBI_MINOR_VERSION)
AC_SUBST(VANUBI_PATCH_VERSION)
AC_SUBST(VANUBI_VERSION)

dnl === Dependencies ==========================================================

GLIB_PREFIX="`$PKG_CONFIG --variable=prefix glib-2.0`"
AC_SUBST(GLIB_PREFIX)
AC_ARG_VAR(top_srcdir, "Top source directory")

VALA_CHECK_MODULES(LIBVANUBI, [gio-2.0 gio-unix-2.0])
LIBVANUBI_VALAFLAGS="$LIBVANUBI_VALAFLAGS --target-glib 2.32"
LIBVANUBI_CFLAGS="$LIBVANUBI_CFLAGS $LIBVANUBI_CUSTOM_CFLAGS"
LIBVANUBI_LIBS="$LIBVANUBI_LIBS $LIBVANUBI_CUSTOM_LIBS"

VALA_CHECK_MODULES(VANUBI, [gtk+-3.0 gio-unix-2.0 gtksourceview-3.0 vte-2.90 gdk-x11-3.0 libwnck-3.0])
dnl We ignore GTK_3_10_*
PKG_CHECK_MODULES(GTK_3_10, [gtk+-3.0 >= 3.10],
				  [VANUBI_VALAFLAGS="$VANUBI_VALAFLAGS -D GTK_3_10"],
				  [echo '*** Recommended version of gtk+-3.0 is at least 3.10'])
VALA_CHECK_PACKAGES([posix], [VANUBI_VALAFLAGS="$VANUBI_VALAFLAGS --pkg posix"])

AM_CONDITIONAL(ENABLE_GLIB_TEST, [test "x$enable_glibtest" = "xyes"])

dnl === Enable debug level ====================================================

AC_ARG_ENABLE([debug],
              [AS_HELP_STRING([--enable-debug=@<:@no/ccode/yes@:>@],
                              [turn on debugging @<:@default=]debug_default[@:>@])],
              [],
              [enable_debug=no])

AS_CASE([$enable_debug],

        [yes],
        [
			LIBVANUBI_VALAFLAGS="$LIBVANUBI_VALAFLAGS -g"
			VANUBI_VALAFLAGS="$VANUBI_VALAFLAGS -g"
			LIBVANUBI_CFLAGS="$LIBVANUBI_CFLAGS -O0"
			VANUBI_CFLAGS="$VANUBI_CFLAGS -O"
        ],

        [ccode],
        [
			LIBVANUBI_CFLAGS="$LIBVANUBI_CFLAGS -g -O0"
			VANUBI_CFLAGS="$VANUBI_CFLAGS -g -O0"
        ],

        [no],
        [
			LIBVANUBI_CFLAGS="$LIBVANUBI_CFLAGS -DG_DISABLE_ASSERT -DG_DISABLE_CHECKS -DG_DISABLE_CAST_CHECKS"
			VANUBI_CFLAGS="$VANUBI_CFLAGS -DG_DISABLE_ASSERT -DG_DISABLE_CHECKS -DG_DISABLE_CAST_CHECKS"
        ],

        [AC_MSG_ERROR([Unknown argument to --enable-debug])]
)

AC_SUBST(VANUBI_DEBUG_CFLAGS)

dnl === Test suite ============================================================

GLIB_TESTS

AC_SUBST(LIBVANUBI_CFLAGS)
AC_SUBST(LIBVANUBI_LIBS)

AC_SUBST(VANUBI_CFLAGS)
AC_SUBST(VANUBI_LIBS)

AC_CONFIG_FILES([
		Makefile
		libvanubi/Makefile
		gui/Makefile
		tests/Makefile
])

AC_OUTPUT

dnl === Summary ===============================================================

echo ""
echo " Vanubi - $VERSION"
echo ""
echo " • Prefix: ${prefix}"
echo " • Debug level: ${enable_debug}"
echo ""
