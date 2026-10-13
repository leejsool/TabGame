import '../core/generator.dart';
import '../core/grid.dart';
import '../core/techniques.dart';
import '../game/hint.dart';
import '../game/sudoku_game.dart';

/// 기본 규칙 튜토리얼이 쓰는 연습 판. 정답이 하나뿐이고 싱글만으로 풀리는 판이며,
/// 아래 칸 번호들은 단계마다 눈에 띄는 칸을 골라 둔 것이다. (basic_lesson_test.dart가 검증)
const String kBasicGivens =
    '208070600000250003506100042010003490000847000850061237040615000180430500065782314';
const String kBasicSolution =
    '298374651471256983536198742617523498329847165854961237743615829182439576965782314';

/// 행에서 마지막 빈 칸 (맨 아랫줄 왼쪽 끝, 정답 9).
const int kLessonRowCell = 72;

/// 박스에서 마지막 빈 칸 (아래쪽 가운데 박스, 정답 9).
const int kLessonBoxCell = 68;

/// 행·열·박스를 함께 봐야 하는 칸 (정답 1).
const int kLessonCrossCell = 42;

/// 메모 연습 칸 (위쪽 줄, 후보 3·9).
const int kLessonNoteCell = 1;

SudokuPuzzle basicPuzzle() => SudokuPuzzle.fromStrings(kBasicGivens, kBasicSolution, Difficulty.easy);

/// 튜토리얼이 단계 안에서 쓰는 상태 묶음.
class LessonContext {
  LessonContext(this.game);

  final SudokuGame game;

  /// 단계끼리 주고받는 값들 (예: 단계에 들어올 때의 채운 칸 수).
  final Map<String, int> vars = {};

  int get filledCount => game.values.where((v) => v != 0).length;

  bool get anyWrong {
    for (var i = 0; i < 81; i++) {
      if (game.isWrong(i)) return true;
    }
    return false;
  }
}

/// 튜토리얼 한 단계. 목표([goal])가 없으면 읽고 넘어가는 단계다.
class LessonStep {
  const LessonStep({
    required this.title,
    required this.text,
    this.success,
    this.visuals,
    this.enter,
    this.goal,
    this.problem,
    this.help,
    this.spotlight = const {},
    this.padSpotlight = false,
    this.showControls = false,
    this.allowWrong = false,
    this.finale = false,
  });

  final String title;
  final String Function(LessonContext c) text;

  /// 목표를 이뤘을 때 보여주는 말.
  final String Function(LessonContext c)? success;

  /// 판 위에 칠할 표시 (행·열·박스, 눌러 볼 칸 등).
  final ActiveHint? Function(LessonContext c)? visuals;

  /// 단계에 들어올 때 한 번 하는 준비 (칸 선택 등).
  final void Function(LessonContext c)? enter;

  /// 이 조건이 되면 목표 달성.
  final bool Function(LessonContext c)? goal;

  /// 잘못된 시도를 알려주는 말. null이면 문제 없음.
  final String? Function(LessonContext c)? problem;

  /// "도와줘요" 버튼을 눌렀을 때 보여줄 말.
  final String Function(LessonContext c)? help;

  /// 깜빡여서 알려줄 액션 버튼들 ('undo' 'erase' 'notes' 'auto' 'hint').
  final Set<String> spotlight;
  final bool padSpotlight;
  final bool showControls;

  /// 일부러 틀린 숫자를 넣어 보는 단계: 틀린 칸을 자동으로 지우지 않는다.
  final bool allowWrong;

  /// 마지막 장 (버튼이 다르다).
  final bool finale;
}

ActiveHint _visual({
  Set<int> region = const {},
  Set<int> target = const {},
  Set<int> cause = const {},
}) =>
    ActiveHint(
      title: '',
      message: '',
      applyLabel: '',
      regionCells: region,
      targetCells: target,
      causeCells: cause,
      visualOnly: true,
    );

Set<int> _row(int cell) => unitCells[rowOf[cell]].toSet();
Set<int> _col(int cell) => unitCells[9 + colOf[cell]].toSet();
Set<int> _box(int cell) => unitCells[18 + boxOf[cell]].toSet();

String _digitsIn(SudokuGame g, Iterable<int> cells) {
  final ds = {
    for (final c in cells)
      if (g.values[c] != 0) g.values[c],
  }.toList()
    ..sort();
  return ds.join(', ');
}

