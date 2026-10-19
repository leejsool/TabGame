import 'dart:math';

import 'package:flutter/material.dart';

import '../core/sprouts_board.dart';
import '../core/sprouts_geometry.dart';
import 'sprouts_painter.dart';

/// "모양이 아니라 이어진 관계" 단원의 예시들: 같은 판을 이렇게도 저렇게도 그려 본 그림.

/// 점 [ctrl]을 차례로 지나는 부드러운 곡선 (캣멀-롬 곡선). 간격이 고르도록 촘촘히 찍는다.
List<P> smoothPath(List<P> ctrl, {double step = 4}) {
  if (ctrl.length < 3) return ctrl;
  final pts = [ctrl.first, ...ctrl, ctrl.last];
  final out = <P>[ctrl.first];
  for (var i = 1; i < pts.length - 2; i++) {
    final p0 = pts[i - 1], p1 = pts[i], p2 = pts[i + 1], p3 = pts[i + 2];
    final n = max(4, (p1.dist(p2) / step).ceil());
    for (var k = 1; k <= n; k++) {
      final t = k / n, t2 = t * t, t3 = t2 * t;
      double c(double a, double b, double cc, double d) =>
          0.5 * (2 * b + (-a + cc) * t + (2 * a - 5 * b + 4 * cc - d) * t2 + (-a + 3 * b - 3 * cc + d) * t3);
      out.add(P(c(p0.x, p1.x, p2.x, p3.x), c(p0.y, p1.y, p2.y, p3.y)));
    }
  }
  return out;
}

/// 한 수: [from]번 점에서 [to]번 점까지, 사이에 [via]를 차례로 지난다. [fromPos]/[toPos]를 주면 그 점이 새로 생긴 점일 때도 자리를 정해 둔다.
class DemoMove {
  const DemoMove(this.from, this.to, this.via);

  final int from;
  final int to;
  final List<P> via;
}

/// [dots]에서 시작해 [moves]를 차례로 둔 판. 새 점은 곡선 위에 생기고, 그 점에는 4번, 5번… 순서로 번호가 붙는다.
///
/// [warp]가 있으면 점과 곡선의 모든 자리를 그 함수로 옮겨서(= 판을 고무판처럼 늘이고 구부려서) 같은 수들을 다시 둔다.
SproutsBoard buildDemo(List<P> dots, List<DemoMove> moves, {P Function(P p)? warp}) => _play(dots, moves, warp);

SproutsBoard _play(List<P> dots, List<DemoMove> moves, P Function(P p)? warp) {
  P w(P p) => warp == null ? p : warp(p);
  final b = SproutsBoard([for (final p in dots) Dot(w(p), 3)], []);
  var owner = 0;
  for (final m in moves) {
    final path = [b.dots[m.from].pos, for (final p in m.via) w(p), b.dots[m.to].pos];
    final stroke = smoothPath(path);
    final r = b.validate(m.from, m.to, stroke.sublist(1, stroke.length - 1));
    assert(r.ok, '예시 그림의 ${m.from}→${m.to}: ${r.reason}');
    if (r.ok) b.apply(m.from, m.to, r, owner);
    owner = 1 - owner;
  }
  return b;
}

/// 조금 복잡한 판: 모서리 점 넷을 고리로 잇고, 그 안에 가운데를 가로지르는 선과 곁가지를 둔 판.
const List<DemoMove> _crossPlan = [
      DemoMove(0, 1, [P(200, 70)]),
      DemoMove(1, 3, [P(335, 230)]),
      DemoMove(3, 2, [P(200, 395)]),
      DemoMove(2, 0, [P(65, 230)]),
      DemoMove(4, 6, [P(200, 230)]), // 위 가운데 점 → 아래 가운데 점
      DemoMove(5, 8, [P(262, 230)]), // 오른쪽 점 → 방금 선 위에 생긴 가운데 점
    ];

/// 위와 같은 점 넷이지만 선을 이은 곳이 다른 판: 이웃한 변의 점끼리 잇는다.
const List<DemoMove> _cornerPlan = [
      DemoMove(0, 1, [P(200, 70)]),
      DemoMove(1, 3, [P(335, 230)]),
      DemoMove(3, 2, [P(200, 395)]),
      DemoMove(2, 0, [P(65, 230)]),
      DemoMove(4, 5, [P(285, 120)]),
      DemoMove(6, 7, [P(115, 340)]),
    ];

const List<P> _cross4 = [P(90, 110), P(310, 110), P(90, 350), P(310, 350)];

const P _mid = P(200, 230);

