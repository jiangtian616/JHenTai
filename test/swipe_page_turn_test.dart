import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jhentai/src/setting/read_setting.dart';
import 'package:jhentai/src/widget/eh_swipe_page_turner.dart';

void main() {
  group('resolveHorizontalSwipe', () {
    test('long horizontal movement is recognized', () {
      expect(resolveHorizontalSwipe(dx: -200, dy: 10, width: 1000, thresholdRatio: 0.12), SwipeDirection.left);
      expect(resolveHorizontalSwipe(dx: 200, dy: -30, width: 1000, thresholdRatio: 0.12), SwipeDirection.right);
    });

    test('short movement is not a swipe', () {
      expect(resolveHorizontalSwipe(dx: 100, dy: 0, width: 1000, thresholdRatio: 0.12), isNull);
      expect(resolveHorizontalSwipe(dx: 0, dy: 0, width: 1000, thresholdRatio: 0.12), isNull);
    });

    test('mostly vertical movement is not a swipe', () {
      expect(resolveHorizontalSwipe(dx: 200, dy: 150, width: 1000, thresholdRatio: 0.12), isNull);
      expect(resolveHorizontalSwipe(dx: 0, dy: 300, width: 1000, thresholdRatio: 0.12), isNull);
    });

    test('invalid width is ignored', () {
      expect(resolveHorizontalSwipe(dx: 200, dy: 0, width: 0, thresholdRatio: 0.12), isNull);
    });

    test('threshold is relative to width', () {
      expect(resolveHorizontalSwipe(dx: 61, dy: 0, width: 1000, thresholdRatio: 0.12), isNull);
      expect(resolveHorizontalSwipe(dx: 121, dy: 0, width: 1000, thresholdRatio: 0.12), SwipeDirection.right);
    });
  });

  group('EHSwipePageTurner', () {
    Future<void> swipe(WidgetTester tester, Offset from, Offset to) async {
      TestGesture gesture = await tester.startGesture(from);
      await gesture.moveTo(to);
      await gesture.up();
      await tester.pump();
    }

    Future<List<String>> pumpTurner(WidgetTester tester, {bool enabled = true, bool canSwipe = true}) async {
      List<String> events = [];
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 1000,
            height: 600,
            child: EHSwipePageTurner(
              enabled: enabled,
              canSwipe: () => canSwipe,
              onSwipeLeft: () => events.add('left'),
              onSwipeRight: () => events.add('right'),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      );
      return events;
    }

    testWidgets('turns page once per swipe', (tester) async {
      List<String> events = await pumpTurner(tester);

      await swipe(tester, const Offset(600, 300), const Offset(300, 300));
      await swipe(tester, const Offset(300, 300), const Offset(600, 300));

      expect(events, ['left', 'right']);
    });

    testWidgets('ignores short swipe', (tester) async {
      List<String> events = await pumpTurner(tester);

      await swipe(tester, const Offset(300, 300), const Offset(330, 300));

      expect(events, isEmpty);
    });

    testWidgets('does nothing when disabled', (tester) async {
      List<String> events = await pumpTurner(tester, enabled: false);

      await swipe(tester, const Offset(600, 300), const Offset(100, 300));

      expect(events, isEmpty);
    });

    testWidgets('ignores swipe when zoomed in', (tester) async {
      List<String> events = await pumpTurner(tester, canSwipe: false);

      await swipe(tester, const Offset(600, 300), const Offset(100, 300));

      expect(events, isEmpty);
    });

    testWidgets('ignores pinch (multi touch)', (tester) async {
      List<String> events = await pumpTurner(tester);

      TestGesture first = await tester.startGesture(const Offset(600, 300), pointer: 1);
      TestGesture second = await tester.startGesture(const Offset(700, 300), pointer: 2);
      await first.moveTo(const Offset(100, 300));
      await first.up();
      await second.up();
      await tester.pump();

      expect(events, isEmpty);
    });
  });

  group('linked switches', () {
    test('swipe switch is only configurable while turn page animation is off', () {
      ReadSetting setting = ReadSetting();
      setting.enablePageTurnAnime.value = true;
      expect(setting.swipePageTurnAnimeConfigurable, isFalse);

      setting.enablePageTurnAnime.value = false;
      expect(setting.swipePageTurnAnimeConfigurable, isTrue);
    });

    test('swiping always animates while turn page animation is on', () {
      ReadSetting setting = ReadSetting();
      setting.enablePageTurnAnime.value = true;
      setting.enableSwipePageTurnAnime.value = false;

      expect(setting.swipePageTurnAnimated, isTrue);
      expect(setting.instantSwipeTurnPage, isFalse);
    });

    test('with turn page animation off, the swipe switch decides', () {
      ReadSetting setting = ReadSetting();
      setting.enablePageTurnAnime.value = false;

      setting.enableSwipePageTurnAnime.value = true;
      expect(setting.swipePageTurnAnimated, isTrue);
      expect(setting.instantSwipeTurnPage, isFalse);

      setting.enableSwipePageTurnAnime.value = false;
      expect(setting.swipePageTurnAnimated, isFalse);
      expect(setting.instantSwipeTurnPage, isTrue);
    });

    test('default keeps upstream behaviour: animation on, swipe animates', () {
      ReadSetting setting = ReadSetting();
      expect(setting.enablePageTurnAnime.value, isTrue);
      expect(setting.enableSwipePageTurnAnime.value, isFalse);
      expect(setting.swipePageTurnAnimated, isTrue);
      expect(setting.instantSwipeTurnPage, isFalse);
    });
  });

  group('enableSwipePageTurnAnime serialization', () {
    test('defaults to false so that turning turn page animation off switches page instantly', () {
      expect(ReadSetting().enableSwipePageTurnAnime.value, isFalse);
    });

    test('survives json round trip', () {
      ReadSetting setting = ReadSetting();
      setting.enableSwipePageTurnAnime.value = true;

      Map<String, dynamic> map = jsonDecode(setting.toConfigString());
      expect(map['enableSwipePageTurnAnime'], isTrue);

      setting.enableSwipePageTurnAnime.value = false;
      setting.applyBeanConfig(jsonEncode(map));
      expect(setting.enableSwipePageTurnAnime.value, isTrue);
    });

    test('config saved by old version without the key still loads', () {
      ReadSetting setting = ReadSetting();
      Map<String, dynamic> map = jsonDecode(setting.toConfigString());
      map.remove('enableSwipePageTurnAnime');

      setting.enableSwipePageTurnAnime.value = true;
      setting.applyBeanConfig(jsonEncode(map));
      expect(setting.enableSwipePageTurnAnime.value, isTrue);
    });
  });
}
