// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#if __has_include("flutter_onnxruntime_objc/Float16Helper.h")
#import "flutter_onnxruntime_objc/Float16Helper.h"  // SPM (public headers under include/flutter_onnxruntime_objc/)
#else
#import "Float16Helper.h"  // CocoaPods
#endif
#import "ort_value_internal.h"
#import "cxx_api.h"

#include <vector>

// Float16 conversion constants (IEEE 754 half-precision)
static const int FLOAT16_EXPONENT_BIAS = 15;
static const int FLOAT32_EXPONENT_BIAS = 127;
static const int FLOAT16_EXPONENT_MASK = 0x7C00;
static const int FLOAT16_MANTISSA_MASK = 0x03FF;

/// Convert a float32 value to float16 (stored as UInt16).
/// Ported from Float16Utils in FlutterOnnxruntimePlugin.kt.
static uint16_t floatToFloat16(float value) {
    uint32_t floatBits;
    memcpy(&floatBits, &value, sizeof(float));

    uint32_t sign = (floatBits >> 31) & 0x1;
    int exponent = (int)((floatBits >> 23) & 0xFF) - FLOAT32_EXPONENT_BIAS + FLOAT16_EXPONENT_BIAS;
    uint32_t mantissa = floatBits & 0x7FFFFF;

    if (exponent <= 0) {
        // Zero or denormal
        return (uint16_t)(sign << 15);
    } else if (exponent >= 31) {
        // Infinity or NaN
        if (mantissa == 0) {
            return (uint16_t)((sign << 15) | FLOAT16_EXPONENT_MASK);
        } else {
            return (uint16_t)((sign << 15) | FLOAT16_EXPONENT_MASK | 0x200);
        }
    }

    // Regular numbers
    uint32_t float16Bits = (sign << 15) | ((uint32_t)exponent << 10) | (mantissa >> 13);
    return (uint16_t)float16Bits;
}

/// Convert a float16 value (stored as UInt16) back to float32.
/// Ported from Float16Utils in FlutterOnnxruntimePlugin.kt.
static float float16ToFloat(uint16_t float16Bits) {
    uint32_t sign = ((uint32_t)(float16Bits & 0x8000)) << 16;
    uint32_t exponent = (float16Bits & FLOAT16_EXPONENT_MASK) >> 10;
    uint32_t mantissa = float16Bits & FLOAT16_MANTISSA_MASK;

    if (exponent == 0) {
        if (mantissa == 0) {
            // Zero
            float result;
            memcpy(&result, &sign, sizeof(float));
            return result;
        }
        // Denormal - convert to normal
        int e = 1;
        uint32_t m = mantissa;
        while ((m & 0x400) == 0) {
            m = m << 1;
            e++;
        }
        int normalizedExponent = (int)exponent - e + 1;
        uint32_t float32Bits = sign |
            (uint32_t)((normalizedExponent + FLOAT32_EXPONENT_BIAS - FLOAT16_EXPONENT_BIAS) << 23) |
            ((m & 0x3FF) << 13);
        float result;
        memcpy(&result, &float32Bits, sizeof(float));
        return result;
    } else if (exponent == 31) {
        // Infinity or NaN
        uint32_t float32Bits;
        if (mantissa == 0) {
            float32Bits = sign | 0x7F800000;
        } else {
            float32Bits = sign | 0x7FC00000;
        }
        float result;
        memcpy(&result, &float32Bits, sizeof(float));
        return result;
    }

    // Regular numbers
    uint32_t float32Bits = sign |
        (uint32_t)((exponent + FLOAT32_EXPONENT_BIAS - FLOAT16_EXPONENT_BIAS) << 23) |
        (mantissa << 13);
    float result;
    memcpy(&result, &float32Bits, sizeof(float));
    return result;
}

@implementation Float16Helper

+ (nullable ORTValue *)createFloat16TensorFromFloat32:(NSArray<NSNumber *> *)float32Values
                                                shape:(NSArray<NSNumber *> *)shape
                                                error:(NSError **)error {
    @try {
        NSUInteger count = float32Values.count;

        // Convert float32 values to float16 (UInt16)
        NSMutableData *float16Data = [NSMutableData dataWithLength:count * sizeof(uint16_t)];
        uint16_t *float16Ptr = (uint16_t *)float16Data.mutableBytes;
        for (NSUInteger i = 0; i < count; i++) {
            float16Ptr[i] = floatToFloat16(float32Values[i].floatValue);
        }

        return [self createFloat16TensorFromRawData:float16Data shape:shape error:error];
    } @catch (NSException *exception) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.masicai.flutter_onnxruntime"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: exception.reason ?: @"Unknown error creating float16 tensor"}];
        }
        return nil;
    }
}

