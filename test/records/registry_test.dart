import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_registry.dart';
import 'package:tabgame/games/rhythm/data/rhythm_storage.dart';
import 'package:tabgame/records/records_screen.dart';

import 'records_test.dart' show appWith, settle;

void main() {
  group('게임 등록', () {
    test('게임 id는 겹치지 않는다', () {
      final ids = [for (final g in allGames) g.id];
      expect(ids.toSet().length, ids.length);
    });

    test('게임 안에서 openRecords로 여는 id는 모두 기록 보드가 있는 게임이다', () {
      final boards = {for (final g in allGames) if (g.hasRecords) g.id};
      final re = RegExp(r"openRecords\([^)]*game:\s*'([^']+)'");
      final used = <String, String>{};
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        for (final m in re.allMatches(f.readAsStringSync())) {
          used[m.group(1)!] = f.path;
        }
      }
      expect(used, isNotEmpty);
      used.forEach((id, file) => expect(boards, contains(id), reason: "$file: '$id'에 기록 보드가 없어요"));
    });

    test('준비된 게임은 모두 기록 보드를 가진다 (기록을 남기지 않는 게임이면 이 검사에서 뺀다)', () {
      for (final g in allGames.where((g) => g.isReady)) {
        expect(g.hasRecords, isTrue, reason: '${g.title}(${g.id})에 recordsTab이 없어요');
      }
    });

    testWidgets('기록 보드가 있는 모든 게임이 기록 화면에서 열린다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      for (final g in allGames.where((g) => g.hasRecords)) {
        SharedPreferences.setMockInitialValues({});
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(await appWith(RecordsScreen(initialGame: g.id)));
        await settle(tester, rounds: 3);
        expect(find.text(g.recordsTitle ?? g.title), findsWidgets, reason: g.id);
        expect(tester.takeException(), isNull, reason: g.id);
      }
    });
  });

  group('리듬 검사단 기록 보드', () {
    testWidgets('코스마다 한 장씩, 안 한 코스는 안내하고 한 코스는 별·점수를 보여 준다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await RhythmStorage.record(const RhythmResult(stars: 2, accuracy: 0.87, score: 4321, maxCombo: 30), 0);
      await RhythmStorage.record(const RhythmResult(stars: 3, accuracy: 0.95, score: 5000, maxCombo: 40), 1);
      await tester.pumpWidget(await appWith(const RecordsScreen(initialGame: 'rhythm_swords')));
      await settle(tester, rounds: 6);
      expect(find.text('훈련소 입소'), findsOneWidget);
      expect(find.text('거대 슬라임'), findsOneWidget);
      expect(find.textContaining('최고 4321점 · 정확도 87% · 1회 수료'), findsOneWidget);
      expect(find.textContaining('최고 5000점 · 정확도 95% · 1회 수료'), findsOneWidget);
      expect(find.text('아직 수료하지 않았어요'), findsNWidgets(4));
      expect(find.text('별 5 / 18개'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('기록이 하나도 없어도 모든 코스가 보인다', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(await appWith(const RecordsScreen(initialGame: 'rhythm_swords')));
      await settle(tester, rounds: 6);
      expect(find.text('아직 수료하지 않았어요'), findsNWidgets(6));
      expect(tester.takeException(), isNull);
    });
  });
}
