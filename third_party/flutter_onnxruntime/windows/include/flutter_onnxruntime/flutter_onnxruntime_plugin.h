// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#ifndef FLUTTER_ONNXRUNTIME_PLUGIN_H_
#define FLUTTER_ONNXRUNTIME_PLUGIN_H_

#include "export.h"
#include <flutter/plugin_registrar_windows.h>

#if defined(__cplusplus)
extern "C" {
#endif

FLUTTER_PLUGIN_EXPORT void FlutterOnnxruntimePluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
} // extern "C"
#endif

#endif // FLUTTER_ONNXRUNTIME_PLUGIN_H_