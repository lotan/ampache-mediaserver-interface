ENTRY='org.gnome.UPnP.MediaServer2.Ampache'
OBJECT='/org/gnome/UPnP/MediaServer2/Ampache'
#OBJECT='/org/gnome/UPnP/MediaServer2/Artists'
#OBJECT='/org/gnome/UPnP/MediaServer2/Genres/29'
#OBJECT='/org/gnome/UPnP/MediaServer2/Albums/29_9'
#OBJECT='/org/gnome/UPnP/MediaServer2/Albums/81_104'
#OBJECT='/org/gnome/UPnP/MediaServer2/Songs/29_9_181'
#OBJECT='/org/gnome/UPnP/MediaServer2/Art/598'
IS_ITEM=0

echo "MediaObject"
echo "Property: Parent"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaObject2' string:'Parent'
echo "Property: Path"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaObject2' string:'Path'
echo "Property: DisplayName"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaObject2' string:'DisplayName'
echo "Property: Type"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaObject2' string:'Type'
if [ $IS_ITEM == 0 ]; then
echo "MediaContainer"
echo "Property: ChildCount"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaContainer2' string:'ChildCount'
echo "Property: ContainerCount"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaContainer2' string:'ContainerCount'
echo "Property: ItemCount"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaContainer2' string:'ItemCount'
echo "Property: Searchable"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaContainer2' string:'Searchable'
echo "Method: ListChildren"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.gnome.UPnP.MediaContainer2.ListChildren' uint32:0 uint32:100 array:string:"*"
echo "Method: ListContainers"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.gnome.UPnP.MediaContainer2.ListContainers' uint32:0 uint32:100 array:string:"*"
echo "Method: ListItems"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.gnome.UPnP.MediaContainer2.ListItems' uint32:0 uint32:100 array:string:"*"
else
echo "MediaItem"
echo "Property: URLs"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaItem2' string:'URLs'
echo "Property: MIMEType"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaItem2' string:'MIMEType'
echo "Property: Size"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaItem2' string:'Size'
echo "Property: Artist"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaItem2' string:'Artist'
echo "Property: Album"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaItem2' string:'Album'
echo "Property: Date"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaItem2' string:'Date'
echo "Property: Genre"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaItem2' string:'Genre'
#echo "Property: DLNAProfile"
#dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaItem2' string:'DLNAProfile'
echo "Property: Duration"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaItem2' string:'Duration'
echo "Property: Bitrate"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaItem2' string:'Bitrate'
#echo "Property: SampleRate"
#dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaItem2' string:'SampleRate'
#echo "Property: BitsPerSample"
#dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaItem2' string:'BitsPerSample'
echo "Property: AlbumArt"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaItem2' string:'AlbumArt'
echo "Property: TrackNumber"
dbus-send --session --print-reply --dest=$ENTRY $OBJECT 'org.freedesktop.DBus.Properties.Get' string:'org.gnome.UPnP.MediaItem2' string:'TrackNumber'
fi
