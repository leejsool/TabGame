/// 도트 그림의 대포 구성과 난이도를 정한다 (갤러리 사진으로 만든 단계용).
///
/// 대포 구성을 몇 가지 만들어 보고, 규칙대로 두는 사람(풀 수 있는 배치인지)과 아무렇게나 두는 사람이
/// 각각 어떻게 되는지를 돌려 보아 난이도를 매긴다. (많이 돌려야 해서 `compute`로 따로 돌리기 좋게 값만 주고받는다)
library;

import 'dart:math';

import 'dot_rules.dart';

/// 대포 구성과 난이도 평가.
class DotAssessment {
  const DotAssessment({
    required this.columns,
    required this.ammoLo,
    required this.ammoHi,
    required this.seed,
    required this.capacity,
    required this.randomWinRate,
    required this.difficulty,
    required this.solvable,
  });

  final int columns;
  final int ammoLo;
  final int ammoHi;
  final int seed;
  final int capacity;

  /// 아무렇게나 둔 사람이 이긴 비율 (0..1). 낮을수록 어렵다.
  final double randomWinRate;

  /// 0 = 쉬움 … 3 = 매우 어려움.
  final int difficulty;

  /// 규칙대로 두면 풀리는 배치인가 (항상 true로 만든다).
  final bool solvable;

  Map<String, dynamic> toMap() => {
        'columns': columns,
        'lo': ammoLo,
        'hi': ammoHi,
        'seed': seed,
        'cap': capacity,
        'rate': randomWinRate,
        'diff': difficulty,
        'ok': solvable,
      };

  static DotAssessment fromMap(Map<String, dynamic> m) => DotAssessment(
        columns: m['columns'] as int,
        ammoLo: m['lo'] as int,
        ammoHi: m['hi'] as int,
        seed: m['seed'] as int,
        capacity: m['cap'] as int,
        randomWinRate: (m['rate'] as num).toDouble(),
        difficulty: m['diff'] as int,
        solvable: m['ok'] as bool,
      );
}

/// 대기열 줄 수·탄 수 범위의 기본값 (도트 수와 색 수에 맞춘다).
({int columns, int lo, int hi}) defaultQueueShape(int pixels, int colors) {
  final perColor = pixels / max(1, colors);
  final columns = pixels < 120 ? 3 : (pixels < 260 ? 4 : 5);
  final lo = max(2, (perColor / 12).round());
  final hi = max(lo + 2, (perColor / 5).round());
  return (columns: columns, lo: lo, hi: hi);
}

/// 아무렇게나(절반의 확률로 아무 대포나 올리며) 둔 판이 이기는가.
bool randomPlayWins(DotGame g, Random r, {int maxSteps = 8000}) {
  while (g.stepCount < maxSteps) {
    if (g.won) return true;
    if (g.stuck) return false;
    final cols = [
      for (var i = 0; i < g.queue.length; i++)
        if (g.canDeploy(i)) i,
    ];
    if (cols.isNotEmpty && r.nextDouble() < 0.5) g.deploy(cols[r.nextInt(cols.length)]);
    g.step();
  }
  return false;
}

/// 이긴 비율로 난이도를 매긴다 (0 = 쉬움 … 3 = 매우 어려움).
int difficultyFromRate(double rate) {
  if (rate >= 0.9) return 0;
  if (rate >= 0.7) return 1;
  if (rate >= 0.45) return 2;
  return 3;
}

/// 정해 준 대포 구성([columns], 탄 [ammoLo]..[ammoHi])과 벨트 자리 [capacity]로, 규칙대로 두면 풀리는 씨앗을 찾고
/// 그 배치를 아무렇게나 [trials]번 둬 보아 난이도를 매긴다. 풀리는 씨앗이 없으면 solvable이 false다.
DotAssessment assessShape({
  required List<int> pixels,
  required int width,
  required int height,
  required int colors,
  required int capacity,
  required int columns,
  required int ammoLo,
  required int ammoHi,
  int trials = 40,
}) {
  for (var seed = 1; seed <= 12; seed++) {
    DotGame make() => DotGame(
          width: width,
          height: height,
          grid: List<int>.of(pixels),
          capacity: capacity,
          queue: buildQueue(pixels, colors, columns: columns, ammoLo: ammoLo, ammoHi: ammoHi, seed: seed),
        );
    if (!botSolves(make())) continue;
    final rnd = Random(seed * 7919);
    var wins = 0;
    for (var i = 0; i < trials; i++) {
      if (randomPlayWins(make(), rnd)) wins++;
    }
    final rate = wins / trials;
    return DotAssessment(
      columns: columns,
      ammoLo: ammoLo,
      ammoHi: ammoHi,
      seed: seed,
      capacity: capacity,
      randomWinRate: rate,
      difficulty: difficultyFromRate(rate),
      solvable: true,
    );
  }
  return DotAssessment(
    columns: columns,
    ammoLo: ammoLo,
    ammoHi: ammoHi,
    seed: 1,
    capacity: capacity,
    randomWinRate: 1,
    difficulty: 0,
    solvable: false,
  );
}

/// 그림 [pixels]([width]×[height], 색 [colors]가지)에 벨트 자리 [capacity]로 대포 구성을 정하고 난이도를 매긴다.
///
/// 풀리는 배치를 찾을 때까지 벨트 자리를 하나씩 늘려 가며 본다.
DotAssessment assessArt({
  required List<int> pixels,
  required int width,
  required int height,
  required int colors,
  required int capacity,
  int trials = 40,
}) {
  final count = pixels.where((c) => c != kDotEmpty).length;
  final shape = defaultQueueShape(count, colors);
  // 도트가 많으면 한 판 돌리는 데 오래 걸려서 시험 횟수를 줄인다
  final n = count > 700 ? min(trials, 24) : trials;
  DotAssessment? last;
  for (var cap = capacity; cap <= capacity + 3; cap++) {
    final a = assessShape(
      pixels: pixels,
      width: width,
      height: height,
      colors: colors,
      capacity: cap,
      columns: shape.columns,
      ammoLo: shape.lo,
      ammoHi: shape.hi,
      trials: n,
    );
    if (a.solvable) return a;
    last = a;
  }
  return last!;
}

/// `compute`에 넘기기 좋은 꼴 (값만 담은 Map 입출력).
Map<String, dynamic> assessArtMap(Map<String, dynamic> a) => assessArt(
      pixels: List<int>.from(a['px'] as List),
      width: a['w'] as int,
      height: a['h'] as int,
      colors: a['colors'] as int,
      capacity: a['cap'] as int,
    ).toMap();
