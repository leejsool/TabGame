import 'package:flutter/material.dart';

import '../../../tutorial/lesson_kit.dart';
import '../core/prophecy_lessons.dart';
import '../core/prophecy_rules.dart';
import 'prophecy_board.dart';

part 'prophecy_lesson_widgets_more.dart';

part 'prophecy_lesson_widgets_text.dart';

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
  static const Color _ink = Color(0xFF222222);

  int _k = 4;
  late List<int> _counts = List<int>.filled(_k, 1);

  void _setK(int k) => setState(() {
        _k = k;
        _counts = List<int>.filled(k, 1);
      });

  /// 위·아래 화살표 단추 (스핀 단추). [enabled]가 아니면 흐리게.
  Widget _arrow({required bool up, required bool enabled, required VoidCallback onTap, required Key key}) => InkWell(
        key: key,
        onTap: enabled ? onTap : null,
        child: SizedBox(
          height: 29,
          child: Center(child: Icon(up ? Icons.arrow_drop_up : Icons.arrow_drop_down, size: 38, color: enabled ? _ink : Colors.black26)),
        ),
      );

  /// 표 아래 줄의 한 칸: 왼쪽에 숫자, 오른쪽에 위·아래 화살표.
  Widget _spinCell(int i, {required bool ok}) => Container(
        height: 60,
        color: ok ? _good.withValues(alpha: 0.16) : _bad.withValues(alpha: 0.10),
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: Text('${_counts[i]}', key: ValueKey('self-count-$i'), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: kPenPink)),
              ),
            ),
            Container(
              width: 30,
              decoration: const BoxDecoration(border: Border(left: BorderSide(color: _ink, width: 1.2))),
              child: Column(
                children: [
                  _arrow(up: true, key: ValueKey('self-up-$i'), enabled: _counts[i] < 2 * _k, onTap: () => setState(() => _counts[i]++)),
                  const Divider(height: 1, thickness: 1.2, color: _ink),
                  _arrow(up: false, key: ValueKey('self-down-$i'), enabled: _counts[i] > 1, onTap: () => setState(() => _counts[i]--)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _label(String t) => Container(
        height: 60,
        alignment: Alignment.center,
        child: Text(t, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1.35, color: _ink)),
      );

  @override
  Widget build(BuildContext context) {
    final accent = LessonAccent.of(context);
    final numbers = [for (var i = 1; i <= _k; i++) i];
    final occ = occurrences(numbers, _counts);
    final solved = selfDescribing(numbers, _counts);
    final widths = <int, TableColumnWidth>{0: const FixedColumnWidth(78), for (var i = 1; i <= _k; i++) i: const FlexColumnWidth()};
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
      Table(
        key: const ValueKey('self-table'),
        border: TableBorder.all(color: _ink, width: 1.2),
        columnWidths: widths,
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(children: [
            _label('숫자'),
            for (final n in numbers)
              Container(
                height: 40,
                alignment: Alignment.center,
                // (아래 줄의 화살표 단추 폭만큼 오른쪽을 비워서, 아래 줄의 숫자와 같은 세로줄에 놓는다)
                padding: const EdgeInsets.only(right: 30),
                child: Text('$n', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800, color: kPenTeal)),
              ),
          ]),
          TableRow(children: [
            _label('나타나는\n횟수'),
            for (var i = 0; i < _k; i++) _spinCell(i, ok: occ[i] == _counts[i]),
          ]),
        ],
      ),
      const SizedBox(height: 6),
      // 표 아래: 칸마다 "실제로는 몇 번 나오는지" (위·아래 줄을 모두 센 값)
      Table(
        columnWidths: widths,
        children: [
          TableRow(children: [
            const SizedBox(),
            for (var i = 0; i < _k; i++)
              Padding(
                padding: const EdgeInsets.only(right: 30),
                child: Text('실제 ${occ[i]}번',
                    key: ValueKey('self-actual-$i'),
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: occ[i] == _counts[i] ? _good : _bad, fontWeight: FontWeight.w800)),
              ),
          ]),
        ],
      ),
      const Padding(
        padding: EdgeInsets.only(top: 6),
        child: Text('아래 줄의 숫자도 표의 일부라서 함께 세어야 해요. 초록 칸은 맞고, 빨강 칸은 틀려요.', style: TextStyle(fontSize: 12.5, color: Color(0xFF666666))),
      ),
      if (solved)
        _verdict('성공! 이 표는 자기 자신을 정확히 설명해요. 아래 줄의 숫자를 바꾸면 "나타나는 횟수"도 바뀌어서 다른 칸이 틀려지는데, 이 조합만 모든 칸이 서로 맞물려요.', good: true)
      else
        _verdict('한 칸을 고치면 다른 칸의 "실제 횟수"가 바뀌어요! 모든 칸이 초록이 되도록 맞춰 보세요.', good: false),
      const SizedBox(height: 6),
      Align(
        alignment: Alignment.centerRight,
        child: Wrap(
          spacing: 4,
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(foregroundColor: accent),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('처음으로'),
              onPressed: () => setState(() => _counts = List<int>.filled(_k, 1)),
            ),
            TextButton.icon(
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
          ],
        ),
      ),
    ]);
  }
}

// ───────────────────────── 거짓말쟁이 역설 ─────────────────────────
