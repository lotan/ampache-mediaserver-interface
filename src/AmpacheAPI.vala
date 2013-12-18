/* AmpacheAPI.vala
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

namespace AmpacheAPI {

const string API_VERSION = "350001";

public class HandshakeDownloader : Object {
    public signal void handshake_downloaded (string data);

    public void download_handshake (string ampache_uri_base, string user, string password256) {

        /* build handshake url */
        
        TimeVal tv = TimeVal ();
        string timestamp = tv.tv_sec.to_string ();
        string auth256 = Checksum.compute_for_string (
            ChecksumType.SHA256,
            timestamp + password256);

        string ampache_server_uri = ampache_uri_base +
           "/server/xml.server.php?action=handshake&auth=" + auth256 +
           "&timestamp=" + timestamp +
           "&user=" + user +
           "&version=" + API_VERSION;

        message ("download handshake: " + ampache_server_uri);

        /* download uri */

        File f = File.new_for_uri (ampache_server_uri);

        f.load_contents_async.begin (null,
                                     (obj, res) => {
            uint8[] characters;
            string etag;

            try {
                f.load_contents_async.end (res, out characters, out etag);
            }
            catch (Error e) {
                error (e.message);
            }

            /* signal download completed */

            handshake_downloaded ((string) (owned) characters);
        });
    }
}

public class ChunkDownloader : Object {
    public signal void chunk_downloaded (string data);
    public signal void download_completed ();

    private string ampache_uri_base;
    private string action;
    private string auth;
    private long   items;
    private long   limit;
    private long   offset;

    private void download_chunk (string action,
                                 string auth,
                                 long   offset,
                                 long   limit) {

        /* build handshake url */
        
        string ampache_server_uri = this.ampache_uri_base +
            "/server/xml.server.php?action=" + action +
            "&auth=" + auth +
            "&offset=" + offset.to_string() +
            "&limit=" + limit.to_string();

        message ("download chunk: " + ampache_server_uri);

        /* download uri */

        File f = File.new_for_uri (ampache_server_uri);

        f.load_contents_async.begin (null, (obj, res) => {

            uint8[] characters;
            string  etag;

            try {
                f.load_contents_async.end (res, out characters, out etag);
            }
            catch (Error e) {
                error (e.message);
            }

            /* signal download completed */

            chunk_downloaded ((string) (owned) characters);

            /* download next chunk */

            iterator ();
        });
    }

    private void iterator() {

        if (this.offset < items) {
            download_chunk (this.action, this.auth, this.offset, this.limit);
            this.offset += this.limit;
        }
        else {
            download_completed ();
        }
    }

    public void download (string ampache_uri_base,
                          string action,
                          string auth,
                          long   items,
                          long   chunk_size) {
        this.ampache_uri_base = ampache_uri_base;
        this.action           = action;
        this.auth             = auth;
        this.items            = items;
        this.limit            = chunk_size;
        this.offset           = 0;

        iterator ();
    }
}

}
