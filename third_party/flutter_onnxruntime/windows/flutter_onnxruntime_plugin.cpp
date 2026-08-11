// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#include "flutter_onnxruntime_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>

// For getPlatformVersion; remove unless needed for your plugin implementation.
#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

// Include our implementation headers
#include "src/session_manager.h"
#include "src/tensor_manager.h"
#include "src/value_conversion.h"
#include "src/windows_utils.h"

#include "include/flutter_onnxruntime/export.h"

namespace flutter_onnxruntime {

// Private implementation class to hold managers
class FlutterOnnxruntimePluginImpl {
public:
  FlutterOnnxruntimePluginImpl()
      : sessionManager_(std::make_unique<SessionManager>()), tensorManager_(std::make_unique<TensorManager>()) {}

  // Manager instances
  std::unique_ptr<SessionManager> sessionManager_;
  std::unique_ptr<TensorManager> tensorManager_;
};

// static
void FlutterOnnxruntimePlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar) {
  auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      registrar->messenger(), "flutter_onnxruntime", &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterOnnxruntimePlugin>();

  channel->SetMethodCallHandler([plugin_pointer = plugin.get()](const auto &call, auto result) {
    plugin_pointer->HandleMethodCall(call, std::move(result));
  });

  registrar->AddPlugin(std::move(plugin));
}

FlutterOnnxruntimePlugin::FlutterOnnxruntimePlugin() : impl_(std::make_unique<FlutterOnnxruntimePluginImpl>()) {}

FlutterOnnxruntimePlugin::~FlutterOnnxruntimePlugin() {}

void FlutterOnnxruntimePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto &method_name = method_call.method_name();

  if (method_name == "getPlatformVersion") {
    std::ostringstream version_stream;
    if (IsWindows10OrGreater()) {
      version_stream << "Windows 10+";
    } else if (IsWindows8OrGreater()) {
      version_stream << "Windows 8";
    } else if (IsWindows7OrGreater()) {
      version_stream << "Windows 7";
    }
    result->Success(flutter::EncodableValue(version_stream.str()));
    return;
  }

  // OrtValue-related methods
  if (method_name == "createOrtValue") {
    HandleCreateOrtValue(method_call, std::move(result));
    return;
  } else if (method_name == "convertOrtValue") {
    HandleConvertOrtValue(method_call, std::move(result));
    return;
  } else if (method_name == "getOrtValueData") {
    HandleGetOrtValueData(method_call, std::move(result));
    return;
  } else if (method_name == "releaseOrtValue") {
    HandleReleaseOrtValue(method_call, std::move(result));
    return;
  }

  // Session-related methods
  if (method_name == "createSession") {
    HandleCreateSession(method_call, std::move(result));
    return;
  } else if (method_name == "getAvailableProviders") {
    HandleGetAvailableProviders(method_call, std::move(result));
    return;
  } else if (method_name == "getRuntimeInfo") {
    HandleGetRuntimeInfo(method_call, std::move(result));
    return;
  } else if (method_name == "runInference") {
    HandleRunInference(method_call, std::move(result));
    return;
  } else if (method_name == "closeSession") {
    HandleCloseSession(method_call, std::move(result));
    return;
  } else if (method_name == "getMetadata") {
    HandleGetMetadata(method_call, std::move(result));
    return;
  } else if (method_name == "getInputInfo") {
    HandleGetInputInfo(method_call, std::move(result));
    return;
  } else if (method_name == "getOutputInfo") {
    HandleGetOutputInfo(method_call, std::move(result));
    return;
  }

  result->NotImplemented();
}

