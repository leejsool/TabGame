import '../core/grid.dart';
import '../core/techniques.dart';

/// 화면에 보여주는 힌트 한 개: 설명 문구 + 보드에 칠할 정보.
class ActiveHint {
  const ActiveHint({
    required this.title,
    required this.message,
    required this.applyLabel,
    this.technique,
    this.causeCells = const {},
    this.targetCells = const {},
    this.regionCells = const {},
    this.cands = const {},
    this.removeMask = const {},
    this.patternDigits = 0,
    this.placeCell = -1,
    this.placeDigit = 0,
    this.wrongCells = const [],
  });

  final String title;
  final String message;
  final String applyLabel;
  final Technique? technique;

  /// 패턴을 이루는 칸 (노란색).
  final Set<int> causeCells;

  /// 숫자를 넣거나 후보를 지울 칸 (초록색).
  final Set<int> targetCells;

  /// 패턴이 놓인 줄/박스 전체 (옅은 색).
  final Set<int> regionCells;

  /// 힌트 설명 중에 보여줄 칸별 후보.
  final Map<int, int> cands;

  /// 칸 → 지울 후보 (빨간색 취소선).
  final Map<int, int> removeMask;

  /// 패턴에 쓰인 숫자들 (파란색 굵게).
  final int patternDigits;

  final int placeCell;
  final int placeDigit;

  /// 틀린 숫자가 들어 있는 칸들.
  final List<int> wrongCells;

  bool get isWrongCells => wrongCells.isNotEmpty;
  bool get isPlacement => placeCell >= 0;
  SolveStepKind get kind => isWrongCells
      ? SolveStepKind.wrong
      : isPlacement
          ? SolveStepKind.place
          : SolveStepKind.eliminate;

  factory ActiveHint.wrong(List<int> cells) {
    final names = _cellList(cells);
    return ActiveHint(
      title: '틀린 숫자가 있어요',
      message: '$names에 틀린 숫자가 들어 있어요. 이 칸을 먼저 지우고 다시 생각해 보세요.',
      applyLabel: '틀린 칸 지우기',
      wrongCells: cells,
      targetCells: cells.toSet(),
    );
  }

  /// 논리 단계로 힌트를 만든다. [g]는 단계를 적용하기 전의 후보 격자.
  factory ActiveHint.fromStep(SolveStep s, CandidateGrid g) {
    final cands = <int, int>{};
    for (final c in s.cells) {
      if (g.cand[c] != 0) cands[c] = g.cand[c];
    }
    for (final c in s.eliminations.keys) {
      cands[c] = g.cand[c];
    }
    final units = <int>{
      if (s.unit >= 0) ...unitCells[s.unit],
      if (s.technique == Technique.pointing ||
          s.technique == Technique.claiming)
        for (final u in s.units) ...unitCells[u],
    };
    final text = describeStep(s, g);
    return ActiveHint(
      title: s.technique.label,
      message: text,
      applyLabel: s.isPlacement ? '입력하기' : '후보 지우기',
      technique: s.technique,
      causeCells: s.isPlacement ? const {} : s.cells.toSet(),
      targetCells: s.isPlacement ? {s.placeCell} : s.eliminations.keys.toSet(),
      regionCells: units,
      cands: s.isPlacement ? const {} : cands,
      removeMask: s.eliminations,
      patternDigits: s.digits,
      placeCell: s.placeCell,
      placeDigit: s.placeDigit,
    );
  }

  /// 논리 단계를 못 찾았을 때: 정답을 알려준다.
  factory ActiveHint.reveal(int cell, int digit) => ActiveHint(
        title: Technique.reveal.label,
        message: '${cellName(cell)}에 들어갈 수 있는 쉬운 논리 단계를 찾지 못했어요. '
            '이 칸의 정답은 $digit${_eulReul(digit)} 넣어 보세요.',
        applyLabel: '입력하기',
        technique: Technique.reveal,
        targetCells: {cell},
        placeCell: cell,
        placeDigit: digit,
      );
}

enum SolveStepKind { place, eliminate, wrong }

// ── 한국어 문구 도우미 ──

String cellName(int c) => '${rowOf[c] + 1}행 ${colOf[c] + 1}열';

const _boxNames = [
  '왼쪽 위 박스', '위쪽 가운데 박스', '오른쪽 위 박스',
  '왼쪽 가운데 박스', '가운데 박스', '오른쪽 가운데 박스',
  '왼쪽 아래 박스', '아래쪽 가운데 박스', '오른쪽 아래 박스',
];

String unitName(int u) {
  if (u < 9) return '${u + 1}행';
  if (u < 18) return '${u - 8}열';
  return _boxNames[u - 18];
}

// 숫자 1~9를 한글로 읽었을 때 받침이 있는가 (일, 삼, 육, 칠, 팔).
bool _hasBatchim(int d) => const {1, 3, 6, 7, 8}.contains(d);

String _eulReul(int d) => _hasBatchim(d) ? '을' : '를';
String _iGa(int d) => _hasBatchim(d) ? '이' : '가';

String _cellList(List<int> cells) {
  final names = [for (final c in cells) cellName(c)];
  if (names.length == 1) return names.first;
  if (names.length == 2) return '${names[0]}과 ${names[1]}';
  return names.join(', ');
}

