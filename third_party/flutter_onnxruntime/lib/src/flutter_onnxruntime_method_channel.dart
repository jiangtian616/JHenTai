// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import 'flutter_onnxruntime_platform_interface.dart';

/// An implementation of [FlutterOnnxruntimePlatform] that uses method channels.
class MethodChannelFlutterOnnxruntime extends FlutterOnnxruntimePlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_onnxruntime');

  @override
  Future<String?> getPlatformVersion() async {
    return await methodChannel.invokeMethod<String>('getPlatformVersion');
  }

  /// Creates a new session for the given model path.
  ///
  /// [modelPath] is the path to the ONNX model file.
  /// [sessionOptions] is an optional map of session options.
  ///
  /// Returns a map of the session options.
  ///
  /// Using model path allows the native code to load the model directly,
  /// which is more memory efficient as it avoids copying the entire model
  /// through the method channel.
  @override
  Future<Map<String, dynamic>> createSession(
    String modelPath, {
    Map<String, dynamic>? sessionOptions,
  }) async {
    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'createSession',
      {'modelPath': modelPath, 'sessionOptions': sessionOptions ?? {}},
    );
    return _convertMapToStringDynamic(result ?? {});
  }

  /// Get the available providers
  @override
  Future<List<String>> getAvailableProviders() async {
    final result = await methodChannel.invokeMethod<List<Object?>>(
      'getAvailableProviders',
    );
    return result?.map((item) => item.toString()).toList() ?? [];
  }

  @override
  Future<Map<String, dynamic>> getRuntimeInfo() async {
    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'getRuntimeInfo',
    );
    return _convertMapToStringDynamic(result ?? {});
  }

  /// Run inference on a session
  ///
  /// [sessionId] is the ID of the session to run inference on
  /// [inputs] is a map of input names to OrtValue objects
  /// [runOptions] is an optional map of run options
  @override
  Future<Map<String, dynamic>> runInference(
    String sessionId,
    Map<String, OrtValue> inputs, {
    Map<String, dynamic>? runOptions,
  }) async {
    // Convert OrtValue objects to valueId maps for platform channel
    final processedInputs = <String, dynamic>{};

    for (final entry in inputs.entries) {
      // Convert each OrtValue to its valueId for the platform channel
      processedInputs[entry.key] = {'valueId': entry.value.id};
    }

    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'runInference',
      {
        'sessionId': sessionId,
        'inputs': processedInputs,
        'runOptions': runOptions ?? {},
      },
    );
    return _convertMapToStringDynamic(result ?? {});
  }

  @override
  Future<void> closeSession(String sessionId) async {
    await methodChannel.invokeMethod<void>('closeSession', {
      'sessionId': sessionId,
    });
  }

  @override
  Future<Map<String, dynamic>> getMetadata(String sessionId) async {
    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'getMetadata',
      {'sessionId': sessionId},
    );
    return _convertMapToStringDynamic(result ?? {});
  }

  @override
  Future<List<Map<String, dynamic>>> getInputInfo(String sessionId) async {
    final result = await methodChannel.invokeMethod<List<Object?>>(
      'getInputInfo',
      {'sessionId': sessionId},
    );
    return result
            ?.map(
              (item) =>
                  _convertMapToStringDynamic(item as Map<Object?, Object?>),
            )
            .toList() ??
        [];
  }

  @override
  Future<List<Map<String, dynamic>>> getOutputInfo(String sessionId) async {
    final result = await methodChannel.invokeMethod<List<Object?>>(
      'getOutputInfo',
      {'sessionId': sessionId},
    );
    return result
            ?.map(
              (item) =>
                  _convertMapToStringDynamic(item as Map<Object?, Object?>),
            )
            .toList() ??
        [];
  }

  // OrtValue operations

  @override
  Future<Map<String, dynamic>> createOrtValue(
    String sourceType,
    dynamic data,
    List<int> shape,
  ) async {
    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'createOrtValue',
      {'sourceType': sourceType, 'data': data, 'shape': shape},
    );
    return _convertMapToStringDynamic(result ?? {});
  }

  @override
  Future<Map<String, dynamic>> convertOrtValue(
    String valueId,
    String targetType,
  ) async {
    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'convertOrtValue',
      {'valueId': valueId, 'targetType': targetType},
    );
    return _convertMapToStringDynamic(result ?? {});
  }

  @override
  Future<Map<String, dynamic>> getOrtValueData(String valueId) async {
    final result = await methodChannel.invokeMethod<Map<Object?, Object?>>(
      'getOrtValueData',
      {'valueId': valueId},
    );
    return _convertMapToStringDynamic(result ?? {});
  }

  @override
  Future<void> releaseOrtValue(String valueId) async {
    await methodChannel.invokeMethod<void>('releaseOrtValue', {
      'valueId': valueId,
    });
  }

  Map<String, dynamic> _convertMapToStringDynamic(Map<Object?, Object?> map) {
    return map.map((key, value) => MapEntry(key.toString(), value));
  }
}
