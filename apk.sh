version=$(head -n 5 pubspec.yaml | tail -n 1 | cut -d ' ' -f 2)

flutter build apk -t lib/src/main.dart --split-per-abi \
&& cp build/app/outputs/apk/release/app-arm64-v8a-release.apk ~/Desktop/JHenTai-${version}-arm64-v8a.apk \
&& cp build/app/outputs/apk/release/app-armeabi-v7a-release.apk ~/Desktop/JHenTai-${version}-armeabi-v7a.apk \
&& cp build/app/outputs/apk/release/app-x86_64-release.apk ~/Desktop/JHenTai-${version}-x86_64.apk \
