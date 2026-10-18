/// 사진 → 도트 그림 변환 (화면과 상관없는 순수한 계산).
library;

import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'dot_rules.dart';

/// 변환된 도트 그림.
class DotArt {
  const DotArt({required this.width, required this.height, required this.pixels, required this.colors});

  final int width;
  final int height;

  /// 색 번호 (줄 단위로 이어 붙임, 빈 칸은 [kDotEmpty]).
  final List<int> pixels;
  final List<Color> colors;

  int get pixelCount => pixels.where((c) => c != kDotEmpty).length;
}

/// 사진의 가로세로 비율을 지키면서 긴 쪽이 [longSide]칸이 되는 도트 그림 크기.
(int, int) dotSizeFor(int imageWidth, int imageHeight, int longSide) {
  final scale = longSide / max(imageWidth, imageHeight);
  final w = (imageWidth * scale).round().clamp(4, longSide);
  final h = (imageHeight * scale).round().clamp(4, longSide);
  return (w, h);
}

/// RGBA 그림([sw]×[sh])을 [dw]×[dh] 칸으로 줄이며 칸마다 색을 평균 낸다. 투명한 곳은 빼고 평균 낸다.
/// 결과는 칸마다 (r, g, b, 불투명한 정도 0..1).
List<(double, double, double, double)> boxDownsample(Uint8List rgba, int sw, int sh, int dw, int dh) {
  final out = <(double, double, double, double)>[];
  for (var y = 0; y < dh; y++) {
    final y0 = (y * sh / dh).floor(), y1 = max(y0 + 1, ((y + 1) * sh / dh).ceil()).clamp(0, sh);
    for (var x = 0; x < dw; x++) {
      final x0 = (x * sw / dw).floor(), x1 = max(x0 + 1, ((x + 1) * sw / dw).ceil()).clamp(0, sw);
      double r = 0, g = 0, b = 0, a = 0;
      var n = 0;
      for (var yy = y0; yy < y1; yy++) {
        for (var xx = x0; xx < x1; xx++) {
          final i = (yy * sw + xx) * 4;
          final al = rgba[i + 3] / 255;
          r += rgba[i] * al;
          g += rgba[i + 1] * al;
          b += rgba[i + 2] * al;
          a += al;
          n++;
        }
      }
      if (a <= 0 || n == 0) {
        out.add((0, 0, 0, 0));
      } else {
        out.add((r / a, g / a, b / a, a / n));
      }
    }
  }
  return out;
}

/// 팔레트의 두 색이 이만큼(눈에 보이는 색 차이, CIE Lab 거리) 이상은 달라야 따로 센다. 그보다 비슷하면 한 색으로 합친다.
/// (사진을 줄이면 같은 사물의 밝고 어두운 부분이 서로 다른 색 번호가 되어, 화면에서는 같은 색처럼 보이는데 다른 대포·다른 탄약으로
/// 갈려 헷갈린다. 또렷하게 다른 색만 남기려고 둔다.)
const double kDotMinColorGap = 26;

/// 합치는 기준을 낮추어 갈 때의 바닥. 이보다 가까운 색은 어떻게 해도 한 색으로 본다.
const double kDotFloorColorGap = 8;

/// 두 색의 눈에 보이는 차이 (CIE Lab 거리, 0이면 같은 색, 보통 20을 넘으면 한눈에 다른 색).
double dotColorGap(Color a, Color b) =>
    _labGap(_lab((a.r * 255, a.g * 255, a.b * 255)), _lab((b.r * 255, b.g * 255, b.b * 255)));

(double, double, double) _lab((double, double, double) c) {
  double lin(double v) {
    final x = v / 255;
    return x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4).toDouble();
  }

  final r = lin(c.$1), g = lin(c.$2), b = lin(c.$3);
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  double f(double t) => t > 0.008856 ? pow(t, 1 / 3).toDouble() : 7.787 * t + 16 / 116;
  return (116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z)));
}

double _labGap((double, double, double) a, (double, double, double) b) {
  final dl = a.$1 - b.$1, da = a.$2 - b.$2, db = a.$3 - b.$3;
  return sqrt(dl * dl + da * da + db * db);
}

double _dist2((double, double, double) a, (double, double, double) b) {
  // 사람 눈에 맞춘 가중치를 살짝 준 거리
  final dr = a.$1 - b.$1, dg = a.$2 - b.$2, db = a.$3 - b.$3;
  return 0.3 * dr * dr + 0.55 * dg * dg + 0.15 * db * db;
}

