/* sqlite.vala
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
using Sqlite;

namespace Store.sqlite {

/* from http://sqlite.org/c3ref/c_abort.html */
public errordomain SqlError {
    ERROR,
    INTERNAL,
    PERM,
    ABORT,
    BUSY,
    LOCKED,
    NOMEM,
    READONLY,
    INTERRUPT,
    IOERR,
    CORRUPT,
    NOTFOUND,
    FULL,
    CANTOPEN,
    PROTOCOL,
    EMPTY,
    SCHEMA,
    TOOBIG,
    CONSTRAINT,
    MISMATCH,
    MISUSE,
    NOLFS,
    AUTH,
    FORMAT,
    RANGE,
    NOTADB
}

/* delegates */

public delegate int AllObjectCount () throws SqlError;
public delegate GLib.HashTable<string, Variant?>[] AllGetObjects (string path, int offset, int limit, string[] filter) throws SqlError;

public delegate int SelectiveObjectCount (int[] id) throws SqlError;
public delegate Variant SelectiveGetObjects (string path, int[] id, int offset, int limit, string[] filter) throws SqlError;

public delegate string IdentifyName (int[] id) throws SqlError;

public delegate Variant GetObject (string path, int[] id, string[] filter) throws SqlError;

/* helpers */

public static void mkdirs (File directory) throws Error {
    SList<File> create_dirs = new SList<File> ();

    File current_dir = directory;
    while (current_dir != null) {
        if (current_dir.query_exists (null)) break;
        create_dirs.prepend (current_dir);
        current_dir = current_dir.get_parent ();
    }

    foreach (File dir in create_dirs) {
        debug ("Creating %s", dir.get_path ());
        dir.make_directory (null);
    }
}

private static Regex reg_auth = null;

public static string rep_auth (string url, string auth) {
    string result = url;

    if (auth.length > 0) {
        try {
            if (reg_auth == null)
                reg_auth = new Regex ("\\b(auth|ssid)=[a-fA-F0-9]+");
            result = reg_auth.replace (url, url.length, 0, "\\1=" + auth);
        } catch (GLib.RegexError e) {
            error ("RegexError: %s", e.message);
        }
    }

    return result;
}

private static Regex reg_prot = null;

public static string rep_prot (string url) {
    string result = url;

    try {
        if (reg_prot == null)
            reg_prot = new Regex ("^https");
        result = reg_prot.replace (url, url.length, 0, "http");
    } catch (GLib.RegexError e) {
        error ("RegexError: %s", e.message);
    }

    return result;
}

private static Regex reg_suffix = null;

public static string? get_suffix (string url) {
    MatchInfo mi;

    try {
        if (reg_suffix == null)
            reg_suffix = new Regex ("\\bname=art\\.([a-fA-F0-9]+)");
        reg_suffix.match (url, 0, out mi);
    } catch (GLib.RegexError e) {
        error ("RegexError: %s", e.message);
    }

    return mi.fetch (1);
}

private static Regex reg_artid = null;

public static int get_artid (string url) {
    MatchInfo mi;
    string?   artid = null;

    try {
        if (reg_artid == null)
            reg_artid = new Regex ("\\bobject_id=([0-9]+)");
        reg_artid.match (url, 0, out mi);
    } catch (GLib.RegexError e) {
        error ("RegexError: %s", e.message);
    }

    if (mi.matches () == true) {
        artid = mi.fetch (1);
    }

    if (artid != null) {
        return int.parse (artid);
    } else {
        // 0 should always be a safe assumption: the default image
        return 0;
    }
}

public class DB : Object {

    public static const string CONTAINER     = "container";
    public static const string MUSIC         = "music";
    public static const string IMAGE         = "image";
    public static const bool   SEARCHABILITY = false;
        
    public static const string YEAR_DATEPREFIX = "-01-01T00:00:00Z";

    public File   database_file { get; construct; }
    public string auth          { get; set; default = ""; }
    public string art_path      { get; set; default = ""; }

    private Database db;
    private Database persistdb;

    private int new_version;

    private static const string CREATE_MIMETYPES =
    """CREATE TABLE mimetypes (
    id   INTEGER,
    type VARCHAR(255),
    PRIMARY KEY(id))""";

    private static const string CREATE_TAGS =
    """CREATE TABLE tags (
    id   INTEGER,
    name VARCHAR(255),
    PRIMARY KEY(id))""";

    private static const string CREATE_ARTISTS =
    """CREATE TABLE artists (
    id   INTEGER,
    name VARCHAR(255),
    PRIMARY KEY(id))""";

    private static const string CREATE_ALBUMS =
    """CREATE TABLE albums (
    id   INTEGER,
    name VARCHAR(255),
    PRIMARY KEY(id))""";

    private static const string CREATE_SONGS =
    """CREATE TABLE songs (
    id        INTEGER,
    url       VARCHAR(1023),
    artist_id INTEGER,
    album_id  INTEGER,
    title     VARCHAR(255),
    tag_id    INTEGER,
    track     INTEGER,
    year      INTEGER,
    bitrate   INTEGER,
    time      INTEGER,
    size      INTEGER,
    rating    INTEGER,
    art_id    INTEGER,
    mime_id   INTEGER,
    PRIMARY KEY(id))""";

    private static const string CREATE_PLAYLISTS =
    """CREATE TABLE playlists (
    id   INTEGER,
    name VARCHAR(255),
    PRIMARY KEY(id))""";

    private static const string CREATE_PLAYLISTSONGS =
    """CREATE TABLE playlistsongs (
    id          INTEGER,
    playlist_id INTEGER,
    track       INTEGER,
    PRIMARY KEY(id,playlist_id))""";

    private static const string CREATE_ART =
    """CREATE TABLE art (
    id  INTEGER,
    url VARCHAR(255),
    PRIMARY KEY(id))""";

    private static const string CREATE_DATES =
    """CREATE TABLE dates (
    type INTEGER,
    date INTEGER,
    PRIMARY KEY(type))""";

    private static const string CREATE_CONFIGURATION =
    """CREATE TABLE configuration (
    key   VARCHAR(255),
    value VARCHAR(255),
    PRIMARY KEY(key))""";

    private static const string INSERT_MIMETYPE =
    "INSERT INTO mimetypes VALUES (?, ?)";

    private static const string INSERT_TAG =
    "INSERT INTO tags VALUES (?, ?)";

    private static const string INSERT_ARTIST =
    "INSERT INTO artists VALUES (?, ?)";

    private static const string INSERT_ALBUM =
    "INSERT INTO albums VALUES (?, ?)";

    private static const string INSERT_SONG =
    "INSERT INTO songs VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)";

    private static const string INSERT_PLAYLIST =
    "INSERT INTO playlists VALUES (?, ?)";

    private static const string INSERT_PLAYLISTSONG =
    "INSERT INTO playlistsongs VALUES (?, ?, ?)";

    private static const string INSERT_ART =
    "INSERT INTO art VALUES (?, ?)";

    private static const string INSERT_DATE =
    "INSERT INTO dates VALUES (?, ?)";

    private static const string SELECT_DATE =
    "SELECT date FROM dates WHERE type = ?";

    private static const string REPLACE_CONFIGURATION =
    "REPLACE INTO configuration VALUES (?, ?)";

    private static const string SELECT_CONFIGURATION =
    "SELECT value FROM configuration WHERE key = ?";

    private static const string DELETE_MIMETYPES =
    "DELETE FROM mimetypes";

    private static const string DELETE_TAGS =
    "DELETE FROM tags";

    private static const string DELETE_ARTISTS =
    "DELETE FROM artists";

    private static const string DELETE_ALBUMS =
    "DELETE FROM albums";

    private static const string DELETE_SONGS =
    "DELETE FROM songs";

    private static const string DELETE_PLAYLISTS =
    "DELETE FROM playlists";

    private static const string DELETE_PLAYLISTSONGS =
    "DELETE FROM playlistsongs";

    private static const string DELETE_ART =
    "DELETE FROM art";

    private static const string DELETE_DATES =
    "DELETE FROM dates";

    private static const string DELETE_CONFIGURATION =
    "DELETE FROM configuration";

