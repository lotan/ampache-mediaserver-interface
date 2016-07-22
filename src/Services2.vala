/* Services2.vala
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

namespace MediaServer2 {

private static const string MEDIASERVER2_OBJECT_INTERFACE    = "org.gnome.UPnP.MediaObject2";
private static const string MEDIASERVER2_ITEM_INTERFACE      = "org.gnome.UPnP.MediaItem2";
private static const string MEDIASERVER2_CONTAINER_INTERFACE = "org.gnome.UPnP.MediaContainer2";

private static const string SERVICE_NAME = "org.gnome.UPnP.MediaServer2.Ampache";

private static const string BASE_PATH = "/org/gnome/UPnP/MediaServer2";

private static const string ROOT      = "Ampache";
private static const string GENRES    = "Genres";
private static const string ARTISTS   = "Artists";
private static const string ALBUMS    = "Albums";
private static const string SONGS     = "Songs";
private static const string PLAYLISTS = "Playlists";
private static const string ART       = "Art";

private static const string ROOT_PATH     = BASE_PATH + "/" + ROOT;
private static const string GENRE_PATH    = BASE_PATH + "/" + GENRES;
private static const string ARTIST_PATH   = BASE_PATH + "/" + ARTISTS;
private static const string ALBUM_PATH    = BASE_PATH + "/" + ALBUMS;
private static const string ALL_PATH      = BASE_PATH + "/" + SONGS;
private static const string PLAYLIST_PATH = BASE_PATH + "/" + PLAYLISTS;
private static const string ART_PATH      = BASE_PATH + "/" + ART;

private static const string MEDIASERVER2_XML = """
    <node>
      <interface name='org.gnome.UPnP.MediaObject2'>
        <property name='Parent' type='o' access='read' />
        <property name='Type' type='s' access='read' />
        <property name='Path' type='s' access='read' />
        <property name='DisplayName' type='s' access='read' />
      </interface>
      <interface name='org.gnome.UPnP.MediaItem2'>
        <property name='URLs' type='as' access='read' />
        <property name='MIMEType' type='s' access='read' />
        <property name='Size' type='i' access='read' />
        <property name='Artist' type='s' access='read' />
        <property name='Album' type='s' access='read' />
        <property name='Date' type='s' access='read' />
        <property name='Genre' type='s' access='read' />
        <property name='DLNAProfile' type='s' access='read' />
        <property name='Duration' type='i' access='read' />
        <property name='Bitrate' type='i' access='read' />
        <property name='SampleRate' type='i' access='read' />
        <property name='BitsPerSample' type='i' access='read' />
        <property name='AlbumArt' type='o' access='read' />
        <property name='TrackNumber' type='i' access='read' />
      </interface>
      <interface name='org.gnome.UPnP.MediaContainer2'>
        <method name='ListChildren'>
          <arg direction='in' name='offset' type='u' />
          <arg direction='in' name='max' type='u' />
          <arg direction='in' name='filter' type='as' />
          <arg direction='out' type='aa{sv}' />
        </method>
        <method name='ListContainers'>
          <arg direction='in' name='offset' type='u' />
          <arg direction='in' name='max' type='u' />
          <arg direction='in' name='filter' type='as' />
          <arg direction='out' type='aa{sv}' />
        </method>
        <method name='ListItems'>
          <arg direction='in' name='offset' type='u' />
          <arg direction='in' name='max' type='u' />
          <arg direction='in' name='filter' type='as' />
          <arg direction='out' type='aa{sv}' />
        </method>
        <method name='SearchObjects'>
          <arg direction='in' name='query' type='s' />
          <arg direction='in' name='offset' type='u' />
          <arg direction='in' name='max' type='u' />
          <arg direction='in' name='filter' type='as' />
          <arg direction='out' type='aa{sv}' />
        </method>
        <signal name='Updated' />
        <property name='ChildCount' type='u' access='read' />
        <property name='ItemCount' type='u' access='read' />
        <property name='ContainerCount' type='u' access='read' />
        <property name='Searchable' type='b' access='read' />
        <property name='Icon' type='o' access='read' />
      </interface>
    </node>
    """;

private static DBusNodeInfo dbni = null;

public class RootMediaContainer2 : GLib.Object, MediaContainer2, MediaObject2 {
    private DB db;

    public RootMediaContainer2 (DB db) {
        this.db = db;
    }

    /* properties MediaObject2 */

    public ObjectPath Parent {
        owned get {
            /* root container => ref to itsself */
            return new ObjectPath (ROOT_PATH);
        }
    }

    public string Path {
        owned get {
            return ROOT_PATH;
        }
    }

    public string DisplayName {
        owned get {
            return "Ampache";
        }
    }

    public string Type {
        owned get {
            return DB.CONTAINER;
        }
    }

    /* properties MediaContainer2 */

    public uint ChildCount {
        get {
            return 5;
        }
    }

    public uint ContainerCount {
        get {
            return ChildCount;
        }
    }

    public uint ItemCount {
        get {
            return 0;
        }
    }

    public bool Searchable {
        get {
            return DB.SEARCHABILITY;
        }
    }

    /* methods MediaContainer2 */

    public GLib.HashTable<string, Variant?>[] ListChildren (
        uint offset, uint max, string[] filter) throws DBusError {

        GLib.HashTable<string, Variant?>[] root = {};

        string[] items = {GENRES, ARTISTS, ALBUMS, SONGS, PLAYLISTS};

        foreach (string container_name in items) {
            GLib.HashTable<string, Variant?> container =
                new GLib.HashTable<string, Variant?> (GLib.str_hash, GLib.str_equal);

            /* properties MediaObject2 */

            DB.hash_insert(container, filter, "Parent", new ObjectPath (ROOT_PATH));
            DB.hash_insert(container, filter, "DisplayName", container_name);
            DB.hash_insert(container, filter, "Path", new ObjectPath (BASE_PATH + "/" + container_name));
            DB.hash_insert(container, filter, "Type", DB.CONTAINER);

            /* properties MediaContainer2 */

            unowned AllObjectCount aoc;
            switch (container_name) {
                case GENRES:    aoc = this.db.count_all_genres;    break;
                case ARTISTS:   aoc = this.db.count_all_artists;   break;
                case ALBUMS:    aoc = this.db.count_all_albums;    break;
                case SONGS:     aoc = this.db.count_all_songs;     break;
                case PLAYLISTS: aoc = this.db.count_all_playlists; break;
                default:        aoc = null;                        break;
            }
            Variant count_containers = new Variant.uint32 (0);
            try {
                count_containers = new Variant.uint32 (aoc ());
            } catch (Store.sqlite.SqlError e) {
                GLib.error ("ListContainers error: %s", e.message);
            }
            DB.hash_insert(container, filter, "ChildCount", count_containers);
            DB.hash_insert(container, filter, "ContainerCount", count_containers);
            DB.hash_insert(container, filter, "ItemCount", new Variant.uint32 (0));
            DB.hash_insert(container, filter, "Searchable", DB.SEARCHABILITY);

            root += container;
        }

        return root;
    }

    public GLib.HashTable<string, Variant?>[] ListContainers (
        uint offset, uint max, string[] filter) throws DBusError {

        return ListChildren (offset, max, filter);
    }

    public GLib.HashTable<string, Variant?>[] ListItems (
        uint offset, uint max, string[] filter) throws DBusError {

        return {};
    }

    public GLib.HashTable<string, Variant?>[] SearchObjects (
        string query, uint offset, uint max, string[] filter) throws DBusError {

        return {};
    }
}

