import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/getcolor/core/getcolor_rules.dart';
import 'package:tabgame/games/getcolor/data/getcolor_storage.dart';
import 'package:tabgame/games/getcolor/game/getcolor_controller.dart';
import 'package:tabgame/games/getcolor/ui/getcolor_board.dart';
import 'package:tabgame/games/getcolor/ui/getcolor_menu_screen.dart';
import 'package:tabgame/games/getcolor/ui/getcolor_records_tab.dart';
import 'package:tabgame/games/getcolor/ui/getcolor_screen.dart';

WaterState s(List<List<int>> b) => WaterState([for (final x in b) List<int>.of(x)]);

GetColorController make(List<List<int>> b, {GcLevel level = GcLevel.easy}) =>
    GetColorController(level: level, initial: s(b));

/// 쉽게 풀리는 작은 판: 두 병을 합치면 끝난다.
List<List<int>> tiny() => [
      [0, 0, 1, 1],
      [1, 1, 0, 0],
      [],
    ];

Future<Widget> appWith(Widget home) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  return SettingsScope(
    settings: settings,
    child: MaterialApp(theme: ThemeData(useMaterial3: true), home: home),
  );
}

Future<void> settle(WidgetTester tester, {int rounds = 8}) async {
  for (var i = 0; i < rounds; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('컨트롤러', () {
    test('병을 누르면 고르고, 다시 누르면 풀리고, 빈 병/끝난 병은 고르지 못한다', () {
      final c = make([
        [0, 1, 0, 1],
        [1, 0, 1, 0],
        [2, 2, 2, 2],
        [],
      ]);
      c.tapBottle(3); // 빈 병
      expect(c.selected, isNull);
      c.tapBottle(2); // 끝난 병
      expect(c.selected, isNull);
      c.tapBottle(0);
      expect(c.selected, 0);
      c.tapBottle(0);
      expect(c.selected, isNull);
    });

    test('고른 병에서 다른 병으로 붓는다 (붓기 횟수와 상태가 바뀐다)', () {
      final c = make(tiny());
      c.tapBottle(0);
      c.tapBottle(2);
      expect(c.state.bottles[0], [0, 0]);
      expect(c.state.bottles[2], [1, 1]);
      expect(c.moveCount, 1);
      expect(c.selected, isNull);
      expect(c.lastPour!.count, 2);
      expect(c.lastPour!.color, 1);
    });

    test('부을 수 없는 병을 누르면 그 병으로 고른 병이 바뀐다', () {
      final c = make([
        [0, 1],
        [1, 0],
        [2],
        [],
      ]);
      c.tapBottle(0); // 맨 위 1
      c.tapBottle(2); // 2 위에는 1을 못 붓는다 → 선택이 2로 바뀜
      expect(c.selected, 2);
      expect(c.moveCount, 0);
      c.tapBottle(3); // 빈 병 → 2의 물을 부을 수 있다
      expect(c.moveCount, 1);
    });

    test('모두 모으면 완성되고 onWon 이 한 번 불린다', () {
      final c = make(tiny());
      var wins = 0;
      c.onWon = () => wins++;
      c.tapBottle(0);
      c.tapBottle(2); // [0,0] / [1,1,0,0] / [1,1]
      c.tapBottle(1);
      c.tapBottle(0); // 1 의 맨 위 0,0 → 0번 병
      expect(c.state.bottles[0], [0, 0, 0, 0]);
      expect(c.completed, isFalse);
      c.tapBottle(1);
      c.tapBottle(2);
      expect(c.completed, isTrue);
      expect(wins, 1);
      c.tapBottle(0); // 끝난 뒤에는 아무것도 하지 않는다
      expect(c.selected, isNull);
    });

    test('되돌리기와 처음부터', () {
      final c = make(tiny());
      c.pourTo(0, 2);
      c.pourTo(1, 0);
      expect(c.moveCount, 2);
      c.undo();
      expect(c.moveCount, 1);
      expect(c.state.bottles[0], [0, 0]);
      c.restart();
      expect(c.moveCount, 0);
      expect(c.state.bottles, s(tiny()).bottles);
      expect(c.untouched, isTrue);
    });

    test('병 더하기는 한 판에 한 번이고, 되돌리면 다시 쓸 수 있다', () {
      final c = make(tiny());
      expect(c.canAddBottle, isTrue);
      c.addBottle();
      expect(c.state.count, 4);
      expect(c.canAddBottle, isFalse);
      expect(c.extraUsed, isTrue);
      expect(c.moveCount, 0); // 붓기가 아니라서 세지 않는다
      c.addBottle();
      expect(c.state.count, 4);
      c.undo();
      expect(c.state.count, 3);
      expect(c.canAddBottle, isTrue);
    });

    test('저장했다가 불러오면 같은 판·같은 진행이다 (병 더하기 포함)', () {
      final c = make(tiny());
      c.pourTo(0, 2);
      c.addBottle();
      c.pourTo(1, 3);
      c.elapsed.value = 77;
      final back = GetColorController.fromJson(c.toJson());
      expect(back.state.bottles, c.state.bottles);
      expect(back.initial.bottles, c.initial.bottles);
      expect(back.moveCount, 2);
      expect(back.extraUsed, isTrue);
      expect(back.elapsed.value, 77);
      back.undo();
      back.undo();
      back.undo();
      expect(back.state.bottles, s(tiny()).bottles);
    });

    test('깨진 저장은 거기까지만 복원한다', () {
      final c = make(tiny());
      final j = c.toJson();
      j['moves'] = [GcMove(2, 0).code, GcMove(0, 2).code]; // 첫 수부터 불가능(빈 병에서 붓기)
      final back = GetColorController.fromJson(j);
      expect(back.moveCount, 0);
      expect(back.state.bottles, s(tiny()).bottles);
    });

    test('새 판은 풀 수 있는 판이다', () async {
      for (final level in GcLevel.values) {
        final c = await GetColorController.create(level, rng: Random(4));
        expect(c.state.count, level.bottles);
        expect(c.completed, isFalse);
        c.dispose();
      }
    });

    test('더 부을 곳이 없으면 막혔다고 알 수 있다', () {
      final c = make([
        [0, 1, 0, 1],
        [1, 0, 1, 0],
      ]);
      expect(c.noMoves, isTrue);
      c.addBottle();
      expect(c.noMoves, isFalse);
    });
  });

  group('힌트', () {
    test('풀 수 있는 판이면 합법적인 한 수를 가리키고, 따라 하면 계속 풀린다', () async {
      final c = await GetColorController.create(GcLevel.normal, rng: Random(8));
      var guard = 0;
      while (!c.completed && guard++ < 80) {
        await c.requestHint();
        final h = c.hint;
        expect(h, isNotNull, reason: '${c.hintMessage}');
        expect(c.state.canPour(h!.from, h.to), isTrue);
        expect(c.hintMessage, contains('풀 수 있어요'));
        expect(c.pourTo(h.from, h.to), isTrue);
        expect(c.hint, isNull); // 한 수 두면 힌트는 사라진다
      }
      expect(c.completed, isTrue);
      c.dispose();
    });

    test('이미 막힌 판이면 막혔다고 알려 준다 (병 더하기로 풀리면 그것도)', () async {
      final c = make([
        [0, 1, 0, 1],
        [1, 0, 1, 0],
      ]);
      await c.requestHint();
      expect(c.hint, isNull);
      expect(c.hintMessage, contains('이미 막혔어요'));
      expect(c.hintMessage, contains('병 더하기'));
      expect(c.hintThinking, isFalse);

      // 병 더하기를 이미 썼는데도 막힌 판
      c.addBottle();
      c.pourTo(0, 2);
      c.pourTo(0, 2);
      c.dismissHint();
      expect(c.hintMessage, isNull);
    });

    test('힌트를 기다리는 사이 수를 두거나 닫으면 낡은 답은 버린다', () async {
      final c = await GetColorController.create(GcLevel.hard, rng: Random(2));
      final pending = c.requestHint();
      expect(c.hintThinking, isTrue);
      final m = c.state.legalMoves().first;
      c.pourTo(m.from, m.to);
      await pending;
      expect(c.hint, isNull);
      expect(c.hintThinking, isFalse);

      final pending2 = c.requestHint();
      c.dismissHint();
      await pending2;
      expect(c.hint, isNull);
      expect(c.hintMessage, isNull);
      c.dispose();
    });
  });

  group('저장·기록', () {
    test('이어하던 판 저장/불러오기/지우기', () async {
      final c = make(tiny());
      GetColorStorage.setActive(c);
      await GetColorStorage.save(c);
      expect(await GetColorStorage.loadSaved(), isNull); // 아직 안 건드렸으면 저장하지 않는다
      c.pourTo(0, 2);
      await GetColorStorage.save(c);
      final saved = await GetColorStorage.loadSaved();
      expect(saved, isNotNull);
      expect(GetColorController.fromJson(saved!).moveCount, 1);
      await GetColorStorage.clearSave(c);
      expect(await GetColorStorage.loadSaved(), isNull);
    });

    test('다른 판이 지금 하는 판이면 늦은 저장이 덮어쓰지 않는다', () async {
      final a = make(tiny());
      final b = make(tiny());
      GetColorStorage.setActive(b);
      a.pourTo(0, 2);
      await GetColorStorage.save(a);
      expect(await GetColorStorage.loadSaved(), isNull);
    });

    test('클리어 기록: 최고 시간·최소 붓기를 따로 센다', () async {
      var b = await GetColorStorage.recordWin(
          const GetColorRecord(at: 1, level: GcLevel.easy, seconds: 100, moves: 20));
      expect(b.time && b.moves, isTrue);
      b = await GetColorStorage.recordWin(
          const GetColorRecord(at: 2, level: GcLevel.easy, seconds: 90, moves: 25));
      expect(b.time, isTrue);
      expect(b.moves, isFalse);
      b = await GetColorStorage.recordWin(
          const GetColorRecord(at: 3, level: GcLevel.easy, seconds: 95, moves: 15));
      expect(b.time, isFalse);
      expect(b.moves, isTrue);
      final st = await GetColorStorage.stats(GcLevel.easy);
      expect(st.wins, 3);
      expect(st.bestSeconds, 90);
      expect(st.bestMoves, 15);
      expect((await GetColorStorage.loadHistory()).first.at, 3);
      expect((await GetColorStorage.stats(GcLevel.hard)).wins, 0);
    });
  });

  group('포기', () {
    test('한 수도 두지 않았으면 포기할 수 없고, 둔 뒤에는 포기하면 더 손댈 수 없다', () {
      final c = make(tiny());
      expect(c.giveUp(), isFalse);
      expect(c.gaveUp, isFalse);
      c.pourTo(0, 2);
      expect(c.giveUp(), isTrue);
      expect(c.gaveUp, isTrue);
      expect(c.canAct, isFalse);
      expect(c.canUndo, isFalse);
      expect(c.canAddBottle, isFalse);
      final before = c.elapsed.value;
      c.tick();
      expect(c.elapsed.value, before);
      expect(c.pourTo(1, 2), isFalse);
      expect(c.giveUp(), isFalse);
      c.restart();
      expect(c.gaveUp, isFalse);
      expect(c.canAct, isTrue);
    });

    test('포기 기록: 같은 판은 하나만 남고, 최고 기록·클리어 횟수에는 들어가지 않는다', () async {
      final init = [
        [0, 0, 1, 1],
        [1, 1, 0, 0],
        <int>[],
      ];
      GetColorRecord gave(int at, List<List<int>> i) =>
          GetColorRecord(at: at, level: GcLevel.easy, seconds: 30, moves: 3, gaveUp: true, initial: i);
      await GetColorStorage.recordGiveUp(gave(1, init));
      await GetColorStorage.recordGiveUp(gave(2, [
        [1, 1, 0, 0],
        <int>[],
        [0, 0, 1, 1],
      ])); // 병 순서만 다른 같은 판
      await GetColorStorage.recordGiveUp(gave(3, [
        [0, 1, 0, 1],
        [1, 0, 1, 0],
        <int>[],
      ]));
      var h = await GetColorStorage.loadHistory();
      expect(h.map((e) => e.at), [3, 2]);
      expect(h.every((e) => e.gaveUp && e.initial != null), isTrue);
      var st = await GetColorStorage.stats(GcLevel.easy);
      expect(st.gaveUps, 3);
      expect(st.wins, 0);
      expect(st.bestSeconds, isNull);

      // 포기했던 판을 클리어하면 "포기한 판"에서 빠진다
      await GetColorStorage.recordWin(
          GetColorRecord(at: 4, level: GcLevel.easy, seconds: 50, moves: 4, initial: init));
      h = await GetColorStorage.loadHistory();
      expect(h.map((e) => e.at), [4, 3]);
      expect(h.first.gaveUp, isFalse);
      expect(h.first.initial, isNull); // 클리어 기록에는 판을 저장하지 않는다 (JSON 으로)
      st = await GetColorStorage.stats(GcLevel.easy);
      expect(st.wins, 1);
      expect(st.bestSeconds, 50);
    });

    testWidgets('화면 메뉴 → 포기하기: 확인하면 기록에 남고, 기록 탭에서 다시 도전하면 같은 판이다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = make(tiny());
      await tester.pumpWidget(await appWith(GetColorScreen(controller: c)));
      await settle(tester, rounds: 3);

      // 아직 한 수도 안 뒀으면 메뉴의 포기하기는 눌러도 아무 일이 없다
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('포기하기'), warnIfMissed: false); // 비활성
      await tester.pumpAndSettle();
      expect(find.text('이 판을 포기할까요?'), findsNothing);
      await tester.tapAt(const Offset(10, 700)); // 메뉴 닫기
      await tester.pumpAndSettle();

      c.pourTo(0, 2);
      await tester.pump();
      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('포기하기'));
      await tester.pumpAndSettle();
      expect(find.text('이 판을 포기할까요?'), findsOneWidget);
      await tester.tap(find.text('계속하기'));
      await tester.pumpAndSettle();
      expect(c.gaveUp, isFalse);

      await tester.tap(find.byIcon(Icons.more_vert_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.text('포기하기'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, '포기'));
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pumpAndSettle();
      expect(c.gaveUp, isTrue);
      expect(find.text('포기했어요'), findsOneWidget);

      final h = await tester.runAsync(GetColorStorage.loadHistory);
      expect(h!.length, 1);
      expect(h.first.gaveUp, isTrue);
      expect(WaterState(h.first.initial!).key, c.initial.key);
    });

    testWidgets('기록 탭: 포기한 판 목록에 다시 도전 단추가 있고, 누르면 같은 판이 열린다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final rec = GetColorRecord(
        at: 1760000000000,
        level: GcLevel.easy,
        seconds: 75,
        moves: 5,
        gaveUp: true,
        initial: tiny(),
      );
      SharedPreferences.setMockInitialValues({'getcolor.history': jsonEncode([rec.toJson()]), 'getcolor.giveups0': 1});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: const MaterialApp(home: Scaffold(body: GetColorRecordsTab())),
      ));
      await settle(tester, rounds: 4);
      expect(find.text('포기한 판'), findsOneWidget);
      expect(find.text('포기'), findsOneWidget);
      expect(find.textContaining('포기 1'), findsOneWidget);
      expect(find.textContaining('아직 클리어한 판이 없어요.'), findsOneWidget);

      await tester.tap(find.text('다시 도전'));
      await settle(tester, rounds: 6);
      final screen = tester.widget<GetColorScreen>(find.byType(GetColorScreen));
      expect(screen.controller.initial.key, WaterState(tiny()).key);
      expect(screen.controller.gaveUp, isFalse);
      expect(tester.takeException(), isNull);
    });
  });

  group('매우 어려움 (컨트롤러)', () {
    test('병이 15개라 병 더하기를 쓸 수 없고, 이어하기 저장·복원이 된다', () async {
      final c = await GetColorController.create(GcLevel.veryHard, rng: Random(4));
      expect(c.state.count, 15);
      expect(c.canAddBottle, isFalse);
      c.addBottle();
      expect(c.state.count, 15);
      final back = GetColorController.fromJson(c.toJson());
      expect(back.level, GcLevel.veryHard);
      expect(back.state.count, 15);
      back.dispose();
      c.dispose();
    });
  });

  group('병 고르기 / 터치 판정', () {
    test('selectBottle: 누르자마자 고르고, 빈 병·끝난 병은 못 고르고, clearSelection으로 내려놓는다', () {
      final c = make([
        [0, 1, 0, 1],
        [1, 0, 1, 0],
        [2, 2, 2, 2],
        [],
      ]);
      expect(c.selectBottle(3), isFalse);
      expect(c.selectBottle(2), isFalse);
      expect(c.selectBottle(0), isTrue);
      expect(c.selected, 0);
      expect(c.selectBottle(0), isTrue); // 이미 골랐으면 그대로
      expect(c.selectBottle(1), isTrue); // 다른 병으로 옮겨 고름 (끌기 시작)
      expect(c.selected, 1);
      c.clearSelection();
      expect(c.selected, isNull);
      c.setPaused(true);
      expect(c.selectBottle(0), isFalse, reason: '일시정지 중에는 못 고른다');
    });

    test('GcLayout.hit: 병 위·틈·위아래 빈 곳은 가까운 병으로, 멀리 떨어진 곳은 null', () {
      for (final size in const [Size(360, 520), Size(800, 1000), Size(1280, 620)]) {
        final l = GcLayout.compute(size, 8);
        for (var i = 0; i < 8; i++) {
          final r = l.rects[i];
          expect(l.hit(r.center), i, reason: '$size 병 $i 가운데');
          // 병 바로 위(들어 올린 높이)와 병 옆 틈의 가운데를 눌러도 같은 줄에서 가장 가까운 병
          expect(l.hit(Offset(r.center.dx, r.top - l.w * 0.3)), i, reason: '$size 병 $i 위쪽');
          expect(l.hit(Offset(r.right + l.w * GcLayout.gapRatio * 0.3, r.center.dy)), i, reason: '$size 병 $i 오른쪽 틈');
        }
        expect(l.hit(const Offset(-500, -500)), isNull);
      }
    });
  });

  group('화면', () {
    test('배치: 병이 모두 영역 안에 들어가고 서로 겹치지 않는다', () {
      for (final size in const [Size(360, 520), Size(800, 1000), Size(1280, 620), Size(533, 333)]) {
        for (final n in [6, 8, 10, 14]) {
          final l = GcLayout.compute(size, n);
          expect(l.rects.length, n);
          for (var i = 0; i < n; i++) {
            final r = l.rects[i];
            expect(r.left, greaterThanOrEqualTo(-0.01), reason: '$size $n #$i');
            expect(r.right, lessThanOrEqualTo(size.width + 0.01), reason: '$size $n #$i');
            expect(r.top, greaterThanOrEqualTo(-0.01), reason: '$size $n #$i');
            expect(r.bottom, lessThanOrEqualTo(size.height + 0.01), reason: '$size $n #$i');
            for (var j = i + 1; j < n; j++) {
              expect(r.overlaps(l.rects[j]), isFalse, reason: '$size $n $i/$j');
            }
          }
        }
      }
    });

    testWidgets('병을 눌러 붓고, 붓는 애니메이션 중에도 바로 다음 병을 고를 수 있다', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = make(tiny());
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: GetColorBoard(controller: c))));
      final origin = tester.getTopLeft(find.byType(GetColorBoard));
      final size = tester.getSize(find.byType(GetColorBoard));
      final layout = GcLayout.compute(size, c.state.count);

      await tester.tapAt(origin + layout.rects[0].center);
      await tester.pump(const Duration(milliseconds: 200));
      expect(c.selected, 0);
      await tester.tapAt(origin + layout.rects[2].center);
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.moveCount, 1);
      // 붓는 중에도 입력이 씹히지 않는다: 바로 다음 병을 고를 수 있다
      await tester.tapAt(origin + layout.rects[1].center);
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.selected, 1);
      // 애니메이션 중간 프레임들이 오류 없이 그려진다
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 80));
      }
      expect(tester.takeException(), isNull);
      await tester.tapAt(origin + layout.rects[1].center);
      await tester.pump(const Duration(milliseconds: 100));
      expect(c.selected, isNull, reason: '같은 병을 다시 누르면 내려놓는다');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });

    testWidgets('누르는 순간 바로 들어 올린다 (손을 떼기 전에), 손가락이 조금 움직여도 탭이 씹히지 않는다', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = make(tiny());
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: GetColorBoard(controller: c))));
      final origin = tester.getTopLeft(find.byType(GetColorBoard));
      final layout = GcLayout.compute(tester.getSize(find.byType(GetColorBoard)), c.state.count);

      final g = await tester.startGesture(origin + layout.rects[0].center);
      expect(c.selected, 0, reason: '손을 떼기 전에 이미 골라진다');
      // 탭 인식기라면 취소됐을 만큼(20px 가까이) 흔들려도 그대로 골라진 채 유지
      await g.moveBy(const Offset(6, 5));
      await g.moveBy(const Offset(-3, 4));
      await g.up();
      await tester.pump();
      expect(c.selected, 0);
      // 병 사이 틈/위쪽 빈 곳을 눌러도 가까운 병을 잡아 준다
      final r2 = layout.rects[2];
      await tester.tapAt(origin + Offset(r2.center.dx, r2.top - layout.w * 0.3));
      await tester.pump(const Duration(milliseconds: 50));
      expect(c.moveCount, 1);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });

    testWidgets('끌어서 붓기: 끄는 동안 병이 골라져 있고, 부을 수 있는 병 위에서 놓으면 붓는다', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = make(tiny());
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: GetColorBoard(controller: c))));
      final origin = tester.getTopLeft(find.byType(GetColorBoard));
      final layout = GcLayout.compute(tester.getSize(find.byType(GetColorBoard)), c.state.count);

      final g = await tester.startGesture(origin + layout.rects[0].center);
      await g.moveTo(origin + layout.rects[1].center); // 병 1 위로 끌고 가는 중 (병 1에는 부을 수 없다: 색이 다름)
      await tester.pump();
      expect(c.selected, 0);
      expect(c.moveCount, 0);
      await g.moveTo(origin + layout.rects[2].center); // 빈 병 위
      await tester.pump();
      expect(c.moveCount, 0, reason: '놓기 전에는 붓지 않는다');
      await g.up();
      await tester.pump(const Duration(milliseconds: 50));
      expect(c.moveCount, 1);
      expect(c.state.bottles[2], [1, 1]);
      expect(c.selected, isNull);
      for (var i = 0; i < 14; i++) {
        await tester.pump(const Duration(milliseconds: 80));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });

    testWidgets('끌다가 부을 수 없는 곳이나 빈 곳에 놓으면 아무 일 없이 내려놓는다', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = make(tiny());
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: GetColorBoard(controller: c))));
      final origin = tester.getTopLeft(find.byType(GetColorBoard));
      final layout = GcLayout.compute(tester.getSize(find.byType(GetColorBoard)), c.state.count);

      // 색이 다른 병 위에 놓기
      var g = await tester.startGesture(origin + layout.rects[0].center);
      await g.moveTo(origin + layout.rects[1].center);
      await g.up();
      await tester.pump(const Duration(milliseconds: 50));
      expect(c.moveCount, 0);
      expect(c.selected, isNull);
      // 판 밖 빈 곳에 놓기
      g = await tester.startGesture(origin + layout.rects[0].center);
      await g.moveTo(origin + const Offset(2, 2));
      await g.up();
      await tester.pump(const Duration(milliseconds: 50));
      expect(c.moveCount, 0);
      expect(c.selected, isNull);
      // 끌다가 취소(포인터 취소)되어도 들린 병이 남지 않는다
      g = await tester.startGesture(origin + layout.rects[0].center);
      await g.moveTo(origin + layout.rects[2].center);
      await g.cancel();
      await tester.pump(const Duration(milliseconds: 50));
      expect(c.selected, isNull);
      expect(c.moveCount, 0);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });

    testWidgets('이미 병을 골라 둔 뒤에도 다른 병에서 끌기를 시작하면 그 병으로 옮겨 붓는다', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = make(tiny());
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: GetColorBoard(controller: c))));
      final origin = tester.getTopLeft(find.byType(GetColorBoard));
      final layout = GcLayout.compute(tester.getSize(find.byType(GetColorBoard)), c.state.count);

      await tester.tapAt(origin + layout.rects[0].center);
      await tester.pump(const Duration(milliseconds: 50));
      expect(c.selected, 0);
      final g = await tester.startGesture(origin + layout.rects[1].center);
      await g.moveTo(origin + layout.rects[2].center);
      await g.up();
      await tester.pump(const Duration(milliseconds: 50));
      expect(c.moveCount, 1);
      expect(c.state.bottles[2], [0, 0], reason: '병 1의 위쪽 색(0)이 빈 병으로 옮겨졌다');
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });

    testWidgets('끝까지 풀면 완성 연출이 돌아가고 오류가 없다', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = make(tiny());
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: GetColorBoard(controller: c))));
      for (final m in const [GcMove(0, 2), GcMove(1, 0), GcMove(1, 2)]) {
        c.pourTo(m.from, m.to);
        await tester.pump();
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 80));
        }
      }
      expect(c.completed, isTrue);
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      c.dispose();
    });

    const sizes = {
      '폰 세로': Size(360, 740),
      '태블릿 세로': Size(800, 1280),
      '태블릿 가로': Size(1280, 800),
      '작은 가로': Size(800, 420),
    };
    sizes.forEach((name, size) {
      testWidgets('$name: 모든 난이도 화면이 넘침 없이 그려진다 (힌트·일시정지 포함)', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        for (final level in GcLevel.values) {
          final c = await tester.runAsync(() => GetColorController.create(level, rng: Random(6)));
          await tester.pumpWidget(await appWith(GetColorScreen(controller: c!)));
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$name ${level.label}');
          expect(find.text('겟 컬러'), findsOneWidget);

          await tester.runAsync(() => c.requestHint());
          await tester.pump(const Duration(milliseconds: 300));
          expect(find.textContaining('풀 수 있어요'), findsOneWidget);
          c.setPaused(true);
          await tester.pump();
          expect(find.text('일시정지'), findsWidgets);
          c.setPaused(false);
          await tester.pump();
          expect(tester.takeException(), isNull, reason: '$name ${level.label}');
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 50));
        }
      });
    });

    testWidgets('메뉴 → 난이도 선택 → 플레이 화면, 하단 버튼이 동작한다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(await appWith(const GetColorMenuScreen()));
      await settle(tester, rounds: 4);
      expect(find.text('쉬움'), findsOneWidget);
      expect(find.text('달인'), findsOneWidget);
      expect(find.text('아직 클리어한 적이 없어요'), findsNWidgets(GcLevel.values.length));

      await tester.tap(find.text('쉬움'));
      await settle(tester, rounds: 8);
      expect(find.byType(GetColorScreen), findsOneWidget);
      expect(find.byKey(const ValueKey('gc-moves')), findsOneWidget);
      expect(find.text('되돌리기'), findsOneWidget);

      // 병 더하기: 한 번 쓰면 버튼이 사용함으로 바뀐다
      await tester.tap(find.text('병 더하기'));
      await tester.pump();
      expect(find.text('병 더하기 (사용함)'), findsOneWidget);
      await tester.tap(find.text('되돌리기'));
      await tester.pump();
      expect(find.text('병 더하기'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('이어하던 판이 있으면 메뉴에 이어하기가 나온다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final c = make(tiny(), level: GcLevel.normal);
      c.pourTo(0, 2);
      c.elapsed.value = 65;
      SharedPreferences.setMockInitialValues({'getcolor.save': jsonEncode(c.toJson())});
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: const MaterialApp(home: GetColorMenuScreen()),
      ));
      await settle(tester, rounds: 4);
      expect(find.text('이어하기'), findsOneWidget);
      expect(find.textContaining('보통 · 완성한 병'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('기록 탭: 비어 있을 때 안내, 기록이 있으면 목록이 보인다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(await appWith(const Scaffold(body: GetColorRecordsTab())));
      await settle(tester, rounds: 4);
      expect(find.textContaining('아직 클리어한 판이 없어요.'), findsOneWidget);

      const rec = GetColorRecord(at: 1760000000000, level: GcLevel.hard, seconds: 83, moves: 31);
      SharedPreferences.setMockInitialValues({
        'getcolor.history': jsonEncode([rec.toJson()]),
        'getcolor.wins2': 1,
        'getcolor.best2': 83,
        'getcolor.bestMoves2': 31,
      });
      final settings = await Settings.load();
      await tester.pumpWidget(SettingsScope(
        settings: settings,
        child: MaterialApp(home: Scaffold(body: GetColorRecordsTab(key: UniqueKey()))),
      ));
      await settle(tester, rounds: 4);
      expect(find.textContaining('어려움 · 01:23'), findsOneWidget);
      expect(find.textContaining('31번 부음'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
