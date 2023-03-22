version=$(head -n 5 pubspec.yaml | tail -n 1 | cut -d ' ' -f 2)

flutter build macos --release -t lib/src/main.dart \
&& hdiutil create -size 150m -fs HFS+ -volname JHenTai JHenTai.dmg \
&& hdiutil attach JHenTai.dmg \
&& cp -R build/macos/Build/Products/Release/jhentai.app /Volumes/JHenTai \
&& pkgbuild --install-location /Applications/JHenTai.app --identifier top.jtmonster.jhentai --version ${version} --root /Volumes/JHenTai/jhentai.app build/macos/JHenTai-${version}.pkg \
&& hdiutil detach /Volumes/JHenTai
