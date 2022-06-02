//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <quick_notify/quick_notify_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) quick_notify_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "QuickNotifyPlugin");
  quick_notify_plugin_register_with_registrar(quick_notify_registrar);
}
