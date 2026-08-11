// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

import 'dart:typed_data';

import 'package:flutter_onnxruntime/src/flutter_onnxruntime_platform_interface.dart';

/// Represents a data type in ONNX Runtime
enum OrtDataType {
  // Numeric types
  float32,
  float16,
  int32,
  int64,
  int16,
  int8,
  uint8,
  uint16,
  uint32,
  uint64,
  bool,

  // String type
  string,

  // Complex types
  complex64,
  complex128,

  // Other numeric types
  bfloat16,
}

/// OrtValue represents a tensor or other data structure used for input/output in ONNX Runtime.
///
/// This class manages memory for tensor data and provides methods for data type conversion.
/// It wraps the native OrtValue (C/C++) or OnnxTensor (Java) types from
/// the ONNX Runtime API.
class OrtValue {
  /// Unique identifier for this tensor in the native code
  final String id;

  /// Data type of this tensor
  final OrtDataType dataType;

  /// Shape of the tensor as a list of dimensions
  final List<int> shape;

  /// Private constructor
  OrtValue._({required this.id, required this.dataType, required this.shape});

  /// Creates an OrtValue from a map returned by the platform interface
  factory OrtValue.fromMap(Map<String, dynamic> map) {
    return OrtValue._(
      id: map['valueId'] as String,
      dataType: OrtDataType.values.firstWhere(
        (dt) => dt.toString() == 'OrtDataType.${map['dataType']}',
        // throw an exception if the data type is not found
        orElse: () => throw ArgumentError('Invalid data type: ${map['dataType']}'),
      ),
      shape: List<int>.from(map['shape'] ?? []),
    );
  }

  /// Creates an OrtValue from any supported list type
  ///
  /// This method detects the list type and converts it to the appropriate format.
  /// Supported types include Float32List, Int32List, Int64List, Uint8List, List\<bool>,
  /// List\<String>, and their corresponding Dart List\<num> types.
  ///
  /// Note:
  /// - The shape of the list is not necessary to be in the correct shapes as they will be flattened in
  ///   the preprocess. However, the order of the elements and the total number of elements must match exactly
  ///   with the target shape
  /// - A List\<int> will be detected and assigned to int32 type in all platforms except Web. The Web
  ///   platform only recognize the float format or you have to typed list such as Int32List, Int64List, etc.
  /// - Int64List is not supported in the web platform.
  ///
  /// [data] is the data to create the tensor from (any supported list type)
  /// [shape] is the shape of the tensor
  static Future<OrtValue> fromList(dynamic data, List<int> shape) async {
    // If data is a regular List, convert it to the appropriate TypedData
    if (data is List &&
        !(data is Float32List || data is Int32List || data is Int64List || data is Uint8List || data is List<String>)) {
      data = _convertListToTypedData(data);
    }

    // Validate data length against shape
    int expectedElements = _calculateExpectedElements(shape);
    int actualElements = _getElementCount(data);

    if (expectedElements != -1 && actualElements != expectedElements) {
      throw ArgumentError(
        'Shape/data size mismatch: data has $actualElements elements, '
        'but shape $shape requires $expectedElements elements',
      );
    }

    String sourceType;

    if (data is Float32List) {
      sourceType = 'float32';
    } else if (data is Int32List) {
      sourceType = 'int32';
    } else if (data is Int64List) {
      sourceType = 'int64';
    } else if (data is Uint8List) {
      sourceType = 'uint8';
    } else if (data is List<bool>) {
      sourceType = 'bool';
    } else if (data is List<String>) {
      sourceType = 'string';
    } else {
      throw ArgumentError('Unsupported data type: ${data.runtimeType}');
    }

    final result = await FlutterOnnxruntimePlatform.instance.createOrtValue(sourceType, data, shape);
    return OrtValue.fromMap(result);
  }

  /// Convert this tensor to a different data type
  ///
  /// [targetType] is the target data type to convert to
  Future<OrtValue> to(OrtDataType targetType) async {
    final result = await FlutterOnnxruntimePlatform.instance.convertOrtValue(id, targetType.toString().split('.').last);
    return OrtValue.fromMap(result);
  }

  /// Get the data from this tensor as a list
  ///
  /// Return a nested list following the shape if the tensor is multi-dimensional
  ///
  /// Returns the data in its original type:
  /// - Float values for float32 and float16 tensors
  /// - Int values for int32, int64, int16, int8, uint8, uint16, uint32, uint64 tensors
  /// - Boolean values for bool tensors
  /// - String values for string tensors
  ///
  Future<List<dynamic>> asList() async {
    final data = await FlutterOnnxruntimePlatform.instance.getOrtValueData(id);
    final rawData = data['data'];
    var dataList1d = (rawData is List) ? rawData : List<dynamic>.from(rawData);
    // On iOS/macOS, bool tensors are stored as uint8 internally,
    // so convert 0/1 integers back to false/true
    if (dataType == OrtDataType.bool && dataList1d.isNotEmpty && dataList1d.first is! bool) {
      dataList1d = dataList1d.map((e) => e != 0).toList();
    }
    return _reshapeList(dataList1d, shape);
  }

