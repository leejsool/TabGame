import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabgame/core/game_save.dart';
import 'package:tabgame/core/settings.dart';
import 'package:tabgame/core/settings_scope.dart';
import 'package:tabgame/games/dotcannon/core/dot_levels.dart';
import 'package:tabgame/games/dotcannon/core/dot_rules.dart';
import 'package:tabgame/games/dotcannon/data/dot_custom_store.dart';
import 'package:tabgame/games/dotcannon/data/dot_storage.dart';
import 'package:tabgame/games/dotcannon/dotcannon_entry.dart';
import 'package:tabgame/games/dotcannon/game/dot_controller.dart';
import 'package:tabgame/games/dotcannon/ui/dot_create_screen.dart';
import 'package:tabgame/games/dotcannon/ui/dot_menu_screen.dart';
import 'package:tabgame/games/dotcannon/ui/dot_screen.dart';

Future<Widget> app(Widget home) async {
  SharedPreferences.setMockInitialValues({});
  final settings = await Settings.load();
  return SettingsScope(
    settings: settings,
    child: MaterialApp(home: home),
  );
}

/// 간단한 규칙([botPick])으로 대포를 올리며 끝까지 한다.
void playToEnd(DotController c) {
  for (var i = 0; i < 400000 && !c.completed && !c.stalled; i++) {
    // 올릴 수 있는 만큼 올린 뒤 벨트를 한 칸 돌린다 (botSolves와 같은 순서라서, 풀리는 판으로 정해 둔 그림이 그대로 풀린다)
    for (var col = botPick(c.game); col != null && c.deploy(col); col = botPick(c.game)) {}
    // (한 번에 한 칸만 돌아가게 짧게 흘려보낸다: 그래야 칸마다 올릴 대포를 살필 수 있다)
    c.advance(DotController.stepSeconds / 4);
  }
}

