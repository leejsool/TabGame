import 'dart:math';

import 'package:flutter/material.dart';

import '../../../tutorial/lesson_kit.dart';
import '../core/yacht_fraction.dart';
import 'yacht_dice_sound.dart';
import 'yacht_fraction_view.dart';
import 'yacht_lesson_parts.dart';
import 'yacht_look.dart';

/// 교과학습 그림에 쓰는 "일어나는 일" 하나: 주사위 두 개(A, B)의 눈으로 정한다.
class YachtLessonEvent {
  const YachtLessonEvent(this.label, this.test);

  final String label;
  final bool Function(int a, int b) test;
}

/// "a / b = 약분한 값" 한 줄.
class YachtFracLine extends StatelessWidget {
  const YachtFracLine(this.num, this.den, {super.key, this.size = 18});

  final int num;
  final int den;
  final double size;

  @override
  Widget build(BuildContext context) {
    final f = YachtFrac(num, den);
    final accent = LessonAccent.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        YachtFractionView.raw(num, den, size: size, bold: true, color: accent),
        if (f.num != num || f.den != den) ...[
          Text('  =  ', style: TextStyle(fontSize: size, fontWeight: FontWeight.w800)),
          YachtFractionView(f, size: size, bold: true, color: accent),
        ],
        Text('   (약 ${yachtPercent(num / den)})', style: TextStyle(fontSize: size * 0.8, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

/// 주사위 두 개의 36가지 경우를 6×6 표로 보여 주고, 알고 싶은 일([events])과 이미 아는 사실([conditions])을 골라 칸을 세어 보는 그림.
/// [conditions]가 있으면 첫 항목은 "조건 없음"이어야 한다.
class TwoDiceExplorer extends StatefulWidget {
  const TwoDiceExplorer({super.key, required this.events, this.conditions, this.initialEvent = 0, this.initialCondition = 0, this.tags = false});

  /// 고르개 이름 앞에 "사건 A"(알고 싶은 일) · "사건 B"(조건) 꼬리표를 붙인다.
  final bool tags;

  final List<YachtLessonEvent> events;
  final List<YachtLessonEvent>? conditions;
  final int initialEvent;
  final int initialCondition;

  @override
  State<TwoDiceExplorer> createState() => _TwoDiceExplorerState();
}

class _TwoDiceExplorerState extends State<TwoDiceExplorer> {
  late int _event = widget.initialEvent;
  late int _cond = widget.initialCondition;

  Widget _chips(String title, List<YachtLessonEvent> items, int selected, ValueChanged<int> onPick, {String? tag}) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (tag != null) ...[eventTag(tag), const SizedBox(width: 8)],
            Flexible(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800))),
          ]),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < items.length; i++)
                ChoiceChip(
                  label: yachtRich(items[i].label, const TextStyle(fontFamily: 'NanumGothic', fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF222222))),
                  selected: i == selected,
                  onSelected: (_) => onPick(i),
                ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = LessonAccent.of(context);
    final ev = widget.events[_event];
    final conds = widget.conditions;
    final cond = conds?[_cond];
    final hasCond = conds != null && _cond > 0;
    var inCond = 0, hit = 0;
    for (var a = 1; a <= 6; a++) {
      for (var b = 1; b <= 6; b++) {
        final c = !hasCond || cond!.test(a, b);
        if (c) inCond++;
        if (c && ev.test(a, b)) hit++;
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _chips('알고 싶은 일', widget.events, _event, (i) => setState(() => _event = i), tag: widget.tags ? 'A' : null),
        if (conds != null) _chips('이미 알고 있는 사실 (조건)', conds, _cond, (i) => setState(() => _cond = i), tag: widget.tags ? 'B' : null),
        const SizedBox(height: 8),
        lessonArt(
          LayoutBuilder(builder: (context, box) {
            final cell = min((box.maxWidth - 24) / 7, 52.0);
            Widget head(Widget child) => SizedBox(width: cell, height: cell, child: Center(child: child));
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      // 모서리: 왼쪽 줄은 주사위 ①, 위쪽 줄은 주사위 ②
                      SizedBox(
                        width: cell,
                        height: cell,
                        child: Stack(children: [
                          Positioned.fill(child: CustomPaint(painter: _SlashPainter())),
                          Positioned(left: 3, bottom: 3, child: CircleNum(1, size: cell * 0.32)),
                          Positioned(right: 3, top: 3, child: CircleNum(2, size: cell * 0.32)),
                        ]),
                      ),
                      for (var b = 1; b <= 6; b++) head(YachtDie(value: b, size: cell * 0.7)),
                    ]),
                    for (var a = 1; a <= 6; a++)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        head(YachtDie(value: a, size: cell * 0.7)),
                        for (var b = 1; b <= 6; b++) _cell(a, b, cell, accent, ev, hasCond ? cond : null),
                      ]),
                  ],
                ),
              ),
            );
          }),
          height: null,
        ),
        yachtRich('왼쪽 줄은 주사위 ①, 위쪽 줄은 주사위 ②의 눈이에요. 색칠한 칸이 "알고 싶은 일"이고, 회색 칸은 조건에 맞지 않아 빠진 칸이에요.',
            const TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF666666)), align: TextAlign.center),
        const SizedBox(height: 6),
        Center(
          child: Column(
            children: [
              Text(
                hasCond ? '조건에 맞는 $inCond칸 중에서 $hit칸' : '전체 36칸 중에서 $hit칸',
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              FittedBox(fit: BoxFit.scaleDown, child: YachtFracLine(hit, inCond)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cell(int a, int b, double size, Color accent, YachtLessonEvent ev, YachtLessonEvent? cond) {
    final inCond = cond == null || cond.test(a, b);
    final hit = inCond && ev.test(a, b);
    return Container(
      width: size,
      height: size,
      margin: EdgeInsets.zero,
      decoration: BoxDecoration(
        color: hit ? accent.withValues(alpha: 0.85) : (inCond ? Colors.white : const Color(0xFFE4E4E4)),
        border: Border.all(color: const Color(0x33000000), width: 0.6),
      ),
      alignment: Alignment.center,
      child: Text(
        '$a,$b',
        style: TextStyle(
          fontSize: size * 0.26,
          fontWeight: FontWeight.w700,
          color: hit ? Colors.white : (inCond ? Colors.black87 : Colors.black26),
        ),
      ),
    );
  }
}

/// "주사위 n개를 굴려 6이 적어도 하나 나올 확률"을 슬라이더로 바꿔 보는 그림: 반대(하나도 안 나옴)를 먼저 구해 1에서 뺀다.
class AtLeastOneExplorer extends StatefulWidget {
  const AtLeastOneExplorer({super.key});

  @override
  State<AtLeastOneExplorer> createState() => _AtLeastOneExplorerState();
}

class _AtLeastOneExplorerState extends State<AtLeastOneExplorer> {
  int _n = 3;

  @override
  Widget build(BuildContext context) {
    final accent = LessonAccent.of(context);
    final all = pow(6, _n).toInt(), none = pow(5, _n).toInt();
    final p = (all - none) / all;
    const label = TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.4);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 3,
              children: [for (var i = 0; i < _n; i++) const YachtDie(value: 6, size: 34)],
            ),
            Row(
              children: [
                const Text('주사위 수', style: TextStyle(fontWeight: FontWeight.w800)),
                Expanded(
                  child: Slider(
                    min: 1,
                    max: 6,
                    divisions: 5,
                    value: _n.toDouble(),
                    label: '$_n개',
                    onChanged: (v) => setState(() => _n = v.round()),
                  ),
                ),
                Text('$_n개', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
              ],
            ),
            Text('1) 모든 경우: 6을 $_n번 곱해서 $all가지', style: label),
            Text('2) 6이 하나도 안 나오는 경우: 주사위마다 1~5의 5가지 → 5를 $_n번 곱해서 $none가지', style: label),
            const SizedBox(height: 4),
            Row(children: [
              const Text('   하나도 안 나올 확률 = ', style: label),
              Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: YachtFracLine(none, all, size: 16))),
            ]),
            const SizedBox(height: 6),
            Text('3) 적어도 하나 나올 확률 = 1 - (하나도 안 나올 확률)', style: label.copyWith(color: accent, fontWeight: FontWeight.w900)),
            Row(children: [
              const Text('   = ', style: label),
              Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: YachtFracLine(all - none, all, size: 16))),
            ]),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                height: 22,
                child: Row(children: [
                  Expanded(flex: (p * 1000).round(), child: Container(color: accent)),
                  Expanded(flex: 1000 - (p * 1000).round(), child: Container(color: const Color(0xFFDDDDDD))),
                ]),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _n == 6 ? '6개를 굴려도 "꼭" 나오지는 않아요! (6 × 1/6 = 1 이 아니에요)' : '주사위가 늘어도 100%가 되지는 않아요.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF555555)),
            ),
          ],
        ),
      ),
    );
  }
}

