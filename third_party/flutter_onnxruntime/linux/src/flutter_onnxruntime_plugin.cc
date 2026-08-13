// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#include "include/flutter_onnxruntime/flutter_onnxruntime_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include "session_manager.h"
#include "tensor_manager.h"
#include "value_conversion.h"
#include <cstring>
#include <map>
#include <memory>
#include <mutex>
#include <onnxruntime_cxx_api.h>
#include <string>
#include <unordered_map>

#define FLUTTER_ONNXRUNTIME_PLUGIN(obj)                                                                                \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_onnxruntime_plugin_get_type(), FlutterOnnxruntimePlugin))

struct _FlutterOnnxruntimePlugin {
  GObject parent_instance;

  // SessionManager for handling ONNX Runtime sessions
  SessionManager *session_manager;

  // TensorManager for handling OrtValue objects
  TensorManager *tensor_manager;

  // Maps to store value data
  std::map<std::string, void *> values;

  // Mutex for thread safety
  std::mutex mutex;
};

G_DEFINE_TYPE(FlutterOnnxruntimePlugin, flutter_onnxruntime_plugin, g_object_get_type())

// Method declarations
static void flutter_onnxruntime_plugin_dispose(GObject *object);
static void flutter_onnxruntime_plugin_handle_method_call(FlutterOnnxruntimePlugin *self, FlMethodCall *method_call);
static void method_call_handler(FlMethodChannel *channel, FlMethodCall *method_call, gpointer user_data);

// Helper function to get platform version
static FlMethodResponse *get_platform_version();

// Session management
static FlMethodResponse *create_session(FlutterOnnxruntimePlugin *self, FlValue *args);
static FlMethodResponse *get_available_providers(FlutterOnnxruntimePlugin *self, FlValue *args);
static FlMethodResponse *get_runtime_info(FlutterOnnxruntimePlugin *self, FlValue *args);
static FlMethodResponse *run_inference(FlutterOnnxruntimePlugin *self, FlValue *args);
static FlMethodResponse *close_session(FlutterOnnxruntimePlugin *self, FlValue *args);
static FlMethodResponse *get_metadata(FlutterOnnxruntimePlugin *self, FlValue *args);
static FlMethodResponse *get_input_info(FlutterOnnxruntimePlugin *self, FlValue *args);
static FlMethodResponse *get_output_info(FlutterOnnxruntimePlugin *self, FlValue *args);

// OrtValue operations
static FlMethodResponse *create_ort_value(FlutterOnnxruntimePlugin *self, FlValue *args);
static FlMethodResponse *convert_ort_value(FlutterOnnxruntimePlugin *self, FlValue *args);
static FlMethodResponse *get_ort_value_data(FlutterOnnxruntimePlugin *self, FlValue *args);
static FlMethodResponse *release_ort_value(FlutterOnnxruntimePlugin *self, FlValue *args);

// Helper function to map C++ API provider names to OrtProvider enum names
static std::string mapProviderNameToEnumName(const std::string &providerName) {
  // Map from C++ API provider names to OrtProvider enum names
  static const std::unordered_map<std::string, std::string> providerNameMap = {
      {"CPUExecutionProvider", "CPU"},
      {"CUDAExecutionProvider", "CUDA"},
      {"TensorrtExecutionProvider", "TENSOR_RT"},
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

  auto it = providerNameMap.find(providerName);
  if (it != providerNameMap.end()) {
    return it->second;
  }

  // Return the original name if no mapping exists
  // This handles cases like custom or new providers that aren't in the enum yet
  return providerName;
}

// Plugin class initialization
static void flutter_onnxruntime_plugin_class_init(FlutterOnnxruntimePluginClass *klass) {
  G_OBJECT_CLASS(klass)->dispose = flutter_onnxruntime_plugin_dispose;
}

static void flutter_onnxruntime_plugin_init(FlutterOnnxruntimePlugin *self) {
  self->session_manager = new SessionManager();
  self->tensor_manager = new TensorManager();
}

static void flutter_onnxruntime_plugin_dispose(GObject *object) {
  FlutterOnnxruntimePlugin *self = FLUTTER_ONNXRUNTIME_PLUGIN(object);

  // Clean up session manager, tensor manager and values
  delete self->session_manager;
  delete self->tensor_manager;

  std::lock_guard<std::mutex> lock(self->mutex);
  self->values.clear();

  G_OBJECT_CLASS(flutter_onnxruntime_plugin_parent_class)->dispose(object);
}

// Plugin registration with Flutter engine
void flutter_onnxruntime_plugin_register_with_registrar(FlPluginRegistrar *registrar) {
  FlutterOnnxruntimePlugin *plugin =
      FLUTTER_ONNXRUNTIME_PLUGIN(g_object_new(flutter_onnxruntime_plugin_get_type(), nullptr));

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  g_autoptr(FlMethodChannel) channel = fl_method_channel_new(fl_plugin_registrar_get_messenger(registrar),
                                                             "flutter_onnxruntime", FL_METHOD_CODEC(codec));

  // Setup method call handler
  fl_method_channel_set_method_call_handler(channel, method_call_handler, g_object_ref(plugin), g_object_unref);

  g_object_unref(plugin);
}

// Method call handler function
static void method_call_handler(FlMethodChannel *channel, FlMethodCall *method_call, gpointer user_data) {
  FlutterOnnxruntimePlugin *self = FLUTTER_ONNXRUNTIME_PLUGIN(user_data);
  flutter_onnxruntime_plugin_handle_method_call(self, method_call);
}

// Handler for method calls from Dart
static void flutter_onnxruntime_plugin_handle_method_call(FlutterOnnxruntimePlugin *self, FlMethodCall *method_call) {
  g_autoptr(FlMethodResponse) response = nullptr;
  const gchar *method = fl_method_call_get_name(method_call);
  FlValue *args = fl_method_call_get_args(method_call);

  // Dispatch the call to the appropriate handler function.
  // Each handler function now directly returns an FlMethodResponse.
  if (strcmp(method, "getPlatformVersion") == 0) {
    response = get_platform_version();
  } else if (strcmp(method, "createSession") == 0) {
    response = create_session(self, args);
  } else if (strcmp(method, "getAvailableProviders") == 0) {
    response = get_available_providers(self, args);
  } else if (strcmp(method, "getRuntimeInfo") == 0) {
    response = get_runtime_info(self, args);
  } else if (strcmp(method, "runInference") == 0) {
    response = run_inference(self, args);
  } else if (strcmp(method, "closeSession") == 0) {
    response = close_session(self, args);
  } else if (strcmp(method, "getMetadata") == 0) {
    response = get_metadata(self, args);
  } else if (strcmp(method, "getInputInfo") == 0) {
    response = get_input_info(self, args);
  } else if (strcmp(method, "getOutputInfo") == 0) {
    response = get_output_info(self, args);
  } else if (strcmp(method, "createOrtValue") == 0) {
    response = create_ort_value(self, args);
  } else if (strcmp(method, "convertOrtValue") == 0) {
    response = convert_ort_value(self, args);
  } else if (strcmp(method, "getOrtValueData") == 0) {
    response = get_ort_value_data(self, args);
  } else if (strcmp(method, "releaseOrtValue") == 0) {
    response = release_ort_value(self, args);
  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  if (response != nullptr) {
    fl_method_call_respond(method_call, response, nullptr);
  } else {
    // Fallback if no response was created (should ideally not happen)
    response =
        FL_METHOD_RESPONSE(fl_method_error_response_new("INTERNAL_ERROR", "Failed to process method call", nullptr));
    fl_method_call_respond(method_call, response, nullptr);
  }
}

// Implementation of method functions
static FlMethodResponse *get_platform_version() {
  struct utsname uname_data = {};
  uname(&uname_data);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_string(uname_data.version)));
}

