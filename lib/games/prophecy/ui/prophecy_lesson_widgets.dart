import 'package:flutter/material.dart';

import '../../../tutorial/lesson_kit.dart';
import '../core/prophecy_lessons.dart';
import '../core/prophecy_rules.dart';
import 'prophecy_board.dart';

const Color _good = Color(0xFF2E9E4F);
const Color _bad = Color(0xFFD64545);

/// 만져 보는 그림들을 담는 둥근 상자.
Widget _box(BuildContext context, {required List<Widget> children}) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: scheme.outlineVariant),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );
}

/// 결과 설명 줄 (맞으면 초록, 모순이면 빨강).
Widget _verdict(String text, {required bool good}) {
  final color = good ? _good : _bad;
  return Container(
    margin: const EdgeInsets.only(top: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(text, style: const TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w600)),
  );
}

/// 눌러서 펼치는 "생각해 보기" 상자.
class LessonReveal extends StatefulWidget {
  const LessonReveal({super.key, required this.title, required this.child, this.openLabel = '답 보기'});

  final String title;
  final Widget child;
  final String openLabel;

  @override
  State<LessonReveal> createState() => _LessonRevealState();
}

class _LessonRevealState extends State<LessonReveal> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final accent = LessonAccent.of(context);
    return _box(context, children: [
      Text(widget.title, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, height: 1.45)),
      const SizedBox(height: 6),
      if (_open)
        Padding(padding: const EdgeInsets.only(top: 4), child: widget.child)
      else
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonal(
            style: FilledButton.styleFrom(foregroundColor: accent),
            onPressed: () => setState(() => _open = true),
            child: Text(widget.openLabel),
          ),
        ),
    ]);
  }
}

// ───────────────────────── 맛보기 노트: 스스로를 망치는 숫자 ─────────────────────────

/// 한 줄 [4, X, 빈칸, 3]: 빈칸에 무엇을 쓰든 예언이 스스로를 훼손하는 모습을 보여 준다.
class SelfDefeatDemo extends StatefulWidget {
  const SelfDefeatDemo({super.key});

  @override
  State<SelfDefeatDemo> createState() => _SelfDefeatDemoState();
}

class _SelfDefeatDemoState extends State<SelfDefeatDemo> {
  /// 빈칸에 쓴 것: null = 아직, kCross = X, 숫자.
  int? _pick;

  static const List<int> _fixed = [4, kCross, kBlank, 3];

  List<int> get _row => [for (var i = 0; i < 4; i++) i == 2 ? (_pick ?? kBlank) : _fixed[i]];

  @override
  Widget build(BuildContext context) {
    final row = _row;
    final done = _pick != null;
    final out = rowOutcome(row);
    Widget cell(int i) {
      final v = row[i];
      final isMine = i == 2;
      final hit = done && v > 0 && v == out.count;
      final color = i == 0 ? kPenPink : kPenTeal;
      return Container(
        width: 62,
        height: 62,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isMine && !done ? kProphColor.withValues(alpha: 0.10) : Colors.white,
          border: Border.all(color: const Color(0xFF4A3B3B), width: 2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: v == kCross
            ? const Icon(Icons.close_rounded, size: 40, color: Color(0xFF4A3B3B))
            : v == kBlank
                ? Text('?', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: kProphColor.withValues(alpha: 0.6)))
                : Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: hit ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isMine ? kPenPink : color, width: 3)) : null,
                    child: Text('$v', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: isMine ? kPenPink : color)),
                  ),
      );
    }

    String verdict;
    var good = true;
    if (!done) {
      verdict = '';
    } else if (_pick == kCross) {
      verdict = '빈칸에 X를 쓰면 이 행의 숫자는 4와 3, 모두 2개예요. 그럼 맞은 예언은 하나도 없어요. 청록의 3은 틀리고, 분홍의 4도 틀려요.\n'
          '그런데 "2개"라고 예언한 사람은 없네요. 2를 쓰고 싶어도…';
    } else {
      good = false;
      verdict = '$_pick를 쓰면 숫자가 4, $_pick, 3으로 3개가 돼요. 그러면 맞은 예언은 청록의 3이에요!\n'
          '분홍은 ${_pick == 2 ? '"숫자가 2개일 거야"라는 뜻으로 2를 썼지만, 2를 쓰는 순간 숫자가 3개가 되어 자기 예언이 틀려요. ' : ''}'
          '내가 쓴 숫자가 상대의 예언을 맞게 만들어 버렸어요.';
    }

    return _box(context, children: [
      const Text('분홍(나)이 이 행의 마지막 빈칸을 채울 차례예요. 4와 3은 이미 있고, 가운데 칸은 X예요.',
          style: TextStyle(fontSize: 14.5, height: 1.45)),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (var i = 0; i < 4; i++) ...[if (i > 0) const SizedBox(width: 6), cell(i)]]),
      const SizedBox(height: 4),
      Text(done ? '이 행의 숫자: ${out.count}개' : '빈칸에 무엇을 쓸까요?', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          for (final (label, v) in const [('1 쓰기', 1), ('2 쓰기', 2), ('X 쓰기', kCross)])
            ChoiceChip(label: Text(label), selected: _pick == v, onSelected: (_) => setState(() => _pick = v)),
          if (done) TextButton(onPressed: () => setState(() => _pick = null), child: const Text('다시')),
        ],
      ),
      if (done) _verdict(verdict, good: good),
    ]);
  }
}

