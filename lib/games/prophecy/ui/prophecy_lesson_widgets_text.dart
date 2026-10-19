part of 'prophecy_lesson_widgets.dart';

// ───────────────────────── 직접 고쳐 보는 자기 설명 문장 ─────────────────────────

/// 글상자에 든 문장을 마음대로 지우고 고쳐 쓰면서, 글자가 몇 개씩 들어 있는지가 바로 바뀌는 것을 보는 상자.
///
/// [keys]가 있으면 그 글자들(소문자로 줄 것)의 개수를 칩으로 보여 주고, 처음 문장과 달라진 칩은 주황색으로 알려 준다.
/// [keys]가 없으면 공백을 뺀 글자 수만 센다. 초기화 단추로 처음 문장으로 돌아간다.
class EditableSentenceTally extends StatefulWidget {
  const EditableSentenceTally({
    super.key,
    required this.initial,
    this.keys,
    this.labelOf,
    this.claimedCount,
    this.fontSize = 15,
  });

  final String initial;

  /// 세어 보여 줄 글자들 (소문자·부호). 영어 문장일 때만 준다.
  final List<String>? keys;

  /// 칩에 쓸 이름 (없으면 대문자로).
  final String Function(String key)? labelOf;

  /// 문장이 스스로 말하는 글자 수 (한국어 문장용). 실제 글자 수와 견준다.
  final int? claimedCount;
  final double fontSize;

  @override
  State<EditableSentenceTally> createState() => _EditableSentenceTallyState();
}

class _EditableSentenceTallyState extends State<EditableSentenceTally> {
  static const Color _changed = Color(0xFFE08A1E);
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  String _label(String k) => widget.labelOf?.call(k) ?? k.toUpperCase();

  @override
  Widget build(BuildContext context) {
    final accent = LessonAccent.of(context);
    final text = _c.text;
    final keys = widget.keys;
    final now = keys == null ? null : charTally(text, keys);
    final base = keys == null ? null : charTally(widget.initial, keys);
    final diff = keys == null ? 0 : keys.where((k) => now![k] != base![k]).length;
    final same = text == widget.initial;
    return _box(context, children: [
      TextField(
        key: const ValueKey('editable-sentence'),
        controller: _c,
        minLines: 2,
        maxLines: null,
        onChanged: (_) => setState(() {}),
        style: TextStyle(fontSize: widget.fontSize, fontWeight: FontWeight.w700, height: 1.45),
        decoration: InputDecoration(
          border: const OutlineInputBorder(),
          isDense: true,
          labelText: '글을 고쳐 보세요 (지우고 쓸 수 있어요)',
          suffixIcon: IconButton(
            key: const ValueKey('editable-clear'),
            tooltip: '모두 지우기',
            icon: const Icon(Icons.backspace_outlined),
            onPressed: () => setState(_c.clear),
          ),
        ),
      ),
      const SizedBox(height: 8),
      if (keys == null) ...[
        Text('공백을 빼고 센 글자 수: ${letterCount(text)}', key: const ValueKey('editable-count'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        if (widget.claimedCount != null)
          _verdict(
            letterCount(text) == widget.claimedCount
                ? '문장이 말한 글자 수(${widget.claimedCount})와 실제 글자 수가 같아요!'
                : '실제로는 ${letterCount(text)}글자인데, 문장은 ${widget.claimedCount}글자라고 말해요. 맞지 않아요.',
            good: letterCount(text) == widget.claimedCount,
          ),
      ] else ...[
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final k in keys)
              Container(
                key: ValueKey('tally-$k'),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: now![k] != base![k] ? _changed.withValues(alpha: 0.18) : kProphColor.withValues(alpha: 0.08),
                  border: now[k] != base[k] ? Border.all(color: _changed, width: 1.4) : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  now[k] != base[k] ? '${_label(k)} ${now[k]} (원래 ${base[k]})' : '${_label(k)} ${now[k]}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          same
              ? '처음 문장 그대로예요. 글자를 고치면 위의 개수가 바로 바뀌어요.'
              : (diff == 0 ? '글자는 달라졌지만 개수는 처음과 같아요.' : '처음과 개수가 달라진 글자가 $diff종류예요 (주황색). 문장이 말한 숫자와 어긋나게 됐어요.'),
          key: const ValueKey('editable-summary'),
          style: const TextStyle(fontSize: 13.5, height: 1.4, color: Color(0xFF555555)),
        ),
      ],
      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          key: const ValueKey('editable-reset'),
          style: TextButton.styleFrom(foregroundColor: accent),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('처음 문장으로'),
          onPressed: () => setState(() => _c.text = widget.initial),
        ),
      ),
    ]);
  }
}