static FlMethodResponse *create_session(FlutterOnnxruntimePlugin *self, FlValue *args) {
  FlValue *model_path_value = fl_value_lookup_string(args, "modelPath");

  if (model_path_value == nullptr || fl_value_get_type(model_path_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_ARG", "Model path cannot be null", nullptr));
  }

  const char *model_path = fl_value_get_string(model_path_value);

  FlValue *session_options_value = fl_value_lookup_string(args, "sessionOptions");

  Ort::SessionOptions session_options;

  // Configure session options if provided
  if (session_options_value != nullptr && fl_value_get_type(session_options_value) == FL_VALUE_TYPE_MAP) {
    auto options_map = fl_value_to_map(session_options_value);

    // Set threading options
    auto intra_threads_val = options_map.find("intraOpNumThreads");
    if (intra_threads_val != options_map.end() && fl_value_get_type(intra_threads_val->second) == FL_VALUE_TYPE_INT) {
      session_options.SetIntraOpNumThreads(fl_value_get_int(intra_threads_val->second));
    }

    auto inter_threads_val = options_map.find("interOpNumThreads");
    if (inter_threads_val != options_map.end() && fl_value_get_type(inter_threads_val->second) == FL_VALUE_TYPE_INT) {
      session_options.SetInterOpNumThreads(fl_value_get_int(inter_threads_val->second));
    }

    auto use_arena_val = options_map.find("useArena");
    if (use_arena_val != options_map.end() &&
        fl_value_get_type(use_arena_val->second) == FL_VALUE_TYPE_BOOL) {
      if (fl_value_get_bool(use_arena_val->second)) {
        session_options.EnableCpuMemArena();
      } else {
        session_options.DisableCpuMemArena();
      }
    }

    auto input_shape_val = options_map.find("inputShape");
    if (input_shape_val != options_map.end() &&
        fl_value_get_type(input_shape_val->second) == FL_VALUE_TYPE_LIST) {
      FlValue *shape = input_shape_val->second;
      for (size_t i = 0; i < fl_value_get_length(shape); ++i) {
        FlValue *dimension = fl_value_get_list_value(shape, i);
        if (fl_value_get_type(dimension) != FL_VALUE_TYPE_INT ||
            fl_value_get_int(dimension) <= 0) {
          return FL_METHOD_RESPONSE(fl_method_error_response_new(
              "INVALID_ARGUMENT", "inputShape must contain positive integers", nullptr));
        }
      }
    }
    auto memory_budget_val = options_map.find("memoryBudgetBytes");
    if (memory_budget_val != options_map.end() &&
        fl_value_get_type(memory_budget_val->second) == FL_VALUE_TYPE_INT &&
        fl_value_get_int(memory_budget_val->second) <= 0) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new(
          "INVALID_ARGUMENT", "memoryBudgetBytes must be positive", nullptr));
    }

    auto config_entries_val = options_map.find("sessionConfigEntries");
    if (config_entries_val != options_map.end() &&
        fl_value_get_type(config_entries_val->second) == FL_VALUE_TYPE_MAP) {
      auto config_entries = fl_value_to_map(config_entries_val->second);
      for (const auto &entry : config_entries) {
        if (fl_value_get_type(entry.second) == FL_VALUE_TYPE_STRING) {
          session_options.AddConfigEntry(entry.first.c_str(), fl_value_get_string(entry.second));
        }
      }
    }

    // get the device id, if not provided, set to 0
    int device_id = 0;
    auto device_id_val = options_map.find("deviceId");
    if (device_id_val != options_map.end() && fl_value_get_type(device_id_val->second) == FL_VALUE_TYPE_INT) {
      device_id = fl_value_get_int(device_id_val->second);
    }

    // Convert device_id to string for use with provider options
    std::string device_id_str = std::to_string(device_id);

    // Handle providers
    auto providers_val = options_map.find("providers");
    std::vector<std::string> providers;
    if (providers_val != options_map.end() && fl_value_get_type(providers_val->second) == FL_VALUE_TYPE_LIST) {
      FlValue *providers_list = providers_val->second;
      size_t num_providers = fl_value_get_length(providers_list);
      for (size_t i = 0; i < num_providers; i++) {
        FlValue *provider_value = fl_value_get_list_value(providers_list, i);
        if (fl_value_get_type(provider_value) == FL_VALUE_TYPE_STRING) {
          providers.push_back(fl_value_get_string(provider_value));
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
          OrtCUDAProviderOptionsV2 *cuda_options = nullptr;
          OrtStatus *status = Ort::GetApi().CreateCUDAProviderOptions(&cuda_options);
          if (status != nullptr) {
            std::string error_message = "Failed to create CUDA provider options: ";
            error_message += Ort::GetApi().GetErrorMessage(status);
            Ort::GetApi().ReleaseStatus(status);
            return FL_METHOD_RESPONSE(fl_method_error_response_new("PROVIDER_ERROR", error_message.c_str(), nullptr));
          }
          // Use g_autoptr for automatic release
          struct CudaOptionsDeleter {
            void operator()(OrtCUDAProviderOptionsV2 *p) { Ort::GetApi().ReleaseCUDAProviderOptions(p); }
          };
          std::unique_ptr<OrtCUDAProviderOptionsV2, CudaOptionsDeleter> cuda_options_ptr(cuda_options);

          // Follow the example at
          // https://onnxruntime.ai/docs/execution-providers/CUDA-ExecutionProvider.html#using-v2-provider-options-struct
          std::vector<const char *> keys{"device_id"};
          std::vector<const char *> values{device_id_str.c_str()};
          status =
              Ort::GetApi().UpdateCUDAProviderOptions(cuda_options_ptr.get(), keys.data(), values.data(), keys.size());
          if (status != nullptr) {
            std::string error_message = "Failed to update CUDA provider options: ";
            error_message += Ort::GetApi().GetErrorMessage(status);
            Ort::GetApi().ReleaseStatus(status);
            return FL_METHOD_RESPONSE(fl_method_error_response_new("PROVIDER_ERROR", error_message.c_str(), nullptr));
          }

          // Append CUDA execution provider to session options
          session_options.AppendExecutionProvider_CUDA_V2(*cuda_options_ptr);

        } else if (provider == "TENSOR_RT") {
          OrtTensorRTProviderOptionsV2 *tensorrt_options = nullptr;
          OrtStatus *status = Ort::GetApi().CreateTensorRTProviderOptions(&tensorrt_options);
          if (status != nullptr) {
            std::string error_message = "Failed to create TensorRT provider options: ";
            error_message += Ort::GetApi().GetErrorMessage(status);
            Ort::GetApi().ReleaseStatus(status);
            return FL_METHOD_RESPONSE(fl_method_error_response_new("PROVIDER_ERROR", error_message.c_str(), nullptr));
          }
          struct TensorRTOptionsDeleter {
            void operator()(OrtTensorRTProviderOptionsV2 *p) { Ort::GetApi().ReleaseTensorRTProviderOptions(p); }
          };
          std::unique_ptr<OrtTensorRTProviderOptionsV2, TensorRTOptionsDeleter> tensorrt_options_ptr(tensorrt_options);

          std::vector<const char *> keys{"device_id"};
          std::vector<const char *> values{device_id_str.c_str()};
          status = Ort::GetApi().UpdateTensorRTProviderOptions(tensorrt_options_ptr.get(), keys.data(), values.data(),
                                                               keys.size());
          if (status != nullptr) {
            std::string error_message = "Failed to update TensorRT provider options: ";
            error_message += Ort::GetApi().GetErrorMessage(status);
            Ort::GetApi().ReleaseStatus(status);
            return FL_METHOD_RESPONSE(fl_method_error_response_new("PROVIDER_ERROR", error_message.c_str(), nullptr));
          }

          session_options.AppendExecutionProvider_TensorRT_V2(*tensorrt_options_ptr);

        } else {
          std::string error_message = "Provider is not supported: " + provider;
          return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_PROVIDER", error_message.c_str(), nullptr));
        }
      }
    } catch (const Ort::Exception &e) {
      // Catch potential exceptions during provider setup (e.g., AppendExecutionProvider)
      return FL_METHOD_RESPONSE(fl_method_error_response_new("PROVIDER_ERROR", e.what(), nullptr));
    } catch (const std::exception &e) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new("PLUGIN_ERROR", e.what(), nullptr));
    }
  }

  try {
    std::string session_id = self->session_manager->createSession(model_path, session_options);

    std::vector<std::string> input_names = self->session_manager->getInputNames(session_id);
    std::vector<std::string> output_names = self->session_manager->getOutputNames(session_id);

    g_autoptr(FlValue) result = fl_value_new_map();
    fl_value_set_string_take(result, "sessionId", fl_value_new_string(session_id.c_str()));
    fl_value_set_string_take(result, "inputNames", vector_to_fl_value(input_names));
    fl_value_set_string_take(result, "outputNames", vector_to_fl_value(output_names));
    fl_value_set_string_take(result, "status", fl_value_new_string("success")); // Keep status for compatibility maybe?
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } catch (const Ort::Exception &e) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("ORT_ERROR", e.what(), nullptr));
  } catch (const std::exception &e) {
    // Catch other potential errors during session creation or name retrieval
    return FL_METHOD_RESPONSE(fl_method_error_response_new("PLUGIN_ERROR", e.what(), nullptr));
  }
}

