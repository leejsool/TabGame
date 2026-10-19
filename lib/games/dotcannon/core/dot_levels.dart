import 'package:flutter/material.dart';

import 'dot_rules.dart';
import 'dot_stage_data.dart';

/// 도트 캐논의 한 단계: 액자 속 도트 그림과 대포 구성.
///
/// 내장 단계([dotLevels])와, 갤러리 사진으로 만든 단계(`custom`)가 같은 모양이다.
class DotLevel {
  DotLevel({
    required this.id,
    required this.name,
    required this.colors,
    required this.pixels,
    required this.width,
    required this.height,
    required this.columns,
    required this.ammoLo,
    required this.ammoHi,
    required this.seed,
    this.capacity = 5,
    this.custom = false,
    this.difficulty = 0,
    this.createdAt = 0,
  });

  /// 내장 단계를 글자 그림으로 만든다. [palette]의 순서가 곧 색 번호, '.'은 빈 칸.
  /// 글자 한 칸을 [scale]×[scale]개의 도트로 키워서, 같은 그림을 훨씬 촘촘한 도트로 만든다.
  factory DotLevel.rows({
    required String name,
    required Map<String, Color> palette,
    required List<String> rows,
    required int columns,
    required int ammoLo,
    required int ammoHi,
    required int seed,
    int capacity = 5,
    int scale = 3,
  }) {
    final keys = palette.keys.toList();
    final width = rows.first.length * scale;
    return DotLevel(
      id: 'b:$name',
      name: name,
      colors: palette.values.toList(),
      pixels: [
        for (final r in rows)
          for (var k = 0; k < scale; k++)
            for (final ch in r.split('')) ...List.filled(scale, ch == '.' ? kDotEmpty : keys.indexOf(ch)),
      ],
      width: width,
      height: rows.length * scale,
      columns: columns,
      ammoLo: ammoLo,
      ammoHi: ammoHi,
      seed: seed,
      capacity: capacity,
    );
  }

  /// 단계를 알아보는 이름표 (내장은 `b:이름`, 내가 만든 것은 `c:만든 시각`).
  final String id;
  final String name;
  final List<Color> colors;

  /// 그림의 색 번호 (줄 단위로 이어 붙임, 빈 칸은 [kDotEmpty]).
  final List<int> pixels;
  final int width;
  final int height;

  /// 대기열 줄 수.
  final int columns;

  /// 대포 한 대의 탄 수 범위.
  final int ammoLo;
  final int ammoHi;

  /// 대포를 섞는 씨앗 (풀 수 있는 배치로 골라 둔 값 — `test/dotcannon/dot_levels_test.dart`가 확인한다).
  final int seed;

  /// 벨트에 한꺼번에 올려 둘 수 있는 대포 수.
  final int capacity;

  /// 갤러리 사진으로 만든 단계인가.
  final bool custom;

  /// 매겨 둔 난이도 (0 = 쉬움 … 3 = 매우 어려움). 내장 단계는 쓰지 않는다.
  final int difficulty;

  final int createdAt;

  int get colorCount => colors.length;
  int get pixelCount => pixels.where((c) => c != kDotEmpty).length;

  /// 처음 판.
  DotGame newGame() {
    final grid = List<int>.of(pixels);
    return DotGame(
      width: width,
      height: height,
      grid: grid,
      capacity: capacity,
      queue: buildQueue(grid, colorCount, columns: columns, ammoLo: ammoLo, ammoHi: ammoHi, seed: seed),
    );
  }

  DotLevel copyWith({String? id, String? name, int? seed, int? capacity, int? columns, int? ammoLo, int? ammoHi, int? difficulty}) =>
      DotLevel(
        id: id ?? this.id,
        name: name ?? this.name,
        colors: colors,
        pixels: pixels,
        width: width,
        height: height,
        columns: columns ?? this.columns,
        ammoLo: ammoLo ?? this.ammoLo,
        ammoHi: ammoHi ?? this.ammoHi,
        seed: seed ?? this.seed,
        capacity: capacity ?? this.capacity,
        custom: custom,
        difficulty: difficulty ?? this.difficulty,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'colors': [for (final c in colors) c.toARGB32()],
        'px': pixels,
        'w': width,
        'h': height,
        'cols': columns,
        'lo': ammoLo,
        'hi': ammoHi,
        'seed': seed,
        'cap': capacity,
        'custom': custom,
        'diff': difficulty,
        'at': createdAt,
      };