    private static const string SELECT_GET_ALL_GENRES =
    """SELECT
        s.tag_id, t.name, s.artists
    FROM
        (SELECT tag_id, COUNT(DISTINCT artist_id) AS artists FROM songs GROUP BY tag_id) s
    LEFT JOIN
        tags t
    ON
        s.tag_id = t.id
    ORDER BY
        t.name
    LIMIT ? OFFSET ?""";

    private static const string SELECT_COUNT_ALL_GENRES =
    """SELECT COUNT(*) FROM (SELECT tag_id FROM songs GROUP BY tag_id)""";

    private static const string SELECT_GET_ALL_ARTISTS =
    """SELECT
        s.artist_id, a.name, s.albums
    FROM
        (SELECT artist_id, COUNT(DISTINCT album_id) AS albums FROM songs GROUP BY artist_id) s
    LEFT JOIN
        artists a
    ON
        s.artist_id = a.id
    ORDER BY
        a.name
    LIMIT ? OFFSET ?""";

    private static const string SELECT_COUNT_ALL_ARTISTS =
    """SELECT COUNT(*) FROM (SELECT artist_id FROM songs GROUP BY artist_id)""";

    private static const string SELECT_GET_ALL_ALBUMS =
    """SELECT
        s.artist_id, s.album_id, a.name, l.name, s.songs
    FROM
        (SELECT artist_id, album_id, COUNT(DISTINCT id) AS songs FROM songs GROUP BY artist_id, album_id) s
    LEFT JOIN
        artists a
    ON
        s.artist_id = a.id
    LEFT JOIN
        albums l
    ON
        s.album_id = l.id
    ORDER BY
        l.name
    LIMIT ? OFFSET ?""";

    private static const string SELECT_COUNT_ALL_ALBUMS =
    """SELECT COUNT(*) FROM (SELECT album_id FROM songs GROUP BY artist_id, album_id)""";

    private static const string SELECT_GET_ALL_SONGS =
    """SELECT
        s.artist_id, s.album_id, s.id, a.name, l.name, s.title, s.url,
        t.name, s.track, s.year, s.bitrate, s.time, s.size, r.url, m.type 
    FROM
        songs s
    LEFT JOIN
        tags t
    ON
        s.tag_id = t.id
    LEFT JOIN
        artists a
    ON
        s.artist_id = a.id
    LEFT JOIN
        albums l
    ON
        s.album_id = l.id
    LEFT JOIN
        art r
    ON
        s.art_id = r.id
    LEFT JOIN
        mimetypes m
    ON
        s.mime_id = m.id
    ORDER BY
        s.title
    LIMIT ? OFFSET ?""";

    private static const string SELECT_COUNT_ALL_SONGS =
    """SELECT COUNT(*) FROM songs""";

    private static const string SELECT_GET_ALL_PLAYLISTS =
    """SELECT
        p.id, p.name, ps.songs
    FROM
        (SELECT playlist_id, COUNT(DISTINCT id) AS songs FROM playlistsongs GROUP BY playlist_id) ps
    LEFT JOIN
        playlists p
    ON
        ps.playlist_id = p.id
    LIMIT ? OFFSET ?""";

    private static const string SELECT_COUNT_ALL_PLAYLISTS =
    """SELECT COUNT(*) FROM playlists""";

    private static const string SELECT_GET_GENRE_ARTISTS =
    """SELECT
        s.artist_id, a.name, s.albums
    FROM
        (SELECT artist_id, COUNT(DISTINCT album_id) AS albums FROM songs WHERE tag_id = ? GROUP BY artist_id) s
    LEFT JOIN
        artists a
    ON
        s.artist_id = a.id
    ORDER BY
        a.name
    LIMIT ? OFFSET ?""";

    private static const string SELECT_COUNT_GENRE_ARTISTS =
    """SELECT COUNT(*) FROM (SELECT artist_id FROM songs WHERE tag_id = ? GROUP BY artist_id)""";

    private static const string SELECT_IDENTIFY_GENRE =
    """SELECT name FROM tags WHERE id = ?""";

    private static const string SELECT_GET_ARTIST_ALBUMS =
    """SELECT
        s.artist_id, s.album_id, a.name, l.name, s.songs
    FROM
        (SELECT artist_id, album_id, COUNT(DISTINCT id) AS songs FROM songs WHERE artist_id = ? GROUP BY album_id) s
    LEFT JOIN
        artists a
    ON
        s.artist_id = a.id
    LEFT JOIN
        albums l
    ON
        s.album_id = l.id
    ORDER BY
        l.name
    LIMIT ? OFFSET ?""";

    private static const string SELECT_COUNT_ARTIST_ALBUMS =
    """SELECT COUNT(*) FROM (SELECT album_id FROM songs WHERE artist_id = ? GROUP BY album_id)""";

    private static const string SELECT_IDENTIFY_ARTIST =
    """SELECT name FROM artists WHERE id = ?""";

    private static const string SELECT_GET_ALBUM_SONGS =
    """SELECT
        s.artist_id, s.album_id, s.id, a.name, l.name, s.title, s.url,
        t.name, s.track, s.year, s.bitrate, s.time, s.size, r.url, m.type 
    FROM
        (SELECT * FROM songs WHERE artist_id = ? AND album_id = ?) s
    LEFT JOIN
        tags t
    ON
        s.tag_id = t.id
    LEFT JOIN
        artists a
    ON
        s.artist_id = a.id
    LEFT JOIN
        albums l
    ON
        s.album_id = l.id
    LEFT JOIN
        art r
    ON
        s.art_id = r.id
    LEFT JOIN
        mimetypes m
    ON
        s.mime_id = m.id
    ORDER BY
        s.track, s.title
    LIMIT ? OFFSET ?""";

    private static const string SELECT_COUNT_ALBUM_SONGS =
    """SELECT COUNT(*) FROM (SELECT * FROM songs WHERE artist_id = ? AND album_id = ?)""";

    private static const string SELECT_IDENTIFY_ALBUM =
    """SELECT name FROM albums WHERE id = ?""";

    private static const string SELECT_GET_SONG =
    """SELECT
        s.artist_id, s.album_id, s.id, a.name, l.name, s.title, s.url,
        t.name, s.track, s.year, s.bitrate, s.time, s.size, r.url, m.type 
    FROM
        (SELECT * FROM songs WHERE id = ?) s
    LEFT JOIN
        tags t
    ON
        s.tag_id = t.id
    LEFT JOIN
        artists a
    ON
        s.artist_id = a.id
    LEFT JOIN
        albums l
    ON
        s.album_id = l.id
    LEFT JOIN
        art r
    ON
        s.art_id = r.id
    LEFT JOIN
        mimetypes m
    ON
        s.mime_id = m.id""";

    private static const string SELECT_GET_PLAYLIST_SONGS =
    """SELECT
        s.artist_id, s.album_id, s.id, a.name, l.name, s.title, s.url,
        t.name, s.track, s.year, s.bitrate, s.time, s.size, r.url, m.type 
    FROM
        (SELECT id, track FROM playlistsongs WHERE playlist_id = ?) p
    LEFT JOIN
        songs s
    ON
        p.id = s.id
    LEFT JOIN
        tags t
    ON
        s.tag_id = t.id
    LEFT JOIN
        artists a
    ON
        s.artist_id = a.id
    LEFT JOIN
        albums l
    ON
        s.album_id = l.id
    LEFT JOIN
        art r
    ON
        s.art_id = r.id
    LEFT JOIN
        mimetypes m
    ON
        s.mime_id = m.id
    ORDER BY
        p.track
    LIMIT ? OFFSET ?""";

    private static const string SELECT_COUNT_PLAYLIST_SONGS =
    """SELECT COUNT(*) FROM (SELECT id FROM playlistsongs WHERE playlist_id = ?)""";

    private static const string SELECT_IDENTIFY_PLAYLIST =
    """SELECT name FROM playlists WHERE id = ?""";

    private static const string SELECT_GET_ART =
    """SELECT id, url FROM art WHERE id = ?""";

    private Statement insert_mimetype_statement;
    private Statement insert_tag_statement;
    private Statement insert_artist_statement;
    private Statement insert_album_statement;
    private Statement insert_song_statement;
    private Statement insert_playlist_statement;
    private Statement insert_playlistsong_statement;
    private Statement insert_art_statement;
    private Statement insert_date_statement;
    private Statement select_date_statement;
    private Statement replace_configuration_statement;
    private Statement select_configuration_statement;

