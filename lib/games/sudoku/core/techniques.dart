import 'grid.dart';
import 'techniques_master.dart';

/// 사람이 스도쿠를 풀 때 쓰는 논리 기술. [level]이 높을수록 어렵다.
enum Technique {
  nakedSingle(1, '네이키드 싱글'),
  hiddenSingle(1, '히든 싱글'),
  pointing(2, '포인팅'),
  claiming(2, '클레이밍'),
  nakedPair(2, '네이키드 페어'),
  hiddenPair(2, '히든 페어'),
  nakedTriple(3, '네이키드 트리플'),
  hiddenTriple(3, '히든 트리플'),
  nakedQuad(3, '네이키드 쿼드'),
  xWing(4, 'X-윙'),
  xyWing(4, 'XY-윙'),
  xyzWing(4, 'XYZ-윙'),
  swordfish(4, '스워드피시'),

  // Lv.5 한 숫자 패턴 · 유일해 기법, Lv.6 체인·ALS, Lv.7 가정법 (심화 기술 연습에서 배운다)
  skyscraper(5, '스카이스크래퍼'),
  twoStringKite(5, '투스트링 카이트'),
  emptyRectangle(5, '빈 직사각형'),
  uniqueRectangle(5, '유니크 직사각형'),
  bugPlusOne(5, 'BUG+1'),
  xyChain(6, 'XY-체인'),
  xChain(6, 'X-체인'),
  alsXz(6, 'ALS-XZ'),
  forcingChain(7, '가정법 (포싱 체인)'),

  /// 논리 기술로 풀리는 다음 단계를 찾지 못했을 때(힌트 전용).
  reveal(9, '정답 확인');

  const Technique(this.level, this.label);

  final int level;
  final String label;
}

/// 논리 풀이의 한 단계: 칸에 숫자를 넣거나, 후보 숫자를 지운다.
class SolveStep {
  const SolveStep({
    required this.technique,
    this.cells = const [],
    this.digits = 0,
    this.unit = -1,
    this.units = const [],
    this.coverUnits = const [],
    this.placeCell = -1,
    this.placeDigit = 0,
    this.eliminations = const {},
    this.note = '',
  });

  final Technique technique;

  /// 패턴을 이루는 칸들 (싱글이면 대상 칸).
  final List<int> cells;

  /// 패턴과 관련된 숫자들(마스크).
  final int digits;

  /// 패턴이 놓인 유닛 (없으면 -1).
  final int unit;

  /// 보조 유닛들 (포인팅/클레이밍의 줄, 피시의 기준 줄).
  final List<int> units;

  /// 피시의 커버 줄.
  final List<int> coverUnits;

  final int placeCell;
  final int placeDigit;

  /// 칸 → 지울 후보 마스크.
  final Map<int, int> eliminations;

  /// 기술마다 따로 쓰는 덧붙임 (유니크 직사각형의 타입, ALS의 숫자들, 가정법의 모순 설명 …).
  final String note;

  bool get isPlacement => placeCell >= 0;
}

/// 칸별 후보 숫자 격자.
class CandidateGrid {
  CandidateGrid._(this.values, this.cand);

  /// [values]의 숫자들로부터 후보를 계산한다. [eliminated]는 이미 확정적으로 지운 후보.
  factory CandidateGrid.fromValues(List<int> values, {List<int>? eliminated}) {
    final v = List<int>.of(values);
    final c = List<int>.filled(81, 0);
    for (var i = 0; i < 81; i++) {
      if (v[i] != 0) continue;
      var m = kAllDigits;
      for (final p in peers[i]) {
        if (v[p] != 0) m &= ~bit(v[p]);
      }
      if (eliminated != null) m &= ~eliminated[i];
      c[i] = m;
    }
    return CandidateGrid._(v, c);
  }

  final List<int> values;
  final List<int> cand;

  bool get isSolved => !values.contains(0);

  bool get hasContradiction {
    for (var i = 0; i < 81; i++) {
      if (values[i] == 0 && cand[i] == 0) return true;
    }
    return false;
  }

  void place(int cell, int digit) {
    values[cell] = digit;
    cand[cell] = 0;
    final m = ~bit(digit);
    for (final p in peers[cell]) {
      cand[p] &= m;
    }
  }

  void apply(SolveStep step) {
    if (step.isPlacement) place(step.placeCell, step.placeDigit);
    step.eliminations.forEach((cell, mask) => cand[cell] &= ~mask);
  }
}

typedef _Finder = SolveStep? Function(CandidateGrid g);

/// 현재 후보 격자에서 가장 쉬운 논리 단계를 찾는다.
class StepFinder {
  StepFinder._();

