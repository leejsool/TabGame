import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/dotcannon/core/dot_levels.dart';
import 'package:tabgame/games/dotcannon/core/dot_rules.dart';
import 'package:tabgame/games/dotcannon/data/dot_storage.dart';
import 'package:tabgame/games/dotcannon/game/dot_controller.dart';
import 'package:tabgame/games/dotcannon/ui/dot_menu_screen.dart';
import 'package:tabgame/games/dotcannon/ui/dot_screen.dart';

import 'dot_screen_test.dart' show app, playToEnd;

void main() {
  test('입구가 막혀 있을 때 누르면 거절하지 않고, 입구가 비는 대로 저절로 올라간다', () {
    final c = DotController(level: dotLevels.first);
    final cols = [for (var i = 0; i < c.game.queue.length; i++) if (c.game.queue[i].isNotEmpty) i];
    expect(cols.length, greaterThanOrEqualTo(2));
    expect(c.deploy(cols[0]), isTrue);
    expect(c.game.belt.length, 1);
    // 첫 대포가 아직 입구에 있다: 두 번째는 기다린다
    expect(c.deploy(cols[1]), isTrue);
    expect(c.game.belt.length, 1);
    expect(c.pending, [cols[1]]);
    c.deploy(cols[1]); // (같은 줄을 또 눌러도 한 번만 기다린다)
    expect(c.pending, [cols[1]]);
    for (var i = 0; i < 20 && c.pending.isNotEmpty; i++) {
      c.advance(0.02);
    }
    expect(c.pending, isEmpty);
    expect(c.game.belt.length, 2);
    expect(c.game.deploys, 2);
    c.dispose();
  });

  test('벨트가 가득 찬 것은 기다리지 않고 거절한다', () {
    final c = DotController(level: dotLevels.first.copyWith(capacity: 1));
    final col = [for (var i = 0; i < c.game.queue.length; i++) if (c.game.queue[i].isNotEmpty) i].first;
    expect(c.deploy(col), isTrue);
    expect(c.deploy(col), isFalse);
    expect(c.pending, isEmpty);
    c.dispose();
  });

  testWidgets('대기 중인 대포를 꾹 누르면 그 색이 표시되고, 손을 떼면 풀린다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1280));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = DotController(level: dotLevels.first);
    await tester.pumpWidget(await app(DotScreen(controller: c)));
    await tester.pump(const Duration(milliseconds: 50));
    // 맨 앞이 아닌 대포도 된다
    final col = [for (var i = 0; i < c.game.queue.length; i++) if (c.game.queue[i].length >= 2) i].first;
    final color = c.game.queue[col][1].color;
    final g = await tester.startGesture(tester.getCenter(find.byKey(ValueKey('dot-hold-$col-1'))));
    await tester.pump(const Duration(milliseconds: 700));
    expect(c.highlight.value, color);
    await g.up();
    await tester.pump();
    expect(c.highlight.value, isNull);
    expect(c.game.deploys, 0, reason: '꾹 누르기는 대포를 올리지 않는다');
  });

  testWidgets('맨 앞 대포를 꾹 눌렀다 떼면 색만 보이고 벨트에 올라가지 않는다 (살짝 톡 누르면 올라간다)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1280));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final c = DotController(level: dotLevels.first);
    await tester.pumpWidget(await app(DotScreen(controller: c)));
    await tester.pump(const Duration(milliseconds: 50));
    final front = find.byKey(const ValueKey('dot-front-0'));
    final g = await tester.startGesture(tester.getCenter(front));
    await tester.pump(const Duration(milliseconds: 400)); // 0.4초: 꾹 누르기로 본다
    expect(c.highlight.value, isNotNull);
    await g.up();
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.highlight.value, isNull);
    expect(c.game.deploys, 0, reason: '색을 확인하려고 꾹 눌렀다 뗀 것은 올리지 않는다');
    await tester.tap(front); // 짧게 톡
    await tester.pump(const Duration(milliseconds: 50));
    expect(c.game.deploys, 1);
  });

  testWidgets('마지막 도트를 맞힌 순간 바로 기록되어, 완성 창이 뜨기 전에 나가도 깬 것으로 남는다', (tester) async {
    final c = DotController(level: dotLevels.first);
    await tester.pumpWidget(await app(DotScreen(controller: c)));
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 60000 && !c.game.won && !c.stalled; i++) {
      final col = botPick(c.game);
      if (col != null) c.deploy(col);
      c.advance(0.016);
    }
    expect(c.game.won, isTrue);
    expect(c.completed, isFalse, reason: '마지막 탄이 아직 날아가는 중');
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    final stats = await tester.runAsync(() => DotStorage.stats(dotLevels.first.id));
    expect(stats!.wins, 1);
    // 화면을 닫고(나가기) 남은 시간이 흘러도 두 번 기록되지 않는다
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    final after = await tester.runAsync(() => DotStorage.stats(dotLevels.first.id));
    expect(after!.wins, 1);
  });

  testWidgets('한 판을 깨고 "메뉴로"를 누르면 메뉴에서 그 그림이 깬 것으로 보인다', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1280));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(await app(const DotMenuScreen()));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('아직 못 깼어요'), findsWidgets);

    await tester.tap(find.byKey(ValueKey('dot-card-${dotLevels.first.id}')));
    for (var i = 0; i < 10 && find.byType(DotScreen).evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    final screen = tester.widget<DotScreen>(find.byType(DotScreen));
    playToEnd(screen.controller);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('그림 완성! 🎉'), findsOneWidget);

    await tester.tap(find.text('메뉴로'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(DotScreen), findsNothing);
    final card = find.byKey(ValueKey('dot-card-${dotLevels.first.id}'));
    expect(find.descendant(of: card, matching: find.text('아직 못 깼어요')), findsNothing, reason: '깬 그림이 못 깬 것으로 보인다');
    expect(find.descendant(of: card, matching: find.textContaining('최단')), findsOneWidget);
  });
}
