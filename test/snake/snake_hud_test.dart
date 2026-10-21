import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/snake/core/snake_body.dart';
import 'package:tabgame/games/snake/ui/snake_hud.dart';

void main() {
  testWidgets('좁은 폰에서 큰 점수도 순위표에서 "…"로 잘리지 않고 다 보인다', (tester) async {
    final snakes = [
      for (var i = 0; i < 30; i++) SnakeBody(id: i, name: '아주아주긴이름의지렁이$i', color: i % 14, seat: i == 11 ? 0 : -1)..mass = 123456.0 - i * 1000,
    ];
    for (final width in [172.0, 150.0]) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Align(alignment: Alignment.topRight, child: SnakeLeaderboard(ranked: snakes, mySeat: 0, width: width, cpuLevel: 10))),
      ));
      expect(tester.takeException(), isNull, reason: '폭 $width: 넘치지 않는다');
      final mine = find.textContaining('내 순위');
      expect(mine, findsOneWidget);
      final text = tester.widget<Text>(mine);
      expect(text.overflow, isNot(TextOverflow.ellipsis), reason: '폭 $width: 점수가 "…"로 잘리지 않는다');
      expect(text.data, contains('${snakes[11].score}점'));
      // 글자를 줄여서라도 순위표 폭 안에 들어온다
      expect(find.ancestor(of: mine, matching: find.byType(FittedBox)), findsOneWidget);
      final box = tester.getRect(find.ancestor(of: mine, matching: find.byType(FittedBox)));
      final board = tester.getRect(find.byType(SnakeLeaderboard));
      expect(box.right, lessThanOrEqualTo(board.right + 0.01));
    }
  });
}