void FlutterOnnxruntimePlugin::HandleCreateOrtValue(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  // Extract parameters
  const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());

  if (!args) {
    result->Error("INVALID_ARG", "Arguments must be provided as a map", nullptr);
    return;
  }

  try {
    // Extract source type
    auto source_type_it = args->find(flutter::EncodableValue("sourceType"));
    if (source_type_it == args->end() || !std::holds_alternative<std::string>(source_type_it->second)) {
      result->Error("INVALID_ARG", "Source type must be a non-null string", nullptr);
      return;
    }
    std::string source_type = std::get<std::string>(source_type_it->second);

    // Extract data
    auto data_it = args->find(flutter::EncodableValue("data"));
    if (data_it == args->end()) {
      result->Error("INVALID_ARG", "Data must be provided", nullptr);
      return;
    }
    const flutter::EncodableValue &data_value = data_it->second;

    // Extract shape
    auto shape_it = args->find(flutter::EncodableValue("shape"));
    if (shape_it == args->end() || !std::holds_alternative<flutter::EncodableList>(shape_it->second)) {
      result->Error("INVALID_ARG", "Shape must be a non-null list", nullptr);
      return;
    }

    // Convert shape to vector<int64_t>
    const flutter::EncodableList &shape_list = std::get<flutter::EncodableList>(shape_it->second);
    std::vector<int64_t> shape;
    shape.reserve(shape_list.size());
    for (const auto &dim : shape_list) {
      if (std::holds_alternative<int32_t>(dim)) {
        shape.push_back(std::get<int32_t>(dim));
      } else if (std::holds_alternative<int64_t>(dim)) {
        shape.push_back(std::get<int64_t>(dim));
      } else {
        result->Error("INVALID_ARG", "Shape dimensions must be integers", nullptr);
        return;
      }
    }

    // Create tensor based on source type
    // check if data_value is a typed list
    // Note: Typed list in Dart is EncodableValue type
    // List<T> in Dart is EncodableList type
    // Dart always pass typed list except for bool
    std::string tensor_id;
    if (source_type == "float32") {
      if (!std::holds_alternative<std::vector<float>>(data_value)) {
        result->Error("INVALID_ARG", "Float32 data must be a list", nullptr);
        return;
      }
      std::vector<float> float_data = std::get<std::vector<float>>(data_value);
      tensor_id = impl_->tensorManager_->createFloat32Tensor(float_data, shape);
    } else if (source_type == "int32") {
      if (!std::holds_alternative<std::vector<int32_t>>(data_value)) {
        result->Error("INVALID_ARG", "Int32 data must be a list", nullptr);
        return;
      }
      std::vector<int32_t> int32_data = std::get<std::vector<int32_t>>(data_value);
      tensor_id = impl_->tensorManager_->createInt32Tensor(int32_data, shape);
    } else if (source_type == "int64") {
      if (!std::holds_alternative<std::vector<int64_t>>(data_value)) {
        result->Error("INVALID_ARG", "Int64 data must be a list", nullptr);
        return;
      }
      std::vector<int64_t> int64_data = std::get<std::vector<int64_t>>(data_value);
      tensor_id = impl_->tensorManager_->createInt64Tensor(int64_data, shape);
    } else if (source_type == "uint8") {
      if (!std::holds_alternative<std::vector<uint8_t>>(data_value)) {
        result->Error("INVALID_ARG", "Uint8 data must be a list", nullptr);
        return;
      }
      std::vector<uint8_t> uint8_data = std::get<std::vector<uint8_t>>(data_value);
      tensor_id = impl_->tensorManager_->createUint8Tensor(uint8_data, shape);
    } else if (source_type == "bool") {
      // Note: for bool values, Dart always pass a List<bool>, not a typed list
      if (!std::holds_alternative<flutter::EncodableList>(data_value)) {
        result->Error("INVALID_ARG", "Bool data must be a list", nullptr);
        return;
      }
      auto bool_data_list = std::get<flutter::EncodableList>(data_value);
      std::vector<bool> bool_data;
      bool_data.reserve(bool_data_list.size());

      for (const auto &item : bool_data_list) {
        if (std::holds_alternative<bool>(item)) {
          bool_data.push_back(std::get<bool>(item));
        } else if (std::holds_alternative<int32_t>(item)) {
          bool_data.push_back(std::get<int32_t>(item) != 0);
        }
      }
      tensor_id = impl_->tensorManager_->createBoolTensor(bool_data, shape);
    } else if (source_type == "string") {
      if (!std::holds_alternative<flutter::EncodableList>(data_value)) {
        result->Error("INVALID_ARG", "String data must be a list of strings", nullptr);
        return;
      }
      auto string_data_list = std::get<flutter::EncodableList>(data_value);
      std::vector<std::string> string_data;
      string_data.reserve(string_data_list.size());

      for (const auto &item : string_data_list) {
        if (std::holds_alternative<std::string>(item)) {
          string_data.push_back(std::get<std::string>(item));
        }
      }
      tensor_id = impl_->tensorManager_->createStringTensor(string_data, shape);
    } else {
      result->Error("INVALID_ARG", "Unsupported data type: " + source_type, nullptr);
      return;
    }

    // Return success with the tensor ID
    flutter::EncodableMap response;
    response[flutter::EncodableValue("valueId")] = flutter::EncodableValue(tensor_id);
    response[flutter::EncodableValue("dataType")] = flutter::EncodableValue(source_type);

    // Convert shape to Flutter list
    flutter::EncodableList response_shape;
    for (const auto &dim : shape) {
      response_shape.push_back(static_cast<int64_t>(dim));
    }
    response[flutter::EncodableValue("shape")] = flutter::EncodableValue(response_shape);

    result->Success(flutter::EncodableValue(response));
  } catch (const Ort::Exception &e) {
    result->Error("ORT_ERROR", e.what(), nullptr);
  } catch (const std::exception &e) {
    result->Error("PLUGIN_ERROR", e.what(), nullptr);
  } catch (...) {
    result->Error("INTERNAL_ERROR", "Unknown error occurred", nullptr);
  }
}

