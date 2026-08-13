// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#include "tensor_manager.h"
#include "session_manager.h"
#include "value_conversion.h"

TensorManager::TensorManager()
    : next_tensor_id_(1), memory_info_(Ort::MemoryInfo::CreateCpu(OrtArenaAllocator, OrtMemTypeDefault)) {}

TensorManager::~TensorManager() {
  std::lock_guard<std::mutex> lock(mutex_);
  tensors_.clear();
  tensor_types_.clear();
  tensor_shapes_.clear();
  tensor_data_buffers_.clear();
}

std::string TensorManager::generateTensorId() { return "tensor_" + std::to_string(next_tensor_id_++); }

std::string TensorManager::createFloat32Tensor(const std::vector<float> &data, const std::vector<int64_t> &shape) {
  std::lock_guard<std::mutex> lock(mutex_);

  try {
    // Create a unique tensor ID
    std::string tensor_id = generateTensorId();
    // Store data in a managed buffer so it is freed when the tensor is released
    std::vector<uint8_t> buffer(data.size() * sizeof(float));
    std::memcpy(buffer.data(), data.data(), data.size() * sizeof(float));
    float *tensor_data = reinterpret_cast<float *>(buffer.data());
    // Create a new tensor with the buffer-backed data
    auto tensor = Ort::Value::CreateTensor<float>(memory_info_, tensor_data, data.size(), shape.data(), shape.size());
    // Store the tensor, its type, shape, and backing buffer
    tensors_[tensor_id] = std::make_unique<Ort::Value>(std::move(tensor));
    tensor_data_buffers_[tensor_id] = std::move(buffer);
    tensor_types_[tensor_id] = "float32";
    tensor_shapes_[tensor_id] = shape;

    return tensor_id;
  } catch (const Ort::Exception &e) {
    throw;
  }
}

std::string TensorManager::createInt32Tensor(const std::vector<int32_t> &data, const std::vector<int64_t> &shape) {
  std::lock_guard<std::mutex> lock(mutex_);

  try {
    // Create a unique tensor ID
    std::string tensor_id = generateTensorId();
    // Store data in a managed buffer so it is freed when the tensor is released
    std::vector<uint8_t> buffer(data.size() * sizeof(int32_t));
    std::memcpy(buffer.data(), data.data(), data.size() * sizeof(int32_t));
    int32_t *tensor_data = reinterpret_cast<int32_t *>(buffer.data());
    // Create a new tensor with the buffer-backed data
    auto tensor = Ort::Value::CreateTensor<int32_t>(memory_info_, tensor_data, data.size(), shape.data(), shape.size());
    // Store the tensor, its type, shape, and backing buffer
    tensors_[tensor_id] = std::make_unique<Ort::Value>(std::move(tensor));
    tensor_data_buffers_[tensor_id] = std::move(buffer);
    tensor_types_[tensor_id] = "int32";
    tensor_shapes_[tensor_id] = shape;

    return tensor_id;
  } catch (const Ort::Exception &e) {
    throw;
  }
}

std::string TensorManager::createInt64Tensor(const std::vector<int64_t> &data, const std::vector<int64_t> &shape) {
  std::lock_guard<std::mutex> lock(mutex_);

  try {
    // Create a unique tensor ID
    std::string tensor_id = generateTensorId();
    // Store data in a managed buffer so it is freed when the tensor is released
    std::vector<uint8_t> buffer(data.size() * sizeof(int64_t));
    std::memcpy(buffer.data(), data.data(), data.size() * sizeof(int64_t));
    int64_t *tensor_data = reinterpret_cast<int64_t *>(buffer.data());
    // Create a new tensor with the buffer-backed data
    auto tensor = Ort::Value::CreateTensor<int64_t>(memory_info_, tensor_data, data.size(), shape.data(), shape.size());
    // Store the tensor, its type, shape, and backing buffer
    tensors_[tensor_id] = std::make_unique<Ort::Value>(std::move(tensor));
    tensor_data_buffers_[tensor_id] = std::move(buffer);
    tensor_types_[tensor_id] = "int64";
    tensor_shapes_[tensor_id] = shape;

    return tensor_id;
  } catch (const Ort::Exception &e) {
    throw;
  }
}

