version=$(head -n 5 pubspec.yaml | tail -n 1 | cut -d ' ' -f 2)

flutter build windows --build-name=JHenTai --build-number=${version}  -t lib/src/main.dart \
&& cp -r build/windows/runner/Release/ ~/Desktop/JHenTai_${version}_windows/ \
&& cd ~/Desktop \
&& zip -ro JHenTai_${version}_windows.zip JHenTai_${version}_windows \
&& rm -rf JHenTai_${version}_windows