// ───────────────────────── 커리의 역설 ─────────────────────────

/// "A이면 B"의 참거짓표.
class ConditionalTruthTable extends StatelessWidget {
  const ConditionalTruthTable({super.key});

  @override
  Widget build(BuildContext context) {
    Widget cell(String t, {bool head = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          child: Text(t, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: head ? FontWeight.w900 : FontWeight.w700, color: color)),
        );
    TableRow row(String a, String b, String r, String why) => TableRow(children: [
          cell(a, color: a == '참' ? _good : _bad),
          cell(b, color: b == '참' ? _good : _bad),
          cell(r, color: r == '참' ? _good : _bad),
          Padding(padding: const EdgeInsets.all(6), child: Text(why, style: const TextStyle(fontSize: 12.5, height: 1.35))),
        ]);
    return _box(context, children: [
      const Text('"A이면 B이다"는 언제 참일까요?  (예: "비가 오면 땅이 젖는다")', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, height: 1.4)),
      const SizedBox(height: 8),
      Table(
        border: TableBorder.all(color: const Color(0xFF4A3B3B), width: 1),
        columnWidths: const {0: FixedColumnWidth(46), 1: FixedColumnWidth(46), 2: FixedColumnWidth(78), 3: FlexColumnWidth()},
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            decoration: const BoxDecoration(color: Color(0xFFF3EDE4)),
            children: [cell('A', head: true), cell('B', head: true), cell('A이면 B', head: true), cell('이유', head: true)],
          ),
          row('참', '참', '참', '비가 왔고 땅도 젖었어요. 약속을 지켰어요.'),
          row('참', '거짓', '거짓', '비가 왔는데 땅이 안 젖었다면 약속이 깨졌어요.'),
          row('거짓', '참', '참', '비가 안 와도 약속은 깨지지 않았어요. (다른 이유로 젖었을 뿐)'),
          row('거짓', '거짓', '참', '비가 안 왔으니 약속을 시험할 일이 없었어요.'),
        ],
      ),
      const SizedBox(height: 8),
      const Text('약속이 깨지는 경우는 딱 하나, "A는 참인데 B는 거짓"일 때뿐이에요. 이 점이 커리의 역설에서 중요해요.',
          style: TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF555555))),
    ]);
  }
}

/// 커리의 역설을 한 단계씩 따라가 보는 상자. 결론 문장 C를 바꿔 가며 해 볼 수 있다.
class CurryParadoxStepper extends StatefulWidget {
  const CurryParadoxStepper({super.key});

  @override
  State<CurryParadoxStepper> createState() => _CurryParadoxStepperState();
}

class _CurryParadoxStepperState extends State<CurryParadoxStepper> {
  static const List<String> _claims = ['달은 치즈로 되어 있다', '1 + 1 = 3이다', '내일 학교는 쉰다'];
  int _claim = 0;
  int _step = 0;

  static const Color _assume = Color(0xFF3F7CAC);

