// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#ifndef FLUTTER_ONNXRUNTIME_SESSION_MANAGER_H_
#define FLUTTER_ONNXRUNTIME_SESSION_MANAGER_H_

#include "pch.h"
#include <map>
#include <memory>
#include <mutex>
#include <onnxruntime_cxx_api.h>
#include <string>
#include <vector>

namespace flutter_onnxruntime {

// Forward declaration
class TensorManager;

// Session information structure
struct SessionInfo {
  std::unique_ptr<Ort::Session> session;
  std::vector<std::string> input_names;
  std::vector<std::string> output_names;
};

// Model metadata structure
struct ModelMetadata {
  std::string producer_name;
  std::string graph_name;
  std::string domain;
  std::string description;
  int64_t version;
  std::map<std::string, std::string> custom_metadata;
};

// Input/Output tensor info structure
struct TensorInfo {
  std::string name;
  std::string type;
  std::vector<int64_t> shape;
};

// Manages ONNX Runtime sessions with proper resource handling
class SessionManager {
public:
  SessionManager();
  ~SessionManager();

  // Create a new session from a model file path
  std::string createSession(const char *model_path, const Ort::SessionOptions &session_options);

  // Close and remove a session
  bool closeSession(const std::string &session_id);

  // Get session info
  bool hasSession(const std::string &session_id);

  // Get input names for a session
  std::vector<std::string> getInputNames(const std::string &session_id);

  // Get output names for a session
  std::vector<std::string> getOutputNames(const std::string &session_id);

  // Get model metadata for a session
  ModelMetadata getModelMetadata(const std::string &session_id);

  // Get input tensor info for a session
  std::vector<TensorInfo> getInputInfo(const std::string &session_id);

  // Get output tensor info for a session
  std::vector<TensorInfo> getOutputInfo(const std::string &session_id);

  // Run inference with a session using provided input names
  std::vector<Ort::Value> runInference(const std::string &session_id, const std::vector<Ort::Value> &input_tensors,
                                       const std::vector<std::string> &input_names,
                                       Ort::RunOptions *run_options = nullptr);

  // Helper method to get element type string
  static const char *getElementTypeString(ONNXTensorElementDataType element_type);

private:
  // Generate a unique session ID
  std::string generateSessionId();

  // Map of session IDs to session info
  std::map<std::string, SessionInfo> sessions_;

  // Counter for generating unique session IDs
  int next_session_id_;

  // Mutex for thread safety
  std::mutex mutex_;

  // ONNX Runtime environment
  Ort::Env env_;
};

} // namespace flutter_onnxruntime

#endif // FLUTTER_ONNXRUNTIME_SESSION_MANAGER_H_