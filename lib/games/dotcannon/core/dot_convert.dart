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

double _dist2((double, double, double) a, (double, double, double) b) {
  // 사람 눈에 맞춘 가중치를 살짝 준 거리
  final dr = a.$1 - b.$1, dg = a.$2 - b.$2, db = a.$3 - b.$3;
  return 0.3 * dr * dr + 0.55 * dg * dg + 0.15 * db * db;
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