void FlutterOnnxruntimePlugin::HandleConvertOrtValue(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  // Extract parameters
  const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());

  if (!args) {
    result->Error("INVALID_ARG", "Arguments must be provided as a map", nullptr);
    return;
  }

  try {
    // Extract value ID
    auto value_id_it = args->find(flutter::EncodableValue("valueId"));
    if (value_id_it == args->end() || !std::holds_alternative<std::string>(value_id_it->second)) {
      result->Error("INVALID_ARG", "Value ID must be a non-null string", nullptr);
      return;
    }
    std::string value_id = std::get<std::string>(value_id_it->second);

    // Extract target type
    auto target_type_it = args->find(flutter::EncodableValue("targetType"));
    if (target_type_it == args->end() || !std::holds_alternative<std::string>(target_type_it->second)) {
      result->Error("INVALID_ARG", "Target type must be a non-null string", nullptr);
      return;
    }
    std::string target_type = std::get<std::string>(target_type_it->second);

    std::string new_tensor_id;
    try {
      // Convert the tensor
      new_tensor_id = impl_->tensorManager_->convertTensor(value_id, target_type);
    } catch (const std::exception &e) {
      result->Error("CONVERSION_ERROR", e.what(), nullptr);
      return;
    }

    // Get the tensor shape
    std::vector<int64_t> shape = impl_->tensorManager_->getTensorShape(new_tensor_id);

    // Convert shape to Flutter list
    flutter::EncodableList shape_list;
    for (const auto &dim : shape) {
      shape_list.push_back(static_cast<int64_t>(dim));
    }

    // Return success with the new tensor ID
    flutter::EncodableMap response;
    response[flutter::EncodableValue("valueId")] = flutter::EncodableValue(new_tensor_id);
    response[flutter::EncodableValue("dataType")] = flutter::EncodableValue(target_type);
    response[flutter::EncodableValue("shape")] = flutter::EncodableValue(shape_list);

    result->Success(flutter::EncodableValue(response));
  } catch (const Ort::Exception &e) {
    result->Error("ORT_ERROR", e.what(), nullptr);
  } catch (const std::exception &e) {
    result->Error("PLUGIN_ERROR", e.what(), nullptr);
  } catch (...) {
    result->Error("INTERNAL_ERROR", "Unknown error occurred", nullptr);
  }
}

void FlutterOnnxruntimePlugin::HandleGetOrtValueData(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  // Extract parameters
  const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());

  if (!args) {
    result->Error("INVALID_ARG", "Arguments must be provided as a map", nullptr);
    return;
  }

  try {
    // Extract value ID
    auto value_id_it = args->find(flutter::EncodableValue("valueId"));
    if (value_id_it == args->end() || !std::holds_alternative<std::string>(value_id_it->second)) {
      result->Error("INVALID_ARG", "Value ID must be a non-null string", nullptr);
      return;
    }
    std::string value_id = std::get<std::string>(value_id_it->second);

    // check if the tensor exists
    Ort::Value *tensor = impl_->tensorManager_->getTensor(value_id);
    if (!tensor) {
      result->Error("INVALID_VALUE", "Tensor not found or already being disposed", nullptr);
      return;
    }

    // Get the tensor data
    flutter::EncodableValue tensor_data = impl_->tensorManager_->getTensorData(value_id);

    // Return success with the tensor data
    result->Success(tensor_data);
  } catch (const Ort::Exception &e) {
    result->Error("ORT_ERROR", e.what(), nullptr);
  } catch (const std::exception &e) {
    result->Error("PLUGIN_ERROR", e.what(), nullptr);
  } catch (...) {
    result->Error("INTERNAL_ERROR", "Unknown error occurred", nullptr);
  }
}

void FlutterOnnxruntimePlugin::HandleReleaseOrtValue(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  // Extract parameters
  const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());

  if (!args) {
    result->Error("INVALID_ARG", "Arguments must be provided as a map", nullptr);
    return;
  }

  try {
    // Extract value ID
    auto value_id_it = args->find(flutter::EncodableValue("valueId"));
    if (value_id_it == args->end() || !std::holds_alternative<std::string>(value_id_it->second)) {
      result->Error("INVALID_ARG", "Value ID must be a non-null string", nullptr);
      return;
    }
    std::string value_id = std::get<std::string>(value_id_it->second);

    // Release the tensor
    bool success = impl_->tensorManager_->releaseTensor(value_id);

    // Return success status
    if (success) {
      result->Success(nullptr);
    } else {
      result->Error("INVALID_VALUE", "Tensor not found", nullptr);
    }
  } catch (const Ort::Exception &e) {
    result->Error("ORT_ERROR", e.what(), nullptr);
  } catch (const std::exception &e) {
    result->Error("PLUGIN_ERROR", e.what(), nullptr);
  } catch (...) {
    result->Error("INTERNAL_ERROR", "Unknown error occurred", nullptr);
  }
}

