// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#ifndef FLUTTER_PLUGIN_FLUTTER_ONNXRUNTIME_EXPORT_H_
#define FLUTTER_PLUGIN_FLUTTER_ONNXRUNTIME_EXPORT_H_

#ifdef FLUTTER_PLUGIN_IMPL
#define FLUTTER_PLUGIN_EXPORT __attribute__((visibility("default")))
#else
#define FLUTTER_PLUGIN_EXPORT
#endif

#endif // FLUTTER_PLUGIN_FLUTTER_ONNXRUNTIME_EXPORT_H_