    private Statement select_get_all_genres_statement;
    private Statement select_count_all_genres_statement;
    private Statement select_get_all_artists_statement;
    private Statement select_count_all_artists_statement;
    private Statement select_get_all_albums_statement;
    private Statement select_count_all_albums_statement;
    private Statement select_get_all_songs_statement;
    private Statement select_count_all_songs_statement;
    private Statement select_get_all_playlists_statement;
    private Statement select_count_all_playlists_statement;

    private Statement select_get_genre_artists_statement;
    private Statement select_count_genre_artists_statement;
    private Statement select_identify_genre_statement;
    private Statement select_get_artist_albums_statement;
    private Statement select_count_artist_albums_statement;
    private Statement select_identify_artist_statement;
    private Statement select_get_album_songs_statement;
    private Statement select_count_album_songs_statement;
    private Statement select_identify_album_statement;
    private Statement select_get_song_statement;
    private Statement select_get_playlist_songs_statement;
    private Statement select_count_playlist_songs_statement;
    private Statement select_identify_playlist_statement;
    private Statement select_get_art_statement;

    public DB (File dbfile, int version) {
        Object (database_file: dbfile);

        this.new_version = version;
    }

    /**
     * Open database and create or upgrade tables if neccessary
     */
    public void open () throws SqlError {

        if (this.db != null) return;

        if (Database.open (":memory:", out this.db) != Sqlite.OK) {
            this.throw_last_error ();
        }

        int version = this.get_version ();

        /* if file exists, restore into memory, otherwise create tables */
        if (this.database_file.query_exists (null)) {

            /* open database file */
            if (Database.open (database_file.get_path (), out this.persistdb) != Sqlite.OK) {
                this.throw_last_error ();
            }

            /* backup file into memory */
            var b = new Sqlite.Backup (this.db, "main", this.persistdb, "main");
            if (b.step (-1) != Sqlite.DONE) {
                this.throw_last_error ();
            }
        } else {
            debug ("Creating tables");
            this.create ();

            if (this.new_version > version) {
                debug ("Updating tables");
                this.upgrade (version, this.new_version);
            }
        }
        this.set_version (this.new_version);
        this.set_journal_mode ();

        this.on_open ();
    }

    /**
     * In order to make changes permanent, this function writes the
     * table in memory back to a file.
     */
    public void store () throws SqlError {

        /* create necessary parent directories */
        File dbfile_dir = database_file.get_parent ();
        if (!dbfile_dir.query_exists (null)) {
            try {
                mkdirs (dbfile_dir);
            } catch (Error e) {
                error ("Could not create directory: %s", e.message);
            }
        }

        /* open file database for writing */
        if (Database.open (database_file.get_path (), out this.persistdb) != Sqlite.OK) {
            this.throw_last_error ();
        }

        /* backup memory to file */
        var b = new Sqlite.Backup (this.persistdb, "main", this.db, "main");
        if (b.step (-1) != Sqlite.DONE) {
            this.throw_last_error ();
        }
    }

    /**
     * Set database version
     */
    public void set_version (int version) {
        try {
            this.exec_sql ("PRAGMA user_version = %d".printf (version));
        } catch (SqlError e) {
            error ("%s", e.message);
        }
    }

    public void set_journal_mode () {
        try {
            this.exec_sql ("PRAGMA journal_mode = TRUNCATE");
        } catch (SqlError e) {
            error ("%s", e.message);
        }
    }

    /**
     * Get database version
     */
    public int get_version () {
        int version = 0;
        try {
            version = this.simple_query_int ("PRAGMA user_version");
        } catch (SqlError e) {
            error ("%s", e.message);
        }
        return version;
    }

    public int simple_query_int (string sql) throws SqlError {
        Statement st;
        this.db.prepare (sql, -1, out st);
        int ret = 0;
        if (st.step () == Sqlite.ROW) {
            ret = st.column_int (0);
        } else {
            this.throw_last_error ();
        }
        return ret;
    }

    public void exec_sql (string sql) throws SqlError {
        string errmsg;
        int val = this.db.exec (sql, null, out errmsg);
        if (val != Sqlite.OK) this.throw_last_error ();
    }

    public void begin_transaction () throws SqlError {
        this.exec_sql ("BEGIN;");
    }

    public void end_transaction () throws SqlError {
        this.exec_sql ("END;");
    }

    protected void throw_last_error_reset (Statement stmnt) throws SqlError {
        stmnt.reset ();
        this.throw_last_error ();
    }

    protected void throw_last_error (string? errmsg=null) throws SqlError {
        int code = this.db.errcode ();
        string msg;
        if (errmsg == null) {
            msg = "SqlError: %d: %s".printf (code, this.db.errmsg ());
        } else {
            msg = errmsg;
        }

        switch (code) {
            case 1:  throw new SqlError.ERROR (msg);
            case 2:  throw new SqlError.INTERNAL (msg);
            case 3:  throw new SqlError.PERM (msg);
            case 4:  throw new SqlError.ABORT (msg);
            case 5:  throw new SqlError.BUSY (msg);
            case 6:  throw new SqlError.LOCKED (msg);
            case 7:  throw new SqlError.NOMEM (msg);
            case 8:  throw new SqlError.READONLY (msg);
            case 9:  throw new SqlError.INTERRUPT (msg);
            case 10: throw new SqlError.IOERR (msg);
            case 11: throw new SqlError.CORRUPT (msg);
            case 12: throw new SqlError.NOTFOUND (msg);
            case 13: throw new SqlError.FULL (msg);
            case 14: throw new SqlError.CANTOPEN (msg);
            case 15: throw new SqlError.PROTOCOL (msg);
            case 16: throw new SqlError.EMPTY (msg);
            case 17: throw new SqlError.SCHEMA (msg);
            case 18: throw new SqlError.TOOBIG    (msg);
            case 19: throw new SqlError.CONSTRAINT (msg);
            case 20: throw new SqlError.MISMATCH (msg);
            case 21: throw new SqlError.MISUSE (msg);
            case 22: throw new SqlError.NOLFS (msg);
            case 23: throw new SqlError.AUTH (msg);
            case 24: throw new SqlError.FORMAT (msg);
            case 25: throw new SqlError.RANGE (msg);
            case 26: throw new SqlError.NOTADB (msg);
            default: break;
        }
    }

    /**
     * Called when the database is created for the first time.
     * Put the commands required to create all tables here.
     */
    public void create () throws SqlError {
        this.exec_sql (CREATE_MIMETYPES);
        this.exec_sql (CREATE_TAGS);
        this.exec_sql (CREATE_ARTISTS);
        this.exec_sql (CREATE_ALBUMS);
        this.exec_sql (CREATE_SONGS);
        this.exec_sql (CREATE_PLAYLISTS);
        this.exec_sql (CREATE_PLAYLISTSONGS);
        this.exec_sql (CREATE_ART);
        this.exec_sql (CREATE_DATES);
        this.exec_sql (CREATE_CONFIGURATION);
    }

    public void delete () throws SqlError {
        this.exec_sql (DELETE_MIMETYPES);
        this.exec_sql (DELETE_TAGS);
        this.exec_sql (DELETE_ARTISTS);
        this.exec_sql (DELETE_ALBUMS);
        this.exec_sql (DELETE_SONGS);
        this.exec_sql (DELETE_PLAYLISTS);
        this.exec_sql (DELETE_PLAYLISTSONGS);
        this.exec_sql (DELETE_ART);
        this.exec_sql (DELETE_DATES);
        /* don't delete configuration */
        /* this.exec_sql (DELETE_CONFIGURATION); */
    }

    /**
     * Called when the database needs to be upgraded.
     */
    public void upgrade (int old_version, int new_version) throws SqlError {
    }

