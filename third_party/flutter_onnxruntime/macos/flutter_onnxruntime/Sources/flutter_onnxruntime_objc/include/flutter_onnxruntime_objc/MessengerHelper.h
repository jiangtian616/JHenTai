// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#import <Foundation/Foundation.h>
#import <FlutterMacOS/FlutterMacOS.h>

NS_ASSUME_NONNULL_BEGIN

@interface MessengerHelper : NSObject

/// Attempts to create a background task queue from the given binary messenger,
/// returning nil if the underlying engine does not implement the selector.
///
/// On some Flutter macOS versions, FlutterBinaryMessengerRelay declares
/// -makeBackgroundTaskQueue but forwards it to a FlutterEngine that does not
/// implement the selector, raising an NSInvalidArgumentException that Swift's
/// optional chaining cannot catch. This helper wraps the call in @try/@catch.
/// See https://github.com/flutter/flutter/issues/184737
+ (nullable NSObject<FlutterTaskQueue> *)safeMakeBackgroundTaskQueue:
    (NSObject<FlutterBinaryMessenger> *)messenger;

@end

NS_ASSUME_NONNULL_END