/// [centers]·[assign]의 복사본에서 서로 [minGap]보다 가까운 색을 한 색으로 합친다 (많이 쓰인 쪽으로, 색은 쓰인 칸 수대로 섞는다).
/// 합친 중심들, 칸별 색 번호, 남은 색 수를 돌려준다. 받은 목록은 건드리지 않는다.
(List<(double, double, double)>, List<int>, int) _mergeClose(
  List<(double, double, double)> centersIn,
  List<int> assignIn,
  List<int> opaque,
  double minGap,
) {
  final centers = [...centersIn];
  final assign = [...assignIn];
  while (true) {
    final use = List<int>.filled(centers.length, 0);
    for (final i in opaque) {
      use[assign[i]]++;
    }
    final labs = [for (final c in centers) _lab(c)];
    var bestA = -1, bestB = -1;
    var bestGap = minGap;
    for (var a = 0; a < centers.length; a++) {
      if (use[a] == 0) continue;
      for (var b = a + 1; b < centers.length; b++) {
        if (use[b] == 0) continue;
        final g = _labGap(labs[a], labs[b]);
        if (g < bestGap) {
          bestGap = g;
          bestA = a;
          bestB = b;
        }
      }
    }
    if (bestA < 0) return (centers, assign, use.where((u) => u > 0).length);
    final keep = use[bestA] >= use[bestB] ? bestA : bestB, drop = keep == bestA ? bestB : bestA;
    final wk = use[keep].toDouble(), wd = use[drop].toDouble(), w = wk + wd;
    centers[keep] = (
      (centers[keep].$1 * wk + centers[drop].$1 * wd) / w,
      (centers[keep].$2 * wk + centers[drop].$2 * wd) / w,
      (centers[keep].$3 * wk + centers[drop].$3 * wd) / w,
    );
    for (final i in opaque) {
      if (assign[i] == drop) assign[i] = keep;
    }
  }
}

