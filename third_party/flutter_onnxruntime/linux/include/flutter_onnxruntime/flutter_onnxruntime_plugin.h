// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#ifndef FLUTTER_PLUGIN_FLUTTER_ONNXRUNTIME_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_ONNXRUNTIME_PLUGIN_H_

#include <flutter_linux/flutter_linux.h>

G_BEGIN_DECLS

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

typedef struct _FlutterOnnxruntimePlugin FlutterOnnxruntimePlugin;
typedef struct {
  GObjectClass parent_class;
} FlutterOnnxruntimePluginClass;

FLUTTER_PLUGIN_EXPORT GType flutter_onnxruntime_plugin_get_type();

FLUTTER_PLUGIN_EXPORT void flutter_onnxruntime_plugin_register_with_registrar(FlPluginRegistrar *registrar);

G_END_DECLS

#endif // FLUTTER_PLUGIN_FLUTTER_ONNXRUNTIME_PLUGIN_H_