void FlutterOnnxruntimePlugin::HandleCreateSession(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  // Extract parameters
  const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());

  if (!args) {
    result->Error("INVALID_ARG", "Arguments must be provided as a map", nullptr);
    return;
  }

  try {
    // Extract model path
    auto model_path_it = args->find(flutter::EncodableValue("modelPath"));
    if (model_path_it == args->end() || !std::holds_alternative<std::string>(model_path_it->second)) {
      result->Error("INVALID_ARG", "Model path must be a non-null string", nullptr);
      return;
    }
    std::string model_path = std::get<std::string>(model_path_it->second);

    // Create session options
    Ort::SessionOptions session_options;

    // Configure session options if provided
    auto session_options_it = args->find(flutter::EncodableValue("sessionOptions"));
    if (session_options_it != args->end() &&
        std::holds_alternative<flutter::EncodableMap>(session_options_it->second)) {

      const auto &options_map = std::get<flutter::EncodableMap>(session_options_it->second);

      // Set threading options
      auto intra_threads_it = options_map.find(flutter::EncodableValue("intraOpNumThreads"));
      if (intra_threads_it != options_map.end() && std::holds_alternative<int32_t>(intra_threads_it->second)) {
        session_options.SetIntraOpNumThreads(std::get<int32_t>(intra_threads_it->second));
      }

      auto inter_threads_it = options_map.find(flutter::EncodableValue("interOpNumThreads"));
      if (inter_threads_it != options_map.end() && std::holds_alternative<int32_t>(inter_threads_it->second)) {
        session_options.SetInterOpNumThreads(std::get<int32_t>(inter_threads_it->second));
      }

      auto use_arena_it = options_map.find(flutter::EncodableValue("useArena"));
      if (use_arena_it != options_map.end() && std::holds_alternative<bool>(use_arena_it->second)) {
        if (std::get<bool>(use_arena_it->second)) {
          session_options.EnableCpuMemArena();
        } else {
          session_options.DisableCpuMemArena();
        }
      }

      auto input_shape_it = options_map.find(flutter::EncodableValue("inputShape"));
      if (input_shape_it != options_map.end() && std::holds_alternative<flutter::EncodableList>(input_shape_it->second)) {
        const auto &shape = std::get<flutter::EncodableList>(input_shape_it->second);
        for (const auto &dimension : shape) {
          int64_t value = 0;
          if (std::holds_alternative<int32_t>(dimension)) {
            value = std::get<int32_t>(dimension);
          } else if (std::holds_alternative<int64_t>(dimension)) {
            value = std::get<int64_t>(dimension);
          } else {
            result->Error("INVALID_ARGUMENT", "inputShape must contain positive integers", nullptr);
            return;
          }
          if (value <= 0) {
            result->Error("INVALID_ARGUMENT", "inputShape must contain positive integers", nullptr);
            return;
          }
        }
      }

      auto memory_budget_it = options_map.find(flutter::EncodableValue("memoryBudgetBytes"));
      if (memory_budget_it != options_map.end()) {
        int64_t value = 0;
        if (std::holds_alternative<int32_t>(memory_budget_it->second)) {
          value = std::get<int32_t>(memory_budget_it->second);
        } else if (std::holds_alternative<int64_t>(memory_budget_it->second)) {
          value = std::get<int64_t>(memory_budget_it->second);
        } else {
          result->Error("INVALID_ARGUMENT", "memoryBudgetBytes must be positive", nullptr);
          return;
        }
        if (value <= 0) {
          result->Error("INVALID_ARGUMENT", "memoryBudgetBytes must be positive", nullptr);
          return;
        }
      }

      auto config_entries_it = options_map.find(flutter::EncodableValue("sessionConfigEntries"));
      if (config_entries_it != options_map.end() &&
          std::holds_alternative<flutter::EncodableMap>(config_entries_it->second)) {
        const auto &config_entries = std::get<flutter::EncodableMap>(config_entries_it->second);
        for (const auto &entry : config_entries) {
          if (std::holds_alternative<std::string>(entry.first) &&
              std::holds_alternative<std::string>(entry.second)) {
            const std::string &key = std::get<std::string>(entry.first);
            const std::string &value = std::get<std::string>(entry.second);
            session_options.AddConfigEntry(key.c_str(), value.c_str());
          }
        }
      }

      // Get the device ID, if not provided, set to 0
      int device_id = 0;
      auto device_id_it = options_map.find(flutter::EncodableValue("deviceId"));
      if (device_id_it != options_map.end() && std::holds_alternative<int32_t>(device_id_it->second)) {
        device_id = std::get<int32_t>(device_id_it->second);
      }

      // Convert device_id to string for use with provider options
      std::string device_id_str = std::to_string(device_id);

      // Handle providers
      auto providers_it = options_map.find(flutter::EncodableValue("providers"));
      std::vector<std::string> providers;

      if (providers_it != options_map.end() && std::holds_alternative<flutter::EncodableList>(providers_it->second)) {

        const auto &providers_list = std::get<flutter::EncodableList>(providers_it->second);

        for (const auto &provider_value : providers_list) {
          if (std::holds_alternative<std::string>(provider_value)) {
            providers.push_back(std::get<std::string>(provider_value));
          }
        }
      }

      // Default to CPU provider if no providers are specified
      if (providers.empty()) {
        providers.push_back("CPU");
      }

      // Set providers in session options
      try {
        for (const auto &provider : providers) {
          if (provider == "CPU") {
            // CPU is implicitly added if no others are, or can be explicitly added.
            // No specific options needed here usually.
            continue;
          } else if (provider == "CUDA") {
            // Use CUDA if available
            OrtCUDAProviderOptionsV2 *cuda_options = nullptr;
            OrtStatus *status = Ort::GetApi().CreateCUDAProviderOptions(&cuda_options);
            if (status != nullptr) {
              std::string error_message = "Failed to create CUDA provider options: ";
              error_message += Ort::GetApi().GetErrorMessage(status);
              Ort::GetApi().ReleaseStatus(status);
              result->Error("PROVIDER_ERROR", error_message.c_str(), nullptr);
              return;
            }

            // Use unique_ptr for automatic release
            struct CudaOptionsDeleter {
              void operator()(OrtCUDAProviderOptionsV2 *p) { Ort::GetApi().ReleaseCUDAProviderOptions(p); }
            };
            std::unique_ptr<OrtCUDAProviderOptionsV2, CudaOptionsDeleter> cuda_options_ptr(cuda_options);

            // Set CUDA options
            std::vector<const char *> keys{"device_id"};
            std::vector<const char *> values{device_id_str.c_str()};
            status = Ort::GetApi().UpdateCUDAProviderOptions(cuda_options_ptr.get(), keys.data(), values.data(),
                                                             keys.size());

            if (status != nullptr) {
              std::string error_message = "Failed to update CUDA provider options: ";
              error_message += Ort::GetApi().GetErrorMessage(status);
              Ort::GetApi().ReleaseStatus(status);
              result->Error("PROVIDER_ERROR", error_message.c_str(), nullptr);
              return;
            }

            // Append CUDA execution provider to session options
            session_options.AppendExecutionProvider_CUDA_V2(*cuda_options_ptr);
          } else if (provider == "TENSOR_RT") {
            // Use TensorRT if available
            // This is just a placeholder - actual implementation would depend on TensorRT availability
            result->Error("PROVIDER_ERROR", "TensorRT provider not implemented yet", nullptr);
            return;
          } else {
            std::string error_message = "Provider is not supported: " + provider;
            result->Error("INVALID_PROVIDER", error_message.c_str(), nullptr);
            return;
          }
        }
      } catch (const Ort::Exception &e) {
        result->Error("PROVIDER_ERROR", e.what(), nullptr);
        return;
      }
    }

    // Create the session
    std::string session_id = impl_->sessionManager_->createSession(model_path.c_str(), session_options);

    if (session_id.empty()) {
      result->Error("SESSION_CREATION_ERROR", "Failed to create ONNX Runtime session", nullptr);
      return;
    }

    // Get input and output names
    std::vector<std::string> input_names = impl_->sessionManager_->getInputNames(session_id);
    std::vector<std::string> output_names = impl_->sessionManager_->getOutputNames(session_id);

    // Prepare response
    flutter::EncodableMap response;
    response[flutter::EncodableValue("sessionId")] = flutter::EncodableValue(session_id);

    // Convert input names to Flutter list
    flutter::EncodableList input_names_list;
    for (const auto &name : input_names) {
      input_names_list.push_back(flutter::EncodableValue(name));
    }
    response[flutter::EncodableValue("inputNames")] = flutter::EncodableValue(input_names_list);

    // Convert output names to Flutter list
    flutter::EncodableList output_names_list;
    for (const auto &name : output_names) {
      output_names_list.push_back(flutter::EncodableValue(name));
    }
    response[flutter::EncodableValue("outputNames")] = flutter::EncodableValue(output_names_list);

    // Add status for compatibility
    response[flutter::EncodableValue("status")] = flutter::EncodableValue("success");

    result->Success(flutter::EncodableValue(response));
  } catch (const Ort::Exception &e) {
    result->Error("ORT_ERROR", e.what(), nullptr);
  } catch (const std::exception &e) {
    result->Error("PLUGIN_ERROR", e.what(), nullptr);
  } catch (...) {
    result->Error("INTERNAL_ERROR", "Unknown error occurred", nullptr);
  }
}