// ───────────────────────── 자기 설명 표 ─────────────────────────

/// 칸이 하나뿐인 표(위 줄 1)의 아래 줄에 1, 2를 써 본 모습을 나란히 보여 준다. 어느 쪽도 맞지 않는다.
class OneCellTableExamples extends StatelessWidget {
  const OneCellTableExamples({super.key});

  Widget _cell(String t, {required Color color, bool circled = false}) => Container(
        width: 64,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: Colors.white, border: Border.all(color: const Color(0xFF4A3B3B), width: 1.8)),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: circled ? BoxDecoration(shape: BoxShape.circle, border: Border.all(color: _bad, width: 2.5)) : null,
          child: Text(t, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
        ),
      );

  /// 줄 이름 칸 ("숫자", "나타나는 횟수").
  Widget _label(String t) => Container(
        width: 92,
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: const Color(0xFFF3EDE4), border: Border.all(color: const Color(0xFF4A3B3B), width: 1.8)),
        child: Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF4A3B3B))),
      );

  /// 아래 줄에 [written]을 쓴 경우의 표 한 장과 풀이.
  Widget _example(String title, int written) {
    final actual = occurrences([1], [written]).single;
    return SizedBox(
      width: 170,
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [_label('숫자'), _cell('1', color: kPenTeal, circled: true)]),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [_label('나타나는\n횟수'), _cell('$written', color: kPenPink, circled: written == 1)]),
          const SizedBox(height: 6),
          Text('표 전체에서 숫자 1은 $actual번', style: const TextStyle(fontWeight: FontWeight.w700)),
          Text('그런데 아래 줄은 "$written번"', style: const TextStyle(fontWeight: FontWeight.w700, color: _bad)),
          const SizedBox(height: 4),
          const Icon(Icons.close_rounded, color: _bad, size: 30),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _box(context, children: [
      const Text('위 줄은 숫자 1 하나, 아래 줄은 "그 1이 이 표에 몇 번 나오는지"를 쓰는 칸이에요. 빨간 동그라미가 센 1이에요.',
          style: TextStyle(fontSize: 14.5, height: 1.45)),
      const SizedBox(height: 12),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 24,
        runSpacing: 16,
        children: [
          _example('아래 줄에 1을 쓰면', 1),
          _example('아래 줄에 2를 쓰면', 2),
        ],
      ),
      _verdict('1을 쓰면 1이 두 번 나오게 되어 틀리고, 2로 고치면 이번에는 1이 한 번뿐이라 또 틀려요. 3 이상을 써도 마찬가지예요. 어떤 숫자를 써도 맞지 않아요!', good: false),
    ]);
  }
}