/// 틀린 숫자를 넣었을 때 이유를 알려준다. (행 → 열 → 박스 순서로 겹치는 숫자를 찾는다)
String explainWrong(SudokuGame g, int cell) {
  final d = g.values[cell];
  final places = [
    ('같은 행', unitCells[rowOf[cell]]),
    ('같은 열', unitCells[9 + colOf[cell]]),
    ('같은 박스', unitCells[18 + boxOf[cell]]),
  ];
  for (final (where, cells) in places) {
    if (cells.any((p) => p != cell && g.values[p] == d)) {
      return '숫자 $d: $where에 이미 있어서 또 넣을 수 없어요. 다시 생각해 보세요!';
    }
  }
  return '숫자 $d: 이 칸의 정답이 아니에요. 같은 행·열·박스에 있는 숫자를 다시 살펴보세요.';
}

int _firstEmptyExcept(SudokuGame g, int skip) {
  for (var i = 0; i < 81; i++) {
    if (g.values[i] == 0 && i != skip) return i;
  }
  return -1;
}

/// 기본 규칙 튜토리얼의 단계들.
List<LessonStep> basicSteps() {
  return [
    LessonStep(
      title: '스도쿠는 이런 퍼즐이에요',
      text: (_) => '가로 9칸, 세로 9칸, 모두 81칸으로 된 판이에요. 빈 칸에 1부터 9까지 숫자를 '
          '채워 넣으면 완성! 처음부터 적혀 있는 검은 숫자는 문제라서 바꿀 수 없어요.',
    ),
    LessonStep(
      title: '가로줄은 "행"',
      text: (_) => '가로로 나란한 9칸을 행이라고 해요. 지금 표시된 줄이 맨 아래 행이에요. '
          '판에는 행이 9개 있어요.',
      visuals: (_) => _visual(region: _row(kLessonRowCell)),
    ),
    LessonStep(
      title: '세로줄은 "열"',
      text: (_) => '세로로 나란한 9칸은 열이에요. 지금 표시된 줄은 왼쪽에서 일곱 번째 열이고, '
          '열도 9개 있어요.',
      visuals: (_) => _visual(region: _col(kLessonCrossCell)),
    ),
    LessonStep(
      title: '굵은 선으로 나뉜 "박스"',
      text: (_) => '굵은 선으로 둘러싸인 3×3 칸 묶음이 박스예요. 판에는 박스가 9개 있어요. '
          '지금 표시된 곳은 아래쪽 가운데 박스예요.',
      visuals: (_) => _visual(region: _box(kLessonBoxCell)),
    ),
    LessonStep(
      title: '규칙은 딱 하나!',
      text: (_) => '모든 행, 모든 열, 모든 박스에 1부터 9까지 숫자가 한 번씩만 들어가야 해요. '
          '같은 행이나 열이나 박스에 같은 숫자가 두 번 나오면 안 돼요. 표시된 맨 아래 행, '
          '맨 왼쪽 열, 왼쪽 아래 박스에도 1~9가 한 번씩만 들어가요.',
      visuals: (_) => _visual(
        region: {..._row(kLessonRowCell), ..._col(kLessonRowCell), ..._box(kLessonRowCell)},
      ),
    ),
    LessonStep(
      title: '칸을 눌러 보세요',
      text: (_) => '초록색으로 표시된 빈 칸을 눌러 보세요. 칸을 고르면 같은 행·열·박스가 '
          '연한 색으로 표시돼요.',
      success: (_) => '좋아요! 고른 칸과 같은 행·열·박스가 연하게 보이죠? 이 칸에 들어갈 숫자는 '
          '그 줄들에 이미 있는 숫자와 달라야 해요.',
      visuals: (_) => _visual(target: {kLessonRowCell}),
      enter: (c) => c.game.select(-1),
      goal: (c) => c.game.selected == kLessonRowCell,
    ),
    LessonStep(
      title: '숫자를 넣어 보세요 (1)',
      text: (_) => '이 칸이 있는 맨 아래 행을 보세요. 1~9 중 8개가 이미 있고, 하나만 빠져 있어요. '
          '빠진 숫자를 아래 숫자 패드에서 눌러 넣어 보세요.',
      success: (_) => '정답이에요! 한 줄에서 빈 칸이 하나뿐이면 빠진 숫자가 곧 답이에요.',
      visuals: (_) => _visual(region: _row(kLessonRowCell), target: {kLessonRowCell}),
      enter: (c) => c.game.select(kLessonRowCell),
      goal: (c) => c.game.values[kLessonRowCell] == 9,
      showControls: true,
      padSpotlight: true,
      help: (c) => '맨 아래 행에 있는 숫자는 ${_digitsIn(c.game, _row(kLessonRowCell))}예요. '
          '1~9 중에 없는 숫자는 뭘까요?',
    ),
    LessonStep(
      title: '숫자를 넣어 보세요 (2)',
      text: (_) => '이번엔 박스예요. 표시된 박스에는 8칸이 차 있고 빈 칸은 하나뿐이에요. '
          '어떤 숫자가 빠졌을까요? 초록 칸을 누르고 숫자를 넣어 보세요.',
      success: (_) => '맞았어요! 박스도 행처럼 1~9가 한 번씩 들어가니까 빠진 숫자를 찾으면 돼요.',
      visuals: (_) => _visual(region: _box(kLessonBoxCell), target: {kLessonBoxCell}),
      enter: (c) => c.game.select(kLessonBoxCell),
      goal: (c) => c.game.values[kLessonBoxCell] == 9,
      showControls: true,
      help: (c) => '이 박스에 있는 숫자는 ${_digitsIn(c.game, _box(kLessonBoxCell))}예요. '
          '빠진 숫자를 찾아보세요.',
    ),
    LessonStep(
      title: '행·열·박스를 함께 봐요',
      text: (_) => '이 칸은 줄 하나만으로는 안 풀려요. 하지만 표시된 행·열·박스에 이미 있는 숫자를 '
          '모두 모으면, 들어갈 수 있는 숫자가 딱 하나만 남아요. 쓸 수 없는 숫자를 하나씩 '
          '지워 가며 답을 찾아 넣어 보세요.',
      success: (_) => '대단해요! 이렇게 "이미 있는 숫자를 빼고 남는 숫자"를 찾는 것이 스도쿠를 푸는 '
          '가장 기본적인 방법이에요.',
      visuals: (_) => _visual(
        region: {..._row(kLessonCrossCell), ..._col(kLessonCrossCell), ..._box(kLessonCrossCell)},
        target: {kLessonCrossCell},
      ),
      enter: (c) => c.game.select(kLessonCrossCell),
      goal: (c) => c.game.values[kLessonCrossCell] == 1,
      showControls: true,
      help: (c) {
        final g = c.game;
        return '행에 있는 숫자: ${_digitsIn(g, _row(kLessonCrossCell))}\n'
            '열에 있는 숫자: ${_digitsIn(g, _col(kLessonCrossCell))}\n'
            '박스에 있는 숫자: ${_digitsIn(g, _box(kLessonCrossCell))}\n'
            '이 숫자들을 뺀 나머지는 하나뿐이에요.';
      },
    ),
    LessonStep(
      title: '일부러 틀려 볼까요?',
      text: (c) => '틀리면 어떻게 되는지 해 봐요. 초록 칸에 들어갈 수 없는 숫자를 아무거나 넣어 보세요. '
          '(같은 행·열·박스에 이미 있는 숫자면 확실히 틀려요.)',
      success: (_) => '칸이 빨갛게 변했죠? 틀린 숫자를 넣으면 이렇게 표시되고 "실수"가 한 번 늘어요. '
          '실수가 3번이 되면 처음부터 다시 하거나 그대로 계속할 수 있어요.',
      visuals: (c) => _visual(target: {c.vars['wrongCell'] ?? 0}),
      enter: (c) {
        final cell = _firstEmptyExcept(c.game, kLessonNoteCell);
        c.vars['wrongCell'] = cell;
        c.game.select(cell);
      },
      goal: (c) => c.game.isWrong(c.vars['wrongCell'] ?? 0),
      showControls: true,
      allowWrong: true,
    ),
    LessonStep(
      title: '지우기와 취소',
      text: (_) => '틀린 숫자는 "지우기"로 지우거나 "취소"로 방금 한 일을 되돌릴 수 있어요. '
          '깜빡이는 버튼 중 하나를 눌러 보세요.',
      success: (_) => '잘했어요! 참고로 맞게 넣은 숫자는 잠겨서 지워지지 않아요. 틀린 칸만 고칠 수 있어요.',
      visuals: (c) => _visual(target: {c.vars['wrongCell'] ?? 0}),
      enter: (c) => c.game.select(c.vars['wrongCell'] ?? 0),
      goal: (c) => !c.anyWrong,
      showControls: true,
      spotlight: const {'erase', 'undo'},
      allowWrong: true,
    ),
    LessonStep(
      title: '메모로 후보를 적어요',
      text: (c) {
        final cand = CandidateGrid.fromValues(c.game.values).cand[kLessonNoteCell];
        final ds = digitsOf(cand).join('과 ');
        return '확실하지 않을 땐 들어갈 수 있는 숫자를 작게 적어 두면 편해요. '
            '먼저 메모 버튼을 눌러 켜고, 초록 칸이 선택된 걸 확인한 뒤, 이 칸에 들어갈 수 있는 숫자 '
            '$ds, 이 두 개를 눌러 보세요.';
      },
      success: (_) => '메모가 작게 적혔어요! 메모를 켠 채로 같은 숫자를 다시 누르면 지워져요. '
          '메모 버튼을 한 번 더 누르면 원래대로 숫자를 넣는 모드로 돌아와요.',
      visuals: (_) => _visual(target: {kLessonNoteCell}),
      enter: (c) {
        c.game.mistakes = 0;
        c.game.select(kLessonNoteCell);
      },
      goal: (c) =>
          c.game.notes[kLessonNoteCell] ==
          CandidateGrid.fromValues(c.game.values).cand[kLessonNoteCell],
      problem: (c) {
        final cand = CandidateGrid.fromValues(c.game.values).cand[kLessonNoteCell];
        final extra = c.game.notes[kLessonNoteCell] & ~cand;
        if (extra == 0) return null;
        final d = digitsOf(extra).first;
        return '숫자 $d: 같은 행·열·박스에 이미 있어서 이 칸에는 못 들어가요. 한 번 더 눌러 지워 보세요.';
      },
      showControls: true,
      spotlight: const {'notes'},
    ),
    LessonStep(
      title: '빠른 메모',
      text: (_) => '모든 빈 칸에 메모를 하나하나 적는 건 번거롭죠. "빠른 메모" 버튼을 누르면 '
          '모든 빈 칸에 들어갈 수 있는 숫자를 한꺼번에 적어 줘요.',
      success: (_) => '한 번에 다 적혔어요! 이제 후보가 하나뿐인 칸을 찾기 쉬워졌어요. '
          '숫자를 맞게 넣으면 같은 줄의 메모도 알아서 지워져요.',
      goal: (c) {
        for (var i = 0; i < 81; i++) {
          if (c.game.values[i] == 0 && c.game.notes[i] == 0) return false;
        }
        return true;
      },
      showControls: true,
      spotlight: const {'auto'},
    ),
    LessonStep(
      title: '막힐 땐 힌트',
      text: (c) => '어디부터 해야 할지 모르겠다면 힌트(전구) 버튼을 눌러 보세요. 정답만 던져 주는 게 '
          '아니라, 지금 논리로 찾을 수 있는 다음 단계를 이유와 함께 알려 줘요. '
          '설명을 읽고 "입력하기"를 눌러 보세요.',
      success: (_) => '힌트로 한 칸을 채웠어요! 힌트를 쓴 횟수는 기록에 남으니, 먼저 직접 풀어 보고 '
          '막힐 때만 써 보세요.',
      enter: (c) => c.vars['filled'] = c.filledCount,
      goal: (c) =>
          c.game.hintsUsed >= 1 && c.game.hint == null && c.filledCount > (c.vars['filled'] ?? 0),
      showControls: true,
      spotlight: const {'hint'},
    ),
    LessonStep(
      title: '알아두면 좋은 기능',
      text: (_) => '• 숫자가 있는 칸을 누르면 같은 숫자가 모두 강조돼요.\n'
          '• "빠른 입력" 스위치를 켜면 숫자를 먼저 고르고 여러 칸을 연달아 눌러 채울 수 있어요. '
          '손가락으로 쓸어서 한꺼번에 채울 수도 있어요.\n'
          '• 남은 칸이 몇 개 안 남으면 알아서 마무리해 줘요(설정에서 끌 수 있어요).\n'
          '• 일시정지하거나 앱을 나가도 판은 저장돼요.',
    ),
    LessonStep(
      title: '기본 규칙 끝!',
      text: (_) => '이제 스도쿠를 시작할 수 있어요. "쉬움" 난이도는 지금 배운 방법만으로 풀 수 있어요. '
          '더 어려운 판을 풀고 싶다면 심화 기술(싱글, 포인팅, 페어, X-윙 …)을 하나씩 연습해 볼 수도 '
          '있어요. 지금 해도 되고, 스도쿠 메뉴의 "심화 기술 연습"에서 언제든 할 수 있어요.',
      finale: true,
    ),
  ];
}