  /// Get the data from this tensor as a flattened list (1D list)
  ///
  /// Returns the data in its original type:
  /// - Float values for float32 and float16 tensors
  /// - Int values for int32, int64, int16, int8, uint8, uint16, uint32, uint64 tensors
  /// - Boolean values for bool tensors
  /// - String values for string tensors
  ///
  Future<List<dynamic>> asFlattenedList() async {
    final data = await FlutterOnnxruntimePlatform.instance.getOrtValueData(id);
    final rawData = data['data'];
    final list = (rawData is List) ? rawData : List<dynamic>.from(rawData);
    // On iOS/macOS, bool tensors are stored as uint8 internally,
    // so convert 0/1 integers back to false/true
    if (dataType == OrtDataType.bool && list.isNotEmpty && list.first is! bool) {
      return list.map((e) => e != 0).toList();
    }
    return list;
  }

  /// Release native resources associated with this tensor
  Future<void> dispose() async {
    await FlutterOnnxruntimePlatform.instance.releaseOrtValue(id);
  }

  /// Converts a regular List to appropriate TypedData based on content
  static dynamic _convertListToTypedData(List data) {
    if (data.isEmpty) {
      throw ArgumentError('Cannot create OrtValue from empty list');
    }

    // Detect and flatten nested lists
    if (data.first is List) {
      data = _flattenNestedList(data);
      if (data.isEmpty) {
        throw ArgumentError('Cannot create OrtValue from empty nested list');
      }
    }

    final firstElement = data.first;

    // Handle boolean lists
    if (firstElement is bool) {
      return data.cast<bool>();
    }

    // Handle string lists
    if (firstElement is String) {
      return data.cast<String>();
    }

    // Handle numeric lists
    if (firstElement is num) {
      // Check if it should be Float32List (contains any doubles or decimal values)
      if (firstElement is double || data.any((e) => e is double || (e is num && e % 1 != 0))) {
        return Float32List.fromList(data.map((e) => (e as num).toDouble()).toList());
      }

      // Check if Int64List is needed (any value outside Int32 range)
      bool needsInt64 = data.any((e) => (e as num).toInt() > 2147483647 || (e).toInt() < -2147483648);

      return needsInt64
          ? Int64List.fromList(data.map((e) => (e as num).toInt()).toList())
          : Int32List.fromList(data.map((e) => (e as num).toInt()).toList());
    }

    throw ArgumentError('Unsupported element type: ${firstElement.runtimeType} in list');
  }

  // Helper method to recursively flatten nested lists
  static List _flattenNestedList(List nestedList) {
    List result = [];

    for (var item in nestedList) {
      if (item is List) {
        result.addAll(_flattenNestedList(item));
      } else {
        result.add(item);
      }
    }

    return result;
  }

  /// Calculates the expected number of elements based on the shape
  ///
  /// Returns -1 if the shape contains dynamic dimensions (negative values)
  /// which indicates that validation should be skipped for that dimension
  static int _calculateExpectedElements(List<int> shape) {
    // If shape has a negative dimension (dynamic size),
    // we can't validate the exact element count
    if (shape.any((dim) => dim < 0)) {
      throw ArgumentError('Shape contains negative dimension: $shape');
    }
    // Calculate product of all dimensions
    return shape.fold(1, (product, dim) => product * dim);
  }

  /// Get the number of elements in the data
  static int _getElementCount(dynamic data) {
    if (data is Float32List || data is Int32List || data is Int64List || data is Uint8List || data is List) {
      return data.length;
    }
    throw ArgumentError('Cannot determine element count for type: ${data.runtimeType}');
  }

  /// Reshapes a flattened list of data according to the provided shape.
  ///
  /// This function takes a flat list and reconstructs it into a nested structure
  /// based on the specified shape dimensions.
  static List _reshapeList(List<dynamic> data, List<int> shape) {
    // Validate shape and data consistency
    if (shape.isEmpty) {
      return data; // No reshaping needed
    }

    // For single dimension, just return the flat list
    if (shape.length == 1) {
      return data;
    }

    // Validate data length against shape
    int expectedElements = _calculateExpectedElements(shape);
    if (data.length != expectedElements) {
      throw ArgumentError(
        'Shape/data size mismatch: data has ${data.length} elements, '
        'but shape $shape requires $expectedElements elements',
      );
    }

    // Start the recursive reshaping
    return _buildNestedList(data, shape, 0);
  }

  // Recursive function to build nested structure
  static List _buildNestedList(List<dynamic> flatData, List<int> dimensions, int offset) {
    // Base case: if we're at the innermost dimension
    if (dimensions.length == 1) {
      return flatData.sublist(offset, offset + dimensions[0]);
    }

    int dimSize = dimensions[0];
    List<int> remainingDims = dimensions.sublist(1);
    int subArraySize = remainingDims.fold(1, (product, dim) => product * dim);

    // Build the list for the current dimension
    List result = [];
    for (int i = 0; i < dimSize; i++) {
      int newOffset = offset + (i * subArraySize);
      result.add(_buildNestedList(flatData, remainingDims, newOffset));
    }

    return result;
  }
}