  static final List<(int, _Finder)> _finders = [
    (1, _nakedSingle),
    (1, _hiddenSingle),
    (2, _pointing),
    (2, _claiming),
    (2, (g) => _nakedSubset(g, 2)),
    (2, (g) => _hiddenSubset(g, 2)),
    (3, (g) => _nakedSubset(g, 3)),
    (3, (g) => _hiddenSubset(g, 3)),
    (3, (g) => _nakedSubset(g, 4)),
    (4, (g) => _fish(g, 2)),
    (4, _xyWing),
    (4, _xyzWing),
    (4, (g) => _fish(g, 3)),
    (5, MasterFinders.skyscraper),
    (5, MasterFinders.twoStringKite),
    (5, MasterFinders.emptyRectangle),
    (5, MasterFinders.uniqueRectangle),
    (5, MasterFinders.bugPlusOne),
    (6, MasterFinders.xyChain),
    (6, MasterFinders.xChain),
    (6, MasterFinders.alsXz),
    (7, MasterFinders.forcingChain),
  ];

  /// [maxLevel] 이하의 기술만 사용해서 다음 단계를 찾는다. 없으면 null.
  static SolveStep? next(CandidateGrid g, {int maxLevel = 4}) {
    for (final (level, finder) in _finders) {
      if (level > maxLevel) continue;
      final s = finder(g);
      if (s != null) return s;
    }
    return null;
  }

  // ── 싱글 ──

  static SolveStep? _nakedSingle(CandidateGrid g) {
    for (var i = 0; i < 81; i++) {
      final m = g.cand[i];
      if (m != 0 && (m & (m - 1)) == 0) {
        return SolveStep(
          technique: Technique.nakedSingle,
          cells: [i],
          digits: m,
          placeCell: i,
          placeDigit: m.bitLength,
        );
      }
    }
    return null;
  }

  static const List<int> _unitOrder = [
    18, 19, 20, 21, 22, 23, 24, 25, 26, //
    0, 1, 2, 3, 4, 5, 6, 7, 8,
    9, 10, 11, 12, 13, 14, 15, 16, 17,
  ];

  static SolveStep? _hiddenSingle(CandidateGrid g) {
    for (final u in _unitOrder) {
      for (var d = 1; d <= 9; d++) {
        final b = bit(d);
        var count = 0;
        var pos = -1;
        for (final c in unitCells[u]) {
          if (g.cand[c] & b != 0) {
            count++;
            pos = c;
          }
        }
        if (count == 1) {
          return SolveStep(
            technique: Technique.hiddenSingle,
            cells: [pos],
            digits: b,
            unit: u,
            placeCell: pos,
            placeDigit: d,
          );
        }
      }
    }
    return null;
  }

  // ── 교차(포인팅/클레이밍) ──

  static List<int> _cellsWith(CandidateGrid g, List<int> cells, int b) => [
        for (final c in cells)
          if (g.cand[c] & b != 0) c,
      ];

  /// 박스 안의 후보가 한 줄에 몰려 있으면, 그 줄의 박스 밖 칸에서 후보를 지운다.
  static SolveStep? _pointing(CandidateGrid g) {
    for (var box = 0; box < 9; box++) {
      final boxUnit = 18 + box;
      for (var d = 1; d <= 9; d++) {
        final b = bit(d);
        final cells = _cellsWith(g, unitCells[boxUnit], b);
        if (cells.length < 2) continue;
        for (final byRow in [true, false]) {
          final line = byRow ? rowOf[cells.first] : colOf[cells.first];
          final sameLine = cells.every(
            (c) => (byRow ? rowOf[c] : colOf[c]) == line,
          );
          if (!sameLine) continue;
          final lineUnit = byRow ? line : 9 + line;
          final elim = <int, int>{
            for (final c in unitCells[lineUnit])
              if (boxOf[c] != box && g.cand[c] & b != 0) c: b,
          };
          if (elim.isEmpty) continue;
          return SolveStep(
            technique: Technique.pointing,
            cells: cells,
            digits: b,
            unit: boxUnit,
            units: [lineUnit],
            eliminations: elim,
          );
        }
      }
    }
    return null;
  }

  /// 줄 안의 후보가 한 박스에 몰려 있으면, 그 박스의 줄 밖 칸에서 후보를 지운다.
  static SolveStep? _claiming(CandidateGrid g) {
    for (var u = 0; u < 18; u++) {
      for (var d = 1; d <= 9; d++) {
        final b = bit(d);
        final cells = _cellsWith(g, unitCells[u], b);
        if (cells.length < 2) continue;
        final box = boxOf[cells.first];
        if (!cells.every((c) => boxOf[c] == box)) continue;
        final elim = <int, int>{
          for (final c in unitCells[18 + box])
            if (!unitCells[u].contains(c) && g.cand[c] & b != 0) c: b,
        };
        if (elim.isEmpty) continue;
        return SolveStep(
          technique: Technique.claiming,
          cells: cells,
          digits: b,
          unit: u,
          units: [18 + box],
          eliminations: elim,
        );
      }
    }
    return null;
  }

