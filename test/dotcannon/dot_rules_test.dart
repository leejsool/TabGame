import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabgame/games/dotcannon/core/dot_assess.dart';
import 'package:tabgame/games/dotcannon/core/dot_convert.dart';
import 'package:tabgame/games/dotcannon/core/dot_rules.dart';

DotGame tiny({int capacity = 5}) {
  // 3×3 그림: 가운데 파랑(1)을 빨강(0)이 둘러싸고 있다
  return DotGame(
    width: 3,
    height: 3,
    grid: [0, 0, 0, 0, 1, 0, 0, 0, 0],
    capacity: capacity,
    queue: [
      [Cannon(id: 0, color: 1, ammo: 1, column: 0), Cannon(id: 1, color: 0, ammo: 8, column: 0)],
    ],
  );
}

void main() {
  test('벨트 자리: 그림 둘레를 한 바퀴 돌고, 마주 보는 줄을 향한다', () {
    final g = tiny();
    expect(g.ringLength, 2 * (3 + 3) + 4);
    final seen = <(int, int)>{for (var i = 0; i < g.ringLength; i++) g.ringCell(i)};
    expect(seen.length, g.ringLength); // 겹치는 자리가 없다
    expect(g.ringCell(0), (-1, -1));
    expect(g.ringCell(g.entryPos), (-1, 3)); // 입구는 왼쪽 아래 모서리
    expect(g.facing(1), (0, 1)); // 맨 윗줄은 아래로
    expect(g.facing(0), isNull); // 모서리에서는 쏘지 않는다
  });

  test('바깥에 보이는 도트만 맞힐 수 있다 (안쪽 파랑은 빨강을 지워야 보인다)', () {
    final g = tiny();
    expect(g.exposedColors(), {0});
    expect(g.target(2), 1); // 맨 윗줄 가운데 자리에서 쏘면 위쪽 가운데 빨강
  });

  test('대포는 자기 색만 쏘고, 탄이 떨어지면 사라진다', () {
    final g = tiny();
    // 파랑 대포를 올려 한 바퀴 돌려도 빨강이 가리고 있어서 못 쏜다
    expect(g.deploy(0), isTrue);
    for (var i = 0; i < g.ringLength; i++) {
      expect(g.step(), isEmpty);
    }
    expect(g.belt.length, 1);
    expect(g.remaining, 9);
    expect(g.stuck, isFalse); // 앞의 빨강 대포로 길이 있다
  });

  test('빨강 8발로 바깥을 다 지우면 안쪽 파랑이 드러나고, 파랑 대포가 맞힌다', () {
    final g = tiny();
    g.queue[0]
      ..clear()
      ..addAll([Cannon(id: 1, color: 0, ammo: 8, column: 0), Cannon(id: 0, color: 1, ammo: 1, column: 0)]);
    expect(g.deploy(0), isTrue);
    var guard = 0;
    while (g.belt.isNotEmpty && guard++ < 200) {
      g.step();
    }
    expect(g.remaining, 1);
    expect(g.exposedColors(), {1});
    expect(g.deploy(0), isTrue);
    guard = 0;
    while (!g.won && guard++ < 200) {
      g.step();
    }
    expect(g.won, isTrue);
  });

  test('맞힐 수 없는 대포로 벨트가 가득 차면 막힌다', () {
    final g = DotGame(
      width: 3,
      height: 3,
      grid: [0, 0, 0, 0, 1, 0, 0, 0, 0],
      capacity: 1,
      queue: [
        [Cannon(id: 0, color: 1, ammo: 1, column: 0)],
        [Cannon(id: 1, color: 0, ammo: 8, column: 1)],
      ],
    );
    expect(g.stuck, isFalse);
    expect(g.deploy(0), isTrue); // 파랑 대포로 자리를 채워 버렸다
    expect(g.deploy(1), isFalse);
    expect(g.stuck, isTrue);
  });

  test('저장했다가 되살려도 같은 판이다', () {
    final g = tiny()..deploy(0);
    g.step();
    final back = DotGame.fromJson(g.toJson());
    expect(back.toJson(), g.toJson());
  });

  test('입구가 비어 있어야 다음 대포를 올릴 수 있다', () {
    final g = DotGame(
      width: 2,
      height: 2,
      grid: [0, 0, 0, 0],
      queue: [
        [Cannon(id: 0, color: 0, ammo: 2, column: 0)],
        [Cannon(id: 1, color: 0, ammo: 2, column: 1)],
      ],
    );
    expect(g.deploy(0), isTrue);
    expect(g.canDeploy(1), isFalse); // 방금 올린 대포가 아직 입구에 있다
    g.step();
    expect(g.canDeploy(1), isTrue);
  });

  group('사진 변환', () {
    test('크기는 사진 비율을 지킨다', () {
      expect(dotSizeFor(400, 200, 16), (16, 8));
      expect(dotSizeFor(100, 300, 12), (4, 12));
    });

    test('색을 줄여 칸마다 번호를 매기고, 배경색 지우기가 가장자리부터 이어진 배경만 지운다', () {
      // 5×5: 가장자리는 흰색, 가운데 3×3은 빨강, 그 한가운데 한 칸은 흰색(구멍)
      const w = 5, h = 5;
      final cells = <(double, double, double, double)>[];
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          final inner = x >= 1 && x <= 3 && y >= 1 && y <= 3;
          final hole = x == 2 && y == 2;
          cells.add(inner && !hole ? (230, 30, 30, 1) : (250, 250, 250, 1));
        }
      }
      final art = quantizeCells(cells, w, h, colors: 2);
      expect(art.colors.length, 2);
      expect(art.pixelCount, 25);
      final cut = quantizeCells(cells, w, h, colors: 2, removeBackground: true);
      expect(cut.pixelCount, 9); // 빨강 8칸 + 안쪽 구멍(배경과 이어지지 않아 남는다)
      expect(cut.pixels[0], kDotEmpty);
    });

    test('투명한 칸은 빈 칸이 된다', () {
      final rgba = Uint8List.fromList([
        255, 0, 0, 255, 0, 0, 0, 0, //
        0, 0, 0, 0, 0, 255, 0, 255,
      ]);
      final cells = boxDownsample(rgba, 2, 2, 2, 2);
      final art = quantizeCells(cells, 2, 2, colors: 2);
      expect(art.pixels.where((c) => c == kDotEmpty).length, 2);
      expect(art.colors.length, 2);
    });
  });

  test('난이도 평가: 풀리는 배치를 찾고 0~3의 난이도를 돌려준다', () {
    // 8×8, 색 3가지가 겹겹이
    final px = <int>[];
    for (var y = 0; y < 8; y++) {
      for (var x = 0; x < 8; x++) {
        final ring = [x, y, 7 - x, 7 - y].reduce((a, b) => a < b ? a : b);
        px.add(ring % 3);
      }
    }
    final a = assessArt(pixels: px, width: 8, height: 8, colors: 3, capacity: 4, trials: 20);
    expect(a.solvable, isTrue);
    expect(a.difficulty, inInclusiveRange(0, 3));
    expect(a.randomWinRate, inInclusiveRange(0.0, 1.0));
    final g = DotGame(
      width: 8,
      height: 8,
      grid: List.of(px),
      capacity: a.capacity,
      queue: buildQueue(px, 3, columns: a.columns, ammoLo: a.ammoLo, ammoHi: a.ammoHi, seed: a.seed),
    );
    expect(botSolves(g), isTrue);
  });
}