public class GenericMediaContainer2 : GLib.Object, MediaContainer2, MediaObject2 {
    private string                  name;
    public  ObjectPath              parent;
    private string                  path;
    private unowned AllObjectCount? child_count;
    private unowned AllGetObjects?  children;
    private bool                    are_children_container;
    private DB                      db;

    public GenericMediaContainer2 (string          name,
                                   string          parent,
                                   string          path,
                                   AllObjectCount? child_count,
                                   AllGetObjects?  children,
                                   bool            are_children_container,
                                   DB              db) {
        this.name = name;
        this.parent = new ObjectPath(parent);
        this.path = path;
        this.child_count = child_count;
        this.children = children;
        this.db = db;
    }

    /* properties MediaObject2 */

    public ObjectPath Parent {
        owned get {
            debug ("get_property <Parent>: " + this.parent.to_string ());
            return this.parent;
        }
    }

    public string Path {
        owned get {
            debug ("get_property <Path>: " + this.path);
            return this.path;
        }
    }

    public string DisplayName {
        owned get {
            debug ("get_property <DisplayName>: " + this.name);
            return this.name;
        }
    }

    public string Type {
        owned get {
            debug ("get_property <Type>: " + DB.CONTAINER);
            return DB.CONTAINER;
        }
    }

    /* properties MediaContainer2 */

