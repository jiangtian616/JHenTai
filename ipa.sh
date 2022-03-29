flutter build ios --release -t lib/src/main.dart

xcodebuild profile -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release