std::string TensorManager::createUint8Tensor(const std::vector<uint8_t> &data, const std::vector<int64_t> &shape) {
  std::lock_guard<std::mutex> lock(mutex_);

  try {
    // Create a unique tensor ID
    std::string tensor_id = generateTensorId();
    // Store data in a managed buffer so it is freed when the tensor is released
    std::vector<uint8_t> buffer(data.size() * sizeof(uint8_t));
    std::memcpy(buffer.data(), data.data(), data.size() * sizeof(uint8_t));
    // Create a new tensor with the buffer-backed data
    auto tensor =
        Ort::Value::CreateTensor<uint8_t>(memory_info_, buffer.data(), data.size(), shape.data(), shape.size());
    // Store the tensor, its type, shape, and backing buffer
    tensors_[tensor_id] = std::make_unique<Ort::Value>(std::move(tensor));
    tensor_data_buffers_[tensor_id] = std::move(buffer);
    tensor_types_[tensor_id] = "uint8";
    tensor_shapes_[tensor_id] = shape;

    return tensor_id;
  } catch (const Ort::Exception &e) {
    throw;
  }
}

std::string TensorManager::createBoolTensor(const std::vector<bool> &data, const std::vector<int64_t> &shape) {
  std::lock_guard<std::mutex> lock(mutex_);

  try {
    // Create a unique tensor ID
    std::string tensor_id = generateTensorId();
    // Store data in a managed buffer (std::vector<bool> is specialized and can't be used directly)
    std::vector<uint8_t> buffer(data.size() * sizeof(bool));
    bool *tensor_data = reinterpret_cast<bool *>(buffer.data());
    for (size_t i = 0; i < data.size(); i++) {
      tensor_data[i] = data[i];
    }
    // Create a new tensor with the buffer-backed data
    auto tensor = Ort::Value::CreateTensor<bool>(memory_info_, tensor_data, data.size(), shape.data(), shape.size());
    // Store the tensor, its type, shape, and backing buffer
    tensors_[tensor_id] = std::make_unique<Ort::Value>(std::move(tensor));
    tensor_data_buffers_[tensor_id] = std::move(buffer);
    tensor_types_[tensor_id] = "bool";
    tensor_shapes_[tensor_id] = shape;

    return tensor_id;
  } catch (const Ort::Exception &e) {
    throw;
  }
}

std::string TensorManager::createStringTensor(const std::vector<std::string> &data, const std::vector<int64_t> &shape) {
  std::lock_guard<std::mutex> lock(mutex_);

  try {
    // Create a unique tensor ID
    std::string tensor_id = generateTensorId();

    // Create a C-style array of const char* for ONNX Runtime
    const char **tensor_data = new const char *[data.size()];
    for (size_t i = 0; i < data.size(); i++) {
      tensor_data[i] = data[i].c_str();
    }

    OrtAllocator *allocator = nullptr;
    // Follow the test at:
    // https://github.com/microsoft/onnxruntime/blob/4adef01e741b2327188279dcd63bc55c5d2307e9/onnxruntime/test/shared_lib/test_inference.cc#L4278
    // create allocator with default options
    Ort::ThrowOnError(Ort::GetApi().GetAllocatorWithDefaultOptions(&allocator));
    auto tensor = Ort::Value::CreateTensor(allocator, shape.data(), shape.size(), ONNX_TENSOR_ELEMENT_DATA_TYPE_STRING);

    // Fill the tensor with string data
    Ort::ThrowOnError(Ort::GetApi().FillStringTensor(tensor, tensor_data, data.size()));

    delete[] tensor_data;

    tensors_[tensor_id] = std::make_unique<Ort::Value>(std::move(tensor));
    tensor_types_[tensor_id] = "string";
    tensor_shapes_[tensor_id] = shape;

    return tensor_id;
  } catch (const Ort::Exception &e) {
    throw;
  }
}