/// 위 줄은 1, 2, …, k, 아래 줄은 "그 숫자가 이 표 전체에 나타나는 횟수". 아래 줄을 직접 고쳐서 표가 자기 자신을
/// 정확히 설명하게 만들어 본다.
class SelfTableLab extends StatefulWidget {
  const SelfTableLab({super.key});

  @override
  State<SelfTableLab> createState() => _SelfTableLabState();
}

class _SelfTableLabState extends State<SelfTableLab> {
  int _k = 4;
  late List<int> _counts = List<int>.filled(_k, 1);

  void _setK(int k) => setState(() {
        _k = k;
        _counts = List<int>.filled(k, 1);
      });

  @override
  Widget build(BuildContext context) {
    final accent = LessonAccent.of(context);
    final numbers = [for (var i = 1; i <= _k; i++) i];
    final occ = occurrences(numbers, _counts);
    final solved = selfDescribing(numbers, _counts);
    Widget cellText(String t, {Color? color, bool bold = false, Color? bg}) => Container(
          width: 50,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, border: Border.all(color: const Color(0xFF4A3B3B), width: 1.6)),
          child: Text(t, style: TextStyle(fontSize: 22, fontWeight: bold ? FontWeight.w900 : FontWeight.w600, color: color)),
        );
    return _box(context, children: [
      Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 4,
        children: [
          const Padding(padding: EdgeInsets.only(right: 2), child: Text('표의 칸 수')),
          for (var k = 1; k <= 5; k++) ChoiceChip(label: Text('$k'), selected: _k == k, onSelected: (_) => _setK(k)),
        ],
      ),
      const SizedBox(height: 10),
      const Text('위 줄: 숫자', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: [for (final n in numbers) cellText('$n', color: kPenTeal, bold: true)]),
      const SizedBox(height: 8),
      const Text('아래 줄: 그 숫자가 이 표에 나타나는 횟수 (위·아래 줄을 모두 센다)', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w700)),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < _k; i++)
            Column(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _counts[i] < 2 * _k ? () => setState(() => _counts[i]++) : null,
                  icon: const Icon(Icons.keyboard_arrow_up_rounded),
                ),
                cellText('${_counts[i]}', color: kPenPink, bold: true, bg: occ[i] == _counts[i] ? _good.withValues(alpha: 0.18) : _bad.withValues(alpha: 0.12)),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: _counts[i] > 1 ? () => setState(() => _counts[i]--) : null,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                ),
                Text('실제 ${occ[i]}번', style: TextStyle(fontSize: 12, color: occ[i] == _counts[i] ? _good : _bad, fontWeight: FontWeight.w700)),
              ],
            ),
        ],
      ),
      if (solved)
        _verdict('성공! 이 표는 자기 자신을 정확히 설명해요. 아래 줄의 숫자를 바꾸면 "나타나는 횟수"도 바뀌어서 다른 칸이 틀려지는데, 이 조합만 모든 칸이 서로 맞물려요.', good: true)
      else
        _verdict('초록 칸은 맞고 빨강 칸은 틀려요. 한 칸을 고치면 다른 칸의 "실제 횟수"가 바뀌어요!', good: false),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          style: TextButton.styleFrom(foregroundColor: accent),
          icon: const Icon(Icons.lightbulb_outline_rounded),
          label: const Text('정답 보기'),
          onPressed: () {
            final sols = selfDescribingTables(_k);
            if (sols.isEmpty) {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text('칸이 $_k개일 때는 답이 없어요'),
                  content: Text('아래 줄에 쓸 수 있는 모든 경우를 하나하나 따져 보면, 칸이 $_k개인 표에는 자기 자신을 정확히 설명하는 짝이 하나도 없어요.\n'
                      '답이 생기는 가장 작은 표는 칸이 4개인 표예요.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요'))],
                ),
              );
            } else {
              setState(() => _counts = List<int>.of(sols.first));
            }
          },
        ),
      ),
    ]);
  }
}

