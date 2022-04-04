flutter build ios --release --no-codesign --obfuscate --split-debug-info=build/app/outputs/symbols -t lib/src/main.dart \
&& mkdir ~/Desktop/Payload \
&& cp -r build/ios/Release-iphoneos/Runner.app/ ~/Desktop/Payload/Runner.app/ \
&& cd ~/Desktop \
&& zip -ro JHenTai.ipa Payload \
&& rm -rf Payload
