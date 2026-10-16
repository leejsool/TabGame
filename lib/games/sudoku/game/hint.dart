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
    this.visualOnly = false,
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

  /// 튜토리얼에서 칸을 색칠해 보여주기만 하는 표시 (설명 카드·입력 버튼은 없다).
  final bool visualOnly;

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
  factory ActiveHint.fromStep(SolveStep s, CandidateGrid g, {bool visualOnly = false}) {
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
          s.technique == Technique.claiming ||
          s.technique == Technique.skyscraper ||
          s.technique == Technique.twoStringKite ||
          s.technique == Technique.emptyRectangle)
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
      visualOnly: visualOnly,
    );
  }

  /// 논리 단계를 못 찾았을 때: 정답을 알려준다.
  factory ActiveHint.reveal(int cell, int digit) => ActiveHint(
        title: Technique.reveal.label,
        message: '배운 논리 기술로 풀 수 있는 다음 단계를 찾지 못했어요. 이런 판은 숫자를 하나 가정해 보고 모순이 나는지 따져야 해요. '
            '${cellName(cell)}의 정답은 $digit${_eulReul(digit)} 넣어 보세요.',
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
    case Technique.skyscraper:
      final digit = digitsOf(s.digits).first;
      final e1 = s.cells[0], b1 = s.cells[1], b2 = s.cells[2], e2 = s.cells[3];
      return '${_unitList(s.units)}에서 $digit${_iGa(digit)} 들어갈 수 있는 칸이 각각 두 곳뿐이에요. '
          '그중 한 곳씩(${cellName(b1)}, ${cellName(b2)})은 같은 줄에 있고, 나머지 두 곳(${cellName(e1)}, ${cellName(e2)})은 서로 달라요.\n'
          '${cellName(e1)}이 $digit${_iGa(digit)} 아니라면 ${cellName(b1)}이 $digit${_iGa(digit)} 되고, '
          '같은 줄인 ${cellName(b2)}는 $digit${_iGa(digit)} 될 수 없으니 ${cellName(e2)}가 $digit${_iGa(digit)} 돼요. '
          '어느 쪽이든 ${cellName(e1)}과 ${cellName(e2)} 중 하나는 반드시 $digit예요. '
          '두 칸이 모두 보는 칸에서는 $digit${_eulReul(digit)} 지울 수 있어요. 표시된 후보를 지우세요.';
    case Technique.twoStringKite:
      final digit = digitsOf(s.digits).first;
      final x2 = s.cells[0], x = s.cells[1], y = s.cells[2], y2 = s.cells[3];
      return '${unitName(s.units[0])}에서 $digit${_iGa(digit)} 들어갈 수 있는 칸은 ${cellName(x2)}과 ${cellName(x)} 두 곳뿐이고, '
          '${unitName(s.units[1])}에서는 ${cellName(y)}과 ${cellName(y2)} 두 곳뿐이에요.\n'
          '${cellName(x)}과 ${cellName(y)}는 같은 박스(${unitName(s.unit)})에 있어서 둘 다 $digit일 수는 없어요(연의 두 끈이 박스에서 만나요). '
          '그래서 ${cellName(x2)}과 ${cellName(y2)} 중 하나는 반드시 $digit예요. '
          '두 칸이 모두 보는 칸에서는 $digit${_eulReul(digit)} 지울 수 있어요. 표시된 후보를 지우세요.';
    case Technique.emptyRectangle:
      final digit = digitsOf(s.digits).first;
      final parts = s.note.split(',');
      final byCol = parts[0] == 'col';
      final r = int.parse(parts[1]), c = int.parse(parts[2]);
      final other = int.parse(parts[3]), link = int.parse(parts[4]);
      final target = s.eliminations.keys.first;
      return '${unitName(s.unit)}에서 $digit${_iGa(digit)} 들어갈 수 있는 칸이 ${r + 1}행과 ${c + 1}열의 십자 모양 안에만 있어요(빈 직사각형).\n'
          '${unitName(s.units[2])}에서는 $digit${_iGa(digit)} 들어갈 수 있는 칸이 ${cellName(link)}과 ${cellName(other)} 두 곳뿐이에요.\n'
          '${cellName(other)}이 $digit이면 ${cellName(target)}과 ${byCol ? '같은 행' : '같은 열'}이라 ${cellName(target)}은 $digit${_iGa(digit)} 아니고, '
          '아니라면 ${cellName(link)}이 $digit${_iGa(digit)} 돼서 박스 안의 ${r + 1}행 칸들이 사라지니 박스의 $digit${_iGa(digit)} ${c + 1}열에 있게 되어 '
          '${cellName(target)}은 $digit${_iGa(digit)} 아니에요. 어느 쪽이든 ${cellName(target)}에서 $digit${_eulReul(digit)} 지울 수 있어요. 표시된 후보를 지우세요.';
    case Technique.uniqueRectangle:
      final pair = digitsOf(s.digits);
      final a = pair[0], b = pair[1];
      final rect = _cellList(s.cells);
      if (s.note == '1') {
        final t = s.eliminations.keys.first;
        return '$rect은 두 박스에 걸친 직사각형이에요. 세 칸의 후보가 ${_digitList(s.digits)}뿐이라, 남은 ${cellName(t)}까지 ${_digitList(s.digits)} 중 하나가 되면 '
            '네 칸의 $a와 $b를 서로 바꿔 써도 모두 맞는 "죽은 패턴"이 되어 정답이 두 개가 돼요. 정답은 하나뿐이니 그럴 수 없어요. '
            '그래서 ${cellName(t)}에서는 $a와 $b를 지울 수 있어요. 표시된 후보를 지우세요.';
      }
      final extra = digitsOf(s.eliminations.values.first).first;
      return '$rect은 두 박스에 걸친 직사각형이에요. 두 칸은 ${_digitList(s.digits)}뿐이고, 나머지 두 칸은 ${_digitList(s.digits)}에 $extra${_iGa(extra)} 더해져 있어요. '
          '두 칸 모두 $extra${_iGa(extra)} 아니라면 네 칸이 ${_digitList(s.digits)}만 남아 정답이 두 개가 되는 "죽은 패턴"이에요. 그럴 수 없으니 둘 중 하나는 반드시 $extra예요. '
          '두 칸이 모두 보는 칸에서는 $extra${_eulReul(extra)} 지울 수 있어요. 표시된 후보를 지우세요.';
    case Technique.bugPlusOne:
      final d = s.placeDigit;
      return '빈 칸이 모두 후보 두 개뿐인데 ${cellName(s.placeCell)}만 후보가 세 개예요. 이대로면 어떻게 채워도 정답이 둘 이상인 모양(BUG)이에요. '
          '정답은 하나뿐이니, 이 칸은 행·열·박스에서 후보가 세 번 나오는 숫자 $d${_iGa(d)} 돼야 해요. $d${_eulReul(d)} 입력하세요.';
    case Technique.xyChain:
      final digit = digitsOf(s.digits).first;
      final lines = [for (final c in s.cells) _cellWithCands(c, g)].join(' → ');
      return '사슬: $lines\n'
          '이웃한 두 칸은 서로 보고 숫자를 하나씩 넘겨요. ${cellName(s.cells.first)}이 $digit${_iGa(digit)} 아니라면 숫자가 차례로 넘어가 '
          '마지막 ${cellName(s.cells.last)}이 $digit${_iGa(digit)} 돼요. 그래서 양 끝 중 하나는 반드시 $digit예요. '
          '양 끝이 모두 보는 칸에서는 $digit${_eulReul(digit)} 지울 수 있어요. 표시된 후보를 지우세요.';
    case Technique.xChain:
      final digit = digitsOf(s.digits).first;
      final parts = <String>[];
      for (var i = 0; i < s.cells.length; i++) {
        parts.add(cellName(s.cells[i]));
        if (i < s.cells.length - 1) parts.add(i.isEven ? '═' : '─');
      }
      return '$digit${_eulReul(digit)} 따라 이은 사슬: ${parts.join(' ')}\n'
          '(═ 그 줄에서 $digit${_iGa(digit)} 들어갈 칸이 두 곳뿐인 연결, ─ 서로 보는 칸의 연결)\n'
          '연결이 번갈아 이어져서 ${cellName(s.cells.first)}이 $digit${_iGa(digit)} 아니면 ${cellName(s.cells.last)}이 반드시 $digit${_iGa(digit)} 돼요. '
          '양 끝 중 하나는 $digit예요. 양 끝이 모두 보는 칸에서는 $digit${_eulReul(digit)} 지울 수 있어요. 표시된 후보를 지우세요.';
    case Technique.alsXz:
      final p = s.note.split(',');
      final x = int.parse(p[0]), z = int.parse(p[1]), n = int.parse(p[2]);
      final a = s.cells.sublist(0, n), b = s.cells.sublist(n);
      int union(List<int> cs) => cs.fold<int>(0, (m, c) => m | g.cand[c]);
      return 'ALS는 한 줄(박스)의 칸 n개에 후보가 n+1개 있는 "거의 잠긴 집합"이에요.\n'
          'A: ${_cellList(a)} {${_digitList(union(a))}}\n'
          'B: ${_cellList(b)} {${_digitList(union(b))}}\n'
          '두 집합의 $x${_eulReul(x)} 가진 칸은 서로 모두 보니, A와 B가 $x${_eulReul(x)} 동시에 가질 수는 없어요. 어느 한쪽은 $x${_eulReul(x)} 잃고 $z${_eulReul(z)} 차지해요. '
          '그래서 두 집합의 $z 칸들이 모두 보는 칸에서는 $z${_eulReul(z)} 지울 수 있어요. 표시된 후보를 지우세요.';
    case Technique.forcingChain:
      final c = s.cells.first;
      final d = digitsOf(s.digits).first;
      return '${cellName(c)}에 $d${_eulReul(d)} 넣는다고 가정해 보세요. 싱글 규칙만 따라가면 "${s.note}" 같은 모순이 생겨요. '
          '그러니 ${cellName(c)}은 $d${_iGa(d)} 아니에요. $d${_eulReul(d)} 후보에서 지우세요. 표시된 후보를 지우세요.';
    case Technique.reveal:
      return '배운 논리 기술로는 막혔어요.';
  }
}