void main() {
  testWidgets('맨 앞 대포를 누르면 벨트에 오르고, 벨트 자리 표시가 바뀐다', (tester) async {
    final c = DotController(level: dotLevels.first);
    await tester.pumpWidget(await app(DotScreen(controller: c)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('0/5'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dot-front-0')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('1/5'), findsOneWidget);
    expect(c.game.belt.length, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('벨트가 시간에 따라 돌고, 배속 단추가 바뀐다', (tester) async {
    final c = DotController(level: dotLevels.first);
    await tester.pumpWidget(await app(DotScreen(controller: c)));
    c.deploy(0);
    final before = c.game.stepCount;
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 100)); // (한 프레임이 길어도 0.1초까지만 흘려보낸다)
    }
    expect(c.game.stepCount, greaterThan(before));
    expect(find.text('1배속'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dot-speed')));
    await tester.pump();
    expect(find.text('2배속'), findsOneWidget);
  });

  testWidgets('끝까지 하면 완성 창이 뜨고 기록이 남는다', (tester) async {
    final c = DotController(level: dotLevels.first);
    await tester.pumpWidget(await app(DotScreen(controller: c)));
    await tester.pump(const Duration(milliseconds: 50));
    playToEnd(c);
    expect(c.completed, isTrue);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('그림 완성! 🎉'), findsOneWidget);
    final stats = await tester.runAsync(() => DotStorage.stats(dotLevels.first.id));
    expect(stats!.wins, 1);
    expect(find.text('다음 그림'), findsOneWidget);
  });

  test('1배속은 예전 2배속 빠르기다 (벨트가 1초에 1/stepSeconds × 2 칸 돈다)', () {
    final c = DotController(level: dotLevels.first)..deploy(0);
    for (var i = 0; i < 14; i++) {
      c.advance(0.05); // 실제 0.7초
    }
    expect(c.game.stepCount, (0.7 * DotController.baseSpeed / DotController.stepSeconds).floor());
    c.dispose();
  });

  test('마지막 도트를 맞혀도 탄이 날아가 터지는 모습을 보여 준 뒤에 완성된다', () {
    final c = DotController(level: dotLevels.first);
    var won = 0;
    c.onWon = () => won++;
    for (var i = 0; i < 60000 && !c.game.won && !c.stalled; i++) {
      final col = botPick(c.game);
      if (col != null) c.deploy(col);
      c.advance(0.016);
    }
    expect(c.game.won, isTrue);
    expect(c.completed, isFalse, reason: '마지막 탄이 아직 날아가는 중');
    expect(won, 0);
    final hitAt = c.clock;
    for (var i = 0; i < 1000 && !c.completed; i++) {
      c.advance(0.016);
    }
    expect(won, 1);
    expect(c.clock - hitAt, greaterThanOrEqualTo(DotController.flightSeconds + DotController.popSeconds));
    c.dispose();
  });

  test('모든 내장 단계는 끝까지 할 수 있다', () {
    for (final l in dotLevels) {
      final c = DotController(level: l);
      playToEnd(c);
      expect(c.completed, isTrue, reason: l.name);
      c.dispose();
    }
  });

  testWidgets('막히면 안내 창이 뜨고 처음부터 다시 할 수 있다', (tester) async {
    // 벨트 자리를 1개로 줄인 판에서, 맞히지 못하는 대포로 자리를 채운다
    final level = dotLevels[2].copyWith(capacity: 1, seed: 1);
    final c = DotController(level: level);
    await tester.pumpWidget(await app(DotScreen(controller: c)));
    await tester.pump(const Duration(milliseconds: 50));
    final ex = c.game.exposedColors();
    final col = [
      for (var i = 0; i < c.game.queue.length; i++)
        if (c.game.queue[i].isNotEmpty && !ex.contains(c.game.queue[i].first.color)) i,
    ];
    if (col.isEmpty) return; // (이 배치는 맨 앞이 모두 맞힐 수 있는 색이다)
    c.deploy(col.first);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 2));
    expect(c.stalled, isTrue);
    expect(find.text('막혔어요'), findsOneWidget);
    await tester.tap(find.text('처음부터'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(c.stalled, isFalse);
    expect(c.untouched, isTrue);
  });

  test('진행 중인 판을 저장했다가 되살려도 그대로다 (내가 만든 그림 포함)', () {
    final custom = DotLevel(
      id: 'c:1',
      name: '시험',
      colors: const [Color(0xFFFF0000), Color(0xFF00FF00)],
      pixels: const [0, 0, 1, 1, 0, 0, 1, 1, 0],
      width: 3,
      height: 3,
      columns: 3,
      ammoLo: 2,
      ammoHi: 3,
      seed: 1,
      custom: true,
    );
    for (final level in [dotLevels[3], custom]) {
      final c = DotController(level: level)..deploy(0);
      c.advance(1.0);
      final back = DotController.fromJson(c.toJson());
      expect(back.game.toJson(), c.game.toJson());
      expect(back.level.id, level.id);
      expect(back.elapsed.value, c.elapsed.value);
    }
  });

  testWidgets('첫 화면: 기본 그림 카드와 사진으로 만들기 단추가 보인다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(await app(const DotMenuScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('dot-create')), findsOneWidget);
    expect(find.byKey(ValueKey('dot-card-${dotLevels.first.id}')), findsOneWidget);
    expect(find.text('1. 하트'), findsOneWidget);
    expect(find.byKey(const ValueKey('dot-resume')), findsNothing);
  });

  testWidgets('그림은 묶음마다 한 줄씩 보이고, 앞 그림을 안 깨도 아무 그림이나 바로 시작한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 3000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(await app(const DotMenuScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    for (final t in DotTheme.values) {
      expect(find.byKey(ValueKey('dot-theme-${t.name}')), findsOneWidget, reason: t.label);
      expect(find.byKey(ValueKey('dot-card-${dotLevelsByTheme[t]!.first.id}')), findsOneWidget, reason: t.label);
    }
    expect(find.text('1. ${dotLevelsByTheme[DotTheme.movie]!.first.name}'), findsOneWidget, reason: '번호는 줄마다 1부터');
    expect(find.byIcon(Icons.lock_rounded), findsNothing);
    // 깬 그림이 하나도 없어도 명화 줄의 첫 그림을 누르면 바로 시작한다
    final art = dotLevelsByTheme[DotTheme.art]!.first;
    await tester.tap(find.byKey(ValueKey('dot-card-${art.id}')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(DotScreen), findsOneWidget);
    expect(find.textContaining('깨야'), findsNothing);
  });

  testWidgets('처음에는 아직 못 깬 가장 앞 그림이 보이고, 왼쪽으로 밀면 깬 그림을 다시 고를 수 있다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final menu = await app(const DotMenuScreen());
    // 앞의 세 그림을 깬 상태: 도전할 그림은 넷째
    await tester.runAsync(() async {
      for (var i = 0; i < 3; i++) {
        await DotStorage.recordWin(dotLevels[i].id, seconds: 60, deploys: 8);
      }
    });
    await tester.pumpWidget(menu);
    await tester.pump(const Duration(milliseconds: 300));
    final target = find.byKey(ValueKey('dot-card-${dotLevels[3].id}'));
    expect(target, findsOneWidget);
    expect(find.text('4. ${dotLevels[3].name}'), findsOneWidget);
    // 첫 그림은 화면 밖 왼쪽에 있다
    final first = find.byKey(ValueKey('dot-card-${dotLevels.first.id}'));
    final list = find.byKey(const ValueKey('dot-stage-list'));
    expect(first, findsNothing);
    // 왼쪽으로 밀면(= 손가락을 오른쪽으로 끌면) 앞 그림이 보인다
    await tester.drag(list, const Offset(700, 0));
    await tester.pump(const Duration(milliseconds: 500));
    expect(first, findsOneWidget);
    expect(tester.getTopLeft(first).dx, greaterThanOrEqualTo(0));
  });

  testWidgets('이어하던 판이 있으면 첫 화면에 이어하기가 뜬다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = DotController(level: dotLevels.first)..deploy(0);
    final widget = await app(const DotMenuScreen());
    await tester.runAsync(() => GameSave.write(dotGameId, c.toJson()));
    await tester.pumpWidget(widget);
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byKey(const ValueKey('dot-resume')), findsOneWidget);
    expect(find.textContaining('하트'), findsWidgets);
  });

  testWidgets('기록을 저장하는 중간에 읽어 클리어는 있는데 최단 시간이 없어도 그림 카드가 깨지지 않는다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 860));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final level = dotLevels.first;
    for (final stats in [null, const DotStageStats(), const DotStageStats(wins: 1), const DotStageStats(wins: 1, bestSeconds: 75, bestDeploys: 9)]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: SingleChildScrollView(child: Wrap(children: [SizedBox(width: 170, child: DotLevelCard(level: level, stats: stats, onTap: () {}))]))),
      ));
      expect(tester.takeException(), isNull, reason: '기록 ${stats?.wins}/${stats?.bestSeconds}');
      expect(find.byType(ErrorWidget), findsNothing);
    }
  });

  testWidgets('사진으로 만들기: 도트로 바꾸고 난이도를 매긴 뒤 저장해서 시작한다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    // 빨강·초록·파랑·노랑이 띠로 나뉜 시험 사진 (PNG)
    final bytes = await tester.runAsync(() async {
      final rec = ui.PictureRecorder();
      final canvas = Canvas(rec);
      final colors = [Colors.red, Colors.green, Colors.blue, Colors.yellow];
      for (var i = 0; i < 4; i++) {
        canvas.drawRect(Rect.fromLTWH(i * 50.0, 0, 50, 120), Paint()..color = colors[i]);
      }
      canvas.drawCircle(const Offset(100, 60), 30, Paint()..color = Colors.white);
      final img = await rec.endRecording().toImage(200, 120);
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    await tester.pumpWidget(await app(DotCreateScreen(bytes: bytes!)));
    // 사진 읽기·변환·난이도 재기는 실제 비동기라서 실제 시간을 흘려보낸다
    for (var i = 0; i < 80; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
      if (find.byKey(const ValueKey('dot-assessment')).evaluate().isNotEmpty) break;
    }
    expect(find.byKey(const ValueKey('dot-preview')), findsOneWidget);
    expect(find.byKey(const ValueKey('dot-assessment')), findsOneWidget);
    final start = find.byKey(const ValueKey('dot-start-custom'));
    await tester.ensureVisible(start);
    await tester.tap(start);
    await tester.pump();
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pump(const Duration(milliseconds: 500));
    // 게임 화면으로 바뀌었고, 만든 그림이 보관됐다
    expect(find.byType(DotScreen), findsOneWidget);
    final saved = await tester.runAsync(DotCustomStore.loadAll);
    expect(saved!.length, 1);
    expect(saved.first.custom, isTrue);
    expect(saved.first.id.startsWith('c:'), isTrue);
    expect(saved.first.colorCount, greaterThanOrEqualTo(3));
  });
}
