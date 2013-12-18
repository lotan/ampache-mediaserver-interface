/* this extension to Gio exists in order to provide a
 * lower level access to register_object
 * this is needed to avoid a duplicate specification of the mediaserver2
 * interface specification
 */
[CCode (cprefix = "G", gir_namespace = "Gio_Ext", gir_version = "2.0", lower_case_cprefix = "g_")]
namespace Gio_Ext {
    [CCode (cheader_filename = "gio/gio.h", simple_generics = true)]
	public uint dbus_connection_register_subtree<G> (GLib.DBusConnection connection, string object_path, Gio_Ext.DBusSubtreeVTable vtable, GLib.DBusSubtreeFlags flags, owned G data) throws GLib.Error;
    [CCode (cheader_filename = "gio/gio.h", has_type_id = false)] 
    public struct DBusInterfaceVTable { 
        public weak Gio_Ext.DBusInterfaceMethodCallFunc method_call; 
        public weak Gio_Ext.DBusInterfaceGetPropertyFunc get_property; 
        public weak Gio_Ext.DBusInterfaceSetPropertyFunc set_property; 
    }
	[CCode (cheader_filename = "gio/gio.h", has_target = false)]
	public delegate void DBusInterfaceMethodCallFunc (GLib.DBusConnection connection, string sender, string object_path, string interface_name, string method_name, GLib.Variant parameters, GLib.DBusMethodInvocation invocation, void* user_data);
	[CCode (cheader_filename = "gio/gio.h", has_target = false)]
	public delegate GLib.Variant DBusInterfaceGetPropertyFunc (GLib.DBusConnection connection, string sender, string object_path, string interface_name, string property_name, GLib.Error* error, void* user_data);
	[CCode (cheader_filename = "gio/gio.h", has_target = false)]
	public delegate bool DBusInterfaceSetPropertyFunc (GLib.DBusConnection connection, string sender, string object_path, string interface_name, string property_name, GLib.Variant value, GLib.Error* error, void* user_data);
	[CCode (cheader_filename = "gio/gio.h", has_type_id = false)]
	public struct DBusSubtreeVTable {
		public weak Gio_Ext.DBusSubtreeEnumerateFunc enumerate;
		public weak Gio_Ext.DBusSubtreeIntrospectFunc introspect;
		public weak Gio_Ext.DBusSubtreeDispatchFunc dispatch;
	}
	[CCode (array_length = false, array_null_terminated = true, cheader_filename = "gio/gio.h", has_target = false)]
	public delegate string[] DBusSubtreeEnumerateFunc (GLib.DBusConnection connection, string sender, string object_path, void* user_data);
	[CCode (array_length = false, array_null_terminated = true, cheader_filename = "gio/gio.h", has_target = false)]
	public delegate GLib.DBusInterfaceInfo[] DBusSubtreeIntrospectFunc (GLib.DBusConnection connection, string sender, string object_path, string node, void* user_data);
	[CCode (cheader_filename = "gio/gio.h", has_target = false)]
	public delegate unowned Gio_Ext.DBusInterfaceVTable? DBusSubtreeDispatchFunc (GLib.DBusConnection connection, string sender, string object_path, string interface_name, string node, void** out_user_data, void* user_data);
}
