//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <quick_blue/quick_blue_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) quick_blue_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "QuickBluePlugin");
  quick_blue_plugin_register_with_registrar(quick_blue_registrar);
}