    /**
      * Called when the database has been opened.
      */
    public void on_open () {
        this.db.prepare (INSERT_MIMETYPE, -1,
            out this.insert_mimetype_statement);
        this.db.prepare (INSERT_TAG, -1,
            out this.insert_tag_statement);
        this.db.prepare (INSERT_ARTIST, -1,
            out this.insert_artist_statement);
        this.db.prepare (INSERT_ALBUM, -1,
            out this.insert_album_statement);
        this.db.prepare (INSERT_SONG, -1,
            out this.insert_song_statement);
        this.db.prepare (INSERT_PLAYLIST, -1,
            out this.insert_playlist_statement);
        this.db.prepare (INSERT_PLAYLISTSONG, -1,
            out this.insert_playlistsong_statement);
        this.db.prepare (INSERT_ART, -1,
            out this.insert_art_statement);
        this.db.prepare (INSERT_DATE, -1,
            out this.insert_date_statement);
        this.db.prepare (SELECT_DATE, -1,
            out this.select_date_statement);
        this.db.prepare (REPLACE_CONFIGURATION, -1,
            out this.replace_configuration_statement);
        this.db.prepare (SELECT_CONFIGURATION, -1,
            out this.select_configuration_statement);

        this.db.prepare (SELECT_GET_ALL_GENRES, -1,
            out this.select_get_all_genres_statement);
        this.db.prepare (SELECT_COUNT_ALL_GENRES, -1,
            out this.select_count_all_genres_statement);
        this.db.prepare (SELECT_GET_ALL_ARTISTS, -1,
            out this.select_get_all_artists_statement);
        this.db.prepare (SELECT_COUNT_ALL_ARTISTS, -1,
            out this.select_count_all_artists_statement);
        this.db.prepare (SELECT_GET_ALL_ALBUMS, -1,
            out this.select_get_all_albums_statement);
        this.db.prepare (SELECT_COUNT_ALL_ALBUMS, -1,
            out this.select_count_all_albums_statement);
        this.db.prepare (SELECT_GET_ALL_SONGS, -1,
            out this.select_get_all_songs_statement);
        this.db.prepare (SELECT_COUNT_ALL_SONGS, -1,
            out this.select_count_all_songs_statement);
        this.db.prepare (SELECT_GET_ALL_PLAYLISTS, -1,
            out this.select_get_all_playlists_statement);
        this.db.prepare (SELECT_COUNT_ALL_PLAYLISTS, -1,
            out this.select_count_all_playlists_statement);

        this.db.prepare (SELECT_GET_GENRE_ARTISTS, -1,
            out this.select_get_genre_artists_statement);
        this.db.prepare (SELECT_COUNT_GENRE_ARTISTS, -1,
            out this.select_count_genre_artists_statement);
        this.db.prepare (SELECT_IDENTIFY_GENRE, -1,
            out this.select_identify_genre_statement);
        this.db.prepare (SELECT_GET_ARTIST_ALBUMS, -1,
            out this.select_get_artist_albums_statement);
        this.db.prepare (SELECT_COUNT_ARTIST_ALBUMS, -1,
            out this.select_count_artist_albums_statement);
        this.db.prepare (SELECT_IDENTIFY_ARTIST, -1,
            out this.select_identify_artist_statement);
        this.db.prepare (SELECT_GET_ALBUM_SONGS, -1,
            out this.select_get_album_songs_statement);
        this.db.prepare (SELECT_COUNT_ALBUM_SONGS, -1,
            out this.select_count_album_songs_statement);
        this.db.prepare (SELECT_IDENTIFY_ALBUM, -1,
            out this.select_identify_album_statement);
        this.db.prepare (SELECT_GET_SONG, -1,
            out this.select_get_song_statement);
        this.db.prepare (SELECT_GET_PLAYLIST_SONGS, -1,
            out this.select_get_playlist_songs_statement);
        this.db.prepare (SELECT_COUNT_PLAYLIST_SONGS, -1,
            out this.select_count_playlist_songs_statement);
        this.db.prepare (SELECT_IDENTIFY_PLAYLIST, -1,
            out this.select_identify_playlist_statement);
        this.db.prepare (SELECT_GET_ART, -1,
            out this.select_get_art_statement);
    }

    public void insert_mimetype (long   mimetype_id,
                                 string mimetype) throws SqlError {
        if (this.insert_mimetype_statement.bind_int  (1, (int) mimetype_id) != Sqlite.OK ||
            this.insert_mimetype_statement.bind_text (2, mimetype)          != Sqlite.OK) {
            this.throw_last_error ();
            return;
        }

        if (this.insert_mimetype_statement.step () != Sqlite.DONE) {
            this.throw_last_error_reset (this.insert_mimetype_statement);
            return;
        }

        this.insert_mimetype_statement.reset ();
    }

    public void insert_tag (long   tag_id,
                            string tag) throws SqlError {
        if (this.insert_tag_statement.bind_int  (1, (int) tag_id) != Sqlite.OK ||
            this.insert_tag_statement.bind_text (2, tag)          != Sqlite.OK) {
            this.throw_last_error ();
            return;
        }

        if (this.insert_tag_statement.step () != Sqlite.DONE) {
            this.throw_last_error_reset (this.insert_tag_statement);
            return;
        }

        this.insert_tag_statement.reset ();
    }

    public void insert_artist (long   artist_id,
                               string artist) throws SqlError {
        if (this.insert_artist_statement.bind_int  (1, (int) artist_id) != Sqlite.OK ||
            this.insert_artist_statement.bind_text (2, artist)          != Sqlite.OK) {
            this.throw_last_error ();
            return;
        }

        if (this.insert_artist_statement.step () != Sqlite.DONE) {
            this.throw_last_error_reset (this.insert_artist_statement);
            return;
        }

        this.insert_artist_statement.reset ();
    }

    public void insert_album (long   album_id,
                              string album) throws SqlError {
        if (this.insert_album_statement.bind_int  (1, (int) album_id) != Sqlite.OK ||
            this.insert_album_statement.bind_text (2, album)          != Sqlite.OK) {
            this.throw_last_error ();
            return;
        }

        if (this.insert_album_statement.step () != Sqlite.DONE) {
            this.throw_last_error_reset (this.insert_album_statement);
            return;
        }

        this.insert_album_statement.reset ();
    }

    public void insert_song (long   song_id,
                             string url,
                             long   artist_id,
                             long   album_id,
                             string title,
                             long   tag_id,
                             long   track,
                             long   year,
                             long   bitrate,
                             long   time,
                             long   size,
                             long   rating,
                             long   art_id,
                             long   mimetype_id) throws SqlError {

        if (this.insert_song_statement.bind_int  (1,  (int) song_id)     != Sqlite.OK ||
            this.insert_song_statement.bind_text (2,  url)               != Sqlite.OK ||
            this.insert_song_statement.bind_int  (3,  (int) artist_id)   != Sqlite.OK ||
            this.insert_song_statement.bind_int  (4,  (int) album_id)    != Sqlite.OK ||
            this.insert_song_statement.bind_text (5,  title)             != Sqlite.OK ||
            this.insert_song_statement.bind_int  (6,  (int) tag_id)      != Sqlite.OK ||
            this.insert_song_statement.bind_int  (7,  (int) track)       != Sqlite.OK ||
            this.insert_song_statement.bind_int  (8,  (int) year)        != Sqlite.OK ||
            this.insert_song_statement.bind_int  (9,  (int) bitrate)     != Sqlite.OK ||
            this.insert_song_statement.bind_int  (10, (int) time)        != Sqlite.OK ||
            this.insert_song_statement.bind_int  (11, (int) size)        != Sqlite.OK ||
            this.insert_song_statement.bind_int  (12, (int) rating)      != Sqlite.OK ||
            this.insert_song_statement.bind_int  (13, (int) art_id)      != Sqlite.OK ||
            this.insert_song_statement.bind_int  (14, (int) mimetype_id) != Sqlite.OK) {
            this.throw_last_error ();
            return;
        }

        if (this.insert_song_statement.step () != Sqlite.DONE) {
            this.throw_last_error_reset (this.insert_song_statement);
            return;
        }

        this.insert_song_statement.reset ();
    }

    public void insert_playlist (long   playlist_id,
                                 string name) throws SqlError {
        if (this.insert_playlist_statement.bind_int  (1, (int) playlist_id) != Sqlite.OK ||
            this.insert_playlist_statement.bind_text (2, name)              != Sqlite.OK) {
            this.throw_last_error ();
            return;
        }

        if (this.insert_playlist_statement.step () != Sqlite.DONE) {
            this.throw_last_error_reset (this.insert_playlist_statement);
            return;
        }

        this.insert_playlist_statement.reset ();
    }

