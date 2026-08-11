// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#ifndef FLUTTER_ONNXRUNTIME_VALUE_CONVERSION_H_
#define FLUTTER_ONNXRUNTIME_VALUE_CONVERSION_H_

#include "pch.h"

namespace flutter_onnxruntime {

// Utility class for converting between Flutter values and C++ types
class ValueConversion {
public:
  // Convert C++ vector to Flutter EncodableList
  template <typename T> static flutter::EncodableValue vectorToFlValue(const std::vector<T> &vec);

  // Specialization for float vectors
  static flutter::EncodableValue vectorToFlValue(const std::vector<float> &vec);

  // Specialization for int32_t vectors
  static flutter::EncodableValue vectorToFlValue(const std::vector<int32_t> &vec);

  // Specialization for int64_t vectors
  static flutter::EncodableValue vectorToFlValue(const std::vector<int64_t> &vec);

  // Specialization for uint8_t vectors
  static flutter::EncodableValue vectorToFlValue(const std::vector<uint8_t> &vec);

  // Specialization for bool vectors
  static flutter::EncodableValue vectorToFlValue(const std::vector<bool> &vec);

  static flutter::EncodableValue vectorToFlValue(const std::vector<std::string> &vec);
};

} // namespace flutter_onnxruntime

#endif // FLUTTER_ONNXRUNTIME_VALUE_CONVERSION_H_