  static DotLevel fromJson(Map<String, dynamic> j) => DotLevel(
        id: j['id'] as String,
        name: j['name'] as String,
        colors: [for (final c in j['colors'] as List) Color(c as int)],
        pixels: List<int>.from(j['px'] as List),
        width: j['w'] as int,
        height: j['h'] as int,
        columns: j['cols'] as int,
        ammoLo: j['lo'] as int,
        ammoHi: j['hi'] as int,
        seed: j['seed'] as int,
        capacity: j['cap'] as int,
        custom: j['custom'] == true,
        difficulty: (j['diff'] as int?) ?? 0,
        createdAt: (j['at'] as int?) ?? 0,
      );
}

/// 난이도 이름 (0 = 쉬움 … 3 = 매우 어려움).
const List<String> dotDifficultyNames = ['쉬움', '보통', '어려움', '매우 어려움'];

const Color _red = Color(0xFFE5484D);
const Color _white = Color(0xFFFFFFFF);
const Color _yellow = Color(0xFFF7C948);
const Color _orange = Color(0xFFF08A24);
const Color _green = Color(0xFF3FA34D);
const Color _brown = Color(0xFF8A5A36);
const Color _pink = Color(0xFFF58FB0);
const Color _navy = Color(0xFF26324D);
const Color _mint = Color(0xFF7FD6B4);
const Color _violet = Color(0xFFA48BE8);

/// 모든 기본 단계. 손으로 만든 그림이 앞에 오고, 그 뒤에 사진에서 뽑은 그림([dotStageData])이 쉬운 것부터 이어져요.
/// 메뉴에서는 앞 단계를 깨야 다음 단계가 열려요.
final List<DotLevel> dotLevels = [
  ..._handmade,
  for (final d in dotStageData) d.toLevel(),
];

/// 손으로 만든 첫 단계들. (글자 그림 한 칸이 3x3 도트가 되어 도트가 360개에서 1100개쯤 돼요.)
final List<DotLevel> _handmade = [
  DotLevel.rows(
    name: '하트',
    palette: {'R': _red, 'W': _white},
    rows: [
      '.RR..RR.',
      'RWWRRRRR',
      'RWRRRRRR',
      'RRRRRRRR',
      '.RRRRRR.',
      '..RRRR..',
      '...RR...',
    ],
    columns: 5,
    ammoLo: 15,
    ammoHi: 36,
    seed: 1,
    capacity: 5,
  ),
  DotLevel.rows(
    name: '아이스크림',
    palette: {'P': _pink, 'W': _white, 'M': _mint, 'Y': _yellow, 'B': _brown},
    rows: [
      '...PPPP...',
      '..PPWPPP..',
      '.PPWPPPPP.',
      '.PPPPPPPP.',
      'MMMMMMMMMM',
      '.MMMWMMMM.',
      '.MMMMMMMM.',
      '..MMMMMM..',
      'YYYYYYYYYY',
      '.YBYBYBYB.',
      '..YBYBYB..',
      '...BYBY...',
      '....BY....',
      '.....B....',
    ],
    columns: 5,
    ammoLo: 13,
    ammoHi: 32,
    seed: 1,
    capacity: 3,
  ),
  DotLevel.rows(
    name: '고양이',
    palette: {'O': _orange, 'P': _pink, 'G': _green, 'K': _navy, 'W': _white},
    rows: [
      '.OO......OO.',
      '.OPO....OPO.',
      '.OOOOOOOOOO.',
      'OOOOOOOOOOOO',
      'OOGKOOOOGKOO',
      'OOGGOOOOGGOO',
      'OOOOOPPOOOOO',
      'OOWOOPPOOWOO',
      'OOWWOOOOWWOO',
      '.OOOWWWWOOO.',
      '..OOOOOOOO..',
    ],
    columns: 5,
    ammoLo: 17,
    ammoHi: 40,
    seed: 1,
    capacity: 3,
  ),
  DotLevel.rows(
    name: '유령',
    palette: {'L': _violet, 'W': _white, 'K': _navy, 'P': _pink, 'R': _red},
    rows: [
      '....LLLL....',
      '..LLLLLLLL..',
      '.LLLLLLLLLL.',
      '.LLWWLLWWLL.',
      'LLLWKLLLWKLL',
      'LLLWWLLLWWLL',
      'LLLLLLLLLLLL',
      'LLPPLLLLPPLL',
      'LLLLLRRLLLLL',
      'LLLLLLLLLLLL',
      'LLLLLLLLLLLL',
      'LL..LLLL..LL',
    ],
    columns: 5,
    ammoLo: 19,
    ammoHi: 45,
    seed: 1,
    capacity: 3,
  ),
];
