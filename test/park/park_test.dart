import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/park/core/park_rules.dart';
import 'package:tabgame/games/park/ui/park_board.dart';
import 'package:tabgame/games/park/ui/park_screen.dart';

const _r = Walk.right, _d = Walk.down;

/// 판 위 점 (행, 열)의 화면 좌표 (ParkBoard의 틀 계산과 같게).
Offset _pt(WidgetTester tester, int n, int r, int c) {
  final rect = tester.getRect(find.byType(ParkBoard).first);
  final gap = rect.shortestSide / (n + 1.24);
  final origin = rect.topLeft + Offset((rect.width - gap * n) / 2, (rect.height - gap * n) / 2);
  return origin + Offset(c * gap, r * gap);
}

Future<void> _draw(WidgetTester tester, int n, List<Walk> steps) async {
  var (r, c) = (0, 0);
  final g = await tester.startGesture(_pt(tester, n, 0, 0));
  for (final s in steps) {
    final from = _pt(tester, n, r, c);
    s == Walk.right ? c++ : r++;
    final to = _pt(tester, n, r, c);
    for (var k = 1; k <= 6; k++) {
      await g.moveTo(Offset.lerp(from, to, k / 6)!);
    }
  }
  await g.up();
  await tester.pump();
}

void main() {
  group('규칙', () {
    test('정답: 2×2는 2가지, 3×3은 10가지, 4×4는 42가지', () {
      expect([for (final s in kParkStages) s.answer], [2, 10, 42]);
    });

    test('문제지의 예: → ↓ ↓ → 는 오른편 숲(처음 두 구간)과 왼편 숲(나중 두 구간)을 모두 지난다', () {
      final s = kParkStages[0];
      expect(s.sides(const [_r, _d, _d, _r]), [ForestSide.right, ForestSide.right, ForestSide.left, ForestSide.left]);
      expect(s.isValid(const [_r, _d, _d, _r]), isTrue);
      expect(s.isValid(const [_r, _r, _d, _d]), isFalse);
    });
  });

  group('화면', () {
    testWidgets('그어서 찾으면 목록에 모이고, 같은 길은 "이미 찾았던 길", 조건이 틀리면 알려 준다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: ParkScreen()));

      await _draw(tester, 2, const [_r, _d, _d, _r]);
      expect(find.textContaining('새 길을 찾았어요'), findsOneWidget);
      expect(find.text('찾은 길 1가지'), findsOneWidget);

      await _draw(tester, 2, const [_r, _d, _d, _r]);
      expect(find.text('이미 찾았던 길이에요 (1번)'), findsOneWidget);
      expect(find.text('찾은 길 1가지'), findsOneWidget);

      await _draw(tester, 2, const [_r, _r, _d, _d]);
      expect(find.textContaining('조건에 맞지 않아요'), findsOneWidget);

      await _draw(tester, 2, const [_d, _r, _r, _d]);
      expect(find.text('모두 찾았어요! 전부 2가지'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      expect(tester.takeException(), isNull);
    });

    testWidgets('정렬을 누르면 찾은 길이 사전식(R·D)으로 줄 선다', (tester) async {
      tester.view.physicalSize = const Size(800, 1280);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: ParkScreen()));
      await tester.tap(find.text('3×3 공원'));
      await tester.pump();
      for (final p in const [
        [_r, _d, _d, _r, _r, _d], // RDDRRD
        [_d, _r, _r, _d, _d, _r], // DRRDDR
        [_r, _d, _d, _d, _r, _r], // RDDDRR
      ]) {
        await _draw(tester, 3, p);
      }
      List<String> order() => [
            for (final t in tester.widgetList<Text>(find.byType(Text)))
              if (RegExp(r'^[RD]{6}$').hasMatch(t.data ?? '')) t.data!,
          ];
      expect(order(), ['RDDRRD', 'DRRDDR', 'RDDDRR']);
      await tester.tap(find.text('정렬'));
      await tester.pump();
      expect(order(), ['DRRDDR', 'RDDDRR', 'RDDRRD']);
      expect(find.textContaining('사전식으로 정렬했어요'), findsOneWidget);
    });

    testWidgets('되돌아가면 길이 지워진다', (tester) async {
      tester.view.physicalSize = const Size(400, 860);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: ParkScreen()));
      final g = await tester.startGesture(_pt(tester, 2, 0, 0));
      for (var k = 1; k <= 6; k++) {
        await g.moveTo(Offset.lerp(_pt(tester, 2, 0, 0), _pt(tester, 2, 0, 2), k / 6)!);
      }
      await tester.pump();
      expect(find.text('숲이 왼편인 구간 0개 · 오른편인 구간 1개'), findsOneWidget);
      for (var k = 1; k <= 6; k++) {
        await g.moveTo(Offset.lerp(_pt(tester, 2, 0, 2), _pt(tester, 2, 0, 1), k / 6)!);
      }
      await g.up();
      await tester.pump();
      expect(find.textContaining('B까지 이어 주세요'), findsOneWidget);
    });
  });
}
