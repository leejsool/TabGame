part of 'dandelion_lesson_screen.dart';

// 만져 보는 시연 위젯들 (화면 코드를 역할별로 나눈 파일)

// ───────────────────────── 만져 보는 그림들 ─────────────────────────

Widget _panel({required Widget child}) => Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x22000000)),
      ),
      child: DefaultTextStyle.merge(style: const TextStyle(color: _ink), child: child),
    );

/// 칸을 누를 수 있는 초원 그림.
class _Meadow extends StatelessWidget {
  const _Meadow({
    required this.cells,
    this.rings = const {},
    this.ringColors = const {},
    this.badges = const {},
    this.links = const [],
    this.onTap,
    this.size = 300,
  });

  final List<int> cells;
  final Set<int> rings;
  final Map<int, Color> ringColors;
  final Map<int, bool> badges;
  final List<(int, int)> links;
  final void Function(int cell)? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final side = box.maxWidth.isFinite ? (box.maxWidth < size ? box.maxWidth : size) : size;
        return Center(
          child: SizedBox(
            width: side,
            height: side,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: onTap == null
                  ? null
                  : (d) {
                      final cell = DandLayout(side).hit(d.localPosition);
                      if (cell != null) onTap!(cell);
                    },
              child: CustomPaint(painter: DandScenePainter(cells: cells, rings: rings, ringColors: ringColors, badges: badges, links: links)),
            ),
          ),
        );
      },
    );
  }
}

String _cellName(int cell) => '${cell ~/ kSize + 1}줄 ${cell % kSize + 1}칸';

/// 바람을 불어 "두 방향에서 오는 칸"이 채워지는 것을 본다.
class _GuaranteeDemo extends StatefulWidget {
  const _GuaranteeDemo();

  @override
  State<_GuaranteeDemo> createState() => _GuaranteeDemoState();
}

class _GuaranteeDemoState extends State<_GuaranteeDemo> {
  static const _flowers = [3, 11];
  static const _target = 13; // 위쪽 꽃(0,3)의 아래쪽이면서 왼쪽 꽃(2,1)의 오른쪽인 칸
  int _used = 0;

  List<WindDir> get _winds => [for (final d in WindDir.values) if (_used & (1 << d.index) != 0) d];

  @override
  Widget build(BuildContext context) {
    final cells = DandState.sow(_flowers, _winds);
    final filled = cells[_target] == kSeed;
    return _panel(
      child: Column(
        children: [
          _Meadow(
            cells: cells,
            rings: const {_target},
            ringColors: {_target: filled ? _good : _accent},
            links: filled ? const [] : const [(3, _target), (11, _target)],
            size: 280,
          ),
          const SizedBox(height: 8),
          DandelionCompass(
            size: 150,
            usedMask: _used,
            enabled: true,
            onBlow: (d) => setState(() => _used |= 1 << d.index),
          ),
          const SizedBox(height: 6),
          Text(
            filled
                ? '동그라미 친 칸에 씨앗이 앉았어요! ${_down() && _right() ? '(아래쪽·오른쪽 둘 다 불었어요)' : ''}'
                : (_used == 0 ? '화살표를 눌러 바람을 불어 보세요.' : '아직 비어 있어요. 아래쪽이나 오른쪽으로 불면 채워져요.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.4),
          ),
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: _used == 0 ? null : () => setState(() => _used = 0),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('처음으로'),
          ),
        ],
      ),
    );
  }

  bool _down() => _used & (1 << WindDir.down.index) != 0;
  bool _right() => _used & (1 << WindDir.right.index) != 0;
}

/// 빈칸을 눌러 "반드시 채워지는 칸"인지 알아맞히는 문제.
class _GuaranteePuzzle extends StatefulWidget {
  const _GuaranteePuzzle();

  @override
  State<_GuaranteePuzzle> createState() => _GuaranteePuzzleState();
}

class _GuaranteePuzzleState extends State<_GuaranteePuzzle> {
  int _index = 0;

  /// 문제마다 찾아낸 보장된 칸, 잘못 누른 칸.
  final List<Set<int>> _found = [for (final _ in kGuaranteeScenarios) <int>{}];
  final List<Set<int>> _wrong = [for (final _ in kGuaranteeScenarios) <int>{}];
  String _message = '보장된 칸을 눌러 보세요.';
  bool _reveal = false;
  bool _celebrated = false;

