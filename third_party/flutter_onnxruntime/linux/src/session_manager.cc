// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#include "session_manager.h"
#include <iostream>

SessionManager::SessionManager() : next_session_id_(1), env_(ORT_LOGGING_LEVEL_WARNING, "FlutterOnnxRuntime") {
  // Initialize ONNX Runtime environment in constructor
}

SessionManager::~SessionManager() {
  // Clear all sessions
  std::lock_guard<std::mutex> lock(mutex_);
  sessions_.clear();
}

std::string SessionManager::createSession(const char *model_path, void *options) {
  std::lock_guard<std::mutex> lock(mutex_);

  // Generate a session ID
  std::string session_id = generateSessionId();

  try {
    // Create session options
    Ort::SessionOptions session_options;

    // If options are provided, use them
    if (options != nullptr) {
      // Cast the void* to the correct type
      Ort::SessionOptions *provided_options = static_cast<Ort::SessionOptions *>(options);

      // Directly use the provided options
      session_options = std::move(*provided_options);
    } else {
      // Configure default execution providers
      // Default to CPU execution provider
    }

    // Create a new session
    std::unique_ptr<Ort::Session> ort_session = std::make_unique<Ort::Session>(env_, model_path, session_options);

    // Create session info
    SessionInfo session_info;
    session_info.session = std::move(ort_session);

    // Get input names
    Ort::AllocatorWithDefaultOptions allocator;
    size_t num_inputs = session_info.session->GetInputCount();
    session_info.input_names.clear();

    for (size_t i = 0; i < num_inputs; i++) {
      auto input_name = session_info.session->GetInputNameAllocated(i, allocator);
      session_info.input_names.push_back(std::string(input_name.get()));
    }

    // Get output names
    size_t num_outputs = session_info.session->GetOutputCount();
    session_info.output_names.clear();

    for (size_t i = 0; i < num_outputs; i++) {
      auto output_name = session_info.session->GetOutputNameAllocated(i, allocator);
      session_info.output_names.push_back(std::string(output_name.get()));
    }

    // Store the session info
    sessions_[session_id] = std::move(session_info);

    return session_id;
  } catch (const Ort::Exception &e) {
    std::cerr << "ONNX Runtime Error: " << e.what() << std::endl;
    throw e;
  } catch (const std::exception &e) {
    std::cerr << "Error: " << e.what() << std::endl;
    throw e;
  }
}

bool SessionManager::closeSession(const std::string &session_id) {
  std::lock_guard<std::mutex> lock(mutex_);

  auto it = sessions_.find(session_id);
  if (it != sessions_.end()) {
    sessions_.erase(it);
    return true;
  }

  return false;
}

bool SessionManager::hasSession(const std::string &session_id) {
  std::lock_guard<std::mutex> lock(mutex_);
  return sessions_.find(session_id) != sessions_.end();
}

std::vector<std::string> SessionManager::getInputNames(const std::string &session_id) {
  std::lock_guard<std::mutex> lock(mutex_);

  auto it = sessions_.find(session_id);
  if (it != sessions_.end()) {
    return it->second.input_names;
  }

  return {};
}

std::vector<std::string> SessionManager::getOutputNames(const std::string &session_id) {
  std::lock_guard<std::mutex> lock(mutex_);

  auto it = sessions_.find(session_id);
  if (it != sessions_.end()) {
    return it->second.output_names;
  }

  return {};
}

std::string SessionManager::generateSessionId() { return "session_" + std::to_string(next_session_id_++); }

// Get element type string helper
const char *SessionManager::getElementTypeString(ONNXTensorElementDataType element_type) {
  switch (element_type) {
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT:
    return "float32";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8:
    return "uint8";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT8:
    return "int8";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT16:
    return "uint16";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT16:
    return "int16";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32:
    return "int32";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64:
    return "int64";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_STRING:
    return "string";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL:
    return "bool";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16:
    return "float16";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_DOUBLE:
    return "float64";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT32:
    return "uint32";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT64:
    return "uint64";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_COMPLEX64:
    return "complex64";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_COMPLEX128:
    return "complex128";
  case ONNX_TENSOR_ELEMENT_DATA_TYPE_BFLOAT16:
    return "bfloat16";
  default:
    return "unknown";
  }
}

// Get model metadata
ModelMetadata SessionManager::getModelMetadata(const std::string &session_id) {
  std::lock_guard<std::mutex> lock(mutex_);
  ModelMetadata metadata{};

  auto it = sessions_.find(session_id);
  if (it != sessions_.end()) {
    try {
      Ort::Session *session = it->second.session.get();
      if (session) {
        // Get model metadata
        Ort::ModelMetadata model_metadata = session->GetModelMetadata();
        Ort::AllocatorWithDefaultOptions allocator;

        // Extract metadata details
        auto producer_name = model_metadata.GetProducerNameAllocated(allocator);
        auto graph_name = model_metadata.GetGraphNameAllocated(allocator);
        auto domain = model_metadata.GetDomainAllocated(allocator);
        auto description = model_metadata.GetDescriptionAllocated(allocator);

        metadata.producer_name = producer_name.get();
        metadata.graph_name = graph_name.get();
        metadata.domain = domain.get();
        metadata.description = description.get();
        metadata.version = model_metadata.GetVersion();

        // Add custom metadata if needed
        // Currently returning an empty map as in the original implementation
      }
    } catch (const Ort::Exception &e) {
      std::cerr << "ONNX Runtime Error: " << e.what() << std::endl;
    } catch (const std::exception &e) {
      std::cerr << "Error: " << e.what() << std::endl;
    }
  }

  return metadata;
}

