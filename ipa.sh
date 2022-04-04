version=$(head -n 5 pubspec.yaml | tail -n 1 | cut -d ' ' -f 2)

flutter build ios --release --no-codesign --obfuscate --split-debug-info=build/app/outputs/symbols -t lib/src/main.dart \
&& mkdir ~/Desktop/Payload \
&& cp -r build/ios/Release-iphoneos/Runner.app/ ~/Desktop/Payload/Runner.app/ \
&& cd ~/Desktop \
&& zip -ro JHenTai_${version}.ipa Payload \
&& rm -rf Payload
