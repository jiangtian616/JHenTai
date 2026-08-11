// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

import 'package:flutter_onnxruntime/src/flutter_onnxruntime_platform_interface.dart';
import 'package:flutter_onnxruntime/src/ort_model_metadata.dart';
import 'package:flutter_onnxruntime/src/ort_provider.dart';
import 'package:flutter_onnxruntime/src/ort_value.dart';

class OrtSession {
  final String id;
  final List<String> inputNames;
  final List<String> outputNames;

  // Private constructor
  OrtSession._({
    required this.id,
    required this.inputNames,
    required this.outputNames,
  });

  // Public factory constructor to create from map
  factory OrtSession.fromMap(Map<String, dynamic> map) {
    return OrtSession._(
      id: map['sessionId'] as String,
      inputNames: List<String>.from(map['inputNames'] ?? []),
      outputNames: List<String>.from(map['outputNames'] ?? []),
    );
  }

  /// Run inference on the session
  ///
  /// [inputs] is a map of input names to OrtValue objects
  /// [options] is an optional map of run options
  ///
  /// Returns a map of output names to OrtValue objects if successful, otherwise throws an exception
  ///
  /// Example:
  /// ```dart
  /// final inputTensor = await OrtValue.fromList(
  ///   [1.0, 2.0, 3.0, 4.0],
  ///   [2, 2]
  /// );
  /// final inputs = {
  ///   'input_name': inputTensor,
  /// };
  /// final outputs = await session.run(inputs);
  /// ```
  Future<Map<String, OrtValue>> run(
    Map<String, OrtValue> inputs, {
    OrtRunOptions? options,
  }) async {
    final result = await FlutterOnnxruntimePlatform.instance.runInference(
      id,
      inputs,
      runOptions: options?.toMap() ?? {},
    );
    final outputs = <String, OrtValue>{};
    for (final entry in result.entries) {
      final tensorMap = {
        'valueId': entry.value[0],
        'dataType': entry.value[1],
        'shape': entry.value[2],
      };
      outputs[entry.key] = OrtValue.fromMap(tensorMap);
    }
    return outputs;
  }

  Future<void> close() async {
    await FlutterOnnxruntimePlatform.instance.closeSession(id);
  }

  /// Get metadata about the model
  ///
  /// Returns information about the model such as producer name, graph name,
  /// domain, description, version, and custom metadata.
  Future<OrtModelMetadata> getMetadata() async {
    final metadataMap = await FlutterOnnxruntimePlatform.instance.getMetadata(
      id,
    );
    return OrtModelMetadata.fromMap(metadataMap);
  }

  /// Get input info about the model
  ///
  /// Returns information about the model's inputs such as name, type, and shape.
  Future<List<Map<String, dynamic>>> getInputInfo() async {
    final inputInfoMap = await FlutterOnnxruntimePlatform.instance.getInputInfo(
      id,
    );
    return inputInfoMap.map((info) => Map<String, dynamic>.from(info)).toList();
  }

  /// Get output info about the model
  ///
  /// Returns information about the model's outputs such as name, type, and shape.
  Future<List<Map<String, dynamic>>> getOutputInfo() async {
    final outputInfoMap = await FlutterOnnxruntimePlatform.instance
        .getOutputInfo(id);
    return outputInfoMap
        .map((info) => Map<String, dynamic>.from(info))
        .toList();
  }
}

class OrtSessionOptions {
  // Sets the number of threads used to parallelize the execution within nodes
  final int? intraOpNumThreads;
  // Sets the number of threads used to parallelize the execution of the graph (across nodes)
  final int? interOpNumThreads;
  // set a list of providers, if one provider is not available, ORT will fallback to the next provider in the list
  // for example: [OrtProvider.CUDA, OrtProvider.CPU]
  final List<OrtProvider>? providers;
  // arena allocator for memory management, default is true
  final bool? useArena;
  // set the device id for the session, default is 0
  final int? deviceId;
  // Provider-specific options keyed by provider enum name.
  final Map<String, Map<String, String>>? providerOptions;
  // ONNX Runtime session config entries forwarded to native code.
  final Map<String, String>? sessionConfigEntries;
  // CoreML options exposed explicitly because they are safety-critical.
  final String? mlComputeUnits;
  final bool? requireStaticShapes;
  // Dart-side guards forwarded for native diagnostics/future hard guards.
  final List<int>? inputShape;
  final int? memoryBudgetBytes;

  OrtSessionOptions({
    this.intraOpNumThreads,
    this.interOpNumThreads,
    this.providers,
    this.useArena,
    this.deviceId,
    this.providerOptions,
    this.sessionConfigEntries,
    this.mlComputeUnits,
    this.requireStaticShapes,
    this.inputShape,
    this.memoryBudgetBytes,
  });

  Map<String, dynamic> toMap() {
    return {
      if (intraOpNumThreads != null) 'intraOpNumThreads': intraOpNumThreads,
      if (interOpNumThreads != null) 'interOpNumThreads': interOpNumThreads,
      if (providers != null && providers!.isNotEmpty)
        'providers': providers!.map((p) => p.name).toList(),
      if (useArena != null) 'useArena': useArena,
      if (deviceId != null) 'deviceId': deviceId,
      if (providerOptions != null) 'providerOptions': providerOptions,
      if (sessionConfigEntries != null)
        'sessionConfigEntries': sessionConfigEntries,
      if (mlComputeUnits != null) 'mlComputeUnits': mlComputeUnits,
      if (requireStaticShapes != null)
        'requireStaticShapes': requireStaticShapes,
      if (inputShape != null) 'inputShape': inputShape,
      if (memoryBudgetBytes != null) 'memoryBudgetBytes': memoryBudgetBytes,
    };
  }
}

class OrtRunOptions {
  // 0 = Verbose
  // 1 = Info
  // 2 = Warning
  // 3 = Error
  // 4 = Fatal
  final int? logSeverityLevel;
  // the higher the number, the more verbose the logging is
  final int? logVerbosityLevel;
  // terminate all incomplete inference using this instance as soon as possible
  final bool? terminate;

  OrtRunOptions({
    this.logSeverityLevel,
    this.logVerbosityLevel,
    this.terminate,
  });

  Map<String, dynamic> toMap() {
    return {
      if (logSeverityLevel != null) 'logSeverityLevel': logSeverityLevel,
      if (logVerbosityLevel != null) 'logVerbosityLevel': logVerbosityLevel,
      if (terminate != null) 'terminate': terminate,
    };
  }
}