String _unitList(List<int> units) {
  final names = [for (final u in units) unitName(u)];
  if (names.length == 1) return names.first;
  if (names.length == 2) {
    final josa = units[0] >= 18 ? '와' : '과';
    return '${names[0]}$josa ${names[1]}';
  }
  return names.join(', ');
}

String _digitList(int mask) => digitsOf(mask).join(', ');

/// 칸 이름 + 후보 집합. 예: "6행 3열 {4, 8}"
String _cellWithCands(int cell, CandidateGrid g) =>
    '${cellName(cell)} {${_digitList(g.cand[cell])}}';

String _digitEulReul(int mask) => _eulReul(digitsOf(mask).last);

/// 한 단계를 한국어로 설명한다. [g]는 그 단계를 적용하기 전의 후보 격자.
String describeStep(SolveStep s, CandidateGrid g) {
  final d = s.placeDigit;
  switch (s.technique) {
    case Technique.nakedSingle:
      return '${cellName(s.placeCell)}에는 들어갈 수 있는 숫자가 $d 하나뿐이에요. '
          '같은 줄과 박스에 이미 있는 숫자들 때문에 나머지는 들어갈 수 없어요. '
          '$d${_eulReul(d)} 입력하세요.';
    case Technique.hiddenSingle:
      return '${unitName(s.unit)}에서 $d${_iGa(d)} 들어갈 수 있는 칸은 '
          '${cellName(s.placeCell)} 하나뿐이에요. $d${_eulReul(d)} 입력하세요.';
    case Technique.pointing:
      final digit = digitsOf(s.digits).first;
      return '${unitName(s.unit)}에서 $digit${_iGa(digit)} 들어갈 수 있는 칸이 모두 '
          '${unitName(s.units.first)}에 있어요. 그래서 ${unitName(s.units.first)}의 '
          '박스 밖 칸에서는 $digit${_eulReul(digit)} 지울 수 있어요. 표시된 후보를 지우세요.';
    case Technique.claiming:
      final digit = digitsOf(s.digits).first;
      return '${unitName(s.unit)}에서 $digit${_iGa(digit)} 들어갈 수 있는 칸이 모두 '
          '${unitName(s.units.first)} 안에 있어요. 그래서 ${unitName(s.units.first)}의 '
          '${unitName(s.unit)} 밖 칸에서는 $digit${_eulReul(digit)} 지울 수 있어요. 표시된 후보를 지우세요.';
    case Technique.nakedPair:
    case Technique.nakedTriple:
    case Technique.nakedQuad:
      return '${_cellList(s.cells)}에는 ${_digitList(s.digits)}만 들어갈 수 있어요. '
          '이 칸들이 그 숫자를 모두 차지하니, ${unitName(s.unit)}의 다른 칸에서는 '
          '${_digitList(s.digits)}${_digitEulReul(s.digits)} 지울 수 있어요. 표시된 후보를 지우세요.';
    case Technique.hiddenPair:
    case Technique.hiddenTriple:
      return '${unitName(s.unit)}에서 ${_digitList(s.digits)}${_iGa(digitsOf(s.digits).last)} '
          '들어갈 수 있는 칸은 ${_cellList(s.cells)}뿐이에요. 이 칸들은 그 숫자들의 차지이니, '
          '다른 후보는 지울 수 있어요. 표시된 후보를 지우세요.';
    case Technique.xWing:
    case Technique.swordfish:
      final digit = digitsOf(s.digits).first;
      return '${_unitList(s.units)}에서 $digit${_iGa(digit)} 들어갈 수 있는 칸이 모두 '
          '${_unitList(s.coverUnits)}에 걸쳐 있어요. 이 숫자는 그 줄들 안에서만 자리를 잡으니, '
          '${_unitList(s.coverUnits)}의 다른 칸에서는 $digit${_eulReul(digit)} 지울 수 있어요. '
          '표시된 후보를 지우세요.';
    case Technique.xyWing:
      final digit = digitsOf(s.digits).first;
      return '중심: ${_cellWithCands(s.cells[0], g)}\n'
          '날개: ${_cellWithCands(s.cells[1], g)}, ${_cellWithCands(s.cells[2], g)}\n'
          '중심 칸이 어떤 숫자가 되든 두 날개 중 하나는 반드시 $digit${_iGa(digit)} 돼요. '
          '그래서 두 날개가 모두 보는 칸에서는 $digit${_eulReul(digit)} 지울 수 있어요. '
          '표시된 후보를 지우세요.';
    case Technique.xyzWing:
      final digit = digitsOf(s.digits).first;
      return '중심: ${_cellWithCands(s.cells[0], g)}\n'
          '날개: ${_cellWithCands(s.cells[1], g)}, ${_cellWithCands(s.cells[2], g)}\n'
          '세 칸 중 하나는 반드시 $digit${_iGa(digit)} 돼요. '
          '그래서 세 칸이 모두 보는 칸에서는 $digit${_eulReul(digit)} 지울 수 있어요. '
          '표시된 후보를 지우세요.';
    case Technique.reveal:
      return '쉬운 논리 단계를 찾지 못했어요.';
  }
}
