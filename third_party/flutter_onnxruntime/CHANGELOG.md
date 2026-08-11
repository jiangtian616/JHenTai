## 1.8.3
* Fix App Store Connect validation errors (ITMS-90208) on iOS/macOS by repackaging ONNX Runtime as a library-format xcframework instead of framework-format (issue #71)

## 1.8.2
* Migrate Kotlin options to a newer format and resolve KTLC warnings to make the plugin ready for Kotlin 2.4 (#70)

## 1.8.1
* Fix memory surge/OOM crash during inference on SME-capable ARM64 devices (iPhone A18+/M4+) caused by a KleidiAI convolution memory regression in ONNX Runtime 1.24.x (#66, upstream microsoft/onnxruntime#29538) (#68)
* Move ONNX Runtime to 1.23.0 on all platforms: Android upgraded from 1.22.0; iOS/macOS downgraded from 1.24.2 via a masicai fork of the ONNX Runtime Swift package (Microsoft's SPM repo has no 1.23.x tag)
* Add save model extraction from assets to avoid ORT loading corrupted models (#67)
* Add true bool support on iOS/macOS via a C++ bridge (#69)

## 1.8.0
* Add Swift Package Manager support for iOS and macOS (#62); CocoaPods remains fully supported
* Upgrade `onnxruntime-objc` from 1.22.0 to 1.24.2 for iOS and macOS (aligned with the official ONNX Runtime Swift package)
* Move Android integration test CI from macOS to Ubuntu

## 1.7.1
* Prevent startup crash from `makeBackgroundTaskQueue` forwarding on macOS (#58 #59)

## 1.7.0
* Run inference on a background thread via Flutter's TaskQueue for Android, iOS, and macOS
* Prevent race condition introduced by running inference on a background thread in the case of disposing the session while inference is running

## 1.6.4
* Fix tensor creation for bool and uint8 types
* Add missing tensor conversions for bool and uint8 types across Android, iOS/macOS, and Web
* Add more integration tests to harness the conversions

## 1.6.3
* Add float16 tensor support for iOS and macOS
* Upgrade `onnxruntime-objc` for macOS to 1.22.0

## 1.6.2
* Fix a memory leak issue for tensor creation in Linux and Windows
* Fix thread safe issue for tensor operations in Linux and Windows

## 1.6.1
* Explicit cleanup for ONNX Runtime resources when applications close in macOS and iOS (#45)

## 1.6.0
* Optimize the data transfer from native to Dart using typed arrays (#43)
* Setup cmake-format for CMake formatting (#41)
* Add bug report and feature request templates

## 1.5.2
* Migrate the web plugin from `dart:js` to `dart:js_interop` (#40)

## 1.5.1
* Upgrade ONNX Runtime to version 1.22.0 for 16KB Page Size support in Android (#39)
* Fix Linux build issues in CMake and X11 display server (#37)
* Upgrade Kotlin version to 2.1.0 (#38)

## 1.4.3
* Fix an issue with input name-value mismatch in Windows (#28 #29)
* Add more integration tests for input name and order consistency
* Add integration tests for int64 input tensor

## 1.4.2
* Remove unnecessary warnings in CMake for the Linux build
* Improve README and troubleshooting documentation

## 1.4.1
* Support string tensors in all platforms
* Reinforce structure and behavior consistency between Linux and Windows implementations
* Minor bug fixes and documentation updates

## 1.4.0
* Support Windows platform 🎉🎉🎉
* Refactor SessionManager in Linux for cleaner architecture
* Add Azure to provider list
* Improve the CMake build stability in Linux

## 1.3.0
* Support Web platform 🎉🎉🎉
* Add integration tests for Web in both local and CI

## 1.2.3
* Standardize Execution Provider names across all platforms
* Fix a bug in get_metadata method for Linux

## 1.2.2
* Improve example documentation

## 1.2.0
* Returning a multi-dimensional list for tensor data extraction
* Support return a flat list

## 1.1.0
* Standardize error codes and error messages from native
* Remove auto disposal of input tensors after inference in Kotlin
* Refactor C++ to return standard Platform Exception and impose standard error handling
* Add back the example to package as required by pub.dev; this will increase the package size unnecessarily

## 1.0.0
* Support running inference with an ONNX model on Android, iOS, Linux, and macOS
* Support ONNX Runtime version 1.21.0
