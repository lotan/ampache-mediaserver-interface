/* XMLParsing.vala
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
using Xml;

namespace XMLParsing {

public class SAXChunkParser : Object {
    protected string ch;

    public signal void xml_parsed ();

    protected virtual void start_element (string name, string[] atts) {
        this.ch = null;
    }

    protected virtual void end_element (string name) {
    }

    private void end_document () {
        xml_parsed ();
    }

    private void characters (string ch, int len) {
        this.ch = ch[0:len];
    }

    private void fatal_error (string msg) {
        GLib.error (msg);
    }

    private void error (string msg) {
        GLib.error (msg);
    }

    private void warning (string msg) {
        GLib.warning (msg);
    }

    public void parse (string buffer) {

        var handler = SAXHandler ();
        handler.startElement = start_element;
        handler.endElement = end_element;
        handler.endDocument = end_document;
        handler.characters = characters;
        handler.fatalError = fatal_error;
        handler.error = error;
        handler.warning = warning;

        var pctx = new ParserCtxt.create_push (
           &handler, this, (char []) buffer.data, buffer.length, null);
        pctx.parse_chunk ((char []) "".data, 0, true);
    }
}

public class HandshakeParser : SAXChunkParser {

    public string auth      { get; private set; }
    public long   update    { get; private set; }
    public long   add       { get; private set; }
    public long   clean     { get; private set; }
    public long   songs     { get; private set; }
    public long   playlists { get; private set; }

    protected override void end_element (string name) {
        base.end_element(name);
        TimeVal tv = TimeVal ();
        switch (name) {
            case "auth":       this.auth = this.ch; break;
            case "update":     tv.from_iso8601 (this.ch); this.update = tv.tv_sec; break;
            case "add":        tv.from_iso8601 (this.ch); this.add    = tv.tv_sec; break;
            case "clean":      tv.from_iso8601 (this.ch); this.clean  = tv.tv_sec; break;
            case "songs":      this.songs = int.parse(this.ch); break;
            case "playlists":  this.playlists = int.parse(this.ch); break;
        }
    }
}

public class SongsParser : SAXChunkParser {
    private long   song_id;
    private string url;
    private long   artist_id;
    private string artist;
    private long   album_id;
    private string album;
    private string title;
    private long   tag_id;
    private string tag;
    private long   track;
    private long   year;
    private long   bitrate;
    private long   time;
    private long   size;
    private long   rating;
    private string art;
    private string mime;

    private static string[] idtags = {"song", "artist", "album", "tag"};

    public SongsParser () {
        init ();
    }

    private void init () {
        song_id   = 0;
        url       = "";
        artist_id = 0;
        artist    = "";
        album_id  = 0;
        album     = "";
        title     = "";
        tag_id    = 0;
        tag       = "";
        track     = 0;
        year      = 0;
        bitrate   = 0;
        time      = 0;
        size      = 0;
        rating    = 0;
        art       = "";
        mime      = "";
    }

    public signal void song_parsed (long   song_id,
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
                                    string mime);

    protected override void start_element (string name, string[] atts) {
        base.start_element(name, atts);
        if (name in idtags) {
            for (int i = 0; i < atts.length; i += 2) {
                if (atts[i] == "id") {
                    switch (name) {
                        case "song":   this.song_id = int.parse(atts[i + 1]);   break;
                        case "artist": this.artist_id = int.parse(atts[i + 1]); break;
                        case "album":  this.album_id = int.parse(atts[i + 1]);  break;
                        case "tag":    this.tag_id = int.parse(atts[i + 1]);    break;
                    }
                }
            }
        }
    }

    protected override void end_element (string name) {
        base.end_element(name);
        switch (name) {
            case "url":     this.url = this.ch;                break;
            case "artist":  this.artist = this.ch;             break;
            case "album":   this.album = this.ch;              break;
            case "title":   this.title = this.ch;              break;
            case "tag":     this.tag = this.ch;                break;
            case "track":   this.track = int.parse(this.ch);   break;
            case "year":    this.year = int.parse(this.ch);    break;
            case "bitrate": this.bitrate = int.parse(this.ch); break;
            case "time":    this.time = int.parse(this.ch);    break;
            case "size":    this.size = int.parse(this.ch);    break;
            case "rating":  this.rating = int.parse(this.ch);  break;
            case "art":     this.art = this.ch;                break;
            case "mime":    this.mime = this.ch;               break;
                           
            case "song":    song_parsed (this.song_id,
                                         this.url,
                                         this.artist_id,
                                         this.artist,
                                         this.album_id,
                                         this.album,
                                         this.title,
                                         this.tag_id,
                                         this.tag,
                                         this.track,
                                         this.year,
                                         this.bitrate,
                                         this.time,
                                         this.size,
                                         this.rating,
                                         this.art,
                                         this.mime);
                            init ();
                            break;
        }
    }
}

public class PlaylistsParser : SAXChunkParser {
    private long   playlist_id;
    private string name;
    private long   items;
    private string owner;
    private string type;

    public PlaylistsParser () {
        init ();
    }

    private void init () {
        playlist_id = 0;
        name        = "";
        items       = 0;
        owner       = "";
        type        = "";
    }

    public signal void playlist_parsed (long   playlist_id,
                                        string name,
                                        long   items,
                                        string owner,
                                        string type);

    protected override void start_element (string name, string[] atts) {
        base.start_element(name, atts);
        if (name == "playlist") {
            for (int i = 0; i < atts.length; i += 2) {
                if (atts[i] == "id") {
                    this.playlist_id = int.parse(atts[i + 1]);
                }
            }
        }
    }

    protected override void end_element (string name) {
        base.end_element(name);
        switch (name) {
            case "name":  this.name = this.ch;              break;
            case "items": this.items = int.parse (this.ch); break;
            case "owner": this.owner = this.ch;             break;
            case "type":  this.type = this.ch;              break;
                           
            case "playlist":  playlist_parsed (this.playlist_id,
                                               this.name,
                                               this.items,
                                               this.owner,
                                               this.type);
                              init ();
                              break;
        }
    }
}

}
