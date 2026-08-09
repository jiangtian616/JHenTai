import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/widget/progressive_image_stack.dart';

void main() {
  testWidgets('removes thumbnail without disposing the loaded full image',
      (tester) async {
    const Key thumbnailKey = Key('thumbnail');
    const Key imageKey = Key('image');
    int imageInitCount = 0;
    int imageDisposeCount = 0;
    int stackDisposeCount = 0;

    Widget build({required bool loaded}) {
      return Directionality(
        textDirection: TextDirection.ltr,
        child: ProgressiveImageStack(
          width: 100,
          height: 200,
          showThumbnail: !loaded,
          thumbnail: const SizedBox(key: thumbnailKey),
          image: _LifecycleProbe(
            key: imageKey,
            onInit: () => imageInitCount++,
            onDispose: () => imageDisposeCount++,
          ),
          onDispose: () => stackDisposeCount++,
        ),
      );
    }

    await tester.pumpWidget(build(loaded: false));
    expect(find.byKey(thumbnailKey), findsOneWidget);
    expect(find.byKey(imageKey), findsOneWidget);

    await tester.pumpWidget(build(loaded: true));
    expect(find.byKey(thumbnailKey), findsNothing);
    expect(find.byKey(imageKey), findsOneWidget);
    expect(imageInitCount, 1);
    expect(imageDisposeCount, 0);
    expect(stackDisposeCount, 0);

    await tester.pumpWidget(const SizedBox());
    expect(imageDisposeCount, 1);
    expect(stackDisposeCount, 1);
  });
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({
    super.key,
    required this.onInit,
    required this.onDispose,
  });

  final VoidCallback onInit;
  final VoidCallback onDispose;

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