    public void insert_playlistsong (long song_id,
                                     long playlist_id,
                                     long track) throws SqlError {
        if (this.insert_playlistsong_statement.bind_int  (1, (int) song_id)     != Sqlite.OK ||
            this.insert_playlistsong_statement.bind_int  (2, (int) playlist_id) != Sqlite.OK ||
            this.insert_playlistsong_statement.bind_int  (3, (int) track)       != Sqlite.OK) {
            this.throw_last_error ();
            return;
        }

        if (this.insert_playlistsong_statement.step () != Sqlite.DONE) {
            this.throw_last_error_reset (this.insert_playlistsong_statement);
            return;
        }

        this.insert_playlistsong_statement.reset ();
    }

    public void insert_art (long   art_id,
                            string art) throws SqlError {
        if (this.insert_art_statement.bind_int  (1, (int) art_id) != Sqlite.OK ||
            this.insert_art_statement.bind_text (2, art)          != Sqlite.OK) {
            this.throw_last_error ();
            return;
        }

        if (this.insert_art_statement.step () != Sqlite.DONE) {
            this.throw_last_error_reset (this.insert_art_statement);
            return;
        }

        this.insert_art_statement.reset ();
    }

    public void insert_date (long type,
                             long date) throws SqlError {
        if (this.insert_date_statement.bind_int (1, (int) type) != Sqlite.OK ||
            this.insert_date_statement.bind_int (2, (int) date) != Sqlite.OK) {
            this.throw_last_error ();
            return;
        }

        if (this.insert_date_statement.step () != Sqlite.DONE) {
            this.throw_last_error_reset (this.insert_date_statement);
            return;
        }

        this.insert_date_statement.reset ();
    }

    public long get_lastupdate () throws SqlError {
        long lastupdate = -1;
        long type = 1;

        if (this.select_date_statement.bind_int (1, (int) type) != Sqlite.OK) {
            this.throw_last_error ();
            return -1;
        }

        while (this.select_date_statement.step () == Sqlite.ROW) {
            lastupdate = this.select_date_statement.column_int (0);
        }

        this.select_date_statement.reset ();

        return lastupdate;
    }

    public void replace_configuration (string key,
                                       string val) throws SqlError {
        if (this.replace_configuration_statement.bind_text (1, key) != Sqlite.OK ||
            this.replace_configuration_statement.bind_text (2, val) != Sqlite.OK) {
            this.throw_last_error ();
            return;
        }

        if (this.replace_configuration_statement.step () != Sqlite.DONE) {
            this.throw_last_error_reset (this.replace_configuration_statement);
            return;
        }

        this.replace_configuration_statement.reset ();
    }

    public string get_configuration (string key) throws SqlError {
        string result = "";

        if (this.select_configuration_statement.bind_text (1, key) != Sqlite.OK) {
            this.throw_last_error ();
            return "";
        }

        while (this.select_configuration_statement.step () == Sqlite.ROW) {
            result = this.select_configuration_statement.column_text (0);
        }

        this.select_configuration_statement.reset ();

        return result;
    }

    /* helpers */

    public static void hash_insert (GLib.HashTable<string, Variant?> ht,
                                    string[]                         filter,
                                    string                           key,
                                    Variant?                         val) {
        if (filter.length == 1 && filter[0] == "*" || key in filter) {
            ht.insert (key, val);
        }
    }

    private static void variant_hash_insert (VariantBuilder vb,
                                             string[]       filter,
                                             string         key,
                                             Variant?       val) {
        if (filter.length == 1 && filter[0] == "*" || key in filter) {
            vb.add ("{sv}", key, val);
        }
    }

    /* all genres */

    public GLib.HashTable<string, Variant?>[] get_all_genres (string   path,
                                                              int      offset,
                                                              int      limit,
                                                              string[] filter) throws SqlError {
        GLib.HashTable<string, Variant?>[] genres = {};

        if (this.select_get_all_genres_statement.bind_int (1, limit) != Sqlite.OK) {
            this.throw_last_error ();
        }

        if (this.select_get_all_genres_statement.bind_int (2, offset) != Sqlite.OK) {
            this.throw_last_error ();
        }

        while (this.select_get_all_genres_statement.step () == Sqlite.ROW) {
            GLib.HashTable<string, Variant?> genre =
                new GLib.HashTable<string, Variant?> (GLib.str_hash, GLib.str_equal);

            /* properties MediaObject2 */

            hash_insert(genre, filter, "Parent", new ObjectPath (path));
            hash_insert(genre, filter, "DisplayName",
                this.select_get_all_genres_statement.column_text (1));
            hash_insert(genre, filter, "Path",
                new ObjectPath (path + "/" +
                    this.select_get_all_genres_statement.column_int (0).to_string()));
            hash_insert(genre, filter, "Type", CONTAINER);

            /* properties MediaContainer2 */

            var container_count = new Variant.uint32 (this.select_get_all_genres_statement.column_int (2));
            hash_insert(genre, filter, "ChildCount", container_count);
            hash_insert(genre, filter, "ContainerCount", container_count);
            hash_insert(genre, filter, "ItemCount", new Variant.uint32 (0));
            hash_insert(genre, filter, "Searchable", SEARCHABILITY);

            genres += genre;
        }

        this.select_get_all_genres_statement.reset ();

        return genres;
    }

    public int count_all_genres () throws SqlError {
        int count = -1;

        while (this.select_count_all_genres_statement.step () == Sqlite.ROW) {
            count = this.select_count_all_genres_statement.column_int (0);
        }

        this.select_count_all_genres_statement.reset ();

        return count;
    }

    /* all artists */

    public GLib.HashTable<string, Variant?>[] get_all_artists (string   path,
                                                               int      offset,
                                                               int      limit,
                                                               string[] filter) throws SqlError {
        GLib.HashTable<string, Variant?>[] artists = {};

        if (this.select_get_all_artists_statement.bind_int (1, limit) != Sqlite.OK) {
            this.throw_last_error ();
        }

        if (this.select_get_all_artists_statement.bind_int (2, offset) != Sqlite.OK) {
            this.throw_last_error ();
        }

        while (this.select_get_all_artists_statement.step () == Sqlite.ROW) {
            GLib.HashTable<string, Variant?> artist =
                new GLib.HashTable<string, Variant?> (GLib.str_hash, GLib.str_equal);

            /* properties MediaObject2 */

            hash_insert(artist, filter, "Parent", new ObjectPath (path));
            hash_insert(artist, filter, "DisplayName",
                this.select_get_all_artists_statement.column_text (1));
            hash_insert(artist, filter, "Path",
                new ObjectPath (path + "/" +
                    this.select_get_all_artists_statement.column_int (0).to_string()));
            hash_insert(artist, filter, "Type", CONTAINER);

            /* properties MediaContainer2 */

            var container_count = new Variant.uint32 (
                this.select_get_all_artists_statement.column_int (2));
            hash_insert(artist, filter, "ChildCount", container_count);
            hash_insert(artist, filter, "ContainerCount", container_count);
            hash_insert(artist, filter, "ItemCount", new Variant.uint32 (0));
            hash_insert(artist, filter, "Searchable", SEARCHABILITY);

            artists += artist;
        }

        this.select_get_all_artists_statement.reset ();

        return artists;
    }

    public int count_all_artists () throws SqlError {
        int count = -1;

        while (this.select_count_all_artists_statement.step () == Sqlite.ROW) {
            count = this.select_count_all_artists_statement.column_int (0);
        }

        this.select_count_all_artists_statement.reset ();

        return count;
    }

    /* all albums */

    public GLib.HashTable<string, Variant?>[] get_all_albums (string   path,
                                                              int      offset,
                                                              int      limit,
                                                              string[] filter) throws SqlError {
        GLib.HashTable<string, Variant?>[] albums = {};

        if (this.select_get_all_albums_statement.bind_int (1, limit) != Sqlite.OK) {
            this.throw_last_error ();
        }

        if (this.select_get_all_albums_statement.bind_int (2, offset) != Sqlite.OK) {
            this.throw_last_error ();
        }

        while (this.select_get_all_albums_statement.step () == Sqlite.ROW) {
            GLib.HashTable<string, Variant?> album =
                new GLib.HashTable<string, Variant?> (GLib.str_hash, GLib.str_equal);

            /* properties MediaObject2 */

            hash_insert(album, filter, "Parent", new ObjectPath (path));
            hash_insert(album, filter, "DisplayName",
                this.select_get_all_albums_statement.column_text (3) + " (" +
                this.select_get_all_albums_statement.column_text (2) + ")");
            hash_insert(album, filter, "Path",
                new ObjectPath (path + "/" +
                    this.select_get_all_albums_statement.column_int (0).to_string() + "_" +
                    this.select_get_all_albums_statement.column_int (1).to_string()));
            hash_insert(album, filter, "Type", CONTAINER);

            /* properties MediaContainer2 */

            var item_count = new Variant.uint32 (
                this.select_get_all_albums_statement.column_int (4));
            hash_insert(album, filter, "ChildCount", item_count);
            hash_insert(album, filter, "ItemCount", item_count);
            hash_insert(album, filter, "ContainerCount", new Variant.uint32 (0));
            hash_insert(album, filter, "Searchable", SEARCHABILITY);

            albums += album;
        }

        this.select_get_all_albums_statement.reset ();

        return albums;
    }

