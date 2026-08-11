// Copyright (c) MASIC AI
// All rights reserved.
//
// This source code is licensed under the license found in the
// LICENSE file in the root directory of this source tree.

#if __has_include("flutter_onnxruntime_objc/MessengerHelper.h")
#import "flutter_onnxruntime_objc/MessengerHelper.h"  // SPM (public headers under include/flutter_onnxruntime_objc/)
#else
#import "MessengerHelper.h"  // CocoaPods
#endif

@implementation MessengerHelper

+ (NSObject<FlutterTaskQueue> *)safeMakeBackgroundTaskQueue:
    (NSObject<FlutterBinaryMessenger> *)messenger {
  if (![messenger respondsToSelector:@selector(makeBackgroundTaskQueue)]) {
    return nil;
  }
  @try {
    return [messenger makeBackgroundTaskQueue];
  } @catch (NSException *exception) {
    return nil;
  }
}

@end
