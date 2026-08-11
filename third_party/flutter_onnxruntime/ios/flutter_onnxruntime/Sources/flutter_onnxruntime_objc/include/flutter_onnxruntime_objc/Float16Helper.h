// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#import <Foundation/Foundation.h>
#if __has_include(<onnxruntime_objc/ort_value.h>)
#import <onnxruntime_objc/ort_value.h>  // CocoaPods
#else
#import "ort_value.h"  // SPM (OnnxRuntimeBindings public include dir on search path)
#endif

NS_ASSUME_NONNULL_BEGIN

/// Helper class for float16 tensor operations using the ONNX Runtime C++ API.
/// This bypasses the ObjC wrapper's lack of float16 enum support by directly
/// using the underlying C++ API (ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16).
@interface Float16Helper : NSObject

/// Creates a float16 ORTValue from float32 input values.
/// Converts each float32 value to IEEE 754 half-precision (UInt16),
/// then creates a C++ Ort::Value and wraps it into an ORTValue.
+ (nullable ORTValue *)createFloat16TensorFromFloat32:(NSArray<NSNumber *> *)float32Values
                                                shape:(NSArray<NSNumber *> *)shape
                                                error:(NSError **)error;

/// Creates a float16 ORTValue from raw UInt16 data (already in float16 format).
+ (nullable ORTValue *)createFloat16TensorFromRawData:(NSData *)rawData
                                                shape:(NSArray<NSNumber *> *)shape
                                                error:(NSError **)error;

/// Extracts float16 tensor data and converts it back to float32.
/// Returns an array of NSNumber (float) values.
+ (nullable NSArray<NSNumber *> *)extractFloat16AsFloat32:(ORTValue *)value
                                                    error:(NSError **)error;

/// Checks if the given ORTValue is a float16 tensor using the C++ API.
+ (BOOL)isFloat16Tensor:(ORTValue *)value;

/// Gets the shape of a tensor using the C++ API. Works for any element type including float16.
+ (nullable NSArray<NSNumber *> *)getTensorShape:(ORTValue *)value
                                           error:(NSError **)error;

/// Returns the element type name string using the C++ API.
+ (NSString *)getElementTypeName:(ORTValue *)value;

@end

NS_ASSUME_NONNULL_END
