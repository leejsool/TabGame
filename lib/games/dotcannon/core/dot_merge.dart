import 'dart:ui' show Color;

import 'dot_convert.dart';
import 'dot_rules.dart';

/// 색 하나를 'RRGGBB' 글자로 (도트 그림 편집 도구와 `stages.json`의 "merge"가 쓴다).
String dotHex(Color c) => (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

/// 애매한 색끼리 합친다: [merges]의 (앞 색, 뒤 색)마다 앞 색 칸을 모두 뒤 색으로 칠하고 앞 색은 목록에서 뺀다.
/// 차례대로 적용하므로 앞에서 합친 결과 색을 뒤에서 다시 합칠 수 있다.
/// 그림에 없는 색 짝은 건너뛰고 [skipped]로 알려 준다.
DotArt mergeDotColors(DotArt art, List<(String, String)> merges, {void Function(String from, String to)? skipped}) {
  var colors = [...art.colors];
  var pixels = [...art.pixels];
  for (final (from, to) in merges) {
    final a = colors.indexWhere((c) => dotHex(c) == from.toUpperCase());
    final b = colors.indexWhere((c) => dotHex(c) == to.toUpperCase());
    if (a < 0 || b < 0 || a == b) {
      skipped?.call(from, to);
      continue;
    }
    pixels = [
      for (final p in pixels)
        if (p == kDotEmpty)
          p
        else if (p == a)
          (b > a ? b - 1 : b)
        else
          (p > a ? p - 1 : p),
    ];
    colors = [...colors]..removeAt(a);
  }
  return DotArt(width: art.width, height: art.height, pixels: pixels, colors: colors);
}
