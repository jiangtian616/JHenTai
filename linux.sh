version=$(head -n 5 pubspec.yaml | tail -n 1 | cut -d ' ' -f 2)

flutter build linux --release -t lib/src/main.dart \
&& mkdir ~/Desktop/JHenTai_${version} \
&& cp -r build/linux/x64/release/bundle/* ~/Desktop/JHenTai_${version}/ \
&& cd ~/Desktop \
&& zip -ro JHenTai_${version}.zip JHenTai_${version} \
&& rm -rf mkdir ~/Desktop/JHenTai_${version}
