import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/jigsaw/core/jigsaw_geometry.dart';
import 'package:tabgame/games/jigsaw/game/jigsaw_controller.dart';

JigsawGeometry geo({int rows = 4, int cols = 6, int seed = 1}) => JigsawGeometry(
      rows: rows,
      cols: cols,
      imageSize: const Size(1200, 800),
      seed: seed,
    );

void main() {
  group('격자', () {
    test('그림 비율에 맞춰 조각이 정사각형에 가깝게 나뉜다', () {
      expect(JigsawGeometry.gridFor(24, 4 / 3), (4, 6));
      expect(JigsawGeometry.gridFor(12, 4 / 3), (3, 4));
      expect(JigsawGeometry.gridFor(24, 3 / 4), (6, 4)); // 세로 사진
      expect(JigsawGeometry.gridFor(48, 16 / 9).$1 * JigsawGeometry.gridFor(48, 16 / 9).$2,
          inInclusiveRange(40, 56));
      // 아주 긴 사진에서도 최소 2×2
      final (r, c) = JigsawGeometry.gridFor(12, 10);
      expect(r, greaterThanOrEqualTo(2));
      expect(c, greaterThanOrEqualTo(2));
    });
  });

  group('조각 모양', () {
    test('같은 seed면 같은 모양, 다른 seed면 다른 모양', () {
      final a = geo(seed: 7), b = geo(seed: 7), c = geo(seed: 8);
      expect(a.boxes, b.boxes);
      expect(a.boxes == c.boxes, isFalse);
    });

    test('모든 조각 상자는 칸을 포함하고 너무 크지 않다', () {
      final g = geo();
      for (var i = 0; i < g.count; i++) {
        final cell = g.cellRect(g.rowOf(i), g.colOf(i));
        final box = g.boxes[i];
        expect(box.left <= cell.left + 4 && box.top <= cell.top + 4, isTrue);
        expect(box.right >= cell.right - 4 && box.bottom >= cell.bottom - 4, isTrue);
        // 볼록이 튀어나와도 칸 크기의 0.5배 이상 나가지 않는다
        expect(box.width, lessThan(g.cw * 2));
        expect(box.height, lessThan(g.ch * 2));
        // 조각 윤곽은 상자 안에 있다
        final b = g.paths[i].getBounds();
        expect(b.left, greaterThanOrEqualTo(-0.01));
        expect(b.top, greaterThanOrEqualTo(-0.01));
        expect(b.right, lessThanOrEqualTo(box.width + 0.01));
        expect(b.bottom, lessThanOrEqualTo(box.height + 0.01));
      }
    });

    test('칸 중심은 항상 조각 안이다', () {
      final g = geo();
      for (var i = 0; i < g.count; i++) {
        final cell = g.cellRect(g.rowOf(i), g.colOf(i));
        final local = cell.center - g.boxes[i].topLeft;
        expect(g.containsLocal(i, local), isTrue, reason: '조각 $i');
      }
    });

    test('이웃한 조각은 겹치지도 비지도 않는다 (경계 곡선 공유)', () {
      // 격자를 촘촘히 훑어서, 모든 점이 정확히 하나의 조각에만 속하는지 확인한다
      final g = geo(rows: 3, cols: 4, seed: 5);
      var bad = 0;
      for (var y = 2.0; y < 800; y += 7.3) {
        for (var x = 2.0; x < 1200; x += 7.3) {
          var inside = 0;
          for (var i = 0; i < g.count; i++) {
            if (g.containsLocal(i, Offset(x, y) - g.boxes[i].topLeft)) inside++;
          }
          if (inside != 1) bad++;
        }
      }
      // 경계선 바로 위의 점은 오차가 있을 수 있어 극소수만 허용
      expect(bad, lessThan(40), reason: '겹치거나 빈 점 $bad개');
    });

    test('볼록·오목이 실제로 있다 (직선 사각형이 아님)', () {
      final g = geo();
      var different = 0;
      for (var i = 0; i < g.count; i++) {
        final cell = g.cellRect(g.rowOf(i), g.colOf(i));
        final b = g.paths[i].getBounds();
        if (b.width > cell.width * 1.05 || b.height > cell.height * 1.05) different++;
      }
      expect(different, greaterThan(g.count ~/ 2));
    });
  });

  group('컨트롤러', () {
    JigsawController make({int seed = 3}) =>
        JigsawController(geometry: geo(rows: 3, cols: 4), scatterSeed: seed);

    test('처음엔 조각이 모두 판 밖에 흩어져 있고 붙은 조각은 없다', () {
      final c = make();
      expect(c.placedCount, 0);
      expect(c.completed, isFalse);
      final board = c.boardRect.deflate(80); // 판 가장자리에 살짝 걸친 것은 "밖"으로 본다
      var outside = 0;
      for (var i = 0; i < c.geometry.count; i++) {
        final box = c.pos[i] & c.geometry.boxes[i].size;
        if (!box.overlaps(board)) outside++;
        // 탁자 안에 있다
        expect(c.pos[i].dx, greaterThanOrEqualTo(0));
        expect(c.pos[i].dy, greaterThanOrEqualTo(0));
        expect(box.right, lessThanOrEqualTo(c.tableSize.width + 0.01));
        expect(box.bottom, lessThanOrEqualTo(c.tableSize.height + 0.01));
      }
      expect(outside, greaterThan(c.geometry.count * 0.8));
    });

    test('탁자는 화면 비율을 따르고, 판은 그 한가운데에 있다', () {
      final g = geo(rows: 3, cols: 4); // 가로로 긴 그림(1200×800)
      final wide = JigsawController(geometry: g, scatterSeed: 1);
      final tall = JigsawController(geometry: g, scatterSeed: 1, tableAspect: 0.6); // 세로 화면
      // 세로 화면이면 탁자가 위아래로 더 길다
      expect(tall.tableSize.height, greaterThan(wide.tableSize.height));
      expect(tall.tableSize.width / tall.tableSize.height, closeTo(0.6, 0.01));
      // 어느 쪽이든 그림 둘레에 충분한 여유가 있다
      for (final c in [wide, tall]) {
        expect(c.tableSize.width, greaterThanOrEqualTo(g.imageSize.width * 1.9 - 0.01));
        expect(c.tableSize.height, greaterThanOrEqualTo(g.imageSize.height * 1.9 - 0.01));
        expect(c.boardRect.center.dx, closeTo(c.tableSize.width / 2, 0.01));
        expect(c.boardRect.center.dy, closeTo(c.tableSize.height / 2, 0.01));
        // 모든 조각이 탁자 안에 흩어진다
        for (var i = 0; i < g.count; i++) {
          final box = c.pos[i] & g.boxes[i].size;
          expect(box.right, lessThanOrEqualTo(c.tableSize.width + 0.01));
          expect(box.bottom, lessThanOrEqualTo(c.tableSize.height + 0.01));
        }
      }
      // 저장·복원해도 같은 탁자
      final r = JigsawController.fromJson(tall.toJson());
      expect(r.tableSize, tall.tableSize);
    });

    test('제자리 근처에 놓으면 딸깍 붙고, 멀면 그냥 놓인다', () {
      final c = make();
      var snaps = 0;
      c.onSnap = () => snaps++;

      // 멀리 놓기
      var p = c.pos[0] + const Offset(10, 10);
      c.beginDrag(0, p);
      expect(c.dragging, 0);
      c.dragTo(c.targetPos(0) + const Offset(300, 300) + (p - c.pos[0]));
      c.endDrag();
      expect(c.placed[0], isFalse);
      expect(snaps, 0);

      // 제자리에서 조금 벗어난 곳에 놓기
      p = c.pos[0] + const Offset(5, 5);
      c.beginDrag(0, p);
      final near = c.targetPos(0) + Offset(c.snapDistance * 0.6, 0);
      c.dragTo(near + (p - c.pos[0]));
      c.endDrag();
      expect(c.placed[0], isTrue);
      expect(c.pos[0], c.targetPos(0));
      expect(snaps, 1);
      expect(c.placedCount, 1);

      // 붙은 조각은 다시 못 잡는다
      c.beginDrag(0, c.pos[0] + const Offset(5, 5));
      expect(c.dragging, isNull);
      expect(c.pieceAt(c.pos[0] + const Offset(20, 20)), isNot(0));
    });

    test('끌면 그 조각이 맨 위로 올라온다', () {
      final c = make();
      c.beginDrag(2, c.pos[2] + const Offset(3, 3));
      expect(c.order.last, 2);
      c.endDrag();
    });

    test('pieceAt: 조각 안을 누르면 그 조각을 잡는다', () {
      final c = make();
      for (var i = 0; i < c.geometry.count; i++) {
        final cell = c.geometry.cellRect(c.geometry.rowOf(i), c.geometry.colOf(i));
        // 조각 칸 중심 (조각 안 확실한 점)
        final p = c.pos[i] + (cell.center - c.geometry.boxes[i].topLeft);
        final got = c.pieceAt(p);
        expect(got, isNotNull);
        // 겹쳐 있으면 위에 있는 조각이 잡힐 수 있지만, 잡힌 조각은 그 점을 실제로 덮고 있어야 한다
        final local = p - c.pos[got!];
        expect(c.geometry.containsLocal(got, local) || got == i, isTrue);
      }
    });

    test('모든 조각을 제자리에 놓으면 완성된다', () {
      final c = make();
      var done = 0;
      c.onCompleted = () => done++;
      for (var i = 0; i < c.geometry.count; i++) {
        c.beginDrag(i, c.pos[i]);
        c.dragTo(c.targetPos(i));
        c.endDrag();
      }
      expect(c.completed, isTrue);
      expect(c.progress, 1.0);
      expect(done, 1);
      // 완성 뒤에는 조각을 못 건드린다
      c.beginDrag(0, c.pos[0]);
      expect(c.dragging, isNull);
    });

    test('붙은 조각은 붙지 않은 조각들보다 아래에 그려진다', () {
      final c = make();
      c.beginDrag(5, c.pos[5]);
      c.dragTo(c.targetPos(5));
      c.endDrag();
      final firstUnplaced = c.order.indexWhere((i) => !c.placed[i]);
      final lastPlaced = c.order.lastIndexWhere((i) => c.placed[i]);
      expect(lastPlaced, lessThan(firstUnplaced));
    });

    test('힌트는 안 붙은 조각을 고르고, 완성 후엔 없다', () {
      final c = make();
      c.giveHint(Random(1));
      expect(c.hintPiece, isNotNull);
      expect(c.placed[c.hintPiece!], isFalse);
      // 가장자리 조각을 우선한다 (3×4 에서는 가운데 조각이 2개뿐)
      final i = c.hintPiece!;
      final r = c.geometry.rowOf(i), cc = c.geometry.colOf(i);
      expect(r == 0 || cc == 0 || r == 2 || cc == 3, isTrue);
      // 끌면 힌트가 꺼진다
      c.beginDrag(i, c.pos[i]);
      expect(c.hintPiece, isNull);
      c.endDrag();
    });

    test('저장 후 복원하면 같은 상태', () {
      final c = make();
      c.beginDrag(1, c.pos[1]);
      c.dragTo(c.targetPos(1));
      c.endDrag();
      c.elapsed.value = 77;
      final r = JigsawController.fromJson(c.toJson());
      expect(r.pos, c.pos);
      expect(r.placed, c.placed);
      expect(r.order, c.order);
      expect(r.elapsed.value, 77);
      expect(r.geometry.boxes, c.geometry.boxes);
    });

    test('다시 흩어 놓아도 붙은 조각은 그대로다', () {
      final c = make();
      c.beginDrag(4, c.pos[4]);
      c.dragTo(c.targetPos(4));
      c.endDrag();
      final fixed = c.pos[4];
      c.scatter(Random(99));
      expect(c.pos[4], fixed);
      expect(c.placed[4], isTrue);
      expect(c.order.length, c.geometry.count);
      expect(c.order.toSet().length, c.geometry.count);
    });
  });
}