  GuaranteeScenario get _s => kGuaranteeScenarios[_index];

  int _maskOf(GuaranteeScenario s) {
    var m = 0;
    for (final d in s.used) {
      m |= 1 << d.index;
    }
    return m;
  }

  int get _usedMask => _maskOf(_s);

  List<int> get _cells => DandState.sow(_s.flowers, _s.used);

  /// 문제 [i]의 보장된 칸을 모두 찾았는가.
  bool _solved(int i) {
    final s = kGuaranteeScenarios[i];
    final sure = DandState.guaranteed(DandState.sow(s.flowers, s.used), _maskOf(s));
    return sure.isNotEmpty && _found[i].containsAll(sure);
  }

  bool get _allSolved => [for (var i = 0; i < kGuaranteeScenarios.length; i++) _solved(i)].every((e) => e);

  void _pick(int i) {
    final cells = _cells;
    if (cells[i] != kEmpty) {
      setState(() => _message = cells[i] == kFlower ? '꽃이 있는 칸이에요. 빈칸을 눌러 보세요.' : '이미 씨앗이 앉은 칸이에요. (과거에 채워짐) 비어 있는 칸을 눌러 보세요.');
      return;
    }
    final masks = DandState.reachMasks(cells, _usedMask);
    final sure = DandState.guaranteed(cells, _usedMask);
    final dirs = [for (final d in WindDir.values) if (masks[i] & (1 << d.index) != 0) d.label];
    var celebrate = false;
    setState(() {
      if (sure.contains(i)) {
        final fresh = _found[_index].add(i);
        _wrong[_index].remove(i);
        final left = sure.length - _found[_index].length;
        final head = '${_cellName(i)}: ${fresh ? '찾았어요!' : '이미 찾은 칸이에요.'} ${dirs.join('·')} 방향 ${dirs.length}가지 길이 있어서, 바람이 한 방향을 빼도 나머지로 씨앗이 닿아요.';
        if (left > 0) {
          _message = '$head (남은 보장된 칸 $left개)';
        } else {
          _message = '$head\n${_s.title} 완성! 보장된 칸 ${sure.length}개를 모두 찾았어요.';
          if (_allSolved && !_celebrated) {
            _celebrated = true;
            celebrate = true;
          }
        }
      } else {
        _wrong[_index].add(i);
        if (dirs.length == 1) {
          _message = '${_cellName(i)}: 보장되지 않아요. 닿는 길이 ${dirs.first} 방향 하나뿐이라, 바람이 그 방향을 빼면 비어 있어요.';
        } else {
          _message = '${_cellName(i)}: 보장되지 않아요. 지금은 씨앗이 닿는 길이 없어요. 꽃을 더 심어야 해요.';
        }
      }
    });
    if (celebrate) {
      WinSound.play(context);
      showWinCelebration(context, title: '축하해요!', subtitle: '보장된 칸을 모두 찾았어요');
    }
  }

  void _select(int i) => setState(() {
        _index = i;
        _reveal = false;
        _message = _solved(i) ? '이 문제는 이미 모두 찾았어요.' : '보장된 칸을 눌러 보세요.';
      });

