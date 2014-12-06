/* DBItemAdder.vala
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
using Store.sqlite;

namespace Glue {

public class SongAdder : Object {
    private DB db;

    private GLib.HashTable<string, long?> mimetypes;
    private GLib.HashTable<long, string> tags;
    private GLib.HashTable<long, string> artists;
    private GLib.HashTable<long, string> albums;
    private GLib.HashTable<string, long> art;

    private long mimetype_index = 1;

    public SongAdder (DB db) {

        this.db = db;

        this.mimetypes = new GLib.HashTable<string, long> (GLib.str_hash, GLib.str_equal);
        this.tags = new GLib.HashTable<long, string> (direct_hash, direct_equal);
        this.artists = new GLib.HashTable<long, string> (direct_hash, direct_equal);
        this.albums = new GLib.HashTable<long, string> (direct_hash, direct_equal);
        this.art = new GLib.HashTable<string, long> (GLib.str_hash, GLib.str_equal);
    }

    public void add_song (long   song_id,
                          string url,
                          long   artist_id,
                          string artist,
                          long   album_id,
                          string album,
                          string title,
                          long   tag_id,
                          string tag,
                          long   track,
                          long   year,
                          long   bitrate,
                          long   time,
                          long   size,
                          long   rating,
                          string art,
                          string mime) throws SqlError {

        long? mimetype_id = this.mimetypes.get (mime);
        if (mimetype_id == null) {
            mimetype_id = mimetype_index;
            mimetype_index++;
            this.mimetypes.set (mime, mimetype_id);
        }

        if (this.tags.get (tag_id) == null) {
            this.tags.set (tag_id, tag);
        }

        if (this.artists.get (artist_id) == null) {
            this.artists.set (artist_id, artist);
        }
        if (this.albums.get (album_id) == null) {
            this.albums.set (album_id, album);
        }

        long art_id = Store.sqlite.get_artid (art);
        this.art.set (art, art_id);

        db.insert_song (song_id,
                        url,
                        artist_id,
                        album_id,
                        title,
                        tag_id,
                        track,
                        year,
                        bitrate,
                        time,
                        size,
                        rating,
                        art_id,
                        mimetype_id);
    }

    public void store_mimetypes_tags_artists_albums () {
        try {
            foreach (string mt in this.mimetypes.get_keys ()) {
                db.insert_mimetype (mimetypes.get (mt), mt);
            }
            foreach (long t in this.tags.get_keys ()) {
                db.insert_tag (t, tags.get (t));
            }
            foreach (long a in this.artists.get_keys ()) {
                db.insert_artist (a, artists.get (a));
            }
            foreach (long a in this.albums.get_keys ()) {
                db.insert_album (a, albums.get (a));
            }
            foreach (string r in this.art.get_keys ()) {
                db.insert_art (art.get (r), r);
            }
        }
        catch (SqlError e) {
            error ("%s", e.message);
        }
    }
}

public class PlaylistsAdder : Object {
    private unowned DB db;

    public PlaylistsAdder (DB db) {
        this.db = db;
    }

    public void add_playlist (long id, string name) throws SqlError {
        db.insert_playlist (id, name);
    }
}

public class PlaylistAdder : Object {
    private unowned DB db;

    public PlaylistAdder (DB db) {
        this.db = db;
    }

    public void add_song (long id,
                          long playlist_id,
                          long track) throws SqlError {
        db.insert_playlistsong (id, playlist_id, track);
    }
}

}