    public uint ChildCount {
        get {
            uint cc = 0;
            try {
                cc = (child_count != null) ? child_count () : 0;
            } catch (Store.sqlite.SqlError e) {
                GLib.error ("ChildCount error: %s", e.message);
            }

            debug ("get_property <ChildCount>: " + cc.to_string ());
            return cc;
        }
    }

    public uint ContainerCount {
        get {
            debug ("get_property <ContainerCount>: calling <ChildCount>");
            if (this.are_children_container) {
                return ChildCount;
            } else {
                return 0;
            }
        }
    }

    public uint ItemCount {
        get {
            debug ("get_property <ItemCount>: calling <ChildCount>");
            if (!this.are_children_container) {
                return ChildCount;
            } else {
                return 0;
            }
        }
    }

    public bool Searchable {
        get {
            debug ("get_property <Searchable>: " + DB.SEARCHABILITY.to_string ());
            return DB.SEARCHABILITY;
        }
    }

    /* methods MediaContainer2 */

    public GLib.HashTable<string, Variant?>[] ListChildren (uint     offset,
                                                            uint     max,
                                                            string[] filter) throws DBusError {
        GLib.HashTable<string, Variant?>[] c = {};

        if (children != null) {
            try {
                c = children (this.path, (int) offset, (int) max, filter);
            } catch (Store.sqlite.SqlError e) {
                GLib.error ("ListChildren error: %s", e.message);
            }
        } else {
            GLib.error ("ListChildren error: containers == null");
        }

        debug ("method_call <ListChildren>:");
        for (int i  = 0; i < c.length; i++) {
            debug ("  [" + i.to_string () + "] {");
            foreach (var k in c[i].get_keys ()) {
                debug ("    " + k + ": " + c[i].get (k).print (false));
            }
            debug ("  }");
        }
        return c;
    }

    public GLib.HashTable<string, Variant?>[] ListContainers (uint     offset,
                                                              uint     max,
                                                              string[] filter) throws DBusError {
        debug ("method_call <ListContainers>: calling <ListChildren>");
        if (this.are_children_container) {
            return ListChildren ((int) offset, (int) max, filter);
        } else {
            return {};
        }
    }

    public GLib.HashTable<string, Variant?>[] ListItems (uint     offset,
                                                         uint     max,
                                                         string[] filter) throws DBusError {
        debug ("method_call <ListContainers>: calling <ListChildren>");
        if (!this.are_children_container) {
            return ListChildren ((int) offset, (int) max, filter);
        } else {
            return {};
        }
    }

    public GLib.HashTable<string, Variant?>[] SearchObjects (
        string query, uint offset, uint max, string[] filter) throws DBusError {

        return {};
    }
}

public class SubtreeUserdata {
    public bool                         is_item;
    public Gio_Ext.DBusInterfaceVTable? interface_vtable;
    public GenericContainerSubtree?     container_subtree;
    public GenericItemSubtree?          item_subtree;
}

/**
 * Registers a facility that handles arbitrary dbus items underneath
 * an object path.
 * It doesn't deal with the object path itself.
 */
public class Subtree {
    private DBusConnection  conn;
    private uint            registration_id;
    private SubtreeUserdata user_data;