// Get input info
std::vector<TensorInfo> SessionManager::getInputInfo(const std::string &session_id) {
  std::lock_guard<std::mutex> lock(mutex_);
  std::vector<TensorInfo> info_list;

  auto it = sessions_.find(session_id);
  if (it != sessions_.end()) {
    try {
      Ort::Session *session = it->second.session.get();
      if (session) {
        size_t num_inputs = session->GetInputCount();
        Ort::AllocatorWithDefaultOptions allocator;

        for (size_t i = 0; i < num_inputs; i++) {
          TensorInfo info{};

          // Get input name
          auto input_name = session->GetInputNameAllocated(i, allocator);
          info.name = input_name.get();

          // Get type and shape
          auto type_info = session->GetInputTypeInfo(i);
          ONNXType onnx_type = type_info.GetONNXType();

          if (onnx_type == ONNX_TYPE_TENSOR) {
            auto tensor_info = type_info.GetTensorTypeAndShapeInfo();
            info.shape = tensor_info.GetShape();

            // Get element type
            ONNXTensorElementDataType element_type = tensor_info.GetElementType();
            info.type = getElementTypeString(element_type);
          } else {
            // Non-tensor type
            info.type = "non-tensor";
          }

          info_list.push_back(info);
        }
      }
    } catch (const Ort::Exception &e) {
      std::cerr << "ONNX Runtime Error: " << e.what() << std::endl;
    } catch (const std::exception &e) {
      std::cerr << "Error: " << e.what() << std::endl;
    }
  }

  return info_list;
}

// Get output info
std::vector<TensorInfo> SessionManager::getOutputInfo(const std::string &session_id) {
  std::lock_guard<std::mutex> lock(mutex_);
  std::vector<TensorInfo> info_list;

  auto it = sessions_.find(session_id);
  if (it != sessions_.end()) {
    try {
      Ort::Session *session = it->second.session.get();
      if (session) {
        size_t num_outputs = session->GetOutputCount();
        Ort::AllocatorWithDefaultOptions allocator;

        for (size_t i = 0; i < num_outputs; i++) {
          TensorInfo info{};

          // Get output name
          auto output_name = session->GetOutputNameAllocated(i, allocator);
          info.name = output_name.get();

          // Get type and shape
          auto type_info = session->GetOutputTypeInfo(i);
          ONNXType onnx_type = type_info.GetONNXType();

          if (onnx_type == ONNX_TYPE_TENSOR) {
            auto tensor_info = type_info.GetTensorTypeAndShapeInfo();
            info.shape = tensor_info.GetShape();

            // Get element type
            ONNXTensorElementDataType element_type = tensor_info.GetElementType();
            info.type = getElementTypeString(element_type);
          } else {
            // Non-tensor type
            info.type = "non-tensor";
          }

          info_list.push_back(info);
        }
      }
    } catch (const Ort::Exception &e) {
      std::cerr << "ONNX Runtime Error: " << e.what() << std::endl;
    } catch (const std::exception &e) {
      std::cerr << "Error: " << e.what() << std::endl;
    }
  }

  return info_list;
}

// Run inference with provided input names
std::vector<Ort::Value> SessionManager::runInference(const std::string &session_id,
                                                     const std::vector<Ort::Value> &input_tensors,
                                                     const std::vector<std::string> &input_names,
                                                     Ort::RunOptions *run_options) {

  std::lock_guard<std::mutex> lock(mutex_);
  std::vector<Ort::Value> output_tensors;

  auto it = sessions_.find(session_id);
  if (it == sessions_.end()) {
    throw Ort::Exception("Session not found", ORT_INVALID_ARGUMENT);
  }

  Ort::Session *session = it->second.session.get();
  if (!session) {
    throw Ort::Exception("Session is invalid", ORT_INVALID_ARGUMENT);
  }

  if (input_tensors.empty()) {
    throw Ort::Exception("No input tensors provided", ORT_INVALID_ARGUMENT);
  }

  if (input_names.size() != input_tensors.size()) {
    throw Ort::Exception("Number of input names must match number of input tensors", ORT_INVALID_ARGUMENT);
  }

  // Prepare input names
  std::vector<const char *> input_names_char;
  for (const auto &name : input_names) {
    input_names_char.push_back(name.c_str());
  }

  // Prepare output names
  std::vector<const char *> output_names_char;
  for (const auto &name : it->second.output_names) {
    output_names_char.push_back(name.c_str());
  }

  // Create default run options if none provided
  Ort::RunOptions default_run_options;
  Ort::RunOptions *run_opts = run_options ? run_options : &default_run_options;

  // Run inference - let exceptions propagate out
  output_tensors = session->Run(*run_opts, input_names_char.data(), input_tensors.data(), input_tensors.size(),
                                output_names_char.data(), output_names_char.size());

  return output_tensors;
}