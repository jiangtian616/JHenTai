version=$(head -n 5 pubspec.yaml | tail -n 1 | cut -d ' ' -f 2)

flutter build macos --release -t lib/src/main.dart \
&& brew install create-dmg \
&& create-dmg --volname JHenTai-${version} --window-pos 200 120 --window-size 800 450 --icon-size 100 --app-drop-link 600 185 JHenTai-${version}.dmg build/macos/Build/Products/Release/jhentai.app