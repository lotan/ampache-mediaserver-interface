#AC_PREREQ(2.63.2)
AC_INIT(ampache-mediaserver, 0.1)
AC_CONFIG_SRCDIR([Makefile.am])
AC_CONFIG_HEADER([config.h])
AM_INIT_AUTOMAKE([1.11 subdir-objects dist-xz no-dist-gzip])

AC_PROG_CC
AC_PROG_INSTALL
AC_PROG_YACC
AC_PROG_LEX
AC_PROG_MAKE_SET
AC_PROG_LIBTOOL

#LT_PREREQ([2.2.6])
#LT_INIT([disable-static])

AM_PROG_VALAC([0.14.0])

AC_SUBST(CFLAGS)
AC_SUBST(CPPFLAGS)
AC_SUBST(LDFLAGS)

#AC_SUBST([CONFIG_STATUS_DEPENDENCIES], ['$(top_srcdir)/po/LINGUAS'])

dnl *********************
dnl * time.h and timegm
dnl *********************
AC_CHECK_HEADERS([time.h], have_time=yes, have_time=no)
if test "x$have_time" = "xno"; then
	AC_MSG_ERROR([Could not find time.h])
fi

AC_CHECK_FUNC([timegm], have_timegm=yes, have_timegm=no)
if test "x$have_timegm" = "xno"; then
	AC_MSG_ERROR([Could not find timegm function])
fi

dnl ***********
dnl * signal.h
dnl ***********
AC_CHECK_HEADERS([signal.h], have_signal=yes, have_signal=no)
if test "x$have_signal" = "xno"; then
	AC_MSG_ERROR([Could not find signal.h])
fi

dnl ******************
dnl * Check for libs
dnl ******************
GLIB_REQUIRED=2.30.0
GEE_REQUIRED=0.5.0
LIBXML_REQUIRED=2.8.0
SQLITE_REQUIRED=3.0.0.0

#PKG_CHECK_MODULES(AMPACHE_MEDIASERVER, glib-2.0 >= $GLIB_REQUIRED
#                            gio-2.0 >= $GLIB_REQUIRED
#                            gobject-2.0 >= $GLIB_REQUIRED)
#AC_SUBST(AMPACHE_MEDIASERVER_CFLAGS)
#AC_SUBST(AMPACHE_MEDIASERVER_LIBS)

PKG_CHECK_MODULES(GLIB,
		  glib-2.0 >= $GLIB_REQUIRED
		  gio-2.0 >= $GLIB_REQUIRED
		  gobject-2.0 >= $GLIB_REQUIRED)
#PKG_CHECK_MODULES(GLIB, glib-2.0 >= $GLIB_REQUIRED)
AC_SUBST(GLIB_CFLAGS)
AC_SUBST(GLIB_LIBS)

PKG_CHECK_MODULES(LIBXML, libxml-2.0 >= $LIBXML_REQUIRED)
AC_SUBST(LIBXML_CFLAGS)
AC_SUBST(LIBXML_LIBS)

PKG_CHECK_MODULES(SQLITE, sqlite3 >= $SQLITE_REQUIRED)
AC_SUBST(SQLITE_CFLAGS)
AC_SUBST(SQLITE_LIBS)

AC_CONFIG_FILES([
	Makefile])

AC_OUTPUT

echo "
$PACKAGE_NAME $PACKAGE_VERSION

    Install Prefix:               ${prefix}
"
