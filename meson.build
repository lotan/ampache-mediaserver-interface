project('ampache-mediaserver', ['vala', 'c'])

add_project_arguments(
    ['--vapidir', join_paths(meson.current_source_dir(), 'vapi')],
    language: 'vala')

vapi = include_directories('vapi')

# find tools
flex = find_program('flex')
bison = find_program('bison')

# dependendies
glib = dependency('glib-2.0', version: '>= 2.30.0')
gobject = dependency('gobject-2.0')
gio = dependency('gio-2.0')
libxml = dependency('libxml-2.0', version: '>= 2.8.0')
sqlite = dependency('sqlite3', version: '>= 3.0.0')

# lexer
lgen = generator(flex,
                 output: '@PLAINNAME@.c',
                 arguments: ['-o', '@OUTPUT@', '@INPUT@'])
lfiles = lgen.process('vapi/query-analyzer.l')

# parser
pgen = generator(bison,
                 output: ['@BASENAME@.c', '@BASENAME@.h'],
                 arguments: ['@INPUT@', '--defines=@OUTPUT1@', '--output=@OUTPUT0@'])
pfiles = pgen.process('vapi/query-parser.y')

libmediaserverqueryparser = library(
    'libmediaserverqueryparser',
    lfiles,
    pfiles,
    include_directories: vapi)
    
libampachemediaserverinterface_utils = library(
    'libampachemediaserverinterface_utils',
    'vapi/cutils.c',
    dependencies: glib)
    
executable('ampache-mediaserver',
           sources: ['src/AmpacheAPI.vala',
		     'src/DBItemAdder.vala',
		     'src/Interfaces2.vala',
		     'src/Main.vala',
		     'src/Services2.vala',
		     'src/sqlite.vala',
		     'src/XMLParsing.vala'],
	   include_directories: vapi,
	   vala_args: ['--pkg', 'cutils',
	   	       '--pkg', 'gio_ext-2.0'],
           dependencies: [glib, gio, libxml, sqlite],
	   link_with: [libampachemediaserverinterface_utils])