    public int count_all_albums () throws SqlError {
        int count = -1;

        while (this.select_count_all_albums_statement.step () == Sqlite.ROW) {
            count = this.select_count_all_albums_statement.column_int (0);
        }

        this.select_count_all_albums_statement.reset ();

        return count;
    }

    /* all songs */

    public GLib.HashTable<string, Variant?>[] get_all_songs (string   path,
                                                             int      offset,
                                                             int      limit,
                                                             string[] filter) throws SqlError {
        GLib.HashTable<string, Variant?>[] songs = {};

        if (this.select_get_all_songs_statement.bind_int (1, limit) != Sqlite.OK) {
            this.throw_last_error ();
        }

        if (this.select_get_all_songs_statement.bind_int (2, offset) != Sqlite.OK) {
            this.throw_last_error ();
        }

        while (this.select_get_all_songs_statement.step () == Sqlite.ROW) {
            GLib.HashTable<string, Variant?> song =
                new GLib.HashTable<string, Variant?> (GLib.str_hash, GLib.str_equal);

            /* properties MediaObject2 */

            hash_insert(song, filter, "Parent", new ObjectPath (path));
            hash_insert(song, filter, "DisplayName",
                this.select_get_all_songs_statement.column_text (5));
            hash_insert(song, filter, "Path",
                new ObjectPath (path + "/" +
                    this.select_get_all_songs_statement.column_int (0).to_string() + "_" +
                    this.select_get_all_songs_statement.column_int (1).to_string() + "_" +
                    this.select_get_all_songs_statement.column_int (2).to_string()));
            hash_insert(song, filter, "Type", MUSIC);

            /* properties MediaItem2 */

            hash_insert(song, filter, "MIMEType",
                this.select_get_all_songs_statement.column_text (14));
            hash_insert(song, filter, "URLs",
                new Variant.strv ({rep_prot (rep_auth (this.select_get_all_songs_statement.column_text (6), this.auth))}));
            hash_insert(song, filter, "Size",
                new Variant.int64 (this.select_get_all_songs_statement.column_int (12)));
            hash_insert(song, filter, "Artist",
                this.select_get_all_songs_statement.column_text (3));
            hash_insert(song, filter, "Album",
                this.select_get_all_songs_statement.column_text (4));
            hash_insert(song, filter, "Date",
                this.select_get_all_songs_statement.column_text (9) + YEAR_DATEPREFIX);
            hash_insert(song, filter, "Genre",
                this.select_get_all_songs_statement.column_text (7));
            hash_insert(song, filter, "Duration",
                new Variant.int32 (this.select_get_all_songs_statement.column_int (11)));
            hash_insert(song, filter, "Bitrate",
                new Variant.int32 (this.select_get_all_songs_statement.column_int (10)));
            string url = this.select_get_all_songs_statement.column_text (13);
            if (url != null && this.art_path != "") {
                hash_insert(song, filter, "AlbumArt",
                    new ObjectPath (this.art_path + "/" + get_artid (url).to_string ()));
            }
            hash_insert(song, filter, "TrackNumber",
                new Variant.int32 (this.select_get_all_songs_statement.column_int (8)));

            songs += song;
        }

        this.select_get_all_songs_statement.reset ();

        return songs;
    }

    public int count_all_songs () throws SqlError {
        int count = -1;

        while (this.select_count_all_songs_statement.step () == Sqlite.ROW) {
            count = this.select_count_all_songs_statement.column_int (0);
        }

        this.select_count_all_songs_statement.reset ();

        return count;
    }

    /* all playlists */

    public GLib.HashTable<string, Variant?>[] get_all_playlists (string   path,
                                                                 int      offset,
                                                                 int      limit,
                                                                 string[] filter) throws SqlError {
        GLib.HashTable<string, Variant?>[] playlists = {};

        if (this.select_get_all_playlists_statement.bind_int (1, limit) != Sqlite.OK) {
            this.throw_last_error ();
        }

        if (this.select_get_all_playlists_statement.bind_int (2, offset) != Sqlite.OK) {
            this.throw_last_error ();
        }

        while (this.select_get_all_playlists_statement.step () == Sqlite.ROW) {
            GLib.HashTable<string, Variant?> playlist =
                new GLib.HashTable<string, Variant?> (GLib.str_hash, GLib.str_equal);

            /* properties MediaObject2 */

            hash_insert(playlist, filter, "Parent", new ObjectPath (path));
            hash_insert(playlist, filter, "DisplayName",
                this.select_get_all_playlists_statement.column_text (1));
            hash_insert(playlist, filter, "Path",
                new ObjectPath (path + "/" +
                    this.select_get_all_playlists_statement.column_int (0).to_string()));
            hash_insert(playlist, filter, "Type", CONTAINER);

            /* properties MediaContainer2 */

            var item_count = new Variant.uint32 (
                this.select_get_all_playlists_statement.column_int (2));
            hash_insert(playlist, filter, "ChildCount", item_count);
            hash_insert(playlist, filter, "ItemCount", new Variant.uint32 (0));
            hash_insert(playlist, filter, "ContainerCount", item_count);
            hash_insert(playlist, filter, "Searchable", SEARCHABILITY);

            playlists += playlist;
        }

        this.select_get_all_playlists_statement.reset ();

        return playlists;
    }

    public int count_all_playlists () throws SqlError {
        int count = -1;

        while (this.select_count_all_playlists_statement.step () == Sqlite.ROW) {
            count = this.select_count_all_playlists_statement.column_int (0);
        }

        this.select_count_all_playlists_statement.reset ();

        return count;
    }

    /* genre artists */

    public Variant get_genre_artists (string   path,
                                      int[]    genre_id,
                                      int      offset,
                                      int      limit,
                                      string[] filter) throws SqlError {
        if (this.select_get_genre_artists_statement.bind_int (1, genre_id[0]) != Sqlite.OK) {
            this.throw_last_error ();
        }

        if (this.select_get_genre_artists_statement.bind_int (2, limit) != Sqlite.OK) {
            this.throw_last_error ();
        }

        if (this.select_get_genre_artists_statement.bind_int (3, offset) != Sqlite.OK) {
            this.throw_last_error ();
        }

        VariantBuilder artists = new VariantBuilder (new VariantType ("aa{sv}"));

        var variant_hash_type = new VariantType ("a{sv}");

        while (this.select_get_genre_artists_statement.step () == Sqlite.ROW) {

            VariantBuilder artist = new VariantBuilder (variant_hash_type);

            /* properties MediaObject2 */

            variant_hash_insert(artist, filter, "Parent",
                new ObjectPath (path));
            variant_hash_insert(artist, filter, "DisplayName",
                this.select_get_genre_artists_statement.column_text (1));
            variant_hash_insert(artist, filter, "Path",
                new ObjectPath (path + "/" +
                    this.select_get_genre_artists_statement.column_int (0).to_string()));
            variant_hash_insert(artist, filter, "Type", CONTAINER);

            /* properties MediaContainer2 */

            var container_count = new Variant.uint32 (
                this.select_get_genre_artists_statement.column_int (2));
            variant_hash_insert(artist, filter, "ChildCount", container_count);
            variant_hash_insert(artist, filter, "ContainerCount", container_count);
            variant_hash_insert(artist, filter, "ItemCount", new Variant.uint32 (0));
            variant_hash_insert(artist, filter, "Searchable", SEARCHABILITY);

            artists.add ("a{sv}", artist);
        }

        this.select_get_genre_artists_statement.reset ();

        return new Variant ("(aa{sv})", artists);
    }

