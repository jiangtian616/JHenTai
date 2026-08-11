// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#ifndef VALUE_CONVERSION_H
#define VALUE_CONVERSION_H

#include <flutter_linux/flutter_linux.h>
#include <map>
#include <string>
#include <vector>

// Convert a C++ vector to a FlValue
template <typename T> FlValue *vector_to_fl_value(const std::vector<T> &vec);

// Specialization for string vectors
template <> FlValue *vector_to_fl_value<std::string>(const std::vector<std::string> &vec);

// Specialization for int vectors
template <> FlValue *vector_to_fl_value<int>(const std::vector<int> &vec);

// Specialization for float vectors
template <> FlValue *vector_to_fl_value<float>(const std::vector<float> &vec);

// Specialization for int32_t vectors
template <> FlValue *vector_to_fl_value<int32_t>(const std::vector<int32_t> &vec);

// Specialization for int64_t vectors
template <> FlValue *vector_to_fl_value<int64_t>(const std::vector<int64_t> &vec);

// Specialization for uint8_t vectors
template <> FlValue *vector_to_fl_value<uint8_t>(const std::vector<uint8_t> &vec);

// Specialization for bool vectors
template <> FlValue *vector_to_fl_value<bool>(const std::vector<bool> &vec);

// Convert a FlValue map to a C++ map
std::map<std::string, FlValue *> fl_value_to_map(FlValue *map_value);

#endif // VALUE_CONVERSION_H