// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:flutter_onnxruntime/src/flutter_onnxruntime_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

abstract class FlutterOnnxruntimePlatform extends PlatformInterface {
  /// Constructs a FlutterOnnxruntimePlatform.
  FlutterOnnxruntimePlatform() : super(token: _token);

  static final Object _token = Object();

  static FlutterOnnxruntimePlatform _instance =
      MethodChannelFlutterOnnxruntime();

  /// The default instance of [FlutterOnnxruntimePlatform] to use.
  ///
  /// Defaults to [MethodChannelFlutterOnnxruntime].
  static FlutterOnnxruntimePlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [FlutterOnnxruntimePlatform] when
  /// they register themselves.
  static set instance(FlutterOnnxruntimePlatform instance) {
    PlatformInterface.verify(instance, _token);
    _instance = instance;
  }

  /// Get the platform version
  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  // Core ONNX Runtime operations
  Future<Map<String, dynamic>> createSession(
    String modelPath, {
    Map<String, dynamic>? sessionOptions,
  }) {
    throw UnimplementedError('createSession() has not been implemented.');
  }

  /// Get the available providers
  Future<List<String>> getAvailableProviders() {
    throw UnimplementedError(
      'getAvailableProviders() has not been implemented.',
    );
  }

  /// Returns the actual native ORT version and native provider list.
  Future<Map<String, dynamic>> getRuntimeInfo() {
    throw UnimplementedError('getRuntimeInfo() has not been implemented.');
  }

  /// Run inference on a session
  ///
  /// [sessionId] is the ID of the session to run inference on
  /// [inputs] is a map of input names to OrtValue objects
  /// [runOptions] is an optional map of run options
  Future<Map<String, dynamic>> runInference(
    String sessionId,
    Map<String, OrtValue> inputs, {
    Map<String, dynamic>? runOptions,
  }) {
    throw UnimplementedError('runInference() has not been implemented.');
  }

  /// Close a session
  ///
  /// [sessionId] is the ID of the session to close
  Future<void> closeSession(String sessionId) {
    throw UnimplementedError('closeSession() has not been implemented.');
  }

  /// Get metadata about the model
  ///
  /// [sessionId] is the ID of the session to get metadata from
  ///
  /// Returns information about the model such as producer name, graph name,
  /// domain, description, version, and custom metadata.
  Future<Map<String, dynamic>> getMetadata(String sessionId) {
    throw UnimplementedError('getMetadata() has not been implemented.');
  }

  /// Get input info about the model
  ///
  /// [sessionId] is the ID of the session to get input info from
  ///
  /// Returns information about the model's inputs such as name, type, and shape.
  Future<List<Map<String, dynamic>>> getInputInfo(String sessionId) {
    throw UnimplementedError('getInputInfo() has not been implemented.');
  }

  /// Get output info about the model
  ///
  /// [sessionId] is the ID of the session to get output info from
  ///
  /// Returns information about the model's outputs such as name, type, and shape.
  Future<List<Map<String, dynamic>>> getOutputInfo(String sessionId) {
    throw UnimplementedError('getOutputInfo() has not been implemented.');
  }

  // OrtValue operations

  /// Creates an OrtValue from data
  ///
  /// [sourceType] is the source data type (e.g., 'float32', 'int32')
  /// [data] is the data to create the tensor from
  /// [shape] is the shape of the tensor
  Future<Map<String, dynamic>> createOrtValue(
    String sourceType,
    dynamic data,
    List<int> shape,
  ) {
    throw UnimplementedError('createOrtValue() has not been implemented.');
  }

  /// Converts an OrtValue to a different data type
  ///
  /// [valueId] is the ID of the OrtValue to convert
  /// [targetType] is the target data type (e.g., 'float32', 'float16')
  Future<Map<String, dynamic>> convertOrtValue(
    String valueId,
    String targetType,
  ) {
    throw UnimplementedError('convertOrtValue() has not been implemented.');
  }

  /// Gets the data from an OrtValue
  ///
  /// [valueId] is the ID of the OrtValue to get data from
  Future<Map<String, dynamic>> getOrtValueData(String valueId) {
    throw UnimplementedError('getOrtValueData() has not been implemented.');
  }

  /// Releases native resources associated with an OrtValue
  ///
  /// [valueId] is the ID of the OrtValue to release
  Future<void> releaseOrtValue(String valueId) {
    throw UnimplementedError('releaseOrtValue() has not been implemented.');
  }
}
