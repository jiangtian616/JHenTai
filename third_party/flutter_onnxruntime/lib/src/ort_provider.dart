// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

// ignore_for_file: constant_identifier_names

/// The execution provider to use for the ONNX Runtime session
///
/// Following the name of the execution provider in the ONNX Runtime Java API at:
/// https://onnxruntime.ai/docs/api/java/ai/onnxruntime/OrtProvider.html
enum OrtProvider {
  ACL,
  ARM_NN,
  AZURE,
  CORE_ML,
  CPU,
  CUDA,
  DIRECT_ML,
  DNNL,
  NNAPI,
  OPEN_VINO,
  QNN,
  ROCM,
  TENSOR_RT,
  XNNPACK,
  WEB_ASSEMBLY,
  WEB_GL,
  WEB_GPU,
  WEB_NN,
}
