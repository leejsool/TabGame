/// 사진을 도트로 줄이기 전에 모양이 더 또렷이 드러나도록 손보는 계산 (화면과 상관없는 순수한 계산).
library;

import 'dart:math';

/// 칸별 색([cells], 칸마다 (r, g, b, 불투명한 정도))을 손봐서 돌려준다. 투명한 칸은 그대로 둔다.
///
/// 1. 밝기를 늘려서 가장 어두운 곳과 가장 밝은 곳이 끝까지 벌어지게 한다 (흐릿한 사진도 색이 더 갈라진다).
/// 2. 색을 [saturation]배로 선명하게 한다.
/// 3. 둘레보다 밝거나 어두운 정도를 [edge]배로 키운다 (윤곽과 눈·입 같은 작은 모양이 살아난다).
///
/// 원래 색과는 조금 달라지지만, 줄인 뒤에도 모양이 남도록 하는 것이 목적이다.
List<(double, double, double, double)> enhanceCells(
  List<(double, double, double, double)> cells,
  int width,
  int height, {
  double saturation = 1.35,
  double edge = 0.8,
}) {
  double lum(double r, double g, double b) => 0.299 * r + 0.587 * g + 0.114 * b;
  final opaque = [for (var i = 0; i < cells.length; i++) if (cells[i].$4 >= 0.5) i];
  if (opaque.length < 2) return cells;

  // 1. 밝기 늘리기: 가장 어두운 2%와 가장 밝은 2%는 끝점을 잡는 데 쓰지 않는다 (티끌 하나가 늘리기를 망치지 않도록)
  final sorted = [for (final i in opaque) lum(cells[i].$1, cells[i].$2, cells[i].$3)]..sort();
  final lo = sorted[(sorted.length * 0.02).floor()];
  final hi = sorted[min(sorted.length - 1, (sorted.length * 0.98).ceil())];
  final stretch = hi - lo >= 8 ? 255 / (hi - lo) : 1.0;
  final shift = hi - lo >= 8 ? lo : 0.0;

  final r = List<double>.filled(cells.length, 0), g = List<double>.filled(cells.length, 0), b = List<double>.filled(cells.length, 0);
  for (final i in opaque) {
    var cr = ((cells[i].$1 - shift) * stretch).clamp(0.0, 255.0);
    var cg = ((cells[i].$2 - shift) * stretch).clamp(0.0, 255.0);
    var cb = ((cells[i].$3 - shift) * stretch).clamp(0.0, 255.0);
    // 2. 선명하게: 회색(밝기)에서 멀어지는 만큼 키운다
    final l = lum(cr, cg, cb);
    cr = (l + (cr - l) * saturation).clamp(0.0, 255.0);
    cg = (l + (cg - l) * saturation).clamp(0.0, 255.0);
    cb = (l + (cb - l) * saturation).clamp(0.0, 255.0);
    r[i] = cr;
    g[i] = cg;
    b[i] = cb;
  }

  // 3. 둘레와 견주어 윤곽 살리기: 둘레(3×3, 가운데에 가중치 2)의 평균 밝기보다 밝으면 더 밝게, 어두우면 더 어둡게
  final out = [...cells];
  for (final i in opaque) {
    final x = i % width, y = i ~/ width;
    var sum = 0.0, weight = 0.0;
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final nx = x + dx, ny = y + dy;
        if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
        final j = ny * width + nx;
        if (cells[j].$4 < 0.5) continue;
        final w = dx == 0 && dy == 0 ? 2.0 : 1.0;
        sum += lum(r[j], g[j], b[j]) * w;
        weight += w;
      }
    }
    final delta = (lum(r[i], g[i], b[i]) - sum / weight) * edge;
    out[i] = (
      (r[i] + delta).clamp(0.0, 255.0),
      (g[i] + delta).clamp(0.0, 255.0),
      (b[i] + delta).clamp(0.0, 255.0),
      cells[i].$4,
    );
  }
  return out;
}
