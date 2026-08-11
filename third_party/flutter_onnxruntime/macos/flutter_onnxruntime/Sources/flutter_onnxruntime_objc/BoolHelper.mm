// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#if __has_include("flutter_onnxruntime_objc/BoolHelper.h")
#import "flutter_onnxruntime_objc/BoolHelper.h"  // SPM (public headers under include/flutter_onnxruntime_objc/)
#else
#import "BoolHelper.h"  // CocoaPods
#endif
#import "ort_value_internal.h"
#import "cxx_api.h"

#include <vector>

// Ort::Exception derives from std::exception, so one catch covers both
static NSError *errorFromException(const std::exception &e) {
    return [NSError errorWithDomain:@"com.masicai.flutter_onnxruntime"
                               code:-1
                           userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}];
}

@implementation BoolHelper

+ (nullable ORTValue *)createBoolTensorFromBytes:(NSData *)bytes
                                           shape:(NSArray<NSNumber *> *)shape
                                           error:(NSError **)error {
    try {
        // Build shape vector
        std::vector<int64_t> shapeVec;
        shapeVec.reserve(shape.count);
        for (NSNumber *dim in shape) {
            shapeVec.push_back(dim.longLongValue);
        }

        // Copy into a mutable buffer that will be kept alive by externalTensorData,
        // normalizing non-zero bytes to 1 (ORT bool tensors expect 0 or 1)
        NSMutableData *mutableData = [NSMutableData dataWithData:bytes];
        uint8_t *bytePtr = (uint8_t *)mutableData.mutableBytes;
        for (NSUInteger i = 0; i < mutableData.length; i++) {
            bytePtr[i] = bytePtr[i] ? 1 : 0;
        }

        // Create C++ Ort::Value with bool element type
        auto memoryInfo = Ort::MemoryInfo::CreateCpu(OrtDeviceAllocator, OrtMemTypeCPU);
        Ort::Value ortValue = Ort::Value::CreateTensor(
            memoryInfo,
            mutableData.mutableBytes,
            mutableData.length,
            shapeVec.data(),
            shapeVec.size(),
            ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL);

        // Wrap into ORTValue using the internal constructor
        // Pass mutableData as externalTensorData to keep the buffer alive
        ORTValue *result = [[ORTValue alloc] initWithCXXAPIOrtValue:std::move(ortValue)
                                                 externalTensorData:mutableData
                                                              error:error];
        return result;
    } catch (const std::exception& e) {
        if (error) {
            *error = errorFromException(e);
        }
        return nil;
    }
}

+ (nullable NSData *)extractBoolData:(ORTValue *)value
                               error:(NSError **)error {
    try {
        Ort::Value& ortValue = [value CXXAPIOrtValue];

        // Get shape info to determine element count
        auto typeInfo = ortValue.GetTensorTypeAndShapeInfo();
        size_t elementCount = typeInfo.GetElementCount();

        // Bool tensors store one byte per element (0 or 1)
        const uint8_t *boolPtr = reinterpret_cast<const uint8_t *>(ortValue.GetTensorData<bool>());
        return [NSData dataWithBytes:boolPtr length:elementCount];
    } catch (const std::exception& e) {
        if (error) {
            *error = errorFromException(e);
        }
        return nil;
    }
}

+ (BOOL)isBoolTensor:(ORTValue *)value {
    try {
        Ort::Value& ortValue = [value CXXAPIOrtValue];
        auto typeInfo = ortValue.GetTensorTypeAndShapeInfo();
        return typeInfo.GetElementType() == ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL;
    } catch (...) {
        return NO;
    }
}

@end