/// 같은 눈 4개를 고정하고 남은 1개를 두 번까지 다시 굴릴 때의 나뭇가지 그림.
class RerollTree extends StatelessWidget {
  const RerollTree({super.key});

  @override
  Widget build(BuildContext context) {
    final accent = LessonAccent.of(context);
    const fail = Color(0xFF9A9A9A);
    Widget row(int depth, String text, int num, int den, {String? result, int? rn, int? rd, bool ok = false}) {
      return Padding(
        padding: EdgeInsets.only(left: depth * 26.0, top: 5, bottom: 5),
        child: Row(
          children: [
            Icon(depth == 0 ? Icons.subdirectory_arrow_right_rounded : Icons.subdirectory_arrow_right_rounded, size: 20, color: Colors.black38),
            const SizedBox(width: 4),
            Flexible(child: Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700))),
            const SizedBox(width: 6),
            YachtFractionView.raw(num, den, size: 14),
            if (result != null) ...[
              const Spacer(),
              Text(result, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: ok ? accent : fail)),
              const SizedBox(width: 4),
              YachtFractionView.raw(rn!, rd!, size: 14, bold: true, color: ok ? accent : fail),
            ],
          ],
        ),
      );
    }

    return lessonArt(
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(children: [
              YachtDie(value: 3, size: 30, held: true),
              SizedBox(width: 3),
              YachtDie(value: 3, size: 30, held: true),
              SizedBox(width: 3),
              YachtDie(value: 3, size: 30, held: true),
              SizedBox(width: 3),
              YachtDie(value: 3, size: 30, held: true),
              SizedBox(width: 8),
              Text('+ 주사위 1개 다시 굴리기', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
            ]),
            const SizedBox(height: 6),
            row(0, '1번째에 3이 나옴', 1, 6, result: '야추!', rn: 6, rd: 36, ok: true),
            row(0, '1번째에 3이 안 나옴', 5, 6),
            row(1, '2번째에 3이 나옴', 1, 6, result: '5/6 × 1/6 =', rn: 5, rd: 36, ok: true),
            row(1, '2번째도 안 나옴', 5, 6, result: '5/6 × 5/6 =', rn: 25, rd: 36),
          ],
        ),
      ),
      height: null,
      caption: '야추가 되는 길은 두 가지: 6/36 + 5/36 = 11/36',
    );
  }
}

