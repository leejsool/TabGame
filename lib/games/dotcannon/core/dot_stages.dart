import 'package:flutter/material.dart';

import 'dot_levels.dart';
import 'dot_rules.dart';

/// 기본 그림의 묶음 (메뉴에서 묶음마다 한 줄로 보인다).
enum DotTheme {
  anime('애니메이션과 게임'),
  movie('영화'),
  art('명화');

  const DotTheme(this.label);

  final String label;
}

/// 사진에서 미리 뽑아 둔 기본 그림 한 장의 데이터 (`tool/make_dot_stages.dart`가 만든다).
///
/// 그림 칸은 한 줄로 이어 붙여 길이 부호화한다: 색 번호는 글자 하나('a'가 0번째 색, '.'은 빈 칸), 그 뒤에 이어진 칸 수.
/// 예: `a12.3b5`는 0번 색 12칸, 빈 칸 3칸, 1번 색 5칸.
class DotStageData {
  const DotStageData({
    required this.name,
    required this.width,
    required this.height,
    required this.colors,
    required this.runs,
    required this.columns,
    required this.ammoLo,
    required this.ammoHi,
    required this.seed,
    required this.capacity,
    this.theme = DotTheme.art,
  });

  final String name;
  final int width;
  final int height;

  /// 0xAARRGGBB 색 목록.
  final List<int> colors;
  final String runs;
  final int columns;
  final int ammoLo;
  final int ammoHi;
  final int seed;
  final int capacity;
  final DotTheme theme;

  DotLevel toLevel() => DotLevel(
        id: 'b:$name',
        name: name,
        colors: [for (final c in colors) Color(c)],
        pixels: decodeDotRuns(runs),
        width: width,
        height: height,
        columns: columns,
        ammoLo: ammoLo,
        ammoHi: ammoHi,
        seed: seed,
        capacity: capacity,
        difficulty: dotStageHardness[name] ?? 0,
      );
}

/// 해 보니 유난히 어려운 기본 그림 (그림 카드 왼쪽 위에 표시). 2 = 어려움(HARD), 3 = 매우 어려움(VERY HARD).
/// (`dot_stage_data.dart`는 도구가 다시 만드는 파일이라 여기에 따로 둔다)
const Map<String, int> dotStageHardness = {
  '절규': 2,
  '아이언맨': 3,
};

/// 그림 칸 목록을 길이 부호화 문자열로 바꾼다 (색은 26가지까지).
String encodeDotRuns(List<int> pixels) {
  final out = StringBuffer();
  var i = 0;
  while (i < pixels.length) {
    var j = i;
    while (j < pixels.length && pixels[j] == pixels[i]) {
      j++;
    }
    out
      ..write(pixels[i] == kDotEmpty ? '.' : String.fromCharCode(0x61 + pixels[i]))
      ..write(j - i);
    i = j;
  }
  return out.toString();
}

/// [encodeDotRuns]의 거꾸로.
List<int> decodeDotRuns(String runs) {
  final out = <int>[];
  var i = 0;
  while (i < runs.length) {
    final ch = runs.codeUnitAt(i++);
    final color = ch == 0x2E ? kDotEmpty : ch - 0x61;
    var n = 0;
    while (i < runs.length && runs.codeUnitAt(i) >= 0x30 && runs.codeUnitAt(i) <= 0x39) {
      n = n * 10 + runs.codeUnitAt(i++) - 0x30;
    }
    out.addAll(List.filled(n, color));
  }
  return out;
}