// ───────────────────────── 거짓말쟁이 역설 ─────────────────────────

/// "이 문장은 거짓이다"를 참이라고 가정해 보고, 거짓이라고 가정해 보는 장치.
class LiarDemo extends StatefulWidget {
  const LiarDemo({super.key});

  @override
  State<LiarDemo> createState() => _LiarDemoState();
}

class _LiarDemoState extends State<LiarDemo> {
  bool? _assume;

  @override
  Widget build(BuildContext context) {
    return _box(context, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kProphColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
        child: const Text('"이 문장은 거짓이다."', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      ),
      const SizedBox(height: 10),
      const Text('이 문장이 참인지 거짓인지 가정해 보세요.', textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          ChoiceChip(label: const Text('참이라고 하자'), selected: _assume == true, onSelected: (_) => setState(() => _assume = true)),
          ChoiceChip(label: const Text('거짓이라고 하자'), selected: _assume == false, onSelected: (_) => setState(() => _assume = false)),
        ],
      ),
      if (_assume == true)
        _verdict('참이라고 하면 문장이 말하는 대로 "거짓"이어야 해요. 그런데 참이라고 했으니 모순!', good: false)
      else if (_assume == false)
        _verdict('거짓이라고 하면 "이 문장은 거짓이다"라는 말이 틀린 셈이니, 문장은 거짓이 아니라 참이어야 해요. 또 모순!', good: false),
    ]);
  }
}

// ───────────────────────── 러셀의 역설 / 이발사의 역설 ─────────────────────────

/// "자기 수염을 깎지 않는 사람만 깎아 주는 이발사"는 자기 수염을 깎을까?
class BarberDemo extends StatefulWidget {
  const BarberDemo({super.key});

  @override
  State<BarberDemo> createState() => _BarberDemoState();
}

class _BarberDemoState extends State<BarberDemo> {
  bool? _shaves;

  @override
  Widget build(BuildContext context) {
    return _box(context, children: [
      const Text(
        '어느 마을의 이발사는 "마을에서 자기 수염을 스스로 깎지 않는 사람만, 그리고 그런 사람은 모두 깎아 준다"고 해요.',
        style: TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      const Text('그럼 이발사 자신의 수염은 누가 깎을까요?', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          ChoiceChip(label: const Text('이발사가 스스로 깎는다'), selected: _shaves == true, onSelected: (_) => setState(() => _shaves = true)),
          ChoiceChip(label: const Text('다른 사람이 깎아 준다'), selected: _shaves == false, onSelected: (_) => setState(() => _shaves = false)),
        ],
      ),
      if (_shaves == true)
        _verdict('이발사는 "스스로 깎지 않는 사람"만 깎아 준다고 했어요. 그런데 스스로 깎았으니 자기 규칙을 어겨요. 모순!', good: false)
      else if (_shaves == false)
        _verdict('이발사의 수염을 깎지 않는 사람이 된 거라서, 이발사는 "스스로 깎지 않는 사람은 모두 깎아 준다"는 규칙대로 자기 수염을 깎아야 해요. 그러면 스스로 깎은 거니까… 또 모순!', good: false),
    ]);
  }
}

// ───────────────────────── 불시 시험 역설 ─────────────────────────

/// 불시 시험 역설: "다음 주 평일 중 하루 불시 시험을 본다"는 예고에서, 학생들이 금요일부터 하루씩 지워 나간다.
class ExamDemo extends StatefulWidget {
  const ExamDemo({super.key});

  @override
  State<ExamDemo> createState() => _ExamDemoState();
}

class _ExamDemoState extends State<ExamDemo> {
  int _step = 0; // 지워진 요일 수 (금요일부터)

  static const _days = ['월', '화', '수', '목', '금'];

