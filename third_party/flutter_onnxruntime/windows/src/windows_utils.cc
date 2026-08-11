// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#include "windows_utils.h"
#include <Shlwapi.h>
#include <VersionHelpers.h>

namespace flutter_onnxruntime {

std::wstring WindowsUtils::utf8ToWide(const std::string &utf8Str) {
  if (utf8Str.empty()) {
    return std::wstring();
  }

  // Calculate required buffer size
  int size = MultiByteToWideChar(CP_UTF8, 0, utf8Str.c_str(), -1, nullptr, 0);
  if (size <= 0) {
    throw std::runtime_error("Failed to convert UTF-8 string to wide string");
  }

  // Perform conversion
  std::vector<wchar_t> buffer(size);
  int result = MultiByteToWideChar(CP_UTF8, 0, utf8Str.c_str(), -1, buffer.data(), size);
  if (result <= 0) {
    throw std::runtime_error("Failed to convert UTF-8 string to wide string");
  }

  return std::wstring(buffer.data());
}

std::string WindowsUtils::wideToUtf8(const std::wstring &wideStr) {
  if (wideStr.empty()) {
    return std::string();
  }

  // Calculate required buffer size
  int size = WideCharToMultiByte(CP_UTF8, 0, wideStr.c_str(), -1, nullptr, 0, nullptr, nullptr);
  if (size <= 0) {
    throw std::runtime_error("Failed to convert wide string to UTF-8 string");
  }

  // Perform conversion
  std::vector<char> buffer(size);
  int result = WideCharToMultiByte(CP_UTF8, 0, wideStr.c_str(), -1, buffer.data(), size, nullptr, nullptr);
  if (result <= 0) {
    throw std::runtime_error("Failed to convert wide string to UTF-8 string");
  }

  return std::string(buffer.data());
}

std::string WindowsUtils::getLastErrorAsString() {
  DWORD error = GetLastError();
  if (error == 0) {
    return "No error";
  }

  LPSTR messageBuffer = nullptr;
  size_t size =
      FormatMessageA(FORMAT_MESSAGE_ALLOCATE_BUFFER | FORMAT_MESSAGE_FROM_SYSTEM | FORMAT_MESSAGE_IGNORE_INSERTS,
                     nullptr, error, MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT), (LPSTR)&messageBuffer, 0, nullptr);

  if (size == 0) {
    return "Unknown error: " + std::to_string(error);
  }

  std::string message(messageBuffer, size);
  LocalFree(messageBuffer);

  // Remove trailing newlines
  message.erase(
      std::find_if(message.rbegin(), message.rend(), [](unsigned char ch) { return ch != '\r' && ch != '\n'; }).base(),
      message.end());

  return message;
}

std::string WindowsUtils::getAppTempDirectory() {
  // Get system temp directory
  wchar_t tempPath[MAX_PATH];
  DWORD result = GetTempPathW(MAX_PATH, tempPath);

  if (result == 0 || result > MAX_PATH) {
    throw std::runtime_error("Failed to get temporary directory: " + getLastErrorAsString());
  }

  // Create a unique subdirectory for the app
  std::wstring appTempPath = std::wstring(tempPath) + L"flutter_onnxruntime\\";
  CreateDirectoryW(appTempPath.c_str(), nullptr);

  return wideToUtf8(appTempPath);
}

std::string WindowsUtils::normalizePathSeparators(const std::string &path) {
  std::string result = path;
  std::replace(result.begin(), result.end(), '/', '\\');
  return result;
}

bool WindowsUtils::pathExists(const std::string &path) {
  std::wstring widePath = utf8ToWide(path);
  DWORD attributes = GetFileAttributesW(widePath.c_str());
  return attributes != INVALID_FILE_ATTRIBUTES;
}

bool WindowsUtils::createDirectories(const std::string &path) {
  std::wstring widePath = utf8ToWide(path);

  // SHCreateDirectoryEx creates all intermediate directories
  int result = SHCreateDirectoryExW(nullptr, widePath.c_str(), nullptr);

  return (result == ERROR_SUCCESS || result == ERROR_ALREADY_EXISTS);
}

std::string WindowsUtils::getModuleDirectory() {
  wchar_t path[MAX_PATH];
  HMODULE hm = nullptr;

  if (GetModuleHandleExW(GET_MODULE_HANDLE_EX_FLAG_FROM_ADDRESS | GET_MODULE_HANDLE_EX_FLAG_UNCHANGED_REFCOUNT,
                         (LPCWSTR)&WindowsUtils::getModuleDirectory, &hm) == 0) {
    throw std::runtime_error("GetModuleHandleEx failed: " + getLastErrorAsString());
  }

  if (GetModuleFileNameW(hm, path, MAX_PATH) == 0) {
    throw std::runtime_error("GetModuleFileName failed: " + getLastErrorAsString());
  }

  // Extract directory portion
  PathRemoveFileSpecW(path);

  return wideToUtf8(path);
}

bool WindowsUtils::addDllDirectory(const std::string &path) {
  std::wstring widePath = utf8ToWide(path);

  // Add directory to DLL search path
  HMODULE kernel32 = GetModuleHandleW(L"kernel32.dll");
  if (!kernel32) {
    return false;
  }

  typedef DLL_DIRECTORY_COOKIE(WINAPI * AddDllDirectoryFunc)(PCWSTR);
  AddDllDirectoryFunc addDllDirectory = (AddDllDirectoryFunc)GetProcAddress(kernel32, "AddDllDirectory");

  if (!addDllDirectory) {
    // On older Windows versions, fallback to SetDllDirectoryW
    return SetDllDirectoryW(widePath.c_str()) != 0;
  }

  return addDllDirectory(widePath.c_str()) != nullptr;
}

std::string WindowsUtils::getWindowsVersionString() {
  std::stringstream ss;

  if (IsWindows10OrGreater()) {
    ss << "Windows 10+";
  } else if (IsWindows8OrGreater()) {
    ss << "Windows 8";
  } else if (IsWindows7OrGreater()) {
    ss << "Windows 7";
  } else {
    ss << "Windows (older)";
  }

  SYSTEM_INFO sysInfo;
  GetNativeSystemInfo(&sysInfo);
  ss << " " << (sysInfo.wProcessorArchitecture == PROCESSOR_ARCHITECTURE_AMD64 ? "x64" : "x86");

  return ss.str();
}

} // namespace flutter_onnxruntime