FlValue *TensorManager::getTensorData(const std::string &tensor_id) {
  std::lock_guard<std::mutex> lock(mutex_);

  // Check if the tensor exists
  auto tensor_it = tensors_.find(tensor_id);
  auto type_it = tensor_types_.find(tensor_id);
  auto shape_it = tensor_shapes_.find(tensor_id);

  if (tensor_it == tensors_.end() || type_it == tensor_types_.end() || shape_it == tensor_shapes_.end()) {
    // Tensor not found
    return fl_value_new_null();
  }

  // Create result map
  g_autoptr(FlValue) result = fl_value_new_map();

  try {
    // Get tensor type
    const std::string &tensor_type = type_it->second;

    // Get tensor shape
    const std::vector<int64_t> &shape = shape_it->second;

    // Convert shape to FlValue
    FlValue *shape_list = fl_value_new_list();
    for (const auto &dim : shape) {
      fl_value_append_take(shape_list, fl_value_new_int(static_cast<int64_t>(dim)));
    }

    // Set shape and type in result
    fl_value_set_string_take(result, "shape", shape_list);
    fl_value_set_string_take(result, "dataType", fl_value_new_string(tensor_type.c_str()));
    // Get tensor info
    Ort::Value *tensor = tensor_it->second.get();
    Ort::TensorTypeAndShapeInfo tensor_info = tensor->GetTensorTypeAndShapeInfo();
    size_t elem_count = tensor_info.GetElementCount();

    // Handle different tensor types
    if (tensor_type == "float32") {
      // Get float data from tensor
      float *tensor_data = tensor->GetTensorMutableData<float>();

      // Create typed data list (Float32List)
      FlValue *data_list = fl_value_new_float32_list(tensor_data, elem_count);

      // Set data in result
      fl_value_set_string_take(result, "data", data_list);
    } else if (tensor_type == "int32") {
      // Get int32 data from tensor
      int32_t *tensor_data = tensor->GetTensorMutableData<int32_t>();

      // Create typed data list (Int32List)
      FlValue *data_list = fl_value_new_int32_list(tensor_data, elem_count);

      // Set data in result
      fl_value_set_string_take(result, "data", data_list);
    } else if (tensor_type == "int64") {
      // Get int64 data from tensor
      int64_t *tensor_data = tensor->GetTensorMutableData<int64_t>();

      // Create typed data list (Int64List)
      FlValue *data_list = fl_value_new_int64_list(tensor_data, elem_count);

      // Set data in result
      fl_value_set_string_take(result, "data", data_list);
    } else if (tensor_type == "uint8") {
      // Get uint8 data from tensor
      uint8_t *tensor_data = tensor->GetTensorMutableData<uint8_t>();

      // Create typed data list (Uint8List)
      FlValue *data_list = fl_value_new_uint8_list(tensor_data, elem_count);

      // Set data in result
      fl_value_set_string_take(result, "data", data_list);
    } else if (tensor_type == "bool") {
      // Get bool data from tensor
      bool *tensor_data = tensor->GetTensorMutableData<bool>();

      // Create data list and copy values - convert bool to int for Flutter compatibility
      std::vector<bool> data_vec(tensor_data, tensor_data + elem_count);
      FlValue *data_list = vector_to_fl_value(data_vec);

      // Set data in result
      fl_value_set_string_take(result, "data", data_list);
    } else if (tensor_type == "string") {
      // Create a list for the strings
      FlValue *data_list = fl_value_new_list();

      // Extract strings from the tensor
      for (size_t i = 0; i < elem_count; i++) {
        std::string s = tensor->GetStringTensorElement(i);
        // Add the string to the list
        fl_value_append_take(data_list, fl_value_new_string(s.c_str()));
      }

      // Set data in result
      fl_value_set_string_take(result, "data", data_list);
    } else {
      // Unsupported tensor type
      throw std::runtime_error("Unsupported tensor type: " + tensor_type);
    }
  } catch (const Ort::Exception &e) {
    throw std::runtime_error(e.what());
  }

  return fl_value_ref(result);
}

bool TensorManager::releaseTensor(const std::string &tensor_id) {
  std::lock_guard<std::mutex> lock(mutex_);

  auto tensor_it = tensors_.find(tensor_id);
  auto type_it = tensor_types_.find(tensor_id);
  auto shape_it = tensor_shapes_.find(tensor_id);
  auto buffer_it = tensor_data_buffers_.find(tensor_id);

  if (tensor_it == tensors_.end()) {
    return false;
  }

  // Remove tensor, type, shape, and buffer
  tensors_.erase(tensor_it);
  if (type_it != tensor_types_.end()) {
    tensor_types_.erase(type_it);
  }
  if (shape_it != tensor_shapes_.end()) {
    tensor_shapes_.erase(shape_it);
  }
  if (buffer_it != tensor_data_buffers_.end()) {
    tensor_data_buffers_.erase(buffer_it);
  }

  return true;
}

Ort::Value *TensorManager::getTensor(const std::string &tensor_id) {
  std::lock_guard<std::mutex> lock(mutex_);

  auto it = tensors_.find(tensor_id);
  if (it == tensors_.end()) {
    return nullptr;
  }

  return it->second.get();
}