  static const _lines = [
    '선생님: "다음 주 월~금 중 하루, 불시 시험을 보겠다. 그날 아침까지는 언제인지 아무도 모를 거야."',
    '금요일에 보는 시험이라면? 목요일까지 시험이 없었다면 금요일이 "확실"해져서 불시가 아니에요. 그러니 금요일은 아니에요!',
    '그럼 마지막 후보는 목요일이에요. 수요일까지 안 봤다면 목요일이 "확실"하니 불시가 아니에요. 목요일도 아니에요!',
    '같은 방식으로 수요일도 지워져요. 화요일까지 안 봤다면 수요일이 "확실"하니까요.',
    '화요일도 지워져요. 월요일까지 안 봤다면 화요일이 "확실"하니까요.',
    '월요일만 남는데, 다른 날이 모두 지워졌으니 월요일이 "확실"해요. 그래서 "불시 시험은 불가능하다!"',
  ];

  @override
  Widget build(BuildContext context) {
    final erased = _step.clamp(0, 5);
    return _box(context, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 5; i++)
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (4 - i) < erased ? const Color(0xFFEEEEEE) : kProphColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: (4 - i) < erased ? const Color(0xFFBDBDBD) : kProphColor, width: 2),
              ),
              child: Text(
                _days[i],
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: (4 - i) < erased ? const Color(0xFFBDBDBD) : kProphColor,
                  decoration: (4 - i) < erased ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 10),
      Text(_lines[erased], style: const TextStyle(fontSize: 15, height: 1.5)),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (erased > 0) TextButton(onPressed: () => setState(() => _step = 0), child: const Text('처음부터')),
          if (erased < 5) FilledButton.tonal(onPressed: () => setState(() => _step++), child: Text(erased == 0 ? '학생들의 생각 따라가 보기' : '다음 생각')),
        ],
      ),
      if (erased == 5)
        _verdict('그런데 선생님이 수요일에 시험지를 나눠 주면? 학생들은 "불가능하다고 했는데!" 하며 정말 깜짝 놀라요. 예고는 참이 되었어요. 추론이 어디서 잘못된 걸까요?', good: false),
    ]);
  }
}

// ───────────────────────── 정지 문제 ─────────────────────────

/// 튜링의 정지 문제: "프로그램이 멈출지 맞히는 기계 H"가 있다고 하고, H의 예언을 뒤집는 프로그램 D를 만든다.
class HaltingDemo extends StatefulWidget {
  const HaltingDemo({super.key});

  @override
  State<HaltingDemo> createState() => _HaltingDemoState();
}

class _HaltingDemoState extends State<HaltingDemo> {
  bool? _predictHalts;

  @override
  Widget build(BuildContext context) {
    return _box(context, children: [
      const Text(
        '예언 기계 H는 어떤 프로그램이 "언젠가 멈출지, 영원히 돌지"를 항상 맞힌다고 해요.\n'
        '심술쟁이 프로그램 D는 이렇게 만들었어요: 자기 자신에 대한 H의 예언을 물어보고, 반대로 행동해요.\n'
        '• H가 "D는 멈춘다"라고 하면 → D는 영원히 돌아요.\n'
        '• H가 "D는 영원히 돈다"라고 하면 → D는 곧바로 멈춰요.',
        style: TextStyle(fontSize: 14.5, height: 1.55),
      ),
      const SizedBox(height: 10),
      const Text('H가 D(자기 자신)에 대해 어떻게 예언할까요?', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          ChoiceChip(label: const Text('"멈춘다"'), selected: _predictHalts == true, onSelected: (_) => setState(() => _predictHalts = true)),
          ChoiceChip(label: const Text('"영원히 돈다"'), selected: _predictHalts == false, onSelected: (_) => setState(() => _predictHalts = false)),
        ],
      ),
      if (_predictHalts == true)
        _verdict('H가 "멈춘다"라고 예언하면 D는 반대로 영원히 돌아요. H의 예언이 틀렸어요!', good: false)
      else if (_predictHalts == false)
        _verdict('H가 "영원히 돈다"라고 예언하면 D는 곧바로 멈춰요. 이번에도 H의 예언이 틀렸어요!', good: false),
      if (_predictHalts != null)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('어느 쪽으로 예언해도 틀려요. 그러니 "언제나 맞히는 예언 기계 H"는 만들 수 없어요. 게임 속 "자기 예언을 스스로 무너뜨리는 숫자"와 똑같은 모양이에요!',
              style: TextStyle(fontSize: 14.5, height: 1.5)),
        ),
    ]);
  }
}