    public Subtree (DBusConnection                        conn,
                    bool                                  is_item,
                    string                                path,
                    Gio_Ext.DBusInterfaceMethodCallFunc?  method_call,
                    Gio_Ext.DBusInterfaceGetPropertyFunc? get_property,
                    Gio_Ext.DBusInterfaceSetPropertyFunc? set_property,
                    GenericContainerSubtree?              container_subtree,
                    GenericItemSubtree?                   item_subtree) {

        this.conn = conn;

        user_data = new SubtreeUserdata ();

        user_data.is_item = is_item;
        user_data.interface_vtable = Gio_Ext.DBusInterfaceVTable () {
            method_call  = method_call,
            get_property = get_property,
            set_property = set_property};
        user_data.container_subtree = container_subtree;
        user_data.item_subtree = item_subtree;

        var subtree_vtable = Gio_Ext.DBusSubtreeVTable () {
            enumerate  = (connection, sender, object_path, user_data) => {

                return {};
            },
            introspect = (connection, sender, object_path, node, user_data) => {

                SubtreeUserdata su = (SubtreeUserdata) user_data;

                return {dbni.lookup_interface (MEDIASERVER2_OBJECT_INTERFACE),
                        (su.is_item) ? dbni.lookup_interface (MEDIASERVER2_ITEM_INTERFACE) :
                        dbni.lookup_interface (MEDIASERVER2_CONTAINER_INTERFACE)};
            },
            dispatch   = (connection, sender, object_path, interface_name, node,
                          out_user_data, user_data) => {

                SubtreeUserdata su = (SubtreeUserdata) user_data;

                // forward user data to interface_vtable functions
                // (method_call, get_property, set_property)
                *out_user_data = user_data;

                return su.interface_vtable;
            }
        };

        try {
            debug ("Registering subtree '%s'.", path);
            this.registration_id = Gio_Ext.dbus_connection_register_subtree<SubtreeUserdata> (
                this.conn, path, subtree_vtable,
                GLib.DBusSubtreeFlags.DISPATCH_TO_UNENUMERATED_NODES, user_data);
        } catch (Error e) {
            GLib.error ("%s", e.message);
        }
    }
    
    ~Subtree () {
        this.conn.unregister_subtree (this.registration_id);
    }
}

public class GenericContainerSubtree {

    private string                        parent;
    private string                        path;
    private unowned SelectiveObjectCount? child_count;
    private unowned SelectiveGetObjects?  children;
    private unowned IdentifyName?         identify_name;
    private bool                          are_children_container;
    private Subtree                       container_subtree;

    public GenericContainerSubtree (DBusConnection        conn,
                                    string                parent,
                                    string                path,
                                    SelectiveObjectCount? child_count,
                                    SelectiveGetObjects?  children, 
                                    IdentifyName?         identify_name,
                                    bool                  are_children_container,
                                    DB                    db) {
        this.parent                 = parent;
        this.path                   = path;
        this.child_count            = child_count;
        this.children               = children;
        this.identify_name          = identify_name;
        this.are_children_container = are_children_container;

        this.container_subtree = new Subtree (
            conn, false, parent, 
            (connection, sender, object_path, interface_name,
             method_name, parameters, invocation, user_data) => {

                SubtreeUserdata subtree_user_data = user_data as SubtreeUserdata;

                Variant result  = new Variant ("(aa{sv})");

                if ((method_name == "ListChildren" ||
                     method_name == "ListContainers" &&
                         subtree_user_data.container_subtree.are_children_container == true ||
                     method_name == "ListItems"      &&
                         subtree_user_data.container_subtree.are_children_container == false) &&
                    subtree_user_data.container_subtree.children != null) {

                    try {
                        result = subtree_user_data.container_subtree.children (
                            subtree_user_data.container_subtree.path,
                            object_path2ids (object_path),
                            (int) parameters.get_child_value (0).get_uint32 (),
                            (int) parameters.get_child_value (1).get_uint32 (),
                            parameters.get_child_value (2).get_strv ());
                    } catch (Store.sqlite.SqlError e) {
                        GLib.error ("%s error: %s", method_name, e.message);
                    }
                }

                debug ("method_call <" + method_name + "(" + parameters.print (true) + ")>: " + result.print (true));

                invocation.return_value (result);
            },
            (connection, sender, object_path, interface_name,
             property_name, error, user_data) => {

                SubtreeUserdata subtree_user_data = user_data as SubtreeUserdata;

                Variant result;

                switch (property_name) {
                    case "Parent":
                        result = new Variant.object_path (subtree_user_data.container_subtree.path);
                        break;

                    case "Path":
                        result = new Variant.object_path (object_path);
                        break;

                    case "DisplayName":
                        if (subtree_user_data.container_subtree.identify_name != null) {
                            try {
                                result = subtree_user_data.container_subtree.identify_name (
                                    object_path2ids (object_path));
                            } catch (Store.sqlite.SqlError e) {
                                GLib.error ("%s error: %s", property_name, e.message);
                            }
                        } else {
                            result = "";
                        }
                        break;

                    case "Type":
                        result = new Variant.string (DB.CONTAINER);
                        break;

                    case "Searchable":
                        result = new Variant.boolean (DB.SEARCHABILITY);
                        break;

                    default:
                        if ((property_name == "ChildCount" ||
                             property_name == "ContainerCount" &&
                                 subtree_user_data.container_subtree.are_children_container == true ||
                             property_name == "ItemCount"      &&
                                 subtree_user_data.container_subtree.are_children_container == false) &&
                            subtree_user_data.container_subtree.child_count != null) {

                            try {
                                result = new Variant.uint32 (
                                    subtree_user_data.container_subtree.child_count (
                                    object_path2ids (object_path)));
                            } catch (Store.sqlite.SqlError e) {
                                GLib.error ("%s error: %s", property_name, e.message);
                            }
                        } else {
                            result = new Variant.uint32 (0);
                        }
                        break;
                }

                debug ("get_property <" + property_name + "> " + result.print (true));

                return result;
            },
            null, this, null);

        // send Updated signal
        try {
            conn.emit_signal (null, this.parent, MEDIASERVER2_CONTAINER_INTERFACE, "Updated", null);
        } catch (Error e) {
            GLib.error ("Error signal \"Updated\": %s", e.message);
        }
    }
}