static FlMethodResponse *get_available_providers(FlutterOnnxruntimePlugin *self, FlValue *args) {
  std::vector<std::string> providers = Ort::GetAvailableProviders();

  g_autoptr(FlValue) result = fl_value_new_list();
  for (const auto &provider : providers) {
    // Map the provider name to the standardized enum name
    std::string mappedName = mapProviderNameToEnumName(provider);
    fl_value_append_take(result, fl_value_new_string(mappedName.c_str()));
  }
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *get_runtime_info(FlutterOnnxruntimePlugin *self, FlValue *args) {
  std::vector<std::string> providers = Ort::GetAvailableProviders();
  g_autoptr(FlValue) provider_list = fl_value_new_list();
  for (const auto &provider : providers) {
    std::string mapped_name = mapProviderNameToEnumName(provider);
    fl_value_append_take(provider_list, fl_value_new_string(mapped_name.c_str()));
  }
  g_autoptr(FlValue) result = fl_value_new_map();
  const std::string ort_version = Ort::GetVersionString();
  fl_value_set_string_take(result, "ortVersion", fl_value_new_string(ort_version.c_str()));
  fl_value_set_string_take(result, "providers", provider_list);
  fl_value_set_string_take(result, "platform", fl_value_new_string("linux"));
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *run_inference(FlutterOnnxruntimePlugin *self, FlValue *args) {
  FlValue *session_id_value = fl_value_lookup_string(args, "sessionId");
  if (session_id_value == nullptr || fl_value_get_type(session_id_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("INVALID_ARG", "Session ID must be a non-null string", nullptr));
  }
  const char *session_id = fl_value_get_string(session_id_value);

  FlValue *inputs_value = fl_value_lookup_string(args, "inputs");
  if (inputs_value == nullptr || fl_value_get_type(inputs_value) != FL_VALUE_TYPE_MAP) { // inputs is a map from Dart
    return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_ARG", "Inputs must be a non-null map", nullptr));
  }

  FlValue *run_options_value = fl_value_lookup_string(args, "runOptions");

  // Check if session exists
  if (!self->session_manager->hasSession(session_id)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_SESSION", "Session not found", nullptr));
  }

  try {
    // Get expected input names from the session
    std::vector<std::string> output_names = self->session_manager->getOutputNames(session_id);

    // Prepare input tensors and input names
    // Use ClonedTensor to keep backing buffers alive during inference
    std::vector<ClonedTensor> cloned_inputs;
    std::vector<std::string> input_names;

    // Iterate through each input
    size_t num_inputs = fl_value_get_length(inputs_value);
    for (size_t i = 0; i < num_inputs; i++) {
      FlValue *key = fl_value_get_map_key(inputs_value, i);
      FlValue *value = fl_value_get_map_value(inputs_value, i);

      if (fl_value_get_type(key) != FL_VALUE_TYPE_STRING || fl_value_get_type(value) != FL_VALUE_TYPE_MAP) {
        continue;
      }

      // Extract the input name from the map key
      std::string input_name = fl_value_get_string(key);

      FlValue *tensor_id_map = fl_value_lookup_string(value, "valueId");

      if (tensor_id_map == nullptr || fl_value_get_type(tensor_id_map) != FL_VALUE_TYPE_STRING) {
        continue;
      }

      std::string tensor_id = fl_value_get_string(tensor_id_map);

      // Get the tensor value
      Ort::Value *tensor_ptr = self->tensor_manager->getTensor(tensor_id);
      if (tensor_ptr != nullptr) {
        try {
          // Clone the tensor — ClonedTensor owns both the Ort::Value and its backing buffer
          ClonedTensor cloned = self->tensor_manager->cloneTensor(tensor_id);
          cloned_inputs.push_back(std::move(cloned));
          input_names.push_back(input_name);
        } catch (const std::exception &e) {
          g_warning("Failed to clone tensor %s: %s", tensor_id.c_str(), e.what());
          // Continue with the next tensor
        }
      }
    }

    // Build a vector of Ort::Value references for Session::Run
    std::vector<Ort::Value> input_tensors;
    input_tensors.reserve(cloned_inputs.size());
    for (auto &ci : cloned_inputs) {
      input_tensors.push_back(std::move(ci.value));
    }

    // Create and configure run options
    Ort::RunOptions run_options;

    // Configure run options if provided
    if (run_options_value != nullptr && fl_value_get_type(run_options_value) == FL_VALUE_TYPE_MAP) {
      // Extract log severity level if provided
      FlValue *log_severity_level_value = fl_value_lookup_string(run_options_value, "logSeverityLevel");
      if (log_severity_level_value != nullptr && fl_value_get_type(log_severity_level_value) == FL_VALUE_TYPE_INT) {
        run_options.SetRunLogSeverityLevel(fl_value_get_int(log_severity_level_value));
      }

      // Extract log verbosity level if provided
      FlValue *log_verbosity_level_value = fl_value_lookup_string(run_options_value, "logVerbosityLevel");
      if (log_verbosity_level_value != nullptr && fl_value_get_type(log_verbosity_level_value) == FL_VALUE_TYPE_INT) {
        run_options.SetRunLogVerbosityLevel(fl_value_get_int(log_verbosity_level_value));
      }

      // Extract terminate option if provided
      FlValue *terminate_value = fl_value_lookup_string(run_options_value, "terminate");
      if (terminate_value != nullptr && fl_value_get_type(terminate_value) == FL_VALUE_TYPE_BOOL) {
        if (fl_value_get_bool(terminate_value)) {
          run_options.SetTerminate();
        }
      }
    }

    // Run inference using SessionManager with input names
    // Note: cloned_inputs (with backing buffers) stays alive through this scope
    std::vector<Ort::Value> output_tensors;
    if (!input_tensors.empty()) {
      output_tensors = self->session_manager->runInference(session_id, input_tensors, input_names, &run_options);
    }

    // Process outputs
    g_autoptr(FlValue) outputs_map = fl_value_new_map();

    // For each output tensor, directly store it using TensorManager's storeTensor
    for (size_t i = 0; i < output_tensors.size(); i++) {
      // Create a tensor ID
      std::string value_id = self->tensor_manager->generateTensorId();

      // Store the tensor directly using storeTensor - this transfers ownership
      self->tensor_manager->storeTensor(value_id, std::move(output_tensors[i]));

      // get the tensor type and shape from tensor manager
      // Note: only do this after storeTensor get the tensor registered in tensor manager
      std::string tensor_type = self->tensor_manager->getTensorType(value_id);
      std::vector<int64_t> shape = self->tensor_manager->getTensorShape(value_id);

      // Add the value ID to the outputs map
      FlValue *shape_list = fl_value_new_list();
      for (const auto &dim : shape) {
        fl_value_append_take(shape_list, fl_value_new_int(dim));
      }

      // Note: Flutter does not allow return a nested map, so we have to use list here to keep the output_info format
      FlValue *output_info = fl_value_new_list();
      fl_value_append_take(output_info, fl_value_new_string(value_id.c_str()));
      fl_value_append_take(output_info, fl_value_new_string(tensor_type.c_str()));
      fl_value_append_take(output_info, shape_list);

      fl_value_set_string_take(outputs_map, output_names[i].c_str(), output_info);
    }
    return FL_METHOD_RESPONSE(fl_method_success_response_new(outputs_map));
  } catch (const Ort::Exception &e) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("INFERENCE_ERROR", e.what(), nullptr));
  } catch (const std::exception &e) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("PLUGIN_ERROR", e.what(), nullptr));
  }
}