/// 칸별 색([cells])을 [colors]가지로 줄여 도트 그림을 만든다.
///
/// [removeBackground]가 true면, 가장자리에서 가장 많이 보이는 색을 가장자리부터 이어진 만큼 지운다.
DotArt quantizeCells(
  List<(double, double, double, double)> cells,
  int width,
  int height, {
  required int colors,
  bool removeBackground = false,
}) {
  final opaque = <int>[];
  for (var i = 0; i < cells.length; i++) {
    if (cells[i].$4 >= 0.5) opaque.add(i);
  }
  if (opaque.isEmpty) {
    return DotArt(width: width, height: height, pixels: List.filled(width * height, kDotEmpty), colors: const []);
  }
  final k = min(colors, opaque.length).clamp(1, 16);
  (double, double, double) rgb(int i) => (cells[i].$1, cells[i].$2, cells[i].$3);

  // 가장 멀리 떨어진 색부터 차례로 고른 처음 중심
  final centers = <(double, double, double)>[];
  var mr = 0.0, mg = 0.0, mb = 0.0;
  for (final i in opaque) {
    mr += cells[i].$1;
    mg += cells[i].$2;
    mb += cells[i].$3;
  }
  final mean = (mr / opaque.length, mg / opaque.length, mb / opaque.length);
  var first = opaque.first;
  var far = -1.0;
  for (final i in opaque) {
    final d = _dist2(rgb(i), mean);
    if (d > far) {
      far = d;
      first = i;
    }
  }
  centers.add(rgb(first));
  while (centers.length < k) {
    var best = -1, bestD = -1.0;
    for (final i in opaque) {
      var d = double.infinity;
      for (final c in centers) {
        d = min(d, _dist2(rgb(i), c));
      }
      if (d > bestD) {
        bestD = d;
        best = i;
      }
    }
    if (bestD <= 0) break;
    centers.add(rgb(best));
  }

  // k-평균으로 중심을 다듬는다
  final assign = List<int>.filled(cells.length, -1);
  for (var iter = 0; iter < 10; iter++) {
    for (final i in opaque) {
      var bi = 0;
      var bd = double.infinity;
      for (var c = 0; c < centers.length; c++) {
        final d = _dist2(rgb(i), centers[c]);
        if (d < bd) {
          bd = d;
          bi = c;
        }
      }
      assign[i] = bi;
    }
    final sum = List.generate(centers.length, (_) => [0.0, 0.0, 0.0, 0.0]);
    for (final i in opaque) {
      final s = sum[assign[i]];
      s[0] += cells[i].$1;
      s[1] += cells[i].$2;
      s[2] += cells[i].$3;
      s[3] += 1;
    }
    for (var c = 0; c < centers.length; c++) {
      if (sum[c][3] > 0) centers[c] = (sum[c][0] / sum[c][3], sum[c][1] / sum[c][3], sum[c][2] / sum[c][3]);
    }
  }

  // 너무 적게 쓰인 색은 가장 가까운 다른 색으로 합친다
  final minUse = max(1, (opaque.length * 0.008).round());
  var merged = true;
  while (merged) {
    merged = false;
    final use = List<int>.filled(centers.length, 0);
    for (final i in opaque) {
      use[assign[i]]++;
    }
    for (var c = 0; c < centers.length; c++) {
      if (use[c] == 0 || use[c] >= minUse) continue;
      var bi = -1;
      var bd = double.infinity;
      for (var o = 0; o < centers.length; o++) {
        if (o == c || use[o] == 0) continue;
        final d = _dist2(centers[c], centers[o]);
        if (d < bd) {
          bd = d;
          bi = o;
        }
      }
      if (bi < 0) continue;
      for (final i in opaque) {
        if (assign[i] == c) assign[i] = bi;
      }
      merged = true;
      break;
    }
  }

  // 눈으로 구분이 안 될 만큼 비슷한 색은 한 색으로 합친다. 기준을 너무 세게 잡으면 사진처럼 색이 부드럽게 이어지는 그림은 색이 서너 가지만
  // 남으니, 가장 센 기준([kDotMinColorGap])부터 조금씩 낮추면서 "달라고 한 색 수(또는 눈으로 구분되는 만큼)"가 남는 가장 센 기준을 고른다.
  final floorCount = _mergeClose(centers, assign, opaque, kDotFloorColorGap).$3;
  final wanted = min(k, floorCount);
  var merged2 = _mergeClose(centers, assign, opaque, kDotMinColorGap);
  for (var gap = kDotMinColorGap - 2; merged2.$3 < wanted && gap >= kDotFloorColorGap; gap -= 2) {
    merged2 = _mergeClose(centers, assign, opaque, gap);
  }
  centers
    ..clear()
    ..addAll(merged2.$1);
  assign.setAll(0, merged2.$2);

  final grid = List<int>.filled(cells.length, kDotEmpty);
  for (final i in opaque) {
    grid[i] = assign[i];
  }

  if (removeBackground) {
    final count = <int, int>{};
    void border(int x, int y) {
      final c = grid[y * width + x];
      if (c != kDotEmpty) count[c] = (count[c] ?? 0) + 1;
    }

    for (var x = 0; x < width; x++) {
      border(x, 0);
      border(x, height - 1);
    }
    for (var y = 0; y < height; y++) {
      border(0, y);
      border(width - 1, y);
    }
    if (count.isNotEmpty) {
      final bg = count.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      final stack = <int>[];
      void push(int x, int y) {
        if (x < 0 || y < 0 || x >= width || y >= height) return;
        final i = y * width + x;
        if (grid[i] == bg) {
          grid[i] = kDotEmpty;
          stack.add(i);
        }
      }

      for (var x = 0; x < width; x++) {
        push(x, 0);
        push(x, height - 1);
      }
      for (var y = 0; y < height; y++) {
        push(0, y);
        push(width - 1, y);
      }
      while (stack.isNotEmpty) {
        final i = stack.removeLast();
        final x = i % width, y = i ~/ width;
        push(x + 1, y);
        push(x - 1, y);
        push(x, y + 1);
        push(x, y - 1);
      }
    }
  }

  // 쓰이는 색만 남겨 번호를 다시 매긴다 (많이 쓰인 색부터)
  final use = <int, int>{};
  for (final c in grid) {
    if (c != kDotEmpty) use[c] = (use[c] ?? 0) + 1;
  }
  final order = use.keys.toList()..sort((a, b) => use[b]!.compareTo(use[a]!));
  final remap = {for (var i = 0; i < order.length; i++) order[i]: i};
  Color toColor((double, double, double) c) =>
      Color.fromARGB(255, c.$1.round().clamp(0, 255), c.$2.round().clamp(0, 255), c.$3.round().clamp(0, 255));
  return DotArt(
    width: width,
    height: height,
    pixels: [for (final c in grid) c == kDotEmpty ? kDotEmpty : remap[c]!],
    colors: [for (final c in order) toColor(centers[c])],
  );
}