/// 판을 가로로 늘이고 세로로 줄인다.
P _stretch(P p) => P(_mid.x + (p.x - _mid.x) * 1.22, _mid.y + (p.y - _mid.y) * 0.8);

/// 판을 비틀듯이 돌린다.
P _twist(P p) {
  final d = p - _mid;
  final a = 0.45;
  return P(_mid.x + d.x * cos(a) - d.y * sin(a) * 0.9, _mid.y + d.x * sin(a) * 0.9 + d.y * cos(a));
}

/// 물결치게 휜다.
P _wobble(P p) => P(p.x + 24 * sin(p.y / 55), p.y + 18 * sin(p.x / 62));

/// 같은 판을 다르게 그린 것 넷과, 이은 곳이 달라서 다른 판 하나.
List<ShapeTile> complexTiles() => [
      ShapeTile(buildDemo(_cross4, _crossPlan), '처음 그린 판', same: true),
      ShapeTile(buildDemo(_cross4, _crossPlan, warp: _stretch), '가로로 늘인 판', same: true),
      ShapeTile(buildDemo(_cross4, _crossPlan, warp: _twist), '비틀어 돌린 판', same: true),
      ShapeTile(buildDemo(_cross4, _crossPlan, warp: _wobble), '물결치게 휜 판', same: true),
      ShapeTile(buildDemo(_cross4, _cornerPlan), '이은 곳이 달라요', same: false),
      ShapeTile(buildDemo(_cross4, _cornerPlan, warp: _twist), '돌려 봐도 달라요', same: false),
    ];

/// 점 하나에서 나가 자기 자신으로 돌아오는 고리를 여러 모양으로 그린 것.
List<ShapeTile> loopTiles() {
  const dot = [P(200, 320)];
  SproutsBoard loop(List<P> via) => buildDemo(dot, [DemoMove(0, 0, via)]);
  List<P> ring(double cx, double cy, double rx, double ry) => [
        for (var i = 1; i < 12; i++)
          P(cx - rx * sin(2 * pi * i / 12), cy + ry * cos(2 * pi * i / 12)),
      ];
  return [
    ShapeTile(loop(ring(200, 215, 95, 105)), '동그란 고리', same: true),
    ShapeTile(loop(ring(200, 205, 55, 120)), '길쭉한 고리', same: true),
    ShapeTile(loop(const [P(300, 330), P(315, 240), P(250, 130), P(200, 70), P(150, 130), P(85, 240), P(100, 330)]), '삼각형 고리', same: true),
    ShapeTile(loop(const [P(290, 300), P(330, 220), P(260, 190), P(300, 120), P(210, 100), P(150, 170), P(110, 260), P(130, 330)]), '울퉁불퉁한 고리', same: true),
  ];
}

/// 판 하나와 그 밑에 붙는 설명.
class ShapeTile {
  const ShapeTile(this.board, this.caption, {required this.same});

  final SproutsBoard board;
  final String caption;

  /// 첫 판과 같은 판인가 (다른 판이면 붉은 테두리로 보여 준다).
  final bool same;
}

/// 판들을 폭에 맞춰 늘어놓는다 (좁은 화면은 한 줄에 둘, 넓은 화면은 더 많이).
class ShapeGallery extends StatelessWidget {
  const ShapeGallery({super.key, required this.tiles, this.padding = 10});

  final List<ShapeTile> tiles;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 10.0;
        final inner = box.maxWidth - padding * 2;
        // 한 줄에 몇 장: 폭에 맞춰 정하되, 마지막 줄에 한 장만 덩그러니 남지 않게 맞춘다
        var cols = ((inner + gap) / (170 + gap)).floor().clamp(2, 4);
        if (tiles.length % cols == 1 && cols > 2) cols = tiles.length % (cols - 1) == 1 ? cols : cols - 1;
        if (tiles.length == 4 && cols == 3) cols = 4;
        cols = min(cols, tiles.length);
        final w = min(220.0, (inner - gap * (cols - 1)) / cols);
        return Padding(
          padding: EdgeInsets.all(padding),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            alignment: WrapAlignment.center,
            children: [for (final t in tiles) SizedBox(width: w, child: _tile(t))],
          ),
        );
      },
    );
  }

  Widget _tile(ShapeTile t) {
    final color = t.same ? const Color(0xFF2E9E5B) : const Color(0xFFD1495B);
    return Column(
      children: [
        DecoratedBox(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.7), width: 2)),
          child: Padding(
            padding: const EdgeInsets.all(3),
            child: AspectRatio(
              aspectRatio: kBoardW / kBoardH,
              child: CustomPaint(painter: SproutsPainter(board: t.board, showGrid: false)),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          t.caption,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color),
        ),
      ],
    );
  }
}