static FlMethodResponse *close_session(FlutterOnnxruntimePlugin *self, FlValue *args) {
  // Get session ID
  FlValue *session_id_value = fl_value_lookup_string(args, "sessionId");

  if (session_id_value == nullptr || fl_value_get_type(session_id_value) != FL_VALUE_TYPE_STRING) {
    // Similar to closeSession, return success even if ID is invalid.
    // Alternatively, return an error:
    return FL_METHOD_RESPONSE(
        fl_method_error_response_new("INVALID_ARG", "Session ID must be a non-null string", nullptr));
  }

  const char *session_id = fl_value_get_string(session_id_value);

  self->session_manager->closeSession(session_id);

  return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
}

static FlMethodResponse *get_metadata(FlutterOnnxruntimePlugin *self, FlValue *args) {
  FlValue *session_id_value = fl_value_lookup_string(args, "sessionId");

  if (session_id_value == nullptr || fl_value_get_type(session_id_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_SESSION", "Invalid session ID", nullptr));
  }

  const char *session_id = fl_value_get_string(session_id_value);

  if (!self->session_manager->hasSession(session_id)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_SESSION", "Session not found", nullptr));
  }

  try {
    // Get metadata using the SessionManager
    ModelMetadata metadata = self->session_manager->getModelMetadata(session_id);

    // Create empty custom metadata map
    FlValue *custom_metadata_map = fl_value_new_map();
    g_autoptr(FlValue) result = fl_value_new_map();
    fl_value_set_string_take(result, "producerName", fl_value_new_string(metadata.producer_name.c_str()));
    fl_value_set_string_take(result, "graphName", fl_value_new_string(metadata.graph_name.c_str()));
    fl_value_set_string_take(result, "domain", fl_value_new_string(metadata.domain.c_str()));
    fl_value_set_string_take(result, "description", fl_value_new_string(metadata.description.c_str()));
    fl_value_set_string_take(result, "version", fl_value_new_int(metadata.version));
    fl_value_set_string_take(result, "customMetadataMap", custom_metadata_map);
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } catch (const Ort::Exception &e) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("ORT_ERROR", e.what(), nullptr));
  } catch (const std::exception &e) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("PLUGIN_ERROR", e.what(), nullptr));
  }
}