    public int count_genre_artists (int[] genre_id) throws SqlError {
        int count = -1;

        if (this.select_count_genre_artists_statement.bind_int (1, genre_id[0]) != Sqlite.OK) {
            this.throw_last_error ();
        }

        while (this.select_count_genre_artists_statement.step () == Sqlite.ROW) {
            count = this.select_count_genre_artists_statement.column_int (0);
        }

        this.select_count_genre_artists_statement.reset ();

        return count;
    }

    public string identify_genre (int[] genre_id) throws SqlError {
        string genre = "";

        if (this.select_identify_genre_statement.bind_int (1, genre_id[0]) != Sqlite.OK) {
            this.throw_last_error ();
        }

        while (this.select_identify_genre_statement.step () == Sqlite.ROW) {
            genre = this.select_identify_genre_statement.column_text (0);
        }

        this.select_identify_genre_statement.reset ();

        return genre;
    }

    /* artist albums */

    public Variant get_artist_albums (string   path,
                                      int[]    artist_id,
                                      int      offset,
                                      int      limit,
                                      string[] filter) throws SqlError {
        if (this.select_get_artist_albums_statement.bind_int (1, artist_id[0]) != Sqlite.OK) {
            this.throw_last_error ();
        }

        if (this.select_get_artist_albums_statement.bind_int (2, limit) != Sqlite.OK) {
            this.throw_last_error ();
        }

        if (this.select_get_artist_albums_statement.bind_int (3, offset) != Sqlite.OK) {
            this.throw_last_error ();
        }

        VariantBuilder albums = new VariantBuilder (new VariantType ("aa{sv}"));

        var variant_hash_type = new VariantType ("a{sv}");

        while (this.select_get_artist_albums_statement.step () == Sqlite.ROW) {

            VariantBuilder album = new VariantBuilder (variant_hash_type);

            /* properties MediaObject2 */

            variant_hash_insert(album, filter, "Parent",
                new ObjectPath (path));
            variant_hash_insert(album, filter, "DisplayName",
                this.select_get_artist_albums_statement.column_text (3) +
                " (" +
                this.select_get_artist_albums_statement.column_text (2) +
                ")");
            variant_hash_insert(album, filter, "Path",
                new ObjectPath (path + "/" +
                    this.select_get_artist_albums_statement.column_int (0).to_string() + "_" +
                    this.select_get_artist_albums_statement.column_int (1).to_string()));
            variant_hash_insert(album, filter, "Type", CONTAINER);

            /* properties MediaContainer2 */

            var item_count = new Variant.uint32 (
                this.select_get_artist_albums_statement.column_int (4));
            variant_hash_insert(album, filter, "ChildCount", item_count);
            variant_hash_insert(album, filter, "ItemCount", item_count);
            variant_hash_insert(album, filter, "ContainerCount", new Variant.uint32 (0));
            variant_hash_insert(album, filter, "Searchable", SEARCHABILITY);

            albums.add ("a{sv}", album);
        }

        this.select_get_artist_albums_statement.reset ();

        return new Variant ("(aa{sv})", albums);
    }

    public int count_artist_albums (int[] artist_id) throws SqlError {
        int count = -1;

        if (this.select_count_artist_albums_statement.bind_int (1, artist_id[0]) != Sqlite.OK) {
            this.throw_last_error ();
        }

        while (this.select_count_artist_albums_statement.step () == Sqlite.ROW) {
            count = this.select_count_artist_albums_statement.column_int (0);
        }

        this.select_count_artist_albums_statement.reset ();

        return count;
    }

    public string identify_artist (int[] artist_id) throws SqlError {
        string artist = "";

        if (this.select_identify_artist_statement.bind_int (1, artist_id[0]) != Sqlite.OK) {
            this.throw_last_error ();
        }

        while (this.select_identify_artist_statement.step () == Sqlite.ROW) {
            artist = this.select_identify_artist_statement.column_text (0);
        }

        this.select_identify_artist_statement.reset ();

        return artist;
    }

    /* album songs */

    public Variant get_album_songs (string   path,
                                    int[]    artist_album_id,
                                    int      offset,
                                    int      limit,
                                    string[] filter) throws SqlError {
        for (int i = 0; i <= 1; i++) {
            if (this.select_get_album_songs_statement.bind_int (i + 1, artist_album_id[i]) != Sqlite.OK) {
                this.throw_last_error ();
            }
        }

        if (this.select_get_album_songs_statement.bind_int (3, limit) != Sqlite.OK) {
            this.throw_last_error ();
        }

        if (this.select_get_album_songs_statement.bind_int (4, offset) != Sqlite.OK) {
            this.throw_last_error ();
        }

        VariantBuilder songs = new VariantBuilder (new VariantType ("aa{sv}"));

        var variant_hash_type = new VariantType ("a{sv}");

        while (this.select_get_album_songs_statement.step () == Sqlite.ROW) {
            VariantBuilder song = new VariantBuilder (variant_hash_type);

            /* properties MediaObject2 */

            variant_hash_insert(song, filter, "Parent",
                new ObjectPath (path));
            variant_hash_insert(song, filter, "DisplayName",
                this.select_get_album_songs_statement.column_text (5));
            variant_hash_insert(song, filter, "Path",
                new ObjectPath (path + "/" +
                    this.select_get_album_songs_statement.column_int (0).to_string() + "_" +
                    this.select_get_album_songs_statement.column_int (1).to_string() + "_" +
                    this.select_get_album_songs_statement.column_int (2).to_string()));
            variant_hash_insert(song, filter, "Type", MUSIC);

            /* properties MediaItem2 */

            variant_hash_insert(song, filter, "MIMEType",
                this.select_get_album_songs_statement.column_text (14));
            variant_hash_insert(song, filter, "URLs",
                new Variant.strv ({rep_prot (rep_auth (this.select_get_album_songs_statement.column_text (6), this.auth))}));
            variant_hash_insert(song, filter, "Size",
                new Variant.int64 (this.select_get_album_songs_statement.column_int (12)));
            variant_hash_insert(song, filter, "Artist",
                this.select_get_album_songs_statement.column_text (3));
            variant_hash_insert(song, filter, "Album",
                this.select_get_album_songs_statement.column_text (4));
            variant_hash_insert(song, filter, "Date",
                this.select_get_album_songs_statement.column_text (9) + YEAR_DATEPREFIX);
            variant_hash_insert(song, filter, "Genre",
                this.select_get_album_songs_statement.column_text (7));
            variant_hash_insert(song, filter, "Duration",
                new Variant.int32 (this.select_get_album_songs_statement.column_int (11)));
            variant_hash_insert(song, filter, "Bitrate",
                new Variant.int32 (this.select_get_album_songs_statement.column_int (10)));
            string url = this.select_get_album_songs_statement.column_text (13);
            if (url != null && this.art_path != "") {
                variant_hash_insert(song, filter, "AlbumArt",
                    new ObjectPath (this.art_path + "/" + get_artid (url).to_string ()));
            }
            variant_hash_insert(song, filter, "TrackNumber",
                new Variant.int32 (this.select_get_album_songs_statement.column_int (8)));

            songs.add ("a{sv}", song);
        }

        this.select_get_album_songs_statement.reset ();

        return new Variant ("(aa{sv})", songs);
    }

    public int count_album_songs (int[] artist_album_id) throws SqlError {
        int count = -1;

        for (int i = 0; i <= 1; i++) {
            if (this.select_count_album_songs_statement.bind_int (i + 1, artist_album_id[i]) != Sqlite.OK) {
                this.throw_last_error ();
            }
        }

        while (this.select_count_album_songs_statement.step () == Sqlite.ROW) {
            count = this.select_count_album_songs_statement.column_int (0);
        }

        this.select_count_album_songs_statement.reset ();

        return count;
    }

    public string identify_album (int[] artist_album_id) throws SqlError {
        string album = "";

        if (this.select_identify_album_statement.bind_int (1, artist_album_id[1]) != Sqlite.OK) {
            this.throw_last_error ();
        }

        while (this.select_identify_album_statement.step () == Sqlite.ROW) {
            album = this.select_identify_album_statement.column_text (0);
        }

        this.select_identify_album_statement.reset ();

        return album;
    }

    /* song */