  // ── 부분집합 ──

  static Iterable<List<int>> _combos(
    List<int> items,
    int k, [
    int start = 0,
    List<int>? cur,
  ]) sync* {
    cur ??= [];
    if (cur.length == k) {
      yield List<int>.of(cur);
      return;
    }
    for (var i = start; i < items.length; i++) {
      cur.add(items[i]);
      yield* _combos(items, k, i + 1, cur);
      cur.removeLast();
    }
  }

  /// 칸 k개의 후보 합집합이 숫자 k개뿐이면, 그 유닛의 다른 칸에서 그 숫자들을 지운다.
  static SolveStep? _nakedSubset(CandidateGrid g, int k) {
    final tech = switch (k) {
      2 => Technique.nakedPair,
      3 => Technique.nakedTriple,
      _ => Technique.nakedQuad,
    };
    for (var u = 0; u < 27; u++) {
      final eligible = [
        for (final c in unitCells[u])
          if (popCount(g.cand[c]) >= 2 && popCount(g.cand[c]) <= k) c,
      ];
      if (eligible.length < k) continue;
      for (final combo in _combos(eligible, k)) {
        var union = 0;
        for (final c in combo) {
          union |= g.cand[c];
        }
        if (popCount(union) != k) continue;
        final elim = <int, int>{
          for (final c in unitCells[u])
            if (!combo.contains(c) && g.cand[c] & union != 0)
              c: g.cand[c] & union,
        };
        if (elim.isEmpty) continue;
        return SolveStep(
          technique: tech,
          cells: combo,
          digits: union,
          unit: u,
          eliminations: elim,
        );
      }
    }
    return null;
  }

  /// 숫자 k개가 유닛 안의 칸 k개에만 들어갈 수 있으면, 그 칸들의 다른 후보를 지운다.
  static SolveStep? _hiddenSubset(CandidateGrid g, int k) {
    final tech = k == 2 ? Technique.hiddenPair : Technique.hiddenTriple;
    for (var u = 0; u < 27; u++) {
      final cells = unitCells[u];
      final pos = List<int>.filled(10, 0); // 숫자 → 유닛 안 위치 마스크
      final eligible = <int>[];
      for (var d = 1; d <= 9; d++) {
        var m = 0;
        for (var i = 0; i < 9; i++) {
          if (g.cand[cells[i]] & bit(d) != 0) m |= 1 << i;
        }
        pos[d] = m;
        final pc = popCount(m);
        if (pc >= 2 && pc <= k) eligible.add(d);
      }
      if (eligible.length < k) continue;
      for (final combo in _combos(eligible, k)) {
        var union = 0;
        var digits = 0;
        for (final d in combo) {
          union |= pos[d];
          digits |= bit(d);
        }
        if (popCount(union) != k) continue;
        final elim = <int, int>{};
        final patternCells = <int>[];
        for (var i = 0; i < 9; i++) {
          if (union & (1 << i) == 0) continue;
          final c = cells[i];
          patternCells.add(c);
          final extra = g.cand[c] & ~digits;
          if (extra != 0) elim[c] = extra;
        }
        if (elim.isEmpty) continue;
        return SolveStep(
          technique: tech,
          cells: patternCells,
          digits: digits,
          unit: u,
          eliminations: elim,
        );
      }
    }
    return null;
  }

  // ── 피시 (X-윙, 스워드피시) ──

