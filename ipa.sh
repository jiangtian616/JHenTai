flutter build ipa --release -t lib/src/main.dart

cp -r build/ios/archive/Runner.xcarchive/Products/Applications/Runner.app ~/Desktop/Runner.app

mkdir ~/Desktop/Payload

mv ~/Desktop/Runner.app ~/Desktop/Payload

zip ~/Desktop/JHenTai.ipa ~/Desktop/Payload