/// 주사위를 여러 번 굴려 평균이 3.5에 가까워지는 것을 보는 그림.
class AverageSimulator extends StatefulWidget {
  const AverageSimulator({super.key, this.seed});

  /// 테스트에서 같은 결과가 나오게 할 때.
  final int? seed;

  @override
  State<AverageSimulator> createState() => _AverageSimulatorState();
}

class _AverageSimulatorState extends State<AverageSimulator> {
  late final Random _rng = Random(widget.seed);
  final List<int> _counts = List<int>.filled(6, 0);

  /// 굴릴 때 나는 주사위 소리 (게임과 같은 소리. 여러 번 굴리면 주사위 여러 개 소리).
  final YachtDiceSound _sound = YachtDiceSound();

  @override
  void dispose() {
    _sound.dispose();
    super.dispose();
  }

  int get _total => _counts.fold(0, (a, b) => a + b);

  void _roll(int times) {
    _sound.play(min(times, 5));
    setState(() {
        for (var i = 0; i < times; i++) {
          _counts[_rng.nextInt(6)]++;
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    final accent = LessonAccent.of(context);
    final total = _total;
    var sum = 0;
    for (var i = 0; i < 6; i++) {
      sum += _counts[i] * (i + 1);
    }
    final most = _counts.reduce(max);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            SizedBox(
              height: 120,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < 6; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('${_counts[i]}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              height: most == 0 ? 2 : 2 + 70.0 * _counts[i] / most,
                              decoration: BoxDecoration(color: accent.withValues(alpha: 0.8), borderRadius: BorderRadius.circular(4)),
                            ),
                            const SizedBox(height: 4),
                            YachtDie(value: i + 1, size: 26),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              total == 0 ? '단추를 눌러 굴려 보세요' : '$total번 굴린 눈의 평균: ${(sum / total).toStringAsFixed(3)}',
              key: const ValueKey('yacht-lesson-average'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final t in const [1, 10, 100, 1000])
                  FilledButton.tonal(onPressed: () => _roll(t), child: Text('$t번')),
                TextButton(onPressed: total == 0 ? null : () => setState(() => _counts.fillRange(0, 6, 0)), child: const Text('처음부터')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 표 모서리 칸의 대각선.
class _SlashPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(Offset(size.width * 0.15, size.height * 0.15), Offset(size.width * 0.85, size.height * 0.85), Paint()..color = const Color(0x55000000)..strokeWidth = 1.2);
  }

  @override
  bool shouldRepaint(_SlashPainter old) => false;
}