public class GenericItemSubtree {
    private string             parent;
    private string             path;
    private Subtree            item_subtree;
    private unowned GetObject? child;
    private DB                 db;

    public GenericItemSubtree (DBusConnection conn,
                               string         parent,
                               string         path,
                               GetObject?     child, 
                               DB             db) {
        this.parent = parent;
        this.path   = path;
        this.child  = child;
        this.db     = db;

        this.item_subtree = new Subtree (
            conn, true, this.parent, null,
            (connection, sender, object_path, interface_name,
             property_name, error, user_data) => {

                SubtreeUserdata subtree_user_data = user_data as SubtreeUserdata;

                Variant result = null;

                Variant item = null;

                try {
                    item = subtree_user_data.item_subtree.child (
                        subtree_user_data.item_subtree.path,
                        object_path2ids (object_path), {"*"});
                } catch (Store.sqlite.SqlError e) {
                    GLib.error ("%s error: %s", property_name, e.message);
                }

                if (item != null) {
                    result = item.lookup_value (property_name, null);
                }
                
                /* all other property_name return 0 */
//                if (result == null) {
//                    result = new Variant.uint32 (0);
//                }

                if (result != null) {
                    debug ("get_property [" + object_path + "]: " + property_name + ": " + result.print (true));
                }

                return result;
            },
            null, null, this);

        /* send Updated signal */
        try {
            conn.emit_signal (null, this.parent, MEDIASERVER2_ITEM_INTERFACE, "Updated", null);
        } catch (Error e) {
            GLib.error ("Error signal \"Updated\": %s", e.message);
        }
    }
}

private static int[] object_path2ids (string object_path) {

    string[] element_strings = object_path.split ("/");
    string[] id_strings = element_strings[element_strings.length - 1].split ("_");
    int[id_strings.length] ids = {0};

    for (int i = 0; i < id_strings.length; i++) {
        ids[i] = int.parse (id_strings[i]);
//        debug ("id: " + ids[i].to_string ());
    }

    return ids;
}

private static uint[] dbus_register_mediacontainer(MediaObject2 o) {
    uint[] ids = {};
    string path = o.Path;

    try {
        debug ("Registering object '%s'.", path);
        ids += conn.register_object (path, o as MediaContainer2);
        ids += conn.register_object (path, o);
    } catch (IOError e) {
        GLib.error ("Unable to register object '%s': %s", path, e.message);
    }

    return ids;
}

// from http://rosettacode.org/wiki/Array_concatenation#Vala
uint[] array_concat (uint[] a, uint[] b) {	
    uint[] c = new uint[a.length + b.length];

    Memory.copy (c, a, a.length * sizeof (uint));
    Memory.copy (&c[a.length], b, b.length * sizeof (uint));
    return c;
}

private static DBusConnection conn;
private static uint bus;

private uint[] object_container_ids;

private DB db;

private RootMediaContainer2     root_container;
private GenericMediaContainer2  genres_container;
private GenericContainerSubtree genre_container_subtree;
private GenericMediaContainer2  artists_container;
private GenericContainerSubtree artist_container_subtree;
private GenericMediaContainer2  albums_container;
private GenericContainerSubtree album_container_subtree;
private GenericMediaContainer2  all_container;
private GenericItemSubtree      all_item_subtree;
private GenericMediaContainer2  playlist_container;
private GenericContainerSubtree playlist_container_subtree;
private GenericItemSubtree      art_item_subtree;

