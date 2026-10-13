import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/jigsaw/core/jigsaw_geometry.dart';
import 'package:tabgame/games/jigsaw/data/jigsaw_storage.dart';
import 'package:tabgame/games/jigsaw/game/jigsaw_controller.dart';
import 'package:tabgame/games/jigsaw/ui/jigsaw_images.dart';
import 'package:tabgame/games/jigsaw/ui/jigsaw_menu_screen.dart';

JigsawController newController() => JigsawController(
      geometry: JigsawGeometry(rows: 3, cols: 4, imageSize: const Size(1200, 800), seed: 1),
      scatterSeed: 1,
    );

/// 이 판을 "지금 하는 판"으로 삼아 저장한다 (시간 순서가 구분되도록 잠깐 쉰다).
Future<JigsawController> play(JigsawSource source, {int target = 12, int placed = 0}) async {
  final c = newController();
  for (var i = 0; i < placed; i++) {
    c.placed[i] = true;
  }
  JigsawStorage.setActive(c);
  await JigsawStorage.save(c, source, target);
  await Future<void>.delayed(const Duration(milliseconds: 3));
  return c;
}

const photoA = JigsawSource('file', '/data/jigsaw_a.jpg');
const photoB = JigsawSource('file', '/data/jigsaw_b.jpg');
const sunset = JigsawSource('sample', 'sunset');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('내 퍼즐 보관함', () {
    test('저장하면 보관함에 생기고, 같은 그림은 칸이 늘지 않고 갱신된다', () async {
      expect(await JigsawStorage.library(), isEmpty);
      await play(photoA, target: 24, placed: 2);
      var list = await JigsawStorage.library();
      expect(list.length, 1);
      expect(list.single.source.ref, photoA.ref);
      expect(list.single.inProgress, isTrue);
      expect(list.single.progress, (2, 12));

      await play(photoA, target: 48, placed: 5);
      list = await JigsawStorage.library();
      expect(list.length, 1);
      expect(list.single.progress, (5, 12));
      expect(list.single.pieceTarget, 48);
    });

    test('다른 그림은 이어하던 판을 따로 간직한다 (새 퍼즐을 시작해도 이전 판이 안 사라진다)', () async {
      await play(photoA, placed: 3);
      await play(photoB, placed: 1);
      final list = await JigsawStorage.library();
      expect(list.length, 2);
      expect(list.first.source.ref, photoB.ref); // 최근에 한 것이 먼저
      expect(list.firstWhere((e) => e.source.ref == photoA.ref).progress, (3, 12));
      expect(list.every((e) => e.save != null), isTrue);
    });

    test('완성하면 갤러리 사진은 남고(완성 횟수 +1), 샘플은 보관함에서 빠진다', () async {
      final a = await play(photoA);
      await JigsawStorage.clear(a, photoA);
      final s = await play(sunset);
      await JigsawStorage.clear(s, sunset);
      final list = await JigsawStorage.library();
      expect(list.length, 1);
      expect(list.single.source.ref, photoA.ref);
      expect(list.single.inProgress, isFalse);
      expect(list.single.wins, 1);
      expect(list.single.save, isNull);

      // 다시 시작하면 같은 칸에서 이어진다 (완성 횟수 유지)
      await play(photoA, placed: 1);
      final again = await JigsawStorage.library();
      expect(again.length, 1);
      expect(again.single.wins, 1);
      expect(again.single.inProgress, isTrue);
    });

    test('지우면 보관함에서 사라진다', () async {
      await play(photoA);
      await play(photoB);
      await JigsawStorage.remove(photoA);
      final list = await JigsawStorage.library();
      expect(list.map((e) => e.source.ref), [photoB.ref]);
    });

    test('지금 하는 판이 아니거나 출처를 모르는 판은 저장하지 않는다', () async {
      final c = newController();
      await JigsawStorage.save(c, photoA, 12); // setActive 안 함
      expect(await JigsawStorage.library(), isEmpty);
      JigsawStorage.setActive(c);
      await JigsawStorage.save(c, JigsawSource.none, 12);
      expect(await JigsawStorage.library(), isEmpty);
    });

    test('예전 형식의 이어하기 저장은 보관함으로 옮겨진다', () async {
      final c = newController();
      SharedPreferences.setMockInitialValues({
        'jigsaw.save': jsonEncode({
          'state': jsonDecode(jsonEncode(c.toJson())),
          'source': photoA.toJson(),
          'target': 24,
        }),
      });
      final list = await JigsawStorage.library();
      expect(list.length, 1);
      expect(list.single.source.ref, photoA.ref);
      expect(list.single.pieceTarget, 24);
      expect(list.single.inProgress, isTrue);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('jigsaw.save'), isNull);
      expect((await JigsawStorage.library()).length, 1); // 두 번째 읽기에서도 그대로
    });

    test('칸이 넘치면 오래된 것부터 정리하되 이어하던 판은 최대한 지킨다', () async {
      // 완성한 사진(이어하던 판 없음) 하나 + 이어하던 판 여러 개
      final done = await play(photoA);
      await JigsawStorage.clear(done, photoA);
      for (var i = 0; i < JigsawStorage.maxEntries; i++) {
        await play(JigsawSource('file', '/data/p$i.jpg'));
      }
      final list = await JigsawStorage.library();
      expect(list.length, JigsawStorage.maxEntries);
      expect(list.any((e) => e.source.ref == photoA.ref), isFalse); // 쉬는 퍼즐이 먼저 정리됨
      expect(list.every((e) => e.inProgress), isTrue);
    });

    test('동시에 여러 번 저장해도 서로 덮어쓰지 않는다', () async {
      final a = newController();
      final b = newController();
      JigsawStorage.setActive(a);
      await Future.wait([
        JigsawStorage.save(a, photoA, 12),
        JigsawStorage.save(a, photoB, 12),
        JigsawStorage.library(),
        JigsawStorage.save(a, sunset, 12),
      ]);
      expect((await JigsawStorage.library()).length, 3);
      expect(b.completed, isFalse);
    });
  });

  testWidgets('메뉴에 내 퍼즐이 나오고 이어하기 카드도 보인다', (tester) async {
    tester.view.physicalSize = const Size(800, 1280);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final c = newController()
      ..placed[0] = true
      ..placed[1] = true
      ..placed[2] = true;
    SharedPreferences.setMockInitialValues({
      'jigsaw.library': jsonEncode([
        {
          'src': sunset.toJson(),
          'at': DateTime.now().millisecondsSinceEpoch,
          'target': 12,
          'state': jsonDecode(jsonEncode(c.toJson())),
          'wins': 0,
        },
        {
          'src': {'kind': 'file', 'ref': '/does/not/exist.jpg'},
          'at': DateTime.now().millisecondsSinceEpoch - 1000,
          'target': 24,
          'wins': 2,
        },
      ]),
    });
    final settings = await Settings.load();
    await tester.pumpWidget(SettingsScope(
      settings: settings,
      child: MaterialApp(theme: ThemeData(useMaterial3: true), home: const JigsawMenuScreen()),
    ));
    for (var i = 0; i < 15 && find.text('내 퍼즐').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('내 퍼즐'), findsOneWidget);
    expect(find.text('이어하기'), findsOneWidget); // 이어하던 판이 있는 가장 최근 퍼즐
    expect(find.text('진행 중 · 3/12'), findsOneWidget);
    expect(find.text('완성 2번 · 다시 도전'), findsOneWidget);
    expect(find.textContaining('내 사진 ·'), findsOneWidget);
    expect(find.text('갤러리에서 사진 고르기'), findsOneWidget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
