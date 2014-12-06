/* Main.vala
 *
 * Copyright (C) 2013  Reinhold May <reinhold.may@gmx.de>
 *
 * This file is part of Ampache Mediaserver Interface.
 *
 * Ampache Mediaserver Interface is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * Ampache Mediaserver Interface is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program; if not, write to the Free Software Foundation,
 * Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 *
 * Author:
 *      Reinhold May <reinhold.may@gmx.de>
 */

using GLib;
using GLib.Log;
using MediaServer2;
using cUtils;

namespace Main {

const string        APPLICATION_VERSION = "1.0";
const int           DEFAULT_CHUNK_SIZE  = 5000;
const OptionEntry[] OPTIONS =  {
    { "ampache_uri_base", 'a', 0, OptionArg.STRING, ref ampache_uri_base, "Specify base URI of Ampache instance.", null},
    { "username", 'u', 0, OptionArg.STRING, ref username, "Specify username to authenticate with Ampache instance.", null},
    { "password", 'p', 0, OptionArg.STRING, ref password, "Specify password to authenticate with Ampache instance.", null},
    { "force-update", 'f', 0, OptionArg.NONE, ref has_force_update, "Force reread of Ampache data.", null},
    { "debug", 'd', 0, OptionArg.NONE, ref has_debug, "Display debug statements on stdout.", null},
    { "version", 0, 0, OptionArg.NONE, ref has_version, "Display version number.", null},
    { null }
};

private static string   ampache_uri_base;
private static string   username;
private static string   password;
private static bool     has_force_update;
private static bool     has_debug;
private static bool     has_version;

private static string   password256;
private static bool     db_change;

private static MainLoop mainloop;

private Store.sqlite.DB db;

private static void on_exit (int signum) {
    message ("Exit signaled...");

    mainloop.quit ();
}

private static void on_update (int signum) {
    message ("Update signaled...");

    has_force_update = true;
    update ();
}

private void add_songs (string user, string auth, long songs, long playlists, long date) {
    message ("Number of songs to download: " + songs.to_string ());

    var sa = new Glue.SongAdder (db);

    /* setup xml songs parser and its signals */

    var sp = new XMLParsing.SongsParser ();

    sp.song_parsed.connect (
        (object, song_id, url, artist_id, artist, album_id, album, title,
         tag_id, tag, track, year, bitrate, time, size, rating, art, mime) => {
            try {
                sa.add_song (song_id, url, artist_id, artist, album_id, album, title,
                    tag_id, tag, track, year, bitrate, time, size, rating, art, mime);
            }
            catch (Store.sqlite.SqlError e) {
                error ("%s", e.message);
            }

            debug (
                "song added: " + song_id.to_string () + ", " +
                url + ", " +
                artist_id.to_string () + ", " +
                artist + ", " +
                album_id.to_string () + ", " +
                album + ", " +
                title + ", " +
                tag_id.to_string () + ", " +
                tag + ", " +
                track.to_string () + ", " +
                year.to_string () + ", " +
                bitrate.to_string () + ", " +
                time.to_string () + ", " +
                size.to_string () + ", " +
                rating.to_string () + ", " +
                art + ", " +
                mime);
        });

    var sd = new AmpacheAPI.ChunkDownloader ();

    sd.chunk_downloaded.connect (
        (object, data) => {
            sp.parse (data);
        });

    sd.download_completed.connect (
        (object) => {
            /* insert accompanying tables into database */
            sa.store_mimetypes_tags_artists_albums ();

            /* add playlists */
            add_playlists (user, auth, playlists, date);
        });

    /* download songs */

#if DEBUG_SONGSFILE
    var fs = FileStream.open ("songs.xml", "r");
    var buf = new uint8[100];
    var b = new uint8[99];
    int size;
    while ((size = (int) fs.read (b)) > 0) {
        Memory.copy (buf, b, size);
        buf[size] = 0;
        debug ("chunk: %s", (string) buf);
        sp.parse ((string) buf);
    }
#else
    sd.download (ampache_uri_base, "songs", auth, songs, DEFAULT_CHUNK_SIZE);
#endif
}

private void add_playlists (string user, string auth, long playlists, long date) {
    message ("Number of playlists to download: " + playlists.to_string ());

    var pl = new List<List<long>> ();

    var pa = new Glue.PlaylistsAdder (db);

    var pp = new XMLParsing.PlaylistsParser ();

    pp.playlist_parsed.connect (
        (object, playlist_id, name, items, owner, type) => {
            if (owner == user || type == "public") {
                try {
                    pa.add_playlist (playlist_id, name);

                    var id_items = new List<long> ();
                    id_items.append (playlist_id);
                    id_items.append (items);
                    pl.append ((owned) id_items);
                }
                catch (Store.sqlite.SqlError e) {
                    error ("%s", e.message);
                }

                debug ("playlist added: " + playlist_id.to_string () + ", " +
                    name + ", " +
                    items.to_string () + ", " +
                    owner + ", " +
                    type);
            } else {
                debug ("playlist \"" + name + "\" not accessible by user.");
            }
        });
    
    var pd = new AmpacheAPI.ChunkDownloader ();

    pd.chunk_downloaded.connect (
        (object, data) => {
            pp.parse (data);
        });

    pd.download_completed.connect (
        (object) => {
            /* iterate playlists */
            iterate_playlists (auth, pl, date);
        });

    /* download playlists */
    pd.download (ampache_uri_base, "playlists", auth, playlists, DEFAULT_CHUNK_SIZE);
}

private void add_playlist (string auth, List<List<long>> playlists, long date) {
    unowned List<List<long>> playlist = playlists.first ();
    unowned List<long> id_items = playlist.data;
    long playlist_id = id_items.nth_data (0);
    long playlist_songs = id_items.nth_data (1);
    playlists.delete_link (playlist);

    message ("Number of playlist songs to download: " + playlist_songs.to_string ());

    var pa = new Glue.PlaylistAdder (db);

    var sp = new XMLParsing.SongsParser ();

    /* the order of the tracks is assumed to be the parse order */
    long playlist_track = 1;

    sp.song_parsed.connect (
        (object, song_id, url, artist_id, artist, album_id, album, title,
         tag_id, tag, track, year, bitrate, time, size, rating, art, mime) => {
            debug (
                "playlist song added: " + song_id.to_string () + ", " +
                playlist_id.to_string ());
            try {
                pa.add_song (song_id, playlist_id, playlist_track);
                playlist_track++;
            }
            catch (Store.sqlite.SqlError e) {
                error ("%s", e.message);
            }

        });
    
    var sd = new AmpacheAPI.ChunkDownloader ();

    sd.chunk_downloaded.connect (
        (object, data) => {
            sp.parse (data);
        });

    sd.download_completed.connect (
        (object) => {
            /* continue with next playlist */
            iterate_playlists (auth, playlists, date);
        });

    /* download playlist songs */
    sd.download (ampache_uri_base, "playlist_songs&filter=" + playlist_id.to_string (),
        auth, playlist_songs, DEFAULT_CHUNK_SIZE);
}

/**
 * insert date from Ampache database
 */
private void add_date(long date) {
    try {
        db.insert_date (1, date);
        db.store ();

        debug ("date added: " + date.to_string ());

        message ("ready to serve...");
    } catch (Store.sqlite.SqlError e) {
        error ("%s", e.message);
    }
}

private void iterate_playlists (string auth, List<List<long>> playlists, long date) {
    if (playlists.length () > 0) {
        add_playlist (auth, playlists, date);
    } else {
        add_date (date);
    }
}

private void update_content (string user, string auth, long songs, long playlists, long date) {
    /* delete all content databases */
    try {
        db.delete ();
    } catch (Store.sqlite.SqlError e) {
        error ("%s", e.message);
    }

    /* start populating the database */
    add_songs (user, auth, songs, playlists, date);
}

private void update () {
    /* load handshake */

    AmpacheAPI.HandshakeDownloader hd = new AmpacheAPI.HandshakeDownloader ();
    hd.download_handshake (ampache_uri_base, username, password256);

    /* handle downloaded handshake message from ampache server */

    hd.handshake_downloaded.connect (
        (object, data) => {
            /* parse xml */

            var hp = new XMLParsing.HandshakeParser ();
            hp.parse (data);
            message ("auth: " + hp.auth);
            var tv = TimeVal ();
            tv.tv_sec = hp.update; tv.tv_usec = 0;
            message ("update: " + tv.to_iso8601 ());
            tv.tv_sec = hp.add; tv.tv_usec = 0;
            message ("add: " + tv.to_iso8601 ());
            tv.tv_sec = hp.clean; tv.tv_usec = 0;
            message ("clean: " + tv.to_iso8601 ());
            message ("songs: " + hp.songs.to_string());
            message ("playlists: " + hp.playlists.to_string());

            /* set auth in database module for url correction */

            db.auth = hp.auth;

            /* get newest date */

            long newest_date = hp.update;
            if (hp.add > newest_date) newest_date = hp.add;
            if (hp.clean > newest_date) newest_date = hp.clean;

            long lu = 0;
            try {
                lu = db.get_lastupdate ();
                tv.tv_sec = lu; tv.tv_usec = 0;
                message ("lastupdate: " + tv.to_iso8601 ());
            }
            catch (Store.sqlite.SqlError e) {
                error ("%s", e.message);
            }

            if (newest_date > lu || has_force_update) {
                if (newest_date > lu)
                    message ("Ampache date > store date: Update...");
                else
                    message ("Force update...");
                update_content (username, hp.auth, hp.songs, hp.playlists, newest_date);
            } else {
                /* store changed configuration parameters */
                try {
                    if (db_change) db.store ();
                } catch (Store.sqlite.SqlError e) {
                    error ("%s", e.message);
                }
                message ("ready to serve...");
            }
        });
}

public static int main (string[] args) {
    ampache_uri_base = "";
    username         = "";
    password         = "";

    Process.signal(ProcessSignal.INT, on_exit);
    Process.signal(ProcessSignal.TERM, on_exit);
    Process.signal(ProcessSignal.USR1, on_update);

    OptionContext context = new OptionContext ("- expose ampache database as dbus Mediaserver2 interface");
    context.add_main_entries (OPTIONS, null);

    try {
        context.parse (ref args);
    } catch (OptionError e) {
        stderr.printf ("%s\n", e.message);
        stderr.printf ("Run '%s --help' to see a full list of available command line options.\n", args[0]);
        return 1;
    }

    if (has_version) {
        stdout.printf (Environment.get_prgname ());
        stdout.printf (" %s\n", APPLICATION_VERSION);
        return 0;
    }

    /* enable debug logging if specified on command line */

    if (has_debug) {
        Environment.set_variable ("G_MESSAGES_DEBUG", "all", false);
    }

    /* Creating a GLib main loop with a default context */

    mainloop = new MainLoop (null, false);

    File db_file = File.new_for_path (Environment.get_user_cache_dir ())
        .get_child ("ampache-mediaserver")
        .get_child ("cache.sqlite3");
    db = new Store.sqlite.DB (db_file, 1);
    try {
        db.open ();
    } catch (Store.sqlite.SqlError e) {
        error ("%s", e.message);
    }

    /* initialize dbus interface */

    MediaServer2.start_dbus_services.begin (db);

    /* acquire Ampache instance, username and password */
    /* if specified on command line, use and insert into database */
    /* if not specified on command line, fetch from database */

    db_change = false;
    try {
        if (ampache_uri_base == "") {
            ampache_uri_base = db.get_configuration ("ampache_uri_base");
        } else {
            db.replace_configuration ("ampache_uri_base", ampache_uri_base);
            db_change = true;
        }

        if (username == "") {
            username = db.get_configuration ("username");
        } else {
            db.replace_configuration ("username", username);
            db_change = true;
        }

        if (password == "") {
            password256 = db.get_configuration ("password256");
        } else {
            password256 = Checksum.compute_for_string (
                ChecksumType.SHA256, password);
            db.replace_configuration ("password256", password256);
            db_change = true;
        }
    } catch (Store.sqlite.SqlError e) {
        error ("%s", e.message);
    }

    if (ampache_uri_base == "") {
        error ("Ampache URI base needed.");
    };
    if (username == "") {
        error ("username to Ampache URL needed.");
    };
    if (password256 == "") {
        error ("password to Ampache URL needed.");
    };
    
    update ();

    /* Start GLib mainloop */

    mainloop.run ();

    return 0;
}

}