public static void on_bus_acquired (DBusConnection _conn) {
    conn = _conn;

    /* root container */

    root_container = new RootMediaContainer2 (db);
    /* send Updated dbus signal */
    root_container.Updated ();
    array_concat (object_container_ids,
        dbus_register_mediacontainer (root_container));

    /* genre object */

    genres_container = new GenericMediaContainer2 (
        GENRES, ROOT_PATH, GENRE_PATH,
        db.count_all_genres, db.get_all_genres, true, db);
    /* send Updated dbus signal */
    genres_container.Updated ();
    array_concat (object_container_ids,
        dbus_register_mediacontainer (genres_container));

    /* genre subtree */

    genre_container_subtree = new GenericContainerSubtree (
        conn, GENRE_PATH, ARTIST_PATH,
        db.count_genre_artists, db.get_genre_artists,
        db.identify_genre, true, db);

    /* artist object */

    artists_container = new GenericMediaContainer2 (
        ARTISTS, ROOT_PATH, ARTIST_PATH,
        db.count_all_artists, db.get_all_artists, true, db);
    /* send Updated dbus signal */
    artists_container.Updated ();
    array_concat (object_container_ids,
        dbus_register_mediacontainer (artists_container));

    /* artist subtree */

    artist_container_subtree = new GenericContainerSubtree (
        conn, ARTIST_PATH, ALBUM_PATH,
        db.count_artist_albums, db.get_artist_albums,
        db.identify_artist, true, db);

    /* album object */

    albums_container = new GenericMediaContainer2 (
        ALBUMS, ROOT_PATH, ALBUM_PATH,
        db.count_all_albums, db.get_all_albums, true, db);
    /* send Updated dbus signal */
    albums_container.Updated ();
    array_concat (object_container_ids,
        dbus_register_mediacontainer (albums_container));

    /* album subtree */

    album_container_subtree = new GenericContainerSubtree (
        conn, ALBUM_PATH, ALL_PATH,
        db.count_album_songs, db.get_album_songs,
        db.identify_album, false, db);

    /* all object */

    all_container = new GenericMediaContainer2 (
        SONGS, ROOT_PATH, ALL_PATH,
        db.count_all_songs, db.get_all_songs, false, db);
    /* send Updated dbus signal */
    all_container.Updated ();
    array_concat (object_container_ids,
        dbus_register_mediacontainer (all_container));

    /* all subtree */

    all_item_subtree = new GenericItemSubtree (
        conn, ALL_PATH, ALL_PATH, db.get_song, db);

    /* Playlists object */

    playlist_container = new GenericMediaContainer2 (
        PLAYLISTS, ROOT_PATH, PLAYLIST_PATH,
        db.count_all_playlists, db.get_all_playlists, true, db);
    /* send Updated dbus signal */
    playlist_container.Updated ();
    array_concat (object_container_ids,
        dbus_register_mediacontainer (playlist_container));

    /* Playlists subtree */

    playlist_container_subtree = new GenericContainerSubtree (
        conn, PLAYLIST_PATH, ALL_PATH,
        db.count_playlist_songs, db.get_playlist_songs,
        db.identify_playlist, false, db);

    /* art subtree */

    art_item_subtree = new GenericItemSubtree (
        conn, ART_PATH, ART_PATH, db.get_art, db);
}

public static async void start_dbus_services (DB d) {
    db = d;

    db.art_path = ART_PATH;

    try {
        dbni = new DBusNodeInfo.for_xml (MEDIASERVER2_XML);
    } catch (Error e) {
        GLib.error ("%s", e.message);
    }

    message ("Creating D-Bus service %s...", SERVICE_NAME);

    bus = Bus.own_name (BusType.SESSION, SERVICE_NAME, BusNameOwnerFlags.NONE,
                        on_bus_acquired,
                        () => {},
                        () => warning ("Could not acquire name"));
}

public static void stop_dbus_services () {
    message ("Destroying D-Bus service %s...", SERVICE_NAME);

    // unregister all dbus objects

    foreach (var oci in object_container_ids) {
        conn.unregister_object (oci);
    }

    Bus.unown_name (bus);
}

}