static FlMethodResponse *get_input_info(FlutterOnnxruntimePlugin *self, FlValue *args) {
  FlValue *session_id_value = fl_value_lookup_string(args, "sessionId");

  if (session_id_value == nullptr || fl_value_get_type(session_id_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_SESSION", "Invalid session ID", nullptr));
  }

  const char *session_id = fl_value_get_string(session_id_value);

  if (!self->session_manager->hasSession(session_id)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_SESSION", "Session not found", nullptr));
  }

  try {
    // Get input info from SessionManager
    std::vector<TensorInfo> input_info = self->session_manager->getInputInfo(session_id);
    g_autoptr(FlValue) result = fl_value_new_list();

    for (const auto &info : input_info) {
      FlValue *info_map = fl_value_new_map();
      fl_value_set_string_take(info_map, "name", fl_value_new_string(info.name.c_str()));

      // Add shape
      FlValue *shape_list = fl_value_new_list();
      for (const auto &dim : info.shape) {
        fl_value_append_take(shape_list, fl_value_new_int(dim));
      }
      fl_value_set_string_take(info_map, "shape", shape_list);

      // Add type
      fl_value_set_string_take(info_map, "type", fl_value_new_string(info.type.c_str()));

      fl_value_append_take(result, info_map);
    }
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } catch (const Ort::Exception &e) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("ORT_ERROR", e.what(), nullptr));
  } catch (const std::exception &e) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("PLUGIN_ERROR", e.what(), nullptr));
  }
}