void TensorManager::storeTensor(const std::string &tensor_id, Ort::Value &&tensor) {
  std::lock_guard<std::mutex> lock(mutex_);

  try {
    // Store the tensor
    tensors_[tensor_id] = std::make_unique<Ort::Value>(std::move(tensor));

    // Get tensor info to store type and shape
    Ort::TensorTypeAndShapeInfo tensor_info = tensors_[tensor_id]->GetTensorTypeAndShapeInfo();

    // Get and store the tensor shape
    auto shape = tensor_info.GetShape();
    tensor_shapes_[tensor_id] = shape;

    // Get and store the tensor type
    ONNXTensorElementDataType element_type = tensor_info.GetElementType();
    tensor_types_[tensor_id] = SessionManager::getElementTypeString(element_type);
  } catch (const std::exception &e) {
    // Handle exception - maybe log it
  }
}

std::string TensorManager::getTensorType(const std::string &tensor_id) {
  std::lock_guard<std::mutex> lock(mutex_);
  return tensor_types_.at(tensor_id);
}

std::vector<int64_t> TensorManager::getTensorShape(const std::string &tensor_id) {
  std::lock_guard<std::mutex> lock(mutex_);
  return tensor_shapes_.at(tensor_id);
}

std::string TensorManager::convertTensor(const std::string &tensor_id, const std::string &target_type) {

  std::lock_guard<std::mutex> lock(mutex_);

  // Check if the tensor exists
  auto tensor_it = tensors_.find(tensor_id);
  auto type_it = tensor_types_.find(tensor_id);
  auto shape_it = tensor_shapes_.find(tensor_id);

  if (tensor_it == tensors_.end() || type_it == tensor_types_.end() || shape_it == tensor_shapes_.end()) {
    throw std::runtime_error("Tensor not found");
  }
  const std::string &source_type = type_it->second;

  // If the target type is the same as the source type, just clone the tensor
  if (source_type == target_type) {

    // Clone the tensor (returns ClonedTensor with managed buffer)
    auto cloned = cloneTensorLocked(tensor_id);
    // Create a new tensor ID
    std::string new_tensor_id = generateTensorId();
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(cloned.value));
    if (!cloned.buffer.empty()) {
      tensor_data_buffers_[new_tensor_id] = std::move(cloned.buffer);
    }

    // Store the type and shape
    Ort::Value *tensor = tensor_it->second.get();
    Ort::TensorTypeAndShapeInfo tensor_info = tensor->GetTensorTypeAndShapeInfo();
    std::vector<int64_t> shape = tensor_info.GetShape();
    tensor_types_[new_tensor_id] = source_type;
    tensor_shapes_[new_tensor_id] = shape;

    return new_tensor_id;
  }

  // Convert based on the source type
  if (source_type == "float32") {
    return convertFloat32To(tensor_id, target_type);
  } else if (source_type == "int32") {
    return convertInt32To(tensor_id, target_type);
  } else if (source_type == "int64") {
    return convertInt64To(tensor_id, target_type);
  } else if (source_type == "uint8") {
    return convertUint8To(tensor_id, target_type);
  } else if (source_type == "bool") {
    return convertBoolTo(tensor_id, target_type);
  }

  throw std::runtime_error("Unsupported type conversion: " + source_type + " to " + target_type);
}

