#include "include/quick_notify/quick_notify_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <libnotify/notify.h>

#include <cstring>

#define QUICK_NOTIFY_PLUGIN(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), quick_notify_plugin_get_type(), \
                              QuickNotifyPlugin))

struct _QuickNotifyPlugin {
  GObject parent_instance;
};

G_DEFINE_TYPE(QuickNotifyPlugin, quick_notify_plugin, g_object_get_type())

// Called when a method call is received from Flutter.
static void quick_notify_plugin_handle_method_call(
    QuickNotifyPlugin* self,
    FlMethodCall* method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;

  const gchar* method = fl_method_call_get_name(method_call);

  if (strcmp(method, "hasPermission") == 0) {
    g_autoptr(FlValue) result = fl_value_new_bool(true);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "requestPermission") == 0) {
    g_autoptr(FlValue) result = fl_value_new_bool(true);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } else if (strcmp(method, "notify") == 0) {
    FlValue* args = fl_method_call_get_args(method_call);
    const gchar* title = fl_value_get_string(fl_value_lookup_string(args, "title"));
    const gchar* content = fl_value_get_string(fl_value_lookup_string(args, "content"));

    notify_init("quick_notify");
    NotifyNotification *n = notify_notification_new(title, content, 0);
    notify_notification_show(n, 0);
    response = FL_METHOD_RESPONSE(fl_method_success_response_new(nullptr));
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  fl_method_call_respond(method_call, response, nullptr);
}

static void quick_notify_plugin_dispose(GObject* object) {
  G_OBJECT_CLASS(quick_notify_plugin_parent_class)->dispose(object);
}

static void quick_notify_plugin_class_init(QuickNotifyPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = quick_notify_plugin_dispose;
}

static void quick_notify_plugin_init(QuickNotifyPlugin* self) {}

static void method_call_cb(FlMethodChannel* channel, FlMethodCall* method_call,
                           gpointer user_data) {
  QuickNotifyPlugin* plugin = QUICK_NOTIFY_PLUGIN(user_data);
  quick_notify_plugin_handle_method_call(plugin, method_call);
}

void quick_notify_plugin_register_with_registrar(FlPluginRegistrar* registrar) {
  QuickNotifyPlugin* plugin = QUICK_NOTIFY_PLUGIN(
      g_object_new(quick_notify_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel =
      fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                            "quick_notify",
                            FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(channel, method_call_cb,
                                            g_object_ref(plugin),
                                            g_object_unref);

  g_object_unref(plugin);
}