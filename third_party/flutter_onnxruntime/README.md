<img src="flutter_onnxruntime.png" alt="flutter_onnxruntime" align="center"/>
<p align="center">
<a href="https://pub.dev/packages/flutter_onnxruntime" alt="Flutter ONNX Runtime on pub.dev">
        <img src="https://img.shields.io/pub/v/flutter_onnxruntime.svg" height="25" /></a>
<a href="https://pub.dev/packages/flutter_onnxruntime" alt="Flutter ONNX Runtime monthly downloads">
        <img src="https://img.shields.io/pub/dm/flutter_onnxruntime.svg" height="25" /></a>
</p>

# flutter_onnxruntime

Native Wrapper Flutter Plugin for ONNX Runtime

*Current supported ONNX Runtime version:* **1.23.0**

*Note:* For Android build, you need to upgrade your `flutter_onnxruntime` to version `>=1.5.1` to satisfy the [16 KB Google Play compatibility requirement](https://android-developers.googleblog.com/2025/05/prepare-play-apps-for-devices-with-16kb-page-size.html).

## 🌟 Why This Project?

`flutter_onnxruntime` is a lightweight plugin that provides native wrappers for running ONNX Runtime on multiple platforms.

      📦 No Pre-built Libraries
      Libraries are fetched directly from official repositories during installation, ensuring they are always up-to-date!

      🛡️ Memory Safety
      All memory management is handled in native code, reducing the risk of memory leaks.

      🔄 Easy Upgrades
      Stay current with the latest ONNX Runtime releases without the hassle of maintaining complex generated FFI wrappers.

## 🚀 Getting Started

### Installation

Add the following dependency to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_onnxruntime: ^1.8.1
```

### Quick Start

Example of running an addition model:
```dart
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

// create inference session
final ort = OnnxRuntime();
final session = await ort.createSessionFromAsset('assets/models/addition_model.onnx');

// specify input with data and shape
final inputs = {
   'A': await OrtValue.fromList([1, 1, 1], [3]),
   'B': await OrtValue.fromList([2, 2, 2], [3])
}

// start the inference
final outputs = await session.run(inputs);

// print output data
print(await outputs['C']!.asList());
```

To get started with the Flutter ONNX Runtime plugin, see the [API Usage Guide](doc/api_usage.md).

## 🧪 Examples

### [Simple Addition Model](example/)

A simple model with only one operator (Add) that takes two inputs and produces one output.

Run this example with:
```bash
cd example
flutter pub get
flutter run
```

### [Image Classification Model](https://github.com/masicai/flutter-onnxruntime-examples)

A more complex model that takes an image as input and classifies it into one of the predefined categories.

Clone [this repository](https://github.com/masicai/flutter-onnxruntime-examples) and run the example following the repo's guidelines.

## 📊 Component Overview

| Component | Description |
|-----------|-------------|
| OnnxRuntime | Main entry point for creating sessions and configuring global options |
| OrtSession | Represents a loaded ML model for running inference |
| OrtValue | Represents tensor data for inputs and outputs |
| OrtSessionOptions | Configuration options for session creation |
| OrtRunOptions | Configuration options for inference execution |

## 🚧 Implementation Status

| Feature | Android | iOS | Linux | macOS | Windows | Web |
|---------|:-------:|:---:|:-----:|:-----:|:-------:|:---: |
| CPU Inference | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| EP<sup>1</sup> Configuration | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Input/Output names | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Data Type Conversion | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Inference on Emulator | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Input/Output Info | ✅ | ❌* | ✅ | ❌* | ✅ | ✅ |
| Model Metadata | ✅ | ❌* | ✅ | ❌* | ✅ | ❌* |
| FP16 Support | ✅ | ✅ | ✍️ | ✅ | ✍️ | ✍️ |

✅: Completed

❌: Not supported

🚧: Ongoing

✍️: Planned

`*`: Retrieving model metadata and input/output info is not available for Swift and Javascript API.

<sup>1</sup>: Execution Providers (EP) are hardware accelerated inference interface for AI inference (e.g., CPU, GPU, NPU, TPU, etc.) 

## 📋 Required development setup

### Android

Android build requires `proguard-rules.pro` inside your Android project at `android/app/` with the following content:
  ```
  -keep class ai.onnxruntime.** { *; }
  ```
or running the below command from your terminal:

  ```bash
  echo "-keep class ai.onnxruntime.** { *; }" > android/app/proguard-rules.pro
  ```

Refer to [troubleshooting.md](doc/troubleshooting.md) for more information.

### iOS

ONNX Runtime requires minimum version `iOS 16` and static linkage.

The plugin supports both CocoaPods (default) and Swift Package Manager. With Swift Package Manager enabled (see [below](#swift-package-manager-ios-and-macos)), no Podfile changes are needed, but the app's iOS "Minimum Deployments" must be at least `16.0` (Xcode enforces the plugin's minimum platform under SPM).

For CocoaPods, in `ios/Podfile`, change the following lines:
```bash
platform :ios, '16.0'

# existing code ...

use_frameworks! :linkage => :static

# existing code ...
```

### macOS

macOS build requires minimum version `macOS 14`.

* For CocoaPods, in `macos/Podfile`, change the following lines:
  ```bash
  platform :osx, '14.0'
  ```

* Change the "Minimum Deployments" to 14.0 in XCode. In your terminal:
  ```bash
  open Runner.xcworkspace
  ```
  In `Runner` -> `General`, change `Minimum Deployments` to `14.0`.

### Swift Package Manager (iOS and macOS)

The plugin supports [Flutter's Swift Package Manager integration](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers), which is opt-in on Flutter 3.24+:

```bash
flutter config --enable-swift-package-manager
```

Both install paths ship the same ONNX Runtime version and behave identically. CocoaPods remains fully supported and is used automatically when the flag is off or on older Flutter versions.


## 🛠️ Troubleshooting

For troubleshooting, see the [troubleshooting.md](doc/troubleshooting.md) file.

## 🤝 Contributing
Contributions to the Flutter ONNX Runtime plugin are welcome. Please see the [CONTRIBUTING.md](CONTRIBUTING.md) file for more information.

## 📚 Documentation
Find more information in the [documentation](doc/).
