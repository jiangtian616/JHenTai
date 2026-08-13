// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#include "value_conversion.h"

namespace flutter_onnxruntime {

// Specialization for float vectors
flutter::EncodableValue ValueConversion::vectorToFlValue(const std::vector<float> &vec) {
  flutter::EncodableList result;
  result.reserve(vec.size());

  for (const auto &val : vec) {
    result.push_back(static_cast<double>(val));
  }

  return flutter::EncodableValue(result);
}

// Specialization for int32_t vectors
flutter::EncodableValue ValueConversion::vectorToFlValue(const std::vector<int32_t> &vec) {
  flutter::EncodableList result;
  result.reserve(vec.size());

  for (const auto &val : vec) {
    result.push_back(val);
  }

  return flutter::EncodableValue(result);
}

// Specialization for int64_t vectors
flutter::EncodableValue ValueConversion::vectorToFlValue(const std::vector<int64_t> &vec) {
  flutter::EncodableList result;
  result.reserve(vec.size());

  for (const auto &val : vec) {
    result.push_back(val);
  }

  return flutter::EncodableValue(result);
}

// Specialization for uint8_t vectors
flutter::EncodableValue ValueConversion::vectorToFlValue(const std::vector<uint8_t> &vec) {
  flutter::EncodableList result;
  result.reserve(vec.size());

  for (const auto &val : vec) {
    result.push_back(static_cast<int32_t>(val));
  }

  return flutter::EncodableValue(result);
}

// Specialization for bool vectors
flutter::EncodableValue ValueConversion::vectorToFlValue(const std::vector<bool> &vec) {
  flutter::EncodableList result;
  result.reserve(vec.size());

  for (size_t i = 0; i < vec.size(); i++) {
    // bool values have to be converted to int for Flutter compatibility
    result.push_back(vec[i] ? 1 : 0);
  }

  return flutter::EncodableValue(result);
}

// Specialization for string vectors
flutter::EncodableValue ValueConversion::vectorToFlValue(const std::vector<std::string> &vec) {
  flutter::EncodableList result;
  result.reserve(vec.size());

  for (size_t i = 0; i < vec.size(); i++) {
    result.push_back(vec[i]);
  }

  return flutter::EncodableValue(result);
}
} // namespace flutter_onnxruntime