std::string TensorManager::convertFloat32To(const std::string &tensor_id, const std::string &target_type) {
  // Get the tensor
  Ort::Value *tensor = tensors_[tensor_id].get();
  Ort::TensorTypeAndShapeInfo tensor_info = tensor->GetTensorTypeAndShapeInfo();
  size_t elem_count = tensor_info.GetElementCount();
  std::vector<int64_t> shape = tensor_info.GetShape();
  float *data = tensor->GetTensorMutableData<float>();

  // Create a new tensor ID
  std::string new_tensor_id = generateTensorId();

  // Convert to the target type
  if (target_type == "int32") {
    // Convert float32 to int32
    std::vector<uint8_t> buffer(elem_count * sizeof(int32_t));
    int32_t *new_data = reinterpret_cast<int32_t *>(buffer.data());
    for (size_t i = 0; i < elem_count; i++) {
      // Round float to int
      new_data[i] = static_cast<int32_t>(data[i] + (data[i] >= 0 ? 0.5f : -0.5f));
    }
    auto new_tensor = Ort::Value::CreateTensor<int32_t>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else if (target_type == "int64") {
    // Convert float32 to int64
    std::vector<uint8_t> buffer(elem_count * sizeof(int64_t));
    int64_t *new_data = reinterpret_cast<int64_t *>(buffer.data());
    for (size_t i = 0; i < elem_count; i++) {
      // Round float to int64
      new_data[i] = static_cast<int64_t>(data[i] + (data[i] >= 0 ? 0.5f : -0.5f));
    }
    auto new_tensor = Ort::Value::CreateTensor<int64_t>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else if (target_type == "uint8") {
    // Convert float32 to uint8
    std::vector<uint8_t> buffer(elem_count * sizeof(uint8_t));
    uint8_t *new_data = buffer.data();
    for (size_t i = 0; i < elem_count; i++) {
      // Clamp between 0 and 255
      float val = data[i] < 0 ? 0 : (data[i] > 255 ? 255 : data[i] + 0.5f);
      new_data[i] = static_cast<uint8_t>(val);
    }
    auto new_tensor = Ort::Value::CreateTensor<uint8_t>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else if (target_type == "bool") {
    // Convert float32 to bool
    std::vector<uint8_t> buffer(elem_count * sizeof(bool));
    bool *new_data = reinterpret_cast<bool *>(buffer.data());
    for (size_t i = 0; i < elem_count; i++) {
      new_data[i] = data[i] != 0.0f;
    }
    auto new_tensor = Ort::Value::CreateTensor<bool>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else {
    throw std::runtime_error("Unsupported type: " + target_type);
  }

  // Store the shape
  tensor_shapes_[new_tensor_id] = shape;
  tensor_types_[new_tensor_id] = target_type;

  return new_tensor_id;
}

std::string TensorManager::convertInt32To(const std::string &tensor_id, const std::string &target_type) {
  // Get the tensor
  Ort::Value *tensor = tensors_[tensor_id].get();
  Ort::TensorTypeAndShapeInfo tensor_info = tensor->GetTensorTypeAndShapeInfo();
  size_t elem_count = tensor_info.GetElementCount();
  std::vector<int64_t> shape = tensor_info.GetShape();
  int32_t *data = tensor->GetTensorMutableData<int32_t>();

  // Create a new tensor ID
  std::string new_tensor_id = generateTensorId();

  // Convert to the target type
  if (target_type == "float32") {
    // Convert int32 to float32
    std::vector<uint8_t> buffer(elem_count * sizeof(float));
    float *new_data = reinterpret_cast<float *>(buffer.data());
    for (size_t i = 0; i < elem_count; i++) {
      new_data[i] = static_cast<float>(data[i]);
    }
    auto new_tensor = Ort::Value::CreateTensor<float>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else if (target_type == "int64") {
    // Convert int32 to int64
    std::vector<uint8_t> buffer(elem_count * sizeof(int64_t));
    int64_t *new_data = reinterpret_cast<int64_t *>(buffer.data());
    for (size_t i = 0; i < elem_count; i++) {
      new_data[i] = static_cast<int64_t>(data[i]);
    }
    auto new_tensor = Ort::Value::CreateTensor<int64_t>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else if (target_type == "uint8") {
    // Convert int32 to uint8
    std::vector<uint8_t> buffer(elem_count * sizeof(uint8_t));
    uint8_t *new_data = buffer.data();
    for (size_t i = 0; i < elem_count; i++) {
      // Clamp between 0 and 255
      int32_t val = data[i] < 0 ? 0 : (data[i] > 255 ? 255 : data[i]);
      new_data[i] = static_cast<uint8_t>(val);
    }
    auto new_tensor = Ort::Value::CreateTensor<uint8_t>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else if (target_type == "bool") {
    // Convert int32 to bool
    std::vector<uint8_t> buffer(elem_count * sizeof(bool));
    bool *new_data = reinterpret_cast<bool *>(buffer.data());
    for (size_t i = 0; i < elem_count; i++) {
      new_data[i] = data[i] != 0;
    }
    auto new_tensor = Ort::Value::CreateTensor<bool>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else {
    throw std::runtime_error("Unsupported type: " + target_type);
  }

  // Store the shape
  tensor_shapes_[new_tensor_id] = shape;
  tensor_types_[new_tensor_id] = target_type;

  return new_tensor_id;
}

std::string TensorManager::convertInt64To(const std::string &tensor_id, const std::string &target_type) {
  // Get the tensor
  Ort::Value *tensor = tensors_[tensor_id].get();
  Ort::TensorTypeAndShapeInfo tensor_info = tensor->GetTensorTypeAndShapeInfo();
  size_t elem_count = tensor_info.GetElementCount();
  std::vector<int64_t> shape = tensor_info.GetShape();
  int64_t *data = tensor->GetTensorMutableData<int64_t>();

  // Create a new tensor ID
  std::string new_tensor_id = generateTensorId();

  // Convert to the target type
  if (target_type == "float32") {
    // Convert int64 to float32
    std::vector<uint8_t> buffer(elem_count * sizeof(float));
    float *new_data = reinterpret_cast<float *>(buffer.data());
    for (size_t i = 0; i < elem_count; i++) {
      // Note: potential precision loss for large int64 values
      new_data[i] = static_cast<float>(data[i]);
    }
    auto new_tensor = Ort::Value::CreateTensor<float>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else if (target_type == "int32") {
    // Convert int64 to int32
    std::vector<uint8_t> buffer(elem_count * sizeof(int32_t));
    int32_t *new_data = reinterpret_cast<int32_t *>(buffer.data());
    for (size_t i = 0; i < elem_count; i++) {
      // Clamp to int32 range to prevent overflow
      int64_t val = data[i];
      if (val > INT32_MAX)
        val = INT32_MAX;
      if (val < INT32_MIN)
        val = INT32_MIN;
      new_data[i] = static_cast<int32_t>(val);
    }
    auto new_tensor = Ort::Value::CreateTensor<int32_t>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else if (target_type == "uint8") {
    // Convert int64 to uint8
    std::vector<uint8_t> buffer(elem_count * sizeof(uint8_t));
    uint8_t *new_data = buffer.data();
    for (size_t i = 0; i < elem_count; i++) {
      // Clamp between 0 and 255
      int64_t val = data[i] < 0 ? 0 : (data[i] > 255 ? 255 : data[i]);
      new_data[i] = static_cast<uint8_t>(val);
    }
    auto new_tensor = Ort::Value::CreateTensor<uint8_t>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else if (target_type == "bool") {
    // Convert int64 to bool
    std::vector<uint8_t> buffer(elem_count * sizeof(bool));
    bool *new_data = reinterpret_cast<bool *>(buffer.data());
    for (size_t i = 0; i < elem_count; i++) {
      new_data[i] = data[i] != 0;
    }
    auto new_tensor = Ort::Value::CreateTensor<bool>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else {
    throw std::runtime_error("Unsupported type: " + target_type);
  }

  // Store the shape
  tensor_shapes_[new_tensor_id] = shape;
  tensor_types_[new_tensor_id] = target_type;

  return new_tensor_id;
}

std::string TensorManager::convertUint8To(const std::string &tensor_id, const std::string &target_type) {
  // Get the tensor
  Ort::Value *tensor = tensors_[tensor_id].get();
  Ort::TensorTypeAndShapeInfo tensor_info = tensor->GetTensorTypeAndShapeInfo();
  size_t elem_count = tensor_info.GetElementCount();
  std::vector<int64_t> shape = tensor_info.GetShape();
  uint8_t *data = tensor->GetTensorMutableData<uint8_t>();

  // Create a new tensor ID
  std::string new_tensor_id = generateTensorId();

  // Convert to the target type
  if (target_type == "float32") {
    // Convert uint8 to float32
    std::vector<uint8_t> buffer(elem_count * sizeof(float));
    float *new_data = reinterpret_cast<float *>(buffer.data());
    for (size_t i = 0; i < elem_count; i++) {
      new_data[i] = static_cast<float>(data[i]);
    }
    auto new_tensor = Ort::Value::CreateTensor<float>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else if (target_type == "int32") {
    // Convert uint8 to int32
    std::vector<uint8_t> buffer(elem_count * sizeof(int32_t));
    int32_t *new_data = reinterpret_cast<int32_t *>(buffer.data());
    for (size_t i = 0; i < elem_count; i++) {
      new_data[i] = static_cast<int32_t>(data[i]);
    }
    auto new_tensor = Ort::Value::CreateTensor<int32_t>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else if (target_type == "int64") {
    // Convert uint8 to int64
    std::vector<uint8_t> buffer(elem_count * sizeof(int64_t));
    int64_t *new_data = reinterpret_cast<int64_t *>(buffer.data());
    for (size_t i = 0; i < elem_count; i++) {
      new_data[i] = static_cast<int64_t>(data[i]);
    }
    auto new_tensor = Ort::Value::CreateTensor<int64_t>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else if (target_type == "bool") {
    // Convert uint8 to bool
    std::vector<uint8_t> buffer(elem_count * sizeof(bool));
    bool *new_data = reinterpret_cast<bool *>(buffer.data());
    for (size_t i = 0; i < elem_count; i++) {
      new_data[i] = data[i] != 0;
    }
    auto new_tensor = Ort::Value::CreateTensor<bool>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else {
    throw std::runtime_error("Unsupported type: " + target_type);
  }

  // Store the shape
  tensor_shapes_[new_tensor_id] = shape;
  tensor_types_[new_tensor_id] = target_type;

  return new_tensor_id;
}

std::string TensorManager::convertBoolTo(const std::string &tensor_id, const std::string &target_type) {
  // Get the tensor
  Ort::Value *tensor = tensors_[tensor_id].get();
  Ort::TensorTypeAndShapeInfo tensor_info = tensor->GetTensorTypeAndShapeInfo();
  size_t elem_count = tensor_info.GetElementCount();
  std::vector<int64_t> shape = tensor_info.GetShape();
  bool *data = tensor->GetTensorMutableData<bool>();

  // Create a new tensor ID
  std::string new_tensor_id = generateTensorId();

  // Convert to the target type
  if (target_type == "float32") {
    // Convert bool to float32
    std::vector<uint8_t> buffer(elem_count * sizeof(float));
    float *new_data = reinterpret_cast<float *>(buffer.data());
    for (size_t i = 0; i < elem_count; i++) {
      new_data[i] = data[i] ? 1.0f : 0.0f;
    }
    auto new_tensor = Ort::Value::CreateTensor<float>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else if (target_type == "int32") {
    // Convert bool to int32
    std::vector<uint8_t> buffer(elem_count * sizeof(int32_t));
    int32_t *new_data = reinterpret_cast<int32_t *>(buffer.data());
    for (size_t i = 0; i < elem_count; i++) {
      new_data[i] = data[i] ? 1 : 0;
    }
    auto new_tensor = Ort::Value::CreateTensor<int32_t>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else if (target_type == "int64") {
    // Convert bool to int64
    std::vector<uint8_t> buffer(elem_count * sizeof(int64_t));
    int64_t *new_data = reinterpret_cast<int64_t *>(buffer.data());
    for (size_t i = 0; i < elem_count; i++) {
      new_data[i] = data[i] ? 1 : 0;
    }
    auto new_tensor = Ort::Value::CreateTensor<int64_t>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else if (target_type == "uint8") {
    // Convert bool to uint8
    std::vector<uint8_t> buffer(elem_count * sizeof(uint8_t));
    uint8_t *new_data = buffer.data();
    for (size_t i = 0; i < elem_count; i++) {
      new_data[i] = data[i] ? 1 : 0;
    }
    auto new_tensor = Ort::Value::CreateTensor<uint8_t>(memory_info_, new_data, elem_count, shape.data(), shape.size());
    tensors_[new_tensor_id] = std::make_unique<Ort::Value>(std::move(new_tensor));
    tensor_data_buffers_[new_tensor_id] = std::move(buffer);
  } else {
    throw std::runtime_error("Unsupported type: " + target_type);
  }

  // Store the shape
  tensor_shapes_[new_tensor_id] = shape;
  tensor_types_[new_tensor_id] = target_type;

  return new_tensor_id;
}

ClonedTensor TensorManager::cloneTensor(const std::string &tensor_id) {
  std::lock_guard<std::mutex> lock(mutex_);

  return cloneTensorLocked(tensor_id);
}

ClonedTensor TensorManager::cloneTensorLocked(const std::string &tensor_id) {
  // Find the tensor
  auto tensor_it = tensors_.find(tensor_id);
  auto type_it = tensor_types_.find(tensor_id);
  auto shape_it = tensor_shapes_.find(tensor_id);

  if (tensor_it == tensors_.end() || type_it == tensor_types_.end() || shape_it == tensor_shapes_.end()) {
    throw std::runtime_error("Tensor not found: " + tensor_id);
  }

  Ort::Value *tensor_ptr = tensor_it->second.get();
  const std::string &tensor_type = type_it->second;
  const std::vector<int64_t> &shape = shape_it->second;

  // Get tensor info
  Ort::TensorTypeAndShapeInfo tensor_info = tensor_ptr->GetTensorTypeAndShapeInfo();
  size_t element_count = tensor_info.GetElementCount();

  // Create a new tensor with the same data as the original, backed by a managed buffer
  if (tensor_type == "float32") {
    float *data = tensor_ptr->GetTensorMutableData<float>();
    std::vector<uint8_t> buffer(element_count * sizeof(float));
    std::memcpy(buffer.data(), data, element_count * sizeof(float));
    float *new_data = reinterpret_cast<float *>(buffer.data());

    ClonedTensor result;
    result.value = Ort::Value::CreateTensor<float>(memory_info_, new_data, element_count, shape.data(), shape.size());
    result.buffer = std::move(buffer);
    return result;
  } else if (tensor_type == "int32") {
    int32_t *data = tensor_ptr->GetTensorMutableData<int32_t>();
    std::vector<uint8_t> buffer(element_count * sizeof(int32_t));
    std::memcpy(buffer.data(), data, element_count * sizeof(int32_t));
    int32_t *new_data = reinterpret_cast<int32_t *>(buffer.data());

    ClonedTensor result;
    result.value = Ort::Value::CreateTensor<int32_t>(memory_info_, new_data, element_count, shape.data(), shape.size());
    result.buffer = std::move(buffer);
    return result;
  } else if (tensor_type == "int64") {
    int64_t *data = tensor_ptr->GetTensorMutableData<int64_t>();
    std::vector<uint8_t> buffer(element_count * sizeof(int64_t));
    std::memcpy(buffer.data(), data, element_count * sizeof(int64_t));
    int64_t *new_data = reinterpret_cast<int64_t *>(buffer.data());

    ClonedTensor result;
    result.value = Ort::Value::CreateTensor<int64_t>(memory_info_, new_data, element_count, shape.data(), shape.size());
    result.buffer = std::move(buffer);
    return result;
  } else if (tensor_type == "uint8") {
    uint8_t *data = tensor_ptr->GetTensorMutableData<uint8_t>();
    std::vector<uint8_t> buffer(element_count * sizeof(uint8_t));
    std::memcpy(buffer.data(), data, element_count * sizeof(uint8_t));

    ClonedTensor result;
    result.value =
        Ort::Value::CreateTensor<uint8_t>(memory_info_, buffer.data(), element_count, shape.data(), shape.size());
    result.buffer = std::move(buffer);
    return result;
  } else if (tensor_type == "bool") {
    bool *data = tensor_ptr->GetTensorMutableData<bool>();
    std::vector<uint8_t> buffer(element_count * sizeof(bool));
    std::memcpy(buffer.data(), data, element_count * sizeof(bool));
    bool *new_data = reinterpret_cast<bool *>(buffer.data());

    ClonedTensor result;
    result.value = Ort::Value::CreateTensor<bool>(memory_info_, new_data, element_count, shape.data(), shape.size());
    result.buffer = std::move(buffer);
    return result;
  } else if (tensor_type == "string") {
    // Extract strings from the tensor
    std::vector<std::string> data_vec;
    data_vec.reserve(element_count);
    for (size_t i = 0; i < element_count; i++) {
      std::string s = tensor_ptr->GetStringTensorElement(i);
      data_vec.push_back(s);
    }

    // Create a C-style array of const char* for ONNX Runtime
    const char **new_tensor_data = new const char *[data_vec.size()];
    for (size_t i = 0; i < data_vec.size(); i++) {
      new_tensor_data[i] = data_vec[i].c_str();
    }
    OrtAllocator *allocator = nullptr;
    // Follow the test at:
    // https://github.com/microsoft/onnxruntime/blob/4adef01e741b2327188279dcd63bc55c5d2307e9/onnxruntime/test/shared_lib/test_inference.cc#L4278
    // create allocator with default options
    Ort::ThrowOnError(Ort::GetApi().GetAllocatorWithDefaultOptions(&allocator));
    auto new_tensor =
        Ort::Value::CreateTensor(allocator, shape.data(), shape.size(), ONNX_TENSOR_ELEMENT_DATA_TYPE_STRING);
    // Fill the tensor with string data
    Ort::ThrowOnError(Ort::GetApi().FillStringTensor(new_tensor, new_tensor_data, data_vec.size()));
    delete[] new_tensor_data;

    // String tensors use ORT's allocator, no external buffer needed
    ClonedTensor result;
    result.value = std::move(new_tensor);
    return result;
  } else {
    throw std::runtime_error("Unsupported tensor type: " + tensor_type);
  }
}
