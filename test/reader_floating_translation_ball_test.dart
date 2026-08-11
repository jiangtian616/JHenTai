import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/service/reader_action_persistence.dart';
import 'package:jhentai/src/widget/reader_floating_translation_ball.dart';

class _MemoryStore implements ReaderActionKeyValueStore {
  final Map<String, String> values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

void main() {
  testWidgets('floating ball is draggable, snaps to an edge, and invokes tap', (
    tester,
  ) async {
    final _MemoryStore memory = _MemoryStore();
    int taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Stack(
            children: [
              ReaderFloatingTranslationBall(
                positionStore: ReaderFloatingBallPositionStore(store: memory),
                isTranslating: false,
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.translate), findsOneWidget);
    await tester.tap(find.byIcon(Icons.translate));
    expect(taps, 1);

    await tester.drag(find.byIcon(Icons.translate), const Offset(-600, 30));
    await tester.pumpAndSettle();
    // Flutter's default test viewport is landscape (800x600), so this also
    // proves the widget writes the orientation-specific slot it is rendered in.
    expect(memory.values['landscape'], isNotNull);
    expect(memory.values['landscape'], contains('"x":0.0'));
  });
}