static FlMethodResponse *get_output_info(FlutterOnnxruntimePlugin *self, FlValue *args) {
  FlValue *session_id_value = fl_value_lookup_string(args, "sessionId");

  if (session_id_value == nullptr || fl_value_get_type(session_id_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_SESSION", "Invalid session ID", nullptr));
  }

  const char *session_id = fl_value_get_string(session_id_value);

  if (!self->session_manager->hasSession(session_id)) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_SESSION", "Session not found", nullptr));
  }

  try {
    // Get output info from SessionManager
    std::vector<TensorInfo> output_info = self->session_manager->getOutputInfo(session_id);
    g_autoptr(FlValue) result = fl_value_new_list();

    for (const auto &info : output_info) {
      FlValue *info_map = fl_value_new_map();
      fl_value_set_string_take(info_map, "name", fl_value_new_string(info.name.c_str()));

      // Add shape
      FlValue *shape_list = fl_value_new_list();
      for (const auto &dim : info.shape) {
        fl_value_append_take(shape_list, fl_value_new_int(dim));
      }
      fl_value_set_string_take(info_map, "shape", shape_list);

      // Add type
      fl_value_set_string_take(info_map, "type", fl_value_new_string(info.type.c_str()));

      fl_value_append_take(result, info_map);
    }
    return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
  } catch (const Ort::Exception &e) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("ORT_ERROR", e.what(), nullptr));
  } catch (const std::exception &e) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("PLUGIN_ERROR", e.what(), nullptr));
  }
}

