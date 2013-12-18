/* Interfaces2.vala
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

[DBus (name = "org.gnome.UPnP.MediaObject2")]
public interface MediaObject2 : GLib.Object {
    public abstract ObjectPath Parent {
        owned get;
    }

    public abstract string DisplayName {
        owned get;
    }

    public abstract string Type {
        owned get;
    }

    public abstract string Path {
        owned get;
    }
}

[DBus (name = "org.gnome.UPnP.MediaContainer2")]
public interface MediaContainer2 : GLib.Object {
    public abstract signal void Updated ();

    public abstract uint ChildCount {
        get;
    }

    public abstract uint ItemCount {
        get;
    }

    public abstract uint ContainerCount {
        get;
    }

    public abstract bool Searchable {
        get;
    }

    public abstract GLib.HashTable<string, Variant?>[] ListChildren (uint     offset,
                                                                     uint     max,
                                                                     string[] filter) throws DBusError;

    public abstract GLib.HashTable<string, Variant?>[] ListContainers (uint     offset,
                                                                       uint     max,
                                                                       string[] filter) throws DBusError;

    public abstract GLib.HashTable<string, Variant?>[] ListItems (uint     offset,
                                                                  uint     max,
                                                                  string[] filter) throws DBusError;
}

[DBus (name = "org.gnome.UPnP.MediaItem2")]
public interface MediaItem2 : GLib.Object {
    public abstract string[] URLs {
        owned get;
    }

    public abstract string MIMEType {
        owned get;
    }
}
