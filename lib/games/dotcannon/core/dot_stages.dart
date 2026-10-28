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
        id: dotStageLegacyIds[name] ?? 'b:$name',
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
      );
}

/// 이름을 바꾼 기본 그림의 옛 번호. 기록·클리어 표시가 번호로 저장되니, 이름을 바꿔도 번호는 그대로 둔다.
/// (`dot_stage_data.dart`는 도구가 다시 만드는 파일이라 여기에 따로 둔다)
const Map<String, String> dotStageLegacyIds = {
  '한복 하치와레': 'b:파란 왕관 친구',
};

/// 기본 그림의 대략적인 난이도 별 (1 = 쉬움 … 5 = 아주 어려움, 그림 카드 왼쪽 위에 표시).
/// 규칙대로 두다가 가끔 아무 대포나 올리는 사람과 아무렇게나 두는 사람을 여러 번 돌려 이긴 비율에, 색 수·도트 수를 더해 대략 매겼다.
/// 해 보니 흉내보다 어려웠던 그림(절규·토끼)은 올려 잡았다. (`dot_stage_data.dart`는 도구가 다시 만드는 파일이라 여기에 따로 둔다)
const Map<String, int> dotStageStars = {
  // 손으로 만든 그림
  '하트': 1, '아이스크림': 1, '고양이': 1, '유령': 1,
  // 애니메이션과 게임
  '마리오': 1, '파이리': 3, '토끼': 5, '슈퍼 마리오': 3, '피카츄': 3, '한복 하치와레': 2, '푸른 용': 5, '쿠파': 5,
  '더피': 2, '액자 속 강아지': 2, '짱구 친구들': 3, '치이카와 세이렌': 4, 'Hello Kitty': 1, '뚱이': 1,
  '고양이 팬케이크 코스터': 4, '닉': 2, '공룡 옷 Kitty': 2, '주디': 3, '시바용사': 2, '마녀 Kitty': 4,
  '강아지 배달원': 3, '어린 왕자': 4, '차곡차곡 쌓인 고양이': 5,
  // 영화
  '아이언맨': 5,
  // 명화
  '거대한 파도': 1, '해바라기': 2, '절규': 4, '지구': 2, '진주 귀걸이 소녀': 4, '키스': 5, '별이 빛나는 밤': 4,
  '고흐 자화상': 5, '모나리자': 5,
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
