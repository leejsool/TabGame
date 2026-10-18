part of 'sprouts_lesson_screen.dart';

// 직접 만져 보는 실험 위젯들 (화면 코드를 역할별로 나눈 파일)

// ───────────────────────── 움직이는 도구들 ─────────────────────────

/// 점의 수를 골라 처음 목숨·최대 수·최소 수를 보는 계산기.
class _LivesCalculator extends StatefulWidget {
  const _LivesCalculator();

  @override
  State<_LivesCalculator> createState() => _LivesCalculatorState();
}

class _LivesCalculatorState extends State<_LivesCalculator> {
  int _n = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget cell(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: _accent)),
              const SizedBox(height: 2),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5)),
            ],
          ),
        );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        color: scheme.surface,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Text('처음 점', style: TextStyle(fontWeight: FontWeight.w800)),
              Expanded(
                child: Slider(
                  min: 1,
                  max: 8,
                  divisions: 7,
                  value: _n.toDouble(),
                  label: '$_n개',
                  onChanged: (v) => setState(() => _n = v.round()),
                ),
              ),
              Text('$_n개', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          Row(
            children: [
              cell('처음 목숨\n(3n)', '${3 * _n}'),
              cell('끝날 때까지\n최대 수 (3n-1)', '${3 * _n - 1}'),
              cell('적어도 두는 수\n(2n)', '${2 * _n}'),
            ],
          ),
        ],
      ),
    );
  }
}

/// 점 2개로 시작해서 한 수씩 두며 점·선·영역·부분을 세어 보는 놀이터.
class _EulerPlayground extends StatefulWidget {
  const _EulerPlayground();

  @override
  State<_EulerPlayground> createState() => _EulerPlaygroundState();
}

class _EulerPlaygroundState extends State<_EulerPlayground> {
  late SproutsBoard _board;
  late SproutsCounts _counts;
  final Random _rng = Random(11);
  int _moves = 0;
  bool _finished = false;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  void _reset() {
    _board = SproutsBoard.initial(2, _rng);
    _counts = countTopology(_board);
    _moves = 0;
    _finished = false;
  }

  void _step() {
    final moves = findMoves(_board);
    if (moves.isEmpty) {
      setState(() => _finished = true);
      return;
    }
    // 고리도 섞이도록 무작위로 고른다
    final m = moves[_rng.nextInt(moves.length)];
    _board.apply(m.s, m.e, m.result, _moves % 2);
    _moves++;
    setState(() {
      _counts = countTopology(_board);
      _finished = findMoves(_board, firstOnly: true).isEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget cell(String label, int v, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
            child: Column(
              children: [
                Text('$v', key: ValueKey('euler-$label'), style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
                Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        );
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
        color: scheme.surface,
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: kBoardW / kBoardH,
            child: CustomPaint(painter: SproutsPainter(board: _board)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              cell('점', _counts.points, const Color(0xFF3E7BFA)),
              const SizedBox(width: 6),
              cell('영역', _counts.regions, const Color(0xFFC2478F)),
              const SizedBox(width: 10),
              const Text('=', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(width: 10),
              cell('선', _counts.lines, const Color(0xFF2E9E5B)),
              const SizedBox(width: 6),
              cell('부분', _counts.parts, const Color(0xFFE08A1E)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${_counts.points} + ${_counts.regions} = ${_counts.left}   ·   ${_counts.lines} + ${_counts.parts} = ${_counts.right}   ${_counts.balanced ? '✔ 같아요!' : ''}',
            key: const ValueKey('euler-equation'),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _finished ? null : _step,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(_finished ? '더 이을 곳이 없어요 ($_moves수)' : '한 수 두기 ($_moves수)'),
                  style: FilledButton.styleFrom(backgroundColor: _accent),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(onPressed: () => setState(_reset), child: const Text('처음부터')),
            ],
          ),
        ],
      ),
    );
  }
}

/// 보통의 띠와 뫼비우스의 띠를 돌려 보는 도구.
class _MobiusLab extends StatefulWidget {
  const _MobiusLab();

  @override
  State<_MobiusLab> createState() => _MobiusLabState();
}

class _MobiusLabState extends State<_MobiusLab> {
  bool _twisted = true;
  double _angle = 0.6;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        lessonArt(CustomPaint(painter: MobiusPainter(twisted: _twisted, angle: _angle)), height: 260),
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('보통 고리')),
            ButtonSegment(value: true, label: Text('뫼비우스의 띠 (반 바퀴 비틀기)')),
          ],
          selected: {_twisted},
          onSelectionChanged: (s) => setState(() => _twisted = s.first),
        ),
        Row(
          children: [
            const Text('돌려 보기', style: TextStyle(fontWeight: FontWeight.w800)),
            Expanded(
              child: Slider(min: 0, max: 2 * pi, value: _angle, onChanged: (v) => setState(() => _angle = v)),
            ),
          ],
        ),
      ],
    );
  }
}