  /// (이름표, 색, 제목, 글)
  List<(String, Color, String, String)> _steps(String c) => [
        ('가정', _assume, '일단 S가 참이라고 가정해 봐요', '진짜로 참이라는 뜻이 아니에요. "만약 S가 참이라면 어떻게 될까?"를 따져 보는 거예요. (아직 S가 참인지는 몰라요)'),
        ('읽기', _assume, 'S가 참이면, S가 하는 말도 참이에요', 'S가 하는 말은 "S가 참이면 $c"예요. 그러니 가정 아래에서는 이 말도 참이에요.'),
        ('따지기', _good, '가정과 S의 말을 합치면 결론이 나와요', '가정은 "S가 참이다", S의 말은 "S가 참이면 $c". 둘을 합치면 → "$c"가 따라 나와요. (비가 왔고, 비가 오면 땅이 젖는다 → 땅이 젖었다, 와 같은 모양이에요)'),
        ('정리', _good, '방금 한 일을 한 문장으로 말해 보면…', '"S가 참이라고 가정했더니 "$c"라는 결과가 나왔다"는 말은 곧 "S가 참이면 $c"예요. 그런데 이 문장이 바로 S 자신이에요! 그러니 가정을 하나도 쓰지 않고 S를 증명한 셈이에요.'),
        ('결론 1', _bad, 'S는 참이에요', '가정 없이 S가 증명되었으니 S는 정말로 참이에요. 여기까지는 이상한 점이 없어 보여요.'),
        ('결론 2', _bad, '그런데 그러면 "$c"도 참이에요', 'S가 참이고, S가 하는 말은 "S가 참이면 $c"예요. 둘을 합치면 또 "$c"예요. 이번에는 가정이 아니라 증명된 사실이라서 정말로 참이 돼 버려요!'),
      ];

  @override
  Widget build(BuildContext context) {
    final accent = LessonAccent.of(context);
    final c = _claims[_claim];
    final steps = _steps(c);
    return _box(context, children: [
      const Text('결론으로 쓸 말 C를 골라 보세요', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [
          for (var i = 0; i < _claims.length; i++)
            ChoiceChip(
              key: ValueKey('curry-claim-$i'),
              label: Text(_claims[i]),
              selected: _claim == i,
              onSelected: (_) => setState(() {
                _claim = i;
                _step = 0;
              }),
            ),
        ],
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: kProphColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12), border: Border.all(color: kProphColor.withValues(alpha: 0.45))),
        child: Column(
          children: [
            const Text('문장 S', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF666666))),
            Text('"이 문장이 참이라면, $c."', textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, height: 1.4)),
            const SizedBox(height: 6),
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.loop_rounded, size: 20, color: kProphColor),
                SizedBox(width: 6),
                Flexible(child: Text('"이 문장"이 가리키는 것은 S 자신이에요. 그래서 S = "S가 참이면 C"', style: TextStyle(fontSize: 13, height: 1.4))),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      for (var i = 0; i < _step; i++) _stepCard(i, steps[i]),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: FilledButton(
              key: const ValueKey('curry-next'),
              style: FilledButton.styleFrom(backgroundColor: accent),
              onPressed: _step < steps.length ? () => setState(() => _step++) : null,
              child: Text(_step == 0 ? '한 단계씩 따라가 보기' : (_step < steps.length ? '다음 단계 ($_step/${steps.length})' : '끝까지 왔어요')),
            ),
          ),
          if (_step > 0) ...[
            const SizedBox(width: 8),
            TextButton(key: const ValueKey('curry-reset'), onPressed: () => setState(() => _step = 0), child: const Text('처음부터')),
          ],
        ],
      ),
      if (_step == steps.length)
        _verdict('S 한 문장만으로 "$c"를 증명해 버렸어요. C 자리에 무슨 말을 넣어도 똑같이 되니, 이런 문장이 있으면 어떤 말이든 "증명"할 수 있어요. 규칙 체계가 통째로 무너지는 거예요.', good: false),
    ]);
  }

  Widget _stepCard(int i, (String, Color, String, String) s) {
    return Container(
      key: ValueKey('curry-step-$i'),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: s.$2.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: s.$2, width: 5))),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: s.$2, borderRadius: BorderRadius.circular(8)),
                child: Text('${i + 1}. ${s.$1}', style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(s.$3, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, height: 1.35))),
            ],
          ),
          const SizedBox(height: 4),
          Text(s.$4, style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }
}