  @override
  Widget build(BuildContext context) {
    final cells = _cells;
    final sure = DandState.guaranteed(cells, _usedMask);
    final marks = <int, bool>{
      for (final c in _wrong[_index]) c: false,
      for (final c in _found[_index]) c: true,
      // (정답 보기로 본 칸은 "찾은 칸"으로 치지 않는다)
      if (_reveal) for (final c in sure) c: true,
    };
    return _panel(
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            children: [
              for (var i = 0; i < kGuaranteeScenarios.length; i++)
                ChoiceChip(
                  avatar: _solved(i) ? const Icon(Icons.check_circle_rounded, size: 18, color: _good) : null,
                  label: Text(kGuaranteeScenarios[i].title),
                  selected: _index == i,
                  onSelected: (_) => _select(i),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(_s.note, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, height: 1.4)),
          const SizedBox(height: 2),
          Text(
            '찾은 보장된 칸  ${_found[_index].length} / ${sure.length}',
            key: const ValueKey('guarantee-progress'),
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900, color: _solved(_index) ? _good : _ink),
          ),
          const SizedBox(height: 6),
          _Meadow(
            cells: cells,
            rings: marks.keys.toSet(),
            ringColors: {for (final e in marks.entries) e.key: e.value ? _good : _bad},
            badges: marks,
            onTap: _pick,
            size: 280,
          ),
          const SizedBox(height: 6),
          DandelionCompass(size: 110, usedMask: _usedMask, windsLeft: 7 - _s.used.length),
          const Text('흐린 화살표 = 이미 분 방향', style: TextStyle(fontSize: 12.5, color: Color(0xFF666666))),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFF4F1E8), borderRadius: BorderRadius.circular(12)),
            child: Text(_message, style: const TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w700)),
          ),
          if (_allSolved) ...[
            const SizedBox(height: 8),
            Container(
              key: const ValueKey('guarantee-done'),
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _good.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: _good.withValues(alpha: 0.5))),
              child: const Text(
                '🎉 축하해요! 세 문제의 보장된 칸을 모두 찾았어요.\n두 방향 이상에서 씨앗이 오는 칸은 바람이 어떻게 불어도 채워진다는 걸 알아냈네요.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w800),
              ),
            ),
          ],
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => setState(() {
              _reveal = !_reveal;
              if (_reveal) {
                _message = '초록 체크 표시가 반드시 채워지는 칸이에요. (${sure.length}칸)';
              }
            }),
            icon: Icon(_reveal ? Icons.visibility_off_rounded : Icons.visibility_rounded),
            label: Text(_reveal ? '정답 숨기기' : '보장된 칸 모두 보기'),
          ),
        ],
      ),
    );
  }
}

/// 꽃을 심은 뒤 남은 바람 횟수에 따라 씨앗이 갈 수 있는 길이 달라지는 것을 본다.
class _ReachDemo extends StatefulWidget {
  const _ReachDemo();

  @override
  State<_ReachDemo> createState() => _ReachDemoState();
}

class _ReachDemoState extends State<_ReachDemo> {
  double _left = 7;

  @override
  Widget build(BuildContext context) {
    final k = _left.round();
    final winds = WindDir.values.take(k).toList();
    final cells = DandState.sow(const [12], winds);
    var mask = 0;
    for (final d in winds) {
      mask |= 1 << d.index;
    }
    final seeds = cells.where((c) => c == kSeed).length;
    final who = k == 7 ? '첫 번째 꽃' : (k == 1 ? '마지막 꽃' : '${8 - k}번째 꽃');
    return _panel(
      child: Column(
        children: [
          _Meadow(cells: cells, size: 260),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text('남은 바람', style: TextStyle(fontWeight: FontWeight.w800)),
              Expanded(
                child: Slider(
                  value: _left,
                  min: 1,
                  max: 7,
                  divisions: 6,
                  label: '$k번',
                  activeColor: _accent,
                  onChanged: (v) => setState(() => _left = v),
                ),
              ),
              SizedBox(width: 36, child: Text('$k번', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))),
            ],
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DandelionCompass(size: 96, usedMask: 255 & ~mask),
              const SizedBox(width: 14),
              Flexible(
                child: Text(
                  '$who: 바람을 $k번 맞아서\n최대 $k방향 · 씨앗 $seeds알',
                  style: const TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const Text('(선명한 화살표 = 씨앗이 갈 수 있는 방향)', style: TextStyle(fontSize: 12.5, color: Color(0xFF666666))),
        ],
      ),
    );
  }
}

/// 협력 계획을 한 수씩 넘겨 본다.
class _CoopReplay extends StatefulWidget {
  const _CoopReplay();

  @override
  State<_CoopReplay> createState() => _CoopReplayState();
}

class _CoopReplayState extends State<_CoopReplay> {
  int _step = 0;

  String _caption() {
    if (_step == 0) return '시작: 아무것도 없는 초원이에요. 이 계획에서는 위쪽 방향은 불지 않아요.';
    final m = kCoopMoves[_step - 1];
    final n = (_step + 1) ~/ 2;
    if (_step.isOdd) {
      return '민들레 $n: ${_cellName(m)}에 꽃을 심어요. (남은 바람 ${8 - n}번)';
    }
    final d = WindDir.values[m].label;
    return '바람 $n: $d${d.endsWith('쪽') ? '으' : ''}로 불어요.';
  }