static FlMethodResponse *create_ort_value(FlutterOnnxruntimePlugin *self, FlValue *args) {
  FlValue *source_type_value = fl_value_lookup_string(args, "sourceType");
  FlValue *data_value = fl_value_lookup_string(args, "data");
  FlValue *shape_value = fl_value_lookup_string(args, "shape");

  // Check if all required arguments are provided
  if (source_type_value == nullptr || data_value == nullptr || shape_value == nullptr ||
      fl_value_get_type(source_type_value) != FL_VALUE_TYPE_STRING ||
      fl_value_get_type(shape_value) != FL_VALUE_TYPE_LIST) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_ARG", "Missing required arguments", nullptr));
  }

  const char *source_type = fl_value_get_string(source_type_value);

  // Convert shape values to vector of int64_t
  size_t shape_size = fl_value_get_length(shape_value);
  std::vector<int64_t> shape;
  for (size_t i = 0; i < shape_size; i++) {
    FlValue *dim = fl_value_get_list_value(shape_value, i);
    if (fl_value_get_type(dim) != FL_VALUE_TYPE_INT) {
      return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_ARG", "Shape must contain integers", nullptr));
    }
    shape.push_back(fl_value_get_int(dim));
  }

  std::string valueId;

  try {
    // Handle data according to source type
    if (strcmp(source_type, "float32") == 0) {
      std::vector<float> data_vec;

      // Convert data to vector of floats
      if (fl_value_get_type(data_value) == FL_VALUE_TYPE_FLOAT32_LIST) {
        size_t data_size = fl_value_get_length(data_value);
        const float *float_array = fl_value_get_float32_list(data_value);
        data_vec.assign(float_array, float_array + data_size);
      } else if (fl_value_get_type(data_value) == FL_VALUE_TYPE_LIST) { // regular float list array
        size_t length = fl_value_get_length(data_value);
        data_vec.reserve(length);
        for (size_t i = 0; i < length; i++) {
          FlValue *val = fl_value_get_list_value(data_value, i);
          // Ensure it's a float or int (can be losslessly converted)
          if (fl_value_get_type(val) != FL_VALUE_TYPE_FLOAT && fl_value_get_type(val) != FL_VALUE_TYPE_INT) {
            return FL_METHOD_RESPONSE(fl_method_error_response_new(
                "INVALID_DATA", "Data must be a list of numbers for float32 type", nullptr));
          }
          data_vec.push_back(fl_value_get_float(val));
        }
      } else {
        return FL_METHOD_RESPONSE(
            fl_method_error_response_new("INVALID_DATA", "Data must be a list of numbers for float32 type", nullptr));
      }
      valueId = self->tensor_manager->createFloat32Tensor(data_vec, shape);
    } else if (strcmp(source_type, "int32") == 0) {
      std::vector<int32_t> data_vec;
      if (fl_value_get_type(data_value) == FL_VALUE_TYPE_INT32_LIST) {
        size_t data_size = fl_value_get_length(data_value);
        const int32_t *int_array = fl_value_get_int32_list(data_value);
        data_vec.assign(int_array, int_array + data_size);
      } else if (fl_value_get_type(data_value) == FL_VALUE_TYPE_LIST) {
        size_t length = fl_value_get_length(data_value);
        data_vec.reserve(length);
        for (size_t i = 0; i < length; i++) {
          FlValue *val = fl_value_get_list_value(data_value, i);
          if (fl_value_get_type(val) != FL_VALUE_TYPE_INT) {
            return FL_METHOD_RESPONSE(
                fl_method_error_response_new("INVALID_DATA", "Data must be a list of numbers for int32 type", nullptr));
          }
          data_vec.push_back(static_cast<int32_t>(fl_value_get_int(val))); // Explicit cast
        }
      } else {
        return FL_METHOD_RESPONSE(
            fl_method_error_response_new("INVALID_DATA", "Data must be a list of numbers for int32 type", nullptr));
      }
      valueId = self->tensor_manager->createInt32Tensor(data_vec, shape);
    } else if (strcmp(source_type, "int64") == 0) {
      std::vector<int64_t> data_vec;
      if (fl_value_get_type(data_value) == FL_VALUE_TYPE_INT64_LIST) {
        size_t data_size = fl_value_get_length(data_value);
        const int64_t *int_array = fl_value_get_int64_list(data_value);
        data_vec.assign(int_array, int_array + data_size);
      } else if (fl_value_get_type(data_value) == FL_VALUE_TYPE_LIST) {
        size_t length = fl_value_get_length(data_value);
        data_vec.reserve(length);
        for (size_t i = 0; i < length; i++) {
          FlValue *val = fl_value_get_list_value(data_value, i);
          if (fl_value_get_type(val) != FL_VALUE_TYPE_INT) {
            return FL_METHOD_RESPONSE(
                fl_method_error_response_new("INVALID_DATA", "Data must be a list of numbers for int64 type", nullptr));
          }
          data_vec.push_back(fl_value_get_int(val)); // Direct conversion works for int64
        }
      } else {
        return FL_METHOD_RESPONSE(
            fl_method_error_response_new("INVALID_DATA", "Data must be a list of numbers for int64 type", nullptr));
      }
      valueId = self->tensor_manager->createInt64Tensor(data_vec, shape);
    } else if (strcmp(source_type, "uint8") == 0) {
      std::vector<uint8_t> data_vec;
      if (fl_value_get_type(data_value) == FL_VALUE_TYPE_UINT8_LIST) {
        size_t data_size = fl_value_get_length(data_value);
        const uint8_t *uint_array = fl_value_get_uint8_list(data_value);
        data_vec.assign(uint_array, uint_array + data_size);
      } else if (fl_value_get_type(data_value) == FL_VALUE_TYPE_LIST) { // regular int list array
        size_t length = fl_value_get_length(data_value);
        data_vec.reserve(length);
        for (size_t i = 0; i < length; i++) {
          FlValue *val = fl_value_get_list_value(data_value, i);
          if (fl_value_get_type(val) != FL_VALUE_TYPE_INT) {
            return FL_METHOD_RESPONSE(
                fl_method_error_response_new("INVALID_DATA", "Data must be a list of numbers for int8 type", nullptr));
          }
          data_vec.push_back(static_cast<uint8_t>(fl_value_get_int(val))); // Explicit cast
        }
      } else {
        return FL_METHOD_RESPONSE(
            fl_method_error_response_new("INVALID_DATA", "Data must be a list of numbers for int8 type", nullptr));
      }
      valueId = self->tensor_manager->createUint8Tensor(data_vec, shape);
    } else if (strcmp(source_type, "bool") == 0) {
      std::vector<bool> data_vec;
      if (fl_value_get_type(data_value) == FL_VALUE_TYPE_LIST) {
        size_t length = fl_value_get_length(data_value);
        data_vec.reserve(length);
        for (size_t i = 0; i < length; i++) {
          FlValue *val = fl_value_get_list_value(data_value, i);
          if (fl_value_get_type(val) != FL_VALUE_TYPE_BOOL) {
            return FL_METHOD_RESPONSE(
                fl_method_error_response_new("INVALID_DATA", "Data must be a list of booleans for bool type", nullptr));
          }
          data_vec.push_back(fl_value_get_bool(val));
        }
      } else {
        return FL_METHOD_RESPONSE(
            fl_method_error_response_new("INVALID_DATA", "Data must be a list of booleans for bool type", nullptr));
      }
      valueId = self->tensor_manager->createBoolTensor(data_vec, shape);
    } else if (strcmp(source_type, "string") == 0) {
      std::vector<std::string> data_vec;
      if (fl_value_get_type(data_value) == FL_VALUE_TYPE_LIST) {
        size_t length = fl_value_get_length(data_value);
        data_vec.reserve(length);
        for (size_t i = 0; i < length; i++) {
          FlValue *val = fl_value_get_list_value(data_value, i);
          if (fl_value_get_type(val) != FL_VALUE_TYPE_STRING) {
            return FL_METHOD_RESPONSE(fl_method_error_response_new(
                "INVALID_DATA", "Data must be a list of strings for string type", nullptr));
          }
          data_vec.push_back(fl_value_get_string(val));
        }
      } else {
        return FL_METHOD_RESPONSE(
            fl_method_error_response_new("INVALID_DATA", "Data must be a list of strings for string type", nullptr));
      }
      valueId = self->tensor_manager->createStringTensor(data_vec, shape);
    } else {
      std::string error_message = "Unsupported source data type: ";
      error_message += source_type;
      return FL_METHOD_RESPONSE(fl_method_error_response_new("UNSUPPORTED_TYPE", error_message.c_str(), nullptr));
    }
  } catch (const std::exception &e) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("TENSOR_CREATION_ERROR", e.what(), nullptr));
  }

  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "valueId", fl_value_new_string(valueId.c_str()));
  fl_value_set_string_take(result, "dataType", fl_value_new_string(source_type));

  // Add shape to response
  FlValue *shape_list = fl_value_new_list();
  for (const auto &dim : shape) {
    fl_value_append_take(shape_list, fl_value_new_int(dim));
  }
  fl_value_set_string_take(result, "shape", shape_list);
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *convert_ort_value(FlutterOnnxruntimePlugin *self, FlValue *args) {
  FlValue *value_id_value = fl_value_lookup_string(args, "valueId");
  FlValue *target_type_value = fl_value_lookup_string(args, "targetType");

  // Check if required arguments are provided
  if (value_id_value == nullptr || target_type_value == nullptr ||
      fl_value_get_type(value_id_value) != FL_VALUE_TYPE_STRING ||
      fl_value_get_type(target_type_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_ARG", "Missing required arguments", nullptr));
  }

  // Get valueId and targetType
  const char *value_id = fl_value_get_string(value_id_value);
  const char *target_type = fl_value_get_string(target_type_value);

  std::string new_tensor_id;
  try {
    std::lock_guard<std::mutex> lock(self->mutex);

    new_tensor_id = self->tensor_manager->convertTensor(value_id, target_type);
  } catch (const std::exception &e) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("CONVERSION_ERROR", e.what(), nullptr));
  }

  std::vector<int64_t> shape = self->tensor_manager->getTensorShape(new_tensor_id);

  g_autoptr(FlValue) result = fl_value_new_map();
  fl_value_set_string_take(result, "valueId", fl_value_new_string(new_tensor_id.c_str()));
  fl_value_set_string_take(result, "dataType", fl_value_new_string(target_type)); // Use target type

  // Add shape
  FlValue *shape_list = fl_value_new_list();
  for (const auto &dim : shape) {
    fl_value_append_take(shape_list, fl_value_new_int(dim));
  }
  fl_value_set_string_take(result, "shape", shape_list);

  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static FlMethodResponse *get_ort_value_data(FlutterOnnxruntimePlugin *self, FlValue *args) {
  FlValue *value_id_value = fl_value_lookup_string(args, "valueId");

  if (value_id_value == nullptr || fl_value_get_type(value_id_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_ARG", "Invalid value ID", nullptr));
  }

  const char *value_id = fl_value_get_string(value_id_value);

  FlValue *tensor_data = nullptr;
  try {
    tensor_data = self->tensor_manager->getTensorData(value_id);

    // If tensor_data is null, it means tensor wasn't found or is invalid
    if (tensor_data == nullptr || fl_value_get_type(tensor_data) == FL_VALUE_TYPE_NULL) {
      if (tensor_data != nullptr) {
        fl_value_unref(tensor_data);
      }
      return FL_METHOD_RESPONSE(
          fl_method_error_response_new("INVALID_VALUE", "Tensor not found or already being disposed", nullptr));
    }
    return FL_METHOD_RESPONSE(fl_method_success_response_new(tensor_data)); // tensor_data ownership transferred
  } catch (const std::exception &e) {
    if (tensor_data != nullptr) {
      fl_value_unref(tensor_data);
    }
    return FL_METHOD_RESPONSE(fl_method_error_response_new("DATA_EXTRACTION_ERROR", e.what(), nullptr));
  }
}

static FlMethodResponse *release_ort_value(FlutterOnnxruntimePlugin *self, FlValue *args) {
  FlValue *value_id_value = fl_value_lookup_string(args, "valueId");

  if (value_id_value == nullptr || fl_value_get_type(value_id_value) != FL_VALUE_TYPE_STRING) {
    return FL_METHOD_RESPONSE(fl_method_error_response_new("INVALID_ARG", "Invalid value ID", nullptr));
  }

  const char *value_id = fl_value_get_string(value_id_value);

  self->tensor_manager->releaseTensor(value_id);

  return FL_METHOD_RESPONSE(fl_method_success_response_new(fl_value_new_null()));
}