void FlutterOnnxruntimePlugin::HandleGetAvailableProviders(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  try {
    // Get available providers from ONNX Runtime
    std::vector<std::string> providers = Ort::GetAvailableProviders();

    // Map provider names to standardized enum names
    flutter::EncodableList providers_list;
    for (const auto &provider : providers) {
      std::string mapped_name = provider;

      // Map C++ API provider names to enum names
      static const std::unordered_map<std::string, std::string> provider_map = {
          {"CPUExecutionProvider", "CPU"},
          {"CUDAExecutionProvider", "CUDA"},
          {"TensorrtExecutionProvider", "TENSOR_RT"},
          {"AzureExecutionProvider", "AZURE"},
          {"MIGraphXExecutionProvider", "MIGRAPHX"},
          {"ROCMExecutionProvider", "ROCM"},
          {"CoreMLExecutionProvider", "CORE_ML"},
          {"DnnlExecutionProvider", "DNNL"},
          {"OpenVINOExecutionProvider", "OPEN_VINO"},
          {"NnapiExecutionProvider", "NNAPI"},
          {"QnnExecutionProvider", "QNN"},
          {"DmlExecutionProvider", "DIRECT_ML"},
          {"ACLExecutionProvider", "ACL"},
          {"ArmNNExecutionProvider", "ARM_NN"},
          {"XnnpackExecutionProvider", "XNNPACK"}};

      auto it = provider_map.find(provider);
      if (it != provider_map.end()) {
        mapped_name = it->second;
      }

      providers_list.push_back(flutter::EncodableValue(mapped_name));
    }

    result->Success(flutter::EncodableValue(providers_list));
  } catch (const Ort::Exception &e) {
    result->Error("ORT_ERROR", e.what(), nullptr);
  } catch (const std::exception &e) {
    result->Error("PLUGIN_ERROR", e.what(), nullptr);
  } catch (...) {
    result->Error("INTERNAL_ERROR", "Unknown error occurred", nullptr);
  }
}

