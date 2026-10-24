import 'dart:math';

import 'package:flutter/material.dart';

import '../../../tutorial/lesson_kit.dart';

/// 베스킨라빈스 31 게임: 1부터 차례로 한 번에 1~3개씩 수를 부르고, 31을 부르는 사람이 진다.
/// 이기는 사람은 30을 부르는 사람이고, 그러려면 26, 22, 18, 14, 10, 6, 2를 차지하면 된다.
bool is31Key(int n) => n % 4 == 2;

/// 컴퓨터가 [last] 다음에 부를 마지막 수. 열쇠 수(4로 나눈 나머지 2)에 닿을 수 있으면 거기까지.
int cpu31(int last, Random rng) {
  for (var k = 1; k <= 3; k++) {
    if (last + k <= 31 && is31Key(last + k)) return last + k;
  }
  return min(31, last + 1 + rng.nextInt(min(3, 31 - last)));
}

/// 교과학습 안에서 바로 해 보는 31 게임 (나 vs 컴퓨터).
class Lesson31Game extends StatefulWidget {
  const Lesson31Game({super.key, this.seed});

  final int? seed;

  @override
  State<Lesson31Game> createState() => Lesson31GameState();
}

class Lesson31GameState extends State<Lesson31Game> {
  late final Random _rng = Random(widget.seed);

  /// 부른 수마다 누가 불렀는지 (true = 나). 길이가 곧 마지막으로 부른 수.
  final List<bool> _said = [];
  bool _started = false;
  bool _showKeys = false;

  int get _last => _said.length;
  bool get _over => _last >= 31;

  void _start(bool meFirst) {
    setState(() {
      _said.clear();
      _started = true;
      if (!meFirst) _cpuTurn();
    });
  }

  void _cpuTurn() {
    final to = cpu31(_last, _rng);
    while (_said.length < to) {
      _said.add(false);
    }
  }

  void _say(int count) {
    setState(() {
      for (var i = 0; i < count && _said.length < 31; i++) {
        _said.add(true);
      }
      if (!_over) _cpuTurn();
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = LessonAccent.of(context);
    final iLost = _over && _said.last;
    final status = !_started
        ? '누가 먼저 할까요?'
        : _over
            ? (iLost ? '31을 불렀어요… 컴퓨터가 이겼어요' : '컴퓨터가 31을 불렀어요. 내가 이겼어요!')
            : '내 차례예요. 수를 몇 개 부를까요?';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Wrap(spacing: 6, runSpacing: 6, alignment: WrapAlignment.center, children: [
          for (var n = 1; n <= 31; n++) _Ball(n: n, by: n <= _last ? _said[n - 1] : null, key31: _showKeys && is31Key(n), accent: accent),
        ]),
        const SizedBox(height: 10),
        Text(status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
          if (!_started || _over) ...[
            FilledButton(onPressed: () => _start(true), style: FilledButton.styleFrom(backgroundColor: accent), child: const Text('내가 먼저')),
            OutlinedButton(onPressed: () => _start(false), child: const Text('컴퓨터 먼저')),
          ] else
            for (var k = 1; k <= 3 && _last + k <= 31; k++)
              FilledButton.tonal(
                onPressed: () => _say(k),
                child: Text([for (var i = 1; i <= k; i++) '${_last + i}'].join(', ')),
              ),
        ]),
        const SizedBox(height: 4),
        TextButton.icon(
          onPressed: () => setState(() => _showKeys = !_showKeys),
          icon: Icon(_showKeys ? Icons.visibility_off_rounded : Icons.key_rounded),
          label: Text(_showKeys ? '열쇠 수 숨기기' : '열쇠 수 보기'),
        ),
      ]),
    );
  }
}

/// 1~31 수 하나. 내가 부른 수는 초록, 컴퓨터가 부른 수는 회색, 열쇠 수는 노란 테두리.
class _Ball extends StatelessWidget {
  const _Ball({required this.n, required this.by, required this.key31, required this.accent});

  final int n;
  final bool? by;
  final bool key31;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final fill = by == null ? Colors.white : (by! ? accent : const Color(0xFF8A8F86));
    return Container(
      width: 34,
      height: 34,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: key31 ? const Color(0xFFF2B705) : const Color(0x33000000), width: key31 ? 3 : 1),
      ),
      child: Text(
        '$n',
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: by == null ? const Color(0xFF555555) : Colors.white),
      ),
    );
  }
}
