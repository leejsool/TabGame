import 'dart:math';
import 'dart:ui' show Offset, Rect;

/// 녹색 판 위 묶음들의 자리 계산 (화면과 무관한 순수 계산).
///
/// 자리는 "타일 한 칸" 단위다: x는 타일 한 장의 가로 칸, y는 묶음 한 줄의 세로 칸. 화면 크기가 바뀌어도 이 단위는 그대로여서,
/// 기기를 돌리거나 상대가 둔 뒤에도 내가 놓은 자리가 유지된다. 묶음은 타일이 [perRow]장을 넘으면 다음 줄로 이어진다.

/// 묶음 하나가 차지하는 칸 (가로 = 타일 수 + 좌우 여백, 세로 = 줄 수).
Rect setRect(Offset anchor, int length, int perRow) {
  final cols = min(length, perRow);
  final rows = (length / perRow).ceil();
  return Rect.fromLTWH(anchor.dx, anchor.dy, cols + kSetPad, rows - 0.12);
}

/// 묶음 가로에 더해지는 좌우 여백 (칸).
const double kSetPad = 0.3;

/// 두 상자 사이의 틈 (겹치면 0). 칸 단위.
double rectGap(Rect a, Rect b) {
  final dx = max(0.0, max(a.left - b.right, b.left - a.right));
  final dy = max(0.0, max(a.top - b.bottom, b.top - a.bottom));
  return sqrt(dx * dx + dy * dy);
}

/// [box]가 [others]와 (여백 [margin]을 두고) 겹치는가.
bool overlapsAny(Rect box, Iterable<Rect> others, {double margin = 0.1}) {
  final b = box.inflate(margin);
  for (final o in others) {
    if (b.overlaps(o)) return true;
  }
  return false;
}

/// 폭 [widthUnits] 안에서 [size] 크기의 상자를 놓을 빈자리를 [from]에서 가까운 곳부터 찾는다.
/// 먼저 같은 줄을 오른쪽으로, 그다음 아래 줄로 훑는다. 빈자리가 없으면 맨 아래에 놓는다.
Offset findFreeSpot(Iterable<Rect> others, Rect size, double widthUnits, {Offset from = Offset.zero}) {
  final maxX = max(0.0, widthUnits - size.width);
  final list = others.toList();
  var y = max(0.0, (from.dy * 2).round() / 2);
  final bottom = list.fold<double>(0, (m, r) => max(m, r.bottom)) + 1;
  while (y <= bottom + 1) {
    for (var x = y == from.dy ? min(maxX, max(0.0, from.dx)) : 0.0; x <= maxX + 0.001; x += 0.5) {
      final box = Rect.fromLTWH(x, y, size.width, size.height);
      if (!overlapsAny(box, list)) return Offset(x, y);
    }
    y += 0.5;
  }
  return Offset(0, bottom);
}

/// 놓은 자리 [want] 근처에서 겹치지 않는 가장 가까운 자리 (격자 0.5칸에 맞춘다). 판 밖으로 나가지 않게 한다.
Offset snapToFree(Iterable<Rect> others, Rect size, double widthUnits, Offset want) {
  final maxX = max(0.0, widthUnits - size.width);
  final list = others.toList();
  double snap(double v) => (v * 2).round() / 2;
  final base = Offset(snap(want.dx).clamp(0.0, maxX), max(0.0, snap(want.dy)));
  Offset? best;
  var bestD = double.infinity;
  for (var dy = -4.0; dy <= 4.0; dy += 0.5) {
    for (var dx = -6.0; dx <= 6.0; dx += 0.5) {
      final x = (base.dx + dx).clamp(0.0, maxX), y = base.dy + dy;
      if (y < 0) continue;
      final box = Rect.fromLTWH(x, y, size.width, size.height);
      if (overlapsAny(box, list)) continue;
      final d = (Offset(x, y) - base).distance;
      if (d < bestD) {
        bestD = d;
        best = Offset(x, y);
      }
    }
  }
  return best ?? findFreeSpot(list, size, widthUnits, from: base);
}