void FlutterOnnxruntimePlugin::HandleGetRuntimeInfo(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  try {
    const std::vector<std::string> providers = Ort::GetAvailableProviders();
    flutter::EncodableList providers_list;
    static const std::unordered_map<std::string, std::string> provider_map = {
        {"CPUExecutionProvider", "CPU"},
        {"CUDAExecutionProvider", "CUDA"},
        {"TensorrtExecutionProvider", "TENSOR_RT"},
        {"DmlExecutionProvider", "DIRECT_ML"},
        {"OpenVINOExecutionProvider", "OPEN_VINO"},
        {"NnapiExecutionProvider", "NNAPI"},
        {"CoreMLExecutionProvider", "CORE_ML"},
        {"XnnpackExecutionProvider", "XNNPACK"}};
    for (const auto &provider : providers) {
      const auto it = provider_map.find(provider);
      providers_list.push_back(flutter::EncodableValue(it == provider_map.end() ? provider : it->second));
    }
    flutter::EncodableMap response;
    response[flutter::EncodableValue("ortVersion")] = flutter::EncodableValue(Ort::GetVersionString());
    response[flutter::EncodableValue("providers")] = flutter::EncodableValue(providers_list);
    response[flutter::EncodableValue("platform")] = flutter::EncodableValue("windows");
    result->Success(flutter::EncodableValue(response));
  } catch (const Ort::Exception &e) {
    result->Error("ORT_ERROR", e.what(), nullptr);
  } catch (const std::exception &e) {
    result->Error("PLUGIN_ERROR", e.what(), nullptr);
  }
}

void FlutterOnnxruntimePlugin::HandleRunInference(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  // Extract parameters
  const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());

  if (!args) {
    result->Error("INVALID_ARG", "Arguments must be provided as a map", nullptr);
    return;
  }

  try {
    // Extract session ID
    auto session_id_it = args->find(flutter::EncodableValue("sessionId"));
    if (session_id_it == args->end() || !std::holds_alternative<std::string>(session_id_it->second)) {
      result->Error("INVALID_ARG", "Session ID must be a non-null string", nullptr);
      return;
    }
    std::string session_id = std::get<std::string>(session_id_it->second);

    // Check if session exists
    if (!impl_->sessionManager_->hasSession(session_id)) {
      result->Error("INVALID_SESSION", "Session not found", nullptr);
      return;
    }

    // Extract inputs map
    auto inputs_it = args->find(flutter::EncodableValue("inputs"));
    if (inputs_it == args->end() || !std::holds_alternative<flutter::EncodableMap>(inputs_it->second)) {
      result->Error("INVALID_ARG", "Inputs must be a non-null map", nullptr);
      return;
    }
    const auto &inputs_map = std::get<flutter::EncodableMap>(inputs_it->second);

    // Extract run options if provided
    auto run_options_it = args->find(flutter::EncodableValue("runOptions"));
    Ort::RunOptions run_options;

    if (run_options_it != args->end() && std::holds_alternative<flutter::EncodableMap>(run_options_it->second)) {

      const auto &options_map = std::get<flutter::EncodableMap>(run_options_it->second);

      // Extract log severity level if provided
      auto log_severity_it = options_map.find(flutter::EncodableValue("logSeverityLevel"));
      if (log_severity_it != options_map.end() && std::holds_alternative<int32_t>(log_severity_it->second)) {
        run_options.SetRunLogSeverityLevel(std::get<int32_t>(log_severity_it->second));
      }

      // Extract log verbosity level if provided
      auto log_verbosity_it = options_map.find(flutter::EncodableValue("logVerbosityLevel"));
      if (log_verbosity_it != options_map.end() && std::holds_alternative<int32_t>(log_verbosity_it->second)) {
        run_options.SetRunLogVerbosityLevel(std::get<int32_t>(log_verbosity_it->second));
      }

      // Extract terminate option if provided
      auto terminate_it = options_map.find(flutter::EncodableValue("terminate"));
      if (terminate_it != options_map.end() && std::holds_alternative<bool>(terminate_it->second)) {
        if (std::get<bool>(terminate_it->second)) {
          run_options.SetTerminate();
        }
      }
    }

    std::vector<std::string> output_names = impl_->sessionManager_->getOutputNames(session_id);

    // Prepare input tensors and input names
    // Use ClonedTensor to keep backing buffers alive during inference
    std::vector<ClonedTensor> cloned_inputs;
    std::vector<std::string> input_names;

    // Iterate through each input
    for (const auto &input_pair : inputs_map) {
      if (!std::holds_alternative<std::string>(input_pair.first) ||
          !std::holds_alternative<flutter::EncodableMap>(input_pair.second)) {
        continue;
      }

      // Extract the input name from the map key
      std::string input_name = std::get<std::string>(input_pair.first);

      const auto &input_value_map = std::get<flutter::EncodableMap>(input_pair.second);
      auto tensor_id_it = input_value_map.find(flutter::EncodableValue("valueId"));

      if (tensor_id_it == input_value_map.end() || !std::holds_alternative<std::string>(tensor_id_it->second)) {
        continue;
      }

      std::string tensor_id = std::get<std::string>(tensor_id_it->second);

      // Get the tensor value
      Ort::Value *tensor_ptr = impl_->tensorManager_->getTensor(tensor_id);
      if (tensor_ptr != nullptr) {
        try {
          // Clone the tensor — ClonedTensor owns both the Ort::Value and its backing buffer
          ClonedTensor cloned = impl_->tensorManager_->cloneTensor(tensor_id);
          if (cloned.value) {
            cloned_inputs.push_back(std::move(cloned));
            input_names.push_back(input_name);
          }
        } catch (const std::exception &e) {
          // Log the error but continue with the next tensor
          std::cerr << "Failed to clone tensor " << tensor_id << ": " << e.what() << std::endl;
        }
      }
    }

    // Build a vector of Ort::Value references for Session::Run
    std::vector<Ort::Value> input_tensors;
    input_tensors.reserve(cloned_inputs.size());
    for (auto &ci : cloned_inputs) {
      input_tensors.push_back(std::move(ci.value));
    }

    // Run inference using SessionManager with input names
    // Note: cloned_inputs (with backing buffers) stays alive through this scope
    std::vector<Ort::Value> output_tensors;
    if (!input_tensors.empty()) {
      output_tensors = impl_->sessionManager_->runInference(session_id, input_tensors, input_names, &run_options);
    }

    // Process outputs
    flutter::EncodableMap outputs_map;

    // For each output tensor, store it using TensorManager
    for (size_t i = 0; i < output_tensors.size(); i++) {
      // Create a tensor ID
      std::string value_id = impl_->tensorManager_->generateTensorId();

      // Store the tensor - this transfers ownership
      // TensorManager::storeTensor returns void (not bool)
      impl_->tensorManager_->storeTensor(value_id, std::move(output_tensors[i]));

      // Get the tensor type and shape
      std::string tensor_type = impl_->tensorManager_->getTensorType(value_id);
      std::vector<int64_t> shape = impl_->tensorManager_->getTensorShape(value_id);

      // Add the value ID to the outputs map
      flutter::EncodableList shape_list;
      for (const auto &dim : shape) {
        shape_list.push_back(static_cast<int64_t>(dim));
      }

      // Create output info (value_id, type, shape)
      flutter::EncodableList output_info;
      output_info.push_back(flutter::EncodableValue(value_id));
      output_info.push_back(flutter::EncodableValue(tensor_type));
      output_info.push_back(flutter::EncodableValue(shape_list));

      if (i < output_names.size()) {
        outputs_map[flutter::EncodableValue(output_names[i])] = flutter::EncodableValue(output_info);
      }
    }

    result->Success(flutter::EncodableValue(outputs_map));
  } catch (const Ort::Exception &e) {
    result->Error("INFERENCE_ERROR", e.what(), nullptr);
  } catch (const std::exception &e) {
    result->Error("PLUGIN_ERROR", e.what(), nullptr);
  } catch (...) {
    result->Error("INTERNAL_ERROR", "Unknown error occurred", nullptr);
  }
}

