// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#ifndef FLUTTER_ONNXRUNTIME_PCH_H_
#define FLUTTER_ONNXRUNTIME_PCH_H_

// Add commonly included headers to speed up compilation times
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif

#include <algorithm>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <numeric> // For std::accumulate
#include <random>  // For random number generation
#include <sstream> // For std::stringstream
#include <stdexcept>
#include <string>
#include <unordered_map>
#include <utility> // For std::pair
#include <vector>
#include <windows.h>

// ONNX Runtime headers
#include <onnxruntime_cxx_api.h>

// Windows-specific utilities
#include <comdef.h>
#include <shlobj.h>
#include <shlwapi.h>

// Flutter plugin headers
#include <flutter/encodable_value.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#endif // FLUTTER_ONNXRUNTIME_PCH_H_