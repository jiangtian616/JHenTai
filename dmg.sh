version=$(head -n 5 pubspec.yaml | tail -n 1 | cut -d ' ' -f 2)

flutter build macos --release -t lib/src/main.dart \
&& cp -r build/macos/Build/Products/Release/jhentai.app ~/Desktop/jhentai.app \
&& create-dmg --hdiutil-quiet ~/Desktop/JHenTai-${version}.dmg ~/Desktop/JHenTai/build/macos/Build/Products/Release/jhentai.app \
&& rm -rf ~/Desktop/jhentai.app