void FlutterOnnxruntimePlugin::HandleCloseSession(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  // Extract parameters
  const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());

  if (!args) {
    result->Error("INVALID_ARG", "Arguments must be provided as a map", nullptr);
    return;
  }

  try {
    // Extract session ID
    auto session_id_it = args->find(flutter::EncodableValue("sessionId"));
    if (session_id_it == args->end() || !std::holds_alternative<std::string>(session_id_it->second)) {
      result->Error("INVALID_ARG", "Session ID must be a non-null string", nullptr);
      return;
    }
    std::string session_id = std::get<std::string>(session_id_it->second);

    // Close the session
    impl_->sessionManager_->closeSession(session_id);

    // Return null for success
    result->Success(nullptr);
  } catch (const Ort::Exception &e) {
    result->Error("ORT_ERROR", e.what(), nullptr);
  } catch (const std::exception &e) {
    result->Error("PLUGIN_ERROR", e.what(), nullptr);
  } catch (...) {
    result->Error("INTERNAL_ERROR", "Unknown error occurred", nullptr);
  }
}

void FlutterOnnxruntimePlugin::HandleGetMetadata(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  // Extract parameters
  const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());

  if (!args) {
    result->Error("INVALID_ARG", "Arguments must be provided as a map", nullptr);
    return;
  }

  try {
    // Extract session ID
    auto session_id_it = args->find(flutter::EncodableValue("sessionId"));
    if (session_id_it == args->end() || !std::holds_alternative<std::string>(session_id_it->second)) {
      result->Error("INVALID_SESSION", "Invalid session ID", nullptr);
      return;
    }
    std::string session_id = std::get<std::string>(session_id_it->second);

    // Check if session exists
    if (!impl_->sessionManager_->hasSession(session_id)) {
      result->Error("INVALID_SESSION", "Session not found", nullptr);
      return;
    }

    // Get metadata
    ModelMetadata metadata = impl_->sessionManager_->getModelMetadata(session_id);

    // Create response
    flutter::EncodableMap response;
    response[flutter::EncodableValue("producerName")] = flutter::EncodableValue(metadata.producer_name);
    response[flutter::EncodableValue("graphName")] = flutter::EncodableValue(metadata.graph_name);
    response[flutter::EncodableValue("domain")] = flutter::EncodableValue(metadata.domain);
    response[flutter::EncodableValue("description")] = flutter::EncodableValue(metadata.description);
    response[flutter::EncodableValue("version")] = flutter::EncodableValue(static_cast<int64_t>(metadata.version));

    // Convert custom metadata map
    flutter::EncodableMap custom_metadata_map;
    for (const auto &pair : metadata.custom_metadata) {
      custom_metadata_map[flutter::EncodableValue(pair.first)] = flutter::EncodableValue(pair.second);
    }
    response[flutter::EncodableValue("customMetadataMap")] = flutter::EncodableValue(custom_metadata_map);

    result->Success(flutter::EncodableValue(response));
  } catch (const Ort::Exception &e) {
    result->Error("ORT_ERROR", e.what(), nullptr);
  } catch (const std::exception &e) {
    result->Error("PLUGIN_ERROR", e.what(), nullptr);
  } catch (...) {
    result->Error("INTERNAL_ERROR", "Unknown error occurred", nullptr);
  }
}