    public Variant get_song (string   path,
                             int[]    artist_album_song_id,
                             string[] filter) throws SqlError {
        if (this.select_get_song_statement.bind_int (1, artist_album_song_id[2]) != Sqlite.OK) {
            this.throw_last_error ();
        }

        VariantBuilder song = new VariantBuilder (new VariantType ("a{sv}"));

        while (this.select_get_song_statement.step () == Sqlite.ROW) {

            /* properties MediaObject2 */

            variant_hash_insert(song, filter, "Parent",
                new ObjectPath (path));
            variant_hash_insert(song, filter, "DisplayName",
                this.select_get_song_statement.column_text (5));
            variant_hash_insert(song, filter, "Path",
                new ObjectPath (path + "/" +
                    this.select_get_song_statement.column_int (0).to_string() + "_" +
                    this.select_get_song_statement.column_int (1).to_string() + "_" +
                    this.select_get_song_statement.column_int (2).to_string()));
            variant_hash_insert(song, filter, "Type", MUSIC);

            /* properties MediaItem2 */

            variant_hash_insert(song, filter, "MIMEType",
                this.select_get_song_statement.column_text (14));
            variant_hash_insert(song, filter, "URLs",
                new Variant.strv ({rep_prot (rep_auth (this.select_get_song_statement.column_text (6), this.auth))}));
            variant_hash_insert(song, filter, "Size",
                new Variant.int64 (this.select_get_song_statement.column_int (12)));
            variant_hash_insert(song, filter, "Artist",
                this.select_get_song_statement.column_text (3));
            variant_hash_insert(song, filter, "Album",
                this.select_get_song_statement.column_text (4));
            variant_hash_insert(song, filter, "Date",
                this.select_get_song_statement.column_text (9) + YEAR_DATEPREFIX);
            variant_hash_insert(song, filter, "Genre",
                this.select_get_song_statement.column_text (7));
            variant_hash_insert(song, filter, "Duration",
                new Variant.int32 (this.select_get_song_statement.column_int (11)));
            variant_hash_insert(song, filter, "Bitrate",
                new Variant.int32 (this.select_get_song_statement.column_int (10)));
            string url = this.select_get_song_statement.column_text (13);
            if (url != null && this.art_path != "") {
                variant_hash_insert(song, filter, "AlbumArt",
                    new ObjectPath (this.art_path + "/" + get_artid (url).to_string ()));
            }
            variant_hash_insert(song, filter, "TrackNumber",
                new Variant.int32 (this.select_get_song_statement.column_int (8)));
        }

        this.select_get_song_statement.reset ();

        return new Variant ("a{sv}", song);
    }

    /* playlist songs */

    public Variant get_playlist_songs (string   path,
                                       int[]    playlist_id,
                                       int      offset,
                                       int      limit,
                                       string[] filter) throws SqlError {
        if (this.select_get_playlist_songs_statement.bind_int (1, playlist_id[0]) != Sqlite.OK) {
            this.throw_last_error ();
        }

        if (this.select_get_playlist_songs_statement.bind_int (2, limit) != Sqlite.OK) {
            this.throw_last_error ();
        }

        if (this.select_get_playlist_songs_statement.bind_int (3, offset) != Sqlite.OK) {
            this.throw_last_error ();
        }

        VariantBuilder songs = new VariantBuilder (new VariantType ("aa{sv}"));

        var variant_hash_type = new VariantType ("a{sv}");

        while (this.select_get_playlist_songs_statement.step () == Sqlite.ROW) {
            VariantBuilder song = new VariantBuilder (variant_hash_type);

            /* properties MediaObject2 */

            variant_hash_insert(song, filter, "Parent",
                new ObjectPath (path));
            variant_hash_insert(song, filter, "DisplayName",
                this.select_get_playlist_songs_statement.column_text (5));
            variant_hash_insert(song, filter, "Path",
                new ObjectPath (path + "/" +
                    this.select_get_playlist_songs_statement.column_int (0).to_string() + "_" +
                    this.select_get_playlist_songs_statement.column_int (1).to_string() + "_" +
                    this.select_get_playlist_songs_statement.column_int (2).to_string()));
            variant_hash_insert(song, filter, "Type", MUSIC);

            /* properties MediaItem2 */

            variant_hash_insert(song, filter, "MIMEType",
                this.select_get_playlist_songs_statement.column_text (14));
            variant_hash_insert(song, filter, "URLs",
                new Variant.strv ({rep_prot (rep_auth (this.select_get_playlist_songs_statement.column_text (6), this.auth))}));
            variant_hash_insert(song, filter, "Size",
                new Variant.int64 (this.select_get_playlist_songs_statement.column_int (12)));
            variant_hash_insert(song, filter, "Artist",
                this.select_get_playlist_songs_statement.column_text (3));
            variant_hash_insert(song, filter, "Album",
                this.select_get_playlist_songs_statement.column_text (4));
            variant_hash_insert(song, filter, "Date",
                this.select_get_playlist_songs_statement.column_text (9) + YEAR_DATEPREFIX);
            variant_hash_insert(song, filter, "Genre",
                this.select_get_playlist_songs_statement.column_text (7));
            variant_hash_insert(song, filter, "Duration",
                new Variant.int32 (this.select_get_playlist_songs_statement.column_int (11)));
            variant_hash_insert(song, filter, "Bitrate",
                new Variant.int32 (this.select_get_playlist_songs_statement.column_int (10)));
            string url = this.select_get_playlist_songs_statement.column_text (13);
            if (url != null && this.art_path != "") {
                variant_hash_insert(song, filter, "AlbumArt",
                    new ObjectPath (this.art_path + "/" + get_artid (url).to_string ()));
            }
            variant_hash_insert(song, filter, "TrackNumber",
                new Variant.int32 (this.select_get_playlist_songs_statement.column_int (8)));

            songs.add ("a{sv}", song);
        }

        this.select_get_playlist_songs_statement.reset ();

        return new Variant ("(aa{sv})", songs);
    }

    public int count_playlist_songs (int[] playlist_id) throws SqlError {
        int count = -1;

        if (this.select_count_playlist_songs_statement.bind_int (1, playlist_id[0]) != Sqlite.OK) {
            this.throw_last_error ();
        }

        while (this.select_count_playlist_songs_statement.step () == Sqlite.ROW) {
            count = this.select_count_playlist_songs_statement.column_int (0);
        }

        this.select_count_playlist_songs_statement.reset ();

        return count;
    }

    public string identify_playlist (int[] playlist_id) throws SqlError {
        string playlist = "";

        if (this.select_identify_playlist_statement.bind_int (1, playlist_id[0]) != Sqlite.OK) {
            this.throw_last_error ();
        }

        while (this.select_identify_playlist_statement.step () == Sqlite.ROW) {
            playlist = this.select_identify_playlist_statement.column_text (0);
        }

        this.select_identify_playlist_statement.reset ();

        return playlist;
    }

    /* art */

    public Variant get_art (string path, int[] art_id, string[] filter) throws SqlError {
        if (this.select_get_art_statement.bind_int (1, art_id[0]) != Sqlite.OK) {
            this.throw_last_error ();
        }

        VariantBuilder art = new VariantBuilder (new VariantType ("a{sv}"));

        while (this.select_get_art_statement.step () == Sqlite.ROW) {
            int    id  = this.select_get_art_statement.column_int (0);
            string uri = this.select_get_art_statement.column_text (1);

            /* properties MediaObject2 */

            variant_hash_insert(art, filter, "Parent",
                new ObjectPath ("/org/gnome/UPnP/MediaServer2/Ampache"));
            variant_hash_insert(art, filter, "DisplayName", id.to_string ());
            variant_hash_insert(art, filter, "Path",
                new ObjectPath (path + "/" + id.to_string()));
            variant_hash_insert(art, filter, "Type", IMAGE);

            /* properties MediaItem2 */

            string mt = "image/jpeg";
            switch (get_suffix (uri)) {
                case "jpg": mt = "image/jpeg"; break;
                case "png": mt = "image/png";  break;
            }

            variant_hash_insert(art, filter, "MIMEType", mt);
            variant_hash_insert(art, filter, "URLs",
                new Variant.strv ({rep_prot (rep_auth (uri, this.auth))}));
        }

        this.select_get_art_statement.reset ();

        return new Variant ("a{sv}", art);
    }
}

}