// ───────────────────────── 집합으로 수를 쌓기 ─────────────────────────

/// 폰 노이만이 보여 준 방법: 0 = {}, 그다음 수는 앞선 모든 수를 모은 집합. 슬라이더로 수를 바꿔 본다.
class VonNeumannExplorer extends StatefulWidget {
  const VonNeumannExplorer({super.key});

  @override
  State<VonNeumannExplorer> createState() => _VonNeumannExplorerState();
}

class _VonNeumannExplorerState extends State<VonNeumannExplorer> {
  double _n = 3;

  @override
  Widget build(BuildContext context) {
    final n = _n.round();
    final accent = LessonAccent.of(context);
    return _box(context, children: [
      Row(
        children: [
          Text('수 $n', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: accent)),
          Expanded(
            child: Slider(value: _n, min: 0, max: 4, divisions: 4, label: '$n', onChanged: (v) => setState(() => _n = v)),
          ),
        ],
      ),
      Text(
        n == 0
            ? '0 = { }  (아무것도 안 든 빈 주머니, "공집합")'
            : '$n = {${[for (var i = 0; i < n; i++) i].join(', ')}}  (0부터 ${n - 1}까지 모두 든 집합)',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      const Text('수 대신 처음의 { }만 써서 풀어 쓰면:', style: TextStyle(fontSize: 13.5)),
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF4F1EA), borderRadius: BorderRadius.circular(10)),
        child: SelectableText(vonNeumann(n), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.5, fontFamily: 'NanumGothic')),
      ),
      const SizedBox(height: 8),
      Text('원소는 $n개, 중괄호 한 쌍은 모두 ${braceCount(n)}개 (= 2를 $n번 곱한 수)예요.', style: const TextStyle(fontSize: 14, height: 1.5)),
    ]);
  }
}

// ───────────────────────── 수학의 탑 ─────────────────────────

/// 수학의 "탑": 아래 층이 위 층을 받친다. [cracked]이면 맨 아래에 금이 간다.
class MathTowerArt extends StatelessWidget {
  const MathTowerArt({super.key, this.cracked = false});

  final bool cracked;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _TowerPainter(cracked: cracked, accent: LessonAccent.of(context)), size: Size.infinite);
  }
}

class _TowerPainter extends CustomPainter {
  _TowerPainter({required this.cracked, required this.accent});

  final bool cracked;
  final Color accent;

  static const _layers = ['미적분·해석학', '대수·기하', '실수·분수·정수', '자연수와 산수', '집합과 공리 (기초)'];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final layerH = (h - 20) / _layers.length;
    for (var i = 0; i < _layers.length; i++) {
      // 위(0)에서 아래(4)로 갈수록 넓어지는 층
      final width = w * (0.45 + 0.1 * i);
      final r = Rect.fromCenter(center: Offset(w / 2, 10 + layerH * (0.5 + i)), width: width, height: layerH - 4);
      final cracks = cracked && i == _layers.length - 1;
      final shape = RRect.fromRectAndRadius(r, const Radius.circular(8));
      canvas.drawRRect(shape, Paint()..color = cracks ? const Color(0xFFE8B4B4) : accent.withValues(alpha: 0.12 + 0.08 * i));
      canvas.drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = cracks ? _bad : accent,
      );
      final tp = TextPainter(
        text: TextSpan(text: _layers[i], style: const TextStyle(fontFamily: 'NanumGothic', fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF333333))),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - 8);
      tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
      if (cracks) {
        final c = r.center;
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 18, r.top)
            ..lineTo(c.dx - 6, c.dy - 4)
            ..lineTo(c.dx - 20, c.dy + 6)
            ..lineTo(c.dx - 8, r.bottom),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = _bad,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TowerPainter old) => old.cracked != cracked || old.accent != accent;
}
