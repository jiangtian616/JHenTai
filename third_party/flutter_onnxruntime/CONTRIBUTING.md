
We welcome contributions to improve the flutter_onnxruntime plugin! Whether you're fixing bugs, adding features, or improving documentation, your help is appreciated.

## Principles

### Tests are the source of truth, respect them

All native implementations are not glued by the Dart API but the Dart integration tests. All native implementations should adapt to pass the tests, not the other way.

Apart from the unit tests at `test/unit`, we have sophisicated integration tests at `example/integration_test` that cover all the supported platforms. Make sure that you run the script at `scripts/run_tests_in_local.sh` to run all the tests before submitting a pull request.

## Setting Up Development Environment

### Pre-commit Setup
We use a pre-commit hook to ensure code quality and consistency. Follow these steps to set it up:

1. Install required tools:
   - Dart SDK and Flutter (required for all platforms)
   - **ktlint** (for Android Kotlin formatting):
     ```
     curl -sSLO https://github.com/pinterest/ktlint/releases/download/1.0.0/ktlint && chmod a+x ktlint && sudo mv ktlint /usr/local/bin/
     ```
   - **SwiftLint** (for iOS/macOS Swift formatting, macOS only):
     ```
     brew install swiftlint
     ```
   - **clang-format** (for C++ formatting):
     ```
     # Ubuntu/Debian
     sudo apt-get install clang-format
     
     # macOS
     brew install clang-format

     # Windows
     winget install -e --id LLVM.ClangFormat
     ```
   - **cmake-format** (for CMake formatting):
     ```
     pip install cmake-format
     ```

2. Copy the pre-commit hook to your local Git hooks directory:
   ```
   cp hooks/pre-commit .git/hooks/
   chmod +x .git/hooks/pre-commit
   ```

The pre-commit hook will:
- Format Dart code
- Format Kotlin code (Android)
- Format Swift code (iOS/macOS)
- Format C++ code
- Run Flutter analyze
- Prevent commits with formatting errors

## Testing

For testing, we use the `scripts/run_tests_in_local.sh` script to run unit and integration tests on all available platforms.

```
./scripts/run_tests_in_local.sh
```

You can also manually run tests for a specific platform:

1. Run unit tests:
    ```
    flutter test test/unit
    ```
    * To run unit tests for a specific platform, for example for Chrome:
    ```
    flutter test test/unit --platform chrome
    ```
2. Run integration tests:
    ```
    cd example
    flutter test integration_test/all_tests.dart -d <device_id>
    ```
    or running via flutter drive:
    ```
    cd example
    flutter drive --driver=test_driver/integration_test.dart --target=integration_test/ -d <device_id>
    ```
  * To run a test separately, you can run the following commands:
    ```
    flutter test integration_test/all_tests.dart --plain-name "<Test Name>" -d <device_id>
    ```

### Run integration tests on web
To run integration tests on web, we need to have a web driver running. We will use Chrome Driver for this example.

1. Download Chrome Driver from [here](https://googlechromelabs.github.io/chrome-for-testing/). Select the version that matches your Chrome version.

2. After download and extract the file, you should see a binary file `chromedriver`. Run the following command to start the driver on port 4444:
    ```
    ./chromedriver --port=4444
    ```

3. Run the integration tests:
    ```
    cd example
    flutter drive -d chrome --driver ./test_driver/integration_test.dart  --target ./integration_test/all_tests.dart
    ```
    Or you can run as a web server in port `8080` with the following command:
    ```
    cd example
    flutter drive -d web-server --web-port=8080 --release  --driver ./test_driver/integration_test.dart  --target ./integration_test/all_tests.dart
    ```

## Contributing
1. Fork the repository
2. Create a feature branch: `git checkout -b feature/my-feature`
3. Make your changes and test on multiple platforms if possible
4. Submit a pull request with a clear description of your changes

### Release a new version
* Update a new version at `pubspec.yaml` and changes in `CHANGELOG.md`
* Commit all changes in local
* Dry run the publish and review the publish information carefully: `dart pub publish --dry-run`
* If the dry run succeeds, run the following command to publish: `dart pub publish`
* Tag the new release: `git tag -a v1.4.2 -m "version 1.4.2"`
* Push changes to remote: `git push`
* Push the tag to remote: `git push --tags`
* Create a new release in Github

## Debug Tips
* Log printing does not work when debugging for C++/Linux. We could use early return of `FL_METHOD_RESPONSE()` to locate the error.
