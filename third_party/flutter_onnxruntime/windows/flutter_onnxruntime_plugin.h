// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#ifndef FLUTTER_PLUGIN_FLUTTER_ONNXRUNTIME_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_ONNXRUNTIME_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_onnxruntime {

// Forward declaration
class FlutterOnnxruntimePluginImpl;

class FlutterOnnxruntimePlugin : public flutter::Plugin {
public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterOnnxruntimePlugin();

  virtual ~FlutterOnnxruntimePlugin();

  // Disallow copy and assign.
  FlutterOnnxruntimePlugin(const FlutterOnnxruntimePlugin &) = delete;
  FlutterOnnxruntimePlugin &operator=(const FlutterOnnxruntimePlugin &) = delete;

private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                        std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Session management method handlers
  void HandleCreateSession(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void HandleGetAvailableProviders(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                                   std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void HandleGetRuntimeInfo(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void HandleRunInference(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void HandleCloseSession(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void HandleGetMetadata(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                         std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void HandleGetInputInfo(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                          std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void HandleGetOutputInfo(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                           std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // OrtValue method handlers
  void HandleCreateOrtValue(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                            std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void HandleConvertOrtValue(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void HandleGetOrtValueData(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  void HandleReleaseOrtValue(const flutter::MethodCall<flutter::EncodableValue> &method_call,
                             std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Private implementation
  std::unique_ptr<FlutterOnnxruntimePluginImpl> impl_;
};

} // namespace flutter_onnxruntime

#endif // FLUTTER_PLUGIN_FLUTTER_ONNXRUNTIME_PLUGIN_H_