void FlutterOnnxruntimePlugin::HandleGetInputInfo(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  // Extract parameters
  const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());

  if (!args) {
    result->Error("INVALID_ARG", "Arguments must be provided as a map", nullptr);
    return;
  }

  try {
    // Extract session ID
    auto session_id_it = args->find(flutter::EncodableValue("sessionId"));
    if (session_id_it == args->end() || !std::holds_alternative<std::string>(session_id_it->second)) {
      result->Error("INVALID_SESSION", "Invalid session ID", nullptr);
      return;
    }
    std::string session_id = std::get<std::string>(session_id_it->second);

    // Check if session exists
    if (!impl_->sessionManager_->hasSession(session_id)) {
      result->Error("INVALID_SESSION", "Session not found", nullptr);
      return;
    }

    // Get input info
    std::vector<TensorInfo> input_info = impl_->sessionManager_->getInputInfo(session_id);

    // Create response list
    flutter::EncodableList response;

    for (const auto &info : input_info) {
      flutter::EncodableMap info_map;
      info_map[flutter::EncodableValue("name")] = flutter::EncodableValue(info.name);
      info_map[flutter::EncodableValue("type")] = flutter::EncodableValue(info.type);

      // Convert shape to Flutter list
      flutter::EncodableList shape_list;
      for (const auto &dim : info.shape) {
        shape_list.push_back(flutter::EncodableValue(static_cast<int64_t>(dim)));
      }
      info_map[flutter::EncodableValue("shape")] = flutter::EncodableValue(shape_list);

      response.push_back(flutter::EncodableValue(info_map));
    }

    result->Success(flutter::EncodableValue(response));
  } catch (const Ort::Exception &e) {
    result->Error("ORT_ERROR", e.what(), nullptr);
  } catch (const std::exception &e) {
    result->Error("PLUGIN_ERROR", e.what(), nullptr);
  } catch (...) {
    result->Error("INTERNAL_ERROR", "Unknown error occurred", nullptr);
  }
}

void FlutterOnnxruntimePlugin::HandleGetOutputInfo(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {

  // Extract parameters
  const auto *args = std::get_if<flutter::EncodableMap>(method_call.arguments());

  if (!args) {
    result->Error("INVALID_ARG", "Arguments must be provided as a map", nullptr);
    return;
  }

  try {
    // Extract session ID
    auto session_id_it = args->find(flutter::EncodableValue("sessionId"));
    if (session_id_it == args->end() || !std::holds_alternative<std::string>(session_id_it->second)) {
      result->Error("INVALID_SESSION", "Invalid session ID", nullptr);
      return;
    }
    std::string session_id = std::get<std::string>(session_id_it->second);

    // Check if session exists
    if (!impl_->sessionManager_->hasSession(session_id)) {
      result->Error("INVALID_SESSION", "Session not found", nullptr);
      return;
    }

    // Get output info
    std::vector<TensorInfo> output_info = impl_->sessionManager_->getOutputInfo(session_id);

    // Create response list
    flutter::EncodableList response;

    for (const auto &info : output_info) {
      flutter::EncodableMap info_map;
      info_map[flutter::EncodableValue("name")] = flutter::EncodableValue(info.name);
      info_map[flutter::EncodableValue("type")] = flutter::EncodableValue(info.type);

      // Convert shape to Flutter list
      flutter::EncodableList shape_list;
      for (const auto &dim : info.shape) {
        shape_list.push_back(flutter::EncodableValue(static_cast<int64_t>(dim)));
      }
      info_map[flutter::EncodableValue("shape")] = flutter::EncodableValue(shape_list);

      response.push_back(flutter::EncodableValue(info_map));
    }

    result->Success(flutter::EncodableValue(response));
  } catch (const Ort::Exception &e) {
    result->Error("ORT_ERROR", e.what(), nullptr);
  } catch (const std::exception &e) {
    result->Error("PLUGIN_ERROR", e.what(), nullptr);
  } catch (...) {
    result->Error("INTERNAL_ERROR", "Unknown error occurred", nullptr);
  }
}

} // namespace flutter_onnxruntime

// C-style function for plugin registration
// This must be implemented for the plugin to be loadable
extern "C" {
FLUTTER_PLUGIN_EXPORT void FlutterOnnxruntimePluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
  // Convert the C-style registrar to the C++ one
  flutter::PluginRegistrarWindows *plugin_registrar =
      flutter::PluginRegistrarManager::GetInstance()->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);

  // Call our plugin's static registration method
  flutter_onnxruntime::FlutterOnnxruntimePlugin::RegisterWithRegistrar(plugin_registrar);
}
}
