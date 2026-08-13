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

/// Helper class for bool tensor operations using the ONNX Runtime C++ API.
/// This bypasses the ObjC wrapper's lack of bool enum support by directly
/// using the underlying C++ API (ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL).
@interface BoolHelper : NSObject

/// Creates a bool ORTValue from one byte per element.
/// Non-zero bytes are normalized to 1 (ORT bool tensors expect 0 or 1),
/// then a C++ Ort::Value is created and wrapped into an ORTValue.
+ (nullable ORTValue *)createBoolTensorFromBytes:(NSData *)bytes
                                           shape:(NSArray<NSNumber *> *)shape
                                           error:(NSError **)error;

/// Extracts bool tensor data as one 0/1 byte per element.
+ (nullable NSData *)extractBoolData:(ORTValue *)value
                               error:(NSError **)error;

/// Checks if the given ORTValue is a bool tensor using the C++ API.
+ (BOOL)isBoolTensor:(ORTValue *)value;

@end

NS_ASSUME_NONNULL_END
