version=$(head -n 5 pubspec.yaml | tail -n 1 | cut -d ' ' -f 2)

flutter build ios --release --no-codesign -t lib/src/main.dart \
&& rm -rf ~/Desktop/Payload \
&& mkdir -p ~/Desktop/Payload \
&& cp -r build/ios/iphoneos/Runner.app ~/Desktop/Payload/Runner.app \
&& cd ~/Desktop \
&& rm -f JHenTai_${version}.ipa \
&& zip -ro JHenTai_${version}.ipa Payload \
&& rm -rf Payload
