AUTOMAKE_OPTIONS = foreign

bin_PROGRAMS = ampache-mediaserver-interface

ampache_mediaserver_interface_SOURCES = \
	src/Main.vala \
	src/Interfaces2.vala \
	src/Services2.vala \
	src/XMLParsing.vala \
	src/AmpacheAPI.vala \
	src/sqlite.vala \
	src/DBItemAdder.vala

vala_pkgs = \
	--pkg glib-2.0 \
	--pkg gio-2.0 \
	--pkg libxml-2.0 \
	--pkg sqlite3 \
        --pkg cutils \
        --pkg mediaserver-query-parser \
	--pkg gio_ext-2.0

ampache_mediaserver_interface_CPPFLAGS = \
	-DPACKAGE_SRC_DIR=\""$(srcdir)"\" \
	$(GLIB_CFLAGS) $(LIBXML_CFLAGS) $(SQLITE_CFLAGS) \
	-include $(CONFIG_HEADER) \
        -I$(top_srcdir)/vapi

AM_VALAFLAGS = \
	--target-glib=2.30 $(vala_pkgs) \
	--basedir $(top_srcdir) \
	--vapidir=$(top_srcdir)/vapi

ampache_mediaserver_interface_LDFLAGS = \
	-Wl,--export-dynamic

ampache_mediaserver_interface_LDADD = \
	$(GLIB_LIBS) $(LIBXML_LIBS) $(SQLITE_LIBS) \
	libampachemediaserverinterface-utils.a \
	libmediaserverqueryparser.a

CLEANFILES = $(ampache_mediaserver_interface_SOURCES:.vala=.c)

noinst_LIBRARIES = libampachemediaserverinterface-utils.a libmediaserverqueryparser.a
libampachemediaserverinterface_utils_a_SOURCES = \
	vapi/cutils.c

libampachemediaserverinterface_utils_a_CPPFLAGS = \
	$(GLIB_CFLAGS)

AM_YFLAGS = --defines

libmediaserverqueryparser_a_SOURCES = \
	vapi/query-parser.y \
	vapi/query-analyzer.l

libmediaserverqueryparser_a_CPPFLAGS = \
	$(GLIB_CFLAGS)

CLEANFILES += vapi/query-parser.c vapi/query-parser.h vapi/query-analyzer.c