+ (nullable ORTValue *)createFloat16TensorFromRawData:(NSData *)rawData
                                                shape:(NSArray<NSNumber *> *)shape
                                                error:(NSError **)error {
    try {
        // Build shape vector
        std::vector<int64_t> shapeVec;
        shapeVec.reserve(shape.count);
        for (NSNumber *dim in shape) {
            shapeVec.push_back(dim.longLongValue);
        }

        // Copy raw data into a mutable buffer that will be kept alive by externalTensorData
        NSMutableData *mutableData = [NSMutableData dataWithData:rawData];

        // Create C++ Ort::Value with float16 element type
        auto memoryInfo = Ort::MemoryInfo::CreateCpu(OrtDeviceAllocator, OrtMemTypeCPU);
        Ort::Value ortValue = Ort::Value::CreateTensor(
            memoryInfo,
            mutableData.mutableBytes,
            mutableData.length,
            shapeVec.data(),
            shapeVec.size(),
            ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16);

        // Wrap into ORTValue using the internal constructor
        // Pass mutableData as externalTensorData to keep the buffer alive
        ORTValue *result = [[ORTValue alloc] initWithCXXAPIOrtValue:std::move(ortValue)
                                                 externalTensorData:mutableData
                                                              error:error];
        return result;
    } catch (const Ort::Exception& e) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.masicai.flutter_onnxruntime"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}];
        }
        return nil;
    } catch (const std::exception& e) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.masicai.flutter_onnxruntime"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}];
        }
        return nil;
    }
}

+ (nullable NSArray<NSNumber *> *)extractFloat16AsFloat32:(ORTValue *)value
                                                    error:(NSError **)error {
    try {
        Ort::Value& ortValue = [value CXXAPIOrtValue];

        // Get shape info to determine element count
        auto typeInfo = ortValue.GetTensorTypeAndShapeInfo();
        size_t elementCount = typeInfo.GetElementCount();

        // Read raw float16 data (UInt16 values)
        const uint16_t *float16Ptr = ortValue.GetTensorData<uint16_t>();

        // Convert to float32
        NSMutableArray<NSNumber *> *float32Values = [NSMutableArray arrayWithCapacity:elementCount];
        for (size_t i = 0; i < elementCount; i++) {
            float val = float16ToFloat(float16Ptr[i]);
            [float32Values addObject:@(val)];
        }

        return float32Values;
    } catch (const Ort::Exception& e) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.masicai.flutter_onnxruntime"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}];
        }
        return nil;
    } catch (const std::exception& e) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.masicai.flutter_onnxruntime"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}];
        }
        return nil;
    }
}

+ (BOOL)isFloat16Tensor:(ORTValue *)value {
    try {
        Ort::Value& ortValue = [value CXXAPIOrtValue];
        auto typeInfo = ortValue.GetTensorTypeAndShapeInfo();
        return typeInfo.GetElementType() == ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16;
    } catch (...) {
        return NO;
    }
}

+ (nullable NSArray<NSNumber *> *)getTensorShape:(ORTValue *)value
                                           error:(NSError **)error {
    try {
        Ort::Value& ortValue = [value CXXAPIOrtValue];
        auto typeInfo = ortValue.GetTensorTypeAndShapeInfo();
        std::vector<int64_t> shape = typeInfo.GetShape();

        NSMutableArray<NSNumber *> *shapeArray = [NSMutableArray arrayWithCapacity:shape.size()];
        for (size_t i = 0; i < shape.size(); i++) {
            [shapeArray addObject:@(shape[i])];
        }
        return shapeArray;
    } catch (const Ort::Exception& e) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.masicai.flutter_onnxruntime"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}];
        }
        return nil;
    } catch (const std::exception& e) {
        if (error) {
            *error = [NSError errorWithDomain:@"com.masicai.flutter_onnxruntime"
                                         code:-1
                                     userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithUTF8String:e.what()]}];
        }
        return nil;
    }
}

+ (NSString *)getElementTypeName:(ORTValue *)value {
    try {
        Ort::Value& ortValue = [value CXXAPIOrtValue];
        auto typeInfo = ortValue.GetTensorTypeAndShapeInfo();
        auto elementType = typeInfo.GetElementType();

        switch (elementType) {
            case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT:
                return @"float32";
            case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT32:
                return @"int32";
            case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT64:
                return @"int64";
            case ONNX_TENSOR_ELEMENT_DATA_TYPE_UINT8:
                return @"uint8";
            case ONNX_TENSOR_ELEMENT_DATA_TYPE_INT8:
                return @"int8";
            case ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT16:
                return @"float16";
            case ONNX_TENSOR_ELEMENT_DATA_TYPE_BOOL:
                return @"bool";
            case ONNX_TENSOR_ELEMENT_DATA_TYPE_STRING:
                return @"string";
            default:
                return @"unknown";
        }
    } catch (...) {
        return @"unknown";
    }
}

@end
