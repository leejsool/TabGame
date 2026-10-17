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

/// 묶음 가로에 더해지는 좌우 여백 (칸). 좁을수록 한 줄에 묶음이 더 많이 들어간다.
const double kSetPad = 0.3;

/// 세로로 묶음 줄 사이의 틈 (픽셀). 좁을수록 녹색 판에 줄이 더 많이 들어간다.
const double kSetRowGap = 4;

/// 세로 화면에서 녹색 판 위 타일 한 장의 가로 크기.
///
/// 3장짜리 묶음 셋이 한 줄에 들어가는 크기로 정하되, 이 크기는 묶음 사이 여백([kSetPad])을 줄여도 **그대로**다.
/// (여백을 줄인 만큼 타일을 키우면 판에 보이는 타일이 오히려 줄어든다. 여백은 줄이고 타일은 그대로 두어 더 많이 보이게 한다.)
/// [inner]는 판 안쪽 가로(테두리·여백을 뺀 폭)다.
double rkTableTileSize(double inner, {double scale = 1}) => (inner / (3 * (3 + _kTileFitPad) + 0.45)).clamp(20.0, 34.0 * scale).floorToDouble();

/// 태블릿(짧은 쪽이 [kTabletMinSide] 이상)에서는 판 위 타일을 대략 이만큼 키운다. 화면이 넓어 타일이 훨씬 커도 많이 들어간다.
/// (실제 크기는 [rkTabletTableTileSize]가 판 폭에 맞춰 정한다.)
const double kTabletTileScale = 1.5;

/// 3장짜리 묶음 [n]개가 한 줄에 나란히 들어가는 데 필요한 판 폭 (칸).
/// 빈자리 찾기는 0.5칸 격자에 묶음 사이를 0.1칸 이상 띄우므로, 묶음 하나의 몫은 3 + [kSetPad] + 0.1을 0.5칸 단위로 올린 값이다
/// (마지막 묶음은 자기 폭만 있으면 된다).
double rkRowUnitsFor3(int n) {
  final slot = ((3 + kSetPad + 0.1) * 2).ceil() / 2;
  return (n - 1) * slot + 3 + kSetPad + 0.02; // (0.02: 소수 계산 오차 여유)
}

/// 태블릿에서 녹색 판 위 타일 한 장의 가로 크기.
///
/// 폰 크기의 [kTabletTileScale]배로 고정하면 판 폭에 따라 줄 끝에 묶음 하나가 못 들어가는 애매한 빈자리가 남는다.
/// 그래서 3장짜리 묶음 N개가 한 줄에 꼭 맞는 크기들 가운데 [target]에 가까운 크기를 고른다: [target]의 95% 이상인 것 중 가장 작은 것
/// (타일은 거의 작아지지 않고, 줄 끝 빈자리가 사라질 만큼만 커진다). [inner]는 판 안쪽 가로다.
double rkTabletTableTileSize(double inner, {double target = 34.0 * kTabletTileScale}) {
  double? best;
  for (var n = 1; n <= 30; n++) {
    final tile = (inner / rkRowUnitsFor3(n)).floorToDouble();
    if (tile < target * 0.95) break;
    best = tile;
  }
  return best ?? (inner / rkRowUnitsFor3(1)).clamp(20.0, target).floorToDouble();
}

/// 타일 크기를 정할 때 쓰는 묶음 사이 여유 (칸). 예전 여백 값으로 고정해 두어, [kSetPad]를 바꿔도 타일 크기는 변하지 않는다.
const double _kTileFitPad = 0.6;

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
