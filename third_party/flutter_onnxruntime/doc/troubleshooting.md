# Troubleshooting

Common issues and their solutions.


## Android
* `JNI DETECTED ERROR IN APPLICATION: mid == null`
    For Android consumers using the library with R8-minimized builds, currently you need to add the following line to your `proguard-rules.pro` inside your Android project at `android/app/` ([reference](https://onnxruntime.ai/docs/build/android.html#note-proguard-rules-for-r8-minimization-android-app-builds-to-work))
    ```
    -keep class ai.onnxruntime.** { *; }
    ```
    or run the below bash command from the project root:
    ```bash
    echo "-keep class ai.onnxruntime.** { *; }" > android/app/proguard-rules.pro
    ```
* `...Module was compiled with an incompatible version of Kotlin. The binary version of its metadata is 2.1.0, expected version is 1.8.0`: update your Kotlin version to 2.1.0 in `android/settings.gradle.kts`:
    ```kotlin
    plugins {
        id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    }
    ```

## iOS
* Target minimum version: iOS 16
    * Open `ios/Podfile` and change the target minimum version to 16.0
        ```pod
        platform :ios, '16.0'
        ```
* "The 'Pods-Runner' target has transitive dependencies that include statically linked binaries: (onnxruntime-objc and onnxruntime-c)". In `Podfile` change:
    ```pod
    target 'Runner' do
    use_frameworks! :linkage => :static
    ```
* `RuntimeException` while running Reshape node with "input_shape_size == size was false"
    If you are using an ORT optimized model, it's possible that there is some certain nodes that is not supported by ORT. Try using the original ONNX model (without ORT optimization) to see if the issue persists.
* `CocoaPods could not find compatible versions for pod "onnxruntime-objc"`:
    This usually happens when you have an older version of `onnxruntime-objc` installed in your local CocoaPods repository. Try running the following command to update your local CocoaPods repository:
    ```
    cd ios/
    pod update onnxruntime-objc
    ```

## macOS
* Target minimum version: MacOS 14
    * Open `macos/Podfile` and change the target minimum version to 14.0
        ```pod
        platform :osx, '14.0'
        ```
    * "error: compiling for macOS 10.14, but module 'flutter_onnxruntime' has a minimum deployment target of macOS 14.0".
        * In terminal, cd to the `macos` directory and run the XCode to open the project:
            ```
            open Runner.xcworkspace
            ```
        * In `Runner` -> `General`, change `Minimum Deployments` to `14.0`.
* "The 'Pods-Runner' target has transitive dependencies that include statically linked binaries: (onnxruntime-objc and onnxruntime-c)". In `Podfile` change:
    ```
    target 'Runner' do
    use_frameworks! :linkage => :static
    ```


## Linux
* When running with ONNX Runtime 1.21.0, you may see reference counting warnings related to FlValue objects. These don't prevent the app from running but may be addressed in future updates.