  static SolveStep? _fish(CandidateGrid g, int k) {
    final tech = k == 2 ? Technique.xWing : Technique.swordfish;
    for (var d = 1; d <= 9; d++) {
      final b = bit(d);
      for (final byRow in [true, false]) {
        final pos = List<int>.filled(9, 0); // 기준 줄 → 교차 위치 마스크
        final lines = <int>[];
        for (var line = 0; line < 9; line++) {
          var m = 0;
          for (var x = 0; x < 9; x++) {
            final cell = byRow ? line * 9 + x : x * 9 + line;
            if (g.cand[cell] & b != 0) m |= 1 << x;
          }
          pos[line] = m;
          final pc = popCount(m);
          if (pc >= 2 && pc <= k) lines.add(line);
        }
        if (lines.length < k) continue;
        for (final combo in _combos(lines, k)) {
          var union = 0;
          for (final l in combo) {
            union |= pos[l];
          }
          if (popCount(union) != k) continue;
          final elim = <int, int>{};
          for (var x = 0; x < 9; x++) {
            if (union & (1 << x) == 0) continue;
            for (var line = 0; line < 9; line++) {
              if (combo.contains(line)) continue;
              final cell = byRow ? line * 9 + x : x * 9 + line;
              if (g.cand[cell] & b != 0) elim[cell] = b;
            }
          }
          if (elim.isEmpty) continue;
          return SolveStep(
            technique: tech,
            cells: [
              for (final l in combo)
                for (var x = 0; x < 9; x++)
                  if (pos[l] & (1 << x) != 0) byRow ? l * 9 + x : x * 9 + l,
            ],
            digits: b,
            units: [for (final l in combo) byRow ? l : 9 + l],
            coverUnits: [
              for (var x = 0; x < 9; x++)
                if (union & (1 << x) != 0) byRow ? 9 + x : x,
            ],
            eliminations: elim,
          );
        }
      }
    }
    return null;
  }

  // ── 윙 ──

  /// 중심 {x,y}, 날개 {x,z}와 {y,z}: 두 날개가 모두 보는 칸에서 z를 지운다.
  static SolveStep? _xyWing(CandidateGrid g) {
    for (var p = 0; p < 81; p++) {
      final pm = g.cand[p];
      if (popCount(pm) != 2) continue;
      for (final w1 in peers[p]) {
        final m1 = g.cand[w1];
        if (popCount(m1) != 2 || popCount(m1 & pm) != 1) continue;
        final z = m1 & ~pm;
        final need2 = (pm & ~m1) | z;
        for (final w2 in peers[p]) {
          if (w2 == w1 || g.cand[w2] != need2) continue;
          final elim = <int, int>{
            for (final t in commonPeers(w1, w2))
              if (t != p && g.cand[t] & z != 0) t: z,
          };
          if (elim.isEmpty) continue;
          return SolveStep(
            technique: Technique.xyWing,
            cells: [p, w1, w2],
            digits: z,
            eliminations: elim,
          );
        }
      }
    }
    return null;
  }

  /// 중심 {x,y,z}, 날개 {x,z}와 {y,z}: 세 칸이 모두 보는 칸에서 z를 지운다.
  static SolveStep? _xyzWing(CandidateGrid g) {
    for (var p = 0; p < 81; p++) {
      final pm = g.cand[p];
      if (popCount(pm) != 3) continue;
      for (final w1 in peers[p]) {
        final m1 = g.cand[w1];
        if (popCount(m1) != 2 || m1 & ~pm != 0) continue;
        for (final w2 in peers[p]) {
          if (w2 <= w1) continue;
          final m2 = g.cand[w2];
          if (popCount(m2) != 2 || m2 & ~pm != 0 || (m1 | m2) != pm) continue;
          final z = m1 & m2;
          if (popCount(z) != 1) continue;
          final elim = <int, int>{
            for (final t in commonPeers(w1, w2))
              if (t != p && sees(t, p) && g.cand[t] & z != 0) t: z,
          };
          if (elim.isEmpty) continue;
          return SolveStep(
            technique: Technique.xyzWing,
            cells: [p, w1, w2],
            digits: z,
            eliminations: elim,
          );
        }
      }
    }
    return null;
  }
}

/// 논리 풀이 결과.
class Grade {
  const Grade({
    required this.solved,
    required this.maxLevel,
    required this.steps,
    this.counts = const {},
  });

  /// 허용한 기술만으로 끝까지 풀렸는가.
  final bool solved;

  /// 풀이에 쓰인 가장 어려운 기술의 레벨.
  final int maxLevel;
  final int steps;

  /// 기술별 사용 횟수.
  final Map<Technique, int> counts;
}

class HumanSolver {
  HumanSolver._();

  /// [values]를 [maxLevel] 이하의 논리 기술만으로 풀어보고 결과를 돌려준다.
  static Grade grade(List<int> values, {int maxLevel = 4}) {
    final g = CandidateGrid.fromValues(values);
    var level = 0;
    var steps = 0;
    final counts = <Technique, int>{};
    Grade result(bool solved) =>
        Grade(solved: solved, maxLevel: level, steps: steps, counts: counts);
    while (!g.isSolved) {
      if (g.hasContradiction) return result(false);
      final s = StepFinder.next(g, maxLevel: maxLevel);
      if (s == null) return result(false);
      if (s.technique.level > level) level = s.technique.level;
      counts[s.technique] = (counts[s.technique] ?? 0) + 1;
      g.apply(s);
      steps++;
    }
    return result(true);
  }
}
