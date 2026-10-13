import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/core/game_registry.dart';
import 'package:tabgame/hub/game_card.dart';
import 'package:tabgame/hub/game_icons.dart';

void main() {
  test('허브에 오른 모든 게임에 직접 그린 아이콘이 있다', () {
    for (final g in allGames) {
      expect(GameIcon.hasArt(g.id), isTrue, reason: '${g.title}(${g.id}) 아이콘이 없어요');
    }
  });

  testWidgets('모든 게임 카드와 아이콘이 크기별로 오류 없이 그려진다', (tester) async {
    for (final size in const [Size(360, 740), Size(1000, 700)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          // 실제 허브와 같은 격자 (카드 높이 220 고정)
          body: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 300,
              mainAxisSpacing: 18,
              crossAxisSpacing: 18,
              mainAxisExtent: 220,
            ),
            itemCount: allGames.length,
            itemBuilder: (context, i) => GameCard(game: allGames[i], onTap: () {}),
          ),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(GameIcon), findsWidgets);
      expect(tester.takeException(), isNull);
      // 큰 아이콘(준비 중 화면용)도 같은 그림으로 그려진다
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Wrap(children: [for (final g in allGames) GameIcon(id: g.id, fallback: g.icon, size: 120)]),
        ),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
    }
  });
}
