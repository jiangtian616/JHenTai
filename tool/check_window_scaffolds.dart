import 'dart:io';

/// Regular pages share NativeWindowScaffold. Only structural layout shells
/// own a plain Scaffold; full-screen readers use their separate window policy.
void main() {
  final root = File.fromUri(Platform.script).parent.parent;
  final pages = Directory('${root.path}/lib/src/pages');
  const shells = {
    'layout/mobile_v2/mobile_layout_page_v2.dart': 'Phone shell; its child pages own headers and safe areas.',
    'layout/tablet_v2/tablet_layout_page_v2.dart': 'Retained pane host; each pane owns its page scaffold.',
    'layout/desktop/desktop_layout_page.dart': 'Desktop tab/window shell.',
  };
  final plainScaffold = RegExp(r'(?<![\w])Scaffold\s*\(');
  final missed = <String>[];
  var checked = 0;
  for (final file in pages.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
    final relative = file.path.substring(pages.path.length + 1).replaceAll('\\', '/');
    final source = file.readAsStringSync();
    if (source.contains('NativeWindowScaffold(')) {
      checked++;
    }
    if (plainScaffold.hasMatch(source) && !shells.containsKey(relative)) {
      missed.add(relative);
    }
  }
  if (missed.isNotEmpty) {
    stderr.writeln('Pages bypassing NativeWindowScaffold: ${missed.join(', ')}');
    exitCode = 1;
    return;
  }
  stdout.writeln('Window scaffold coverage passed: $checked page files, ${shells.length} documented layout shells.');
}
