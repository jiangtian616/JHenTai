// VENDORED from https://github.com/masicai/onnxruntime-swift-package-manager tag 1.23.0 (objectivec/ort_value_internal.h);
// Internal header of the onnxruntime ObjC bindings, not exposed by the SPM package or CocoaPods pod.
// Required for float16 support (see docs/proposal_float16_ios_macos.md and docs/proposal_spm_migration.md §5.1).
// MUST stay byte-identical (below this comment) to the pinned onnxruntime version — re-diff on every ORT bump.
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License.

#import "ort_value.h"

#import "cxx_api.h"

NS_ASSUME_NONNULL_BEGIN

@interface ORTValue ()

/**
 * Creates a value from an existing C++ API Ort::Value and takes ownership from it.
 * Note: Ownership is guaranteed to be transferred on success but not otherwise.
 *
 * @param existingCXXAPIOrtValue The existing C++ API Ort::Value.
 * @param externalTensorData Any external tensor data referenced by `existingCXXAPIOrtValue`.
 * @param error Optional error information set if an error occurs.
 * @return The instance, or nil if an error occurs.
 */
- (nullable instancetype)initWithCXXAPIOrtValue:(Ort::Value&&)existingCXXAPIOrtValue
                             externalTensorData:(nullable NSMutableData*)externalTensorData
                                          error:(NSError**)error NS_DESIGNATED_INITIALIZER;

- (Ort::Value&)CXXAPIOrtValue;

@end

NS_ASSUME_NONNULL_END