  @override
  Widget build(BuildContext context) {
    final s = DandState.fromMoves(kCoopMoves.take(_step));
    final empties = s.emptyCount;
    return _panel(
      child: Column(
        children: [
          _Meadow(cells: s.cells, size: 280),
          const SizedBox(height: 6),
          DandelionCompass(size: 110, usedMask: s.usedWinds, windsLeft: s.windsLeft),
          const SizedBox(height: 6),
          Text(_caption(), textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            empties == 0 ? '초원이 가득 찼어요! 🎉' : '남은 빈칸 $empties칸',
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: empties == 0 ? _good : const Color(0xFF666666)),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: '이전 수',
                onPressed: _step == 0 ? null : () => setState(() => _step--),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              const SizedBox(width: 12),
              Text('$_step / ${kCoopMoves.length}', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                tooltip: '다음 수',
                onPressed: _step == kCoopMoves.length ? null : () => setState(() => _step++),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 꽃과 바람이 번갈아 나오는 시간표. [flower]번째 꽃과 그 꽃이 맞는 바람들에 표시를 한다.
class _Timeline extends StatelessWidget {
  const _Timeline({required this.flower});

  final int flower;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final w = box.maxWidth.isFinite ? (box.maxWidth < 340 ? box.maxWidth : 340.0) : 340.0;
        return SizedBox(width: w, height: 92, child: CustomPaint(painter: _TimelinePainter(flower)));
      },
    );
  }
}

class _TimelinePainter extends CustomPainter {
  const _TimelinePainter(this.flower);

  final int flower;

  void _text(Canvas canvas, String s, Offset center, double size, Color color, {FontWeight weight = FontWeight.w700}) {
    final tp = TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(fontFamily: 'NanumGothic', fontSize: size, fontWeight: weight, color: color, height: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    const slots = kWindTurns * 2;
    final w = size.width / slots;
    final y = 22.0;
    for (var i = 0; i < slots; i++) {
      final k = i ~/ 2 + 1; // 몇 번째 짝인지
      final isFlower = i.isEven;
      final c = Offset(w * (i + 0.5), y);
      final hot = isFlower ? k == flower : k >= flower;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      if (isFlower) {
        drawFlower(canvas, Offset.zero, w * 0.46, alpha: hot ? 1 : 0.4);
        if (hot) {
          canvas.drawCircle(Offset.zero, w * 0.62, Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..color = const Color(0xFFE08A00));
        }
      } else {
        canvas.translate(-w * 0.42, -w * 0.42);
        canvas.saveLayer(Rect.fromLTWH(0, 0, w * 0.84, w * 0.84), Paint()..color = Colors.white.withValues(alpha: hot ? 1 : 0.35));
        paintRoleIcon(canvas, Size(w * 0.84, w * 0.84), Role.wind);
        canvas.restore();
      }
      canvas.restore();
      if (!isFlower) _text(canvas, '$k', Offset(c.dx, y + w * 0.8), 11, hot ? kWindColor : const Color(0xFF999999), weight: FontWeight.w900);
    }
    // 이 꽃이 맞는 바람들을 묶는 괄호
    final startSlot = (flower - 1) * 2 + 1;
    final x0 = w * startSlot + w * 0.15, x1 = size.width - w * 0.15;
    const by = 64.0;
    final bracket = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..color = kWindColor;
    final path = Path()
      ..moveTo(x0, by - 6)
      ..lineTo(x0, by)
      ..lineTo(x1, by)
      ..lineTo(x1, by - 6);
    canvas.drawPath(path, bracket);
    final n = kWindTurns - flower + 1;
    // 괄호가 짧아도 글이 잘리지 않게, 판 안에 들어오도록 옮겨 놓는다
    final label = TextPainter(
      text: const TextSpan(),
      textDirection: TextDirection.ltr,
    );
    label.text = TextSpan(
      text: '$flower번째 꽃이 맞는 바람: $n번',
      style: const TextStyle(fontFamily: 'NanumGothic', fontSize: 13, fontWeight: FontWeight.w800, color: kWindColor, height: 1.0),
    );
    label.layout();
    final left = ((x0 + x1) / 2 - label.width / 2).clamp(0.0, size.width - label.width);
    label.paint(canvas, Offset(left, by + 8));
  }

  @override
  bool shouldRepaint(_TimelinePainter old) => old.flower != flower;
}
