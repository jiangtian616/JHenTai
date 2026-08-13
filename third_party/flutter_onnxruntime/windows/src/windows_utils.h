// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#ifndef FLUTTER_ONNXRUNTIME_WINDOWS_UTILS_H_
#define FLUTTER_ONNXRUNTIME_WINDOWS_UTILS_H_

#include "pch.h"

// Include Windows headers
#include <windows.h>

namespace flutter_onnxruntime {

// Utility class for Windows-specific functionality
class WindowsUtils {
public:
  // Convert UTF-8 string to wide (UTF-16) string
  static std::wstring utf8ToWide(const std::string &utf8Str);

  // Convert wide (UTF-16) string to UTF-8 string
  static std::string wideToUtf8(const std::wstring &wideStr);

  // Get last Windows error as string
  static std::string getLastErrorAsString();

  // Get path to application's temporary directory
  static std::string getAppTempDirectory();

  // Convert forward slashes to backslashes
  static std::string normalizePathSeparators(const std::string &path);

  // Check if path exists
  static bool pathExists(const std::string &path);

  // Create directory recursively
  static bool createDirectories(const std::string &path);

  // Get current module directory
  static std::string getModuleDirectory();

  // Add directory to DLL search path
  static bool addDllDirectory(const std::string &path);

  // Get Windows version information
  static std::string getWindowsVersionString();
};

} // namespace flutter_onnxruntime

#endif // FLUTTER_ONNXRUNTIME_WINDOWS_UTILS_H_