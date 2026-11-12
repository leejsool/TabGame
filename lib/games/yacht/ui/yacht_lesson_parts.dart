import 'dart:math';

import 'package:flutter/material.dart';

import '../../../tutorial/lesson_kit.dart';

// 야추 교과학습의 글·식 조각: 원 안의 번호(①②), 진짜 분수 모양, 조건부 확률 식 카드, 식 뒤집기 애니메이션, 도박사의 오류 실험.

/// 사건 A · 사건 B의 색 (표의 고르개, 식 카드, 애니메이션이 같은 색을 쓴다).
const Color kEventA = Color(0xFF2D7D5A);
const Color kEventB = Color(0xFF3F6FB5);

/// 원 안의 번호 (글꼴에 ①② 글자가 없어서 직접 그린다).
class CircleNum extends StatelessWidget {
  const CircleNum(this.n, {super.key, this.size = 16, this.color = const Color(0xFF444444)});

  final int n;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 1.15,
      height: size * 1.15,
      alignment: Alignment.center,
      decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color, width: max(1.2, size * 0.08))),
      child: Text('$n', style: TextStyle(fontFamily: 'NanumGothic', fontSize: size * 0.72, height: 1.0, fontWeight: FontWeight.w900, color: color)),
    );
  }
}

/// 글 속 분수 (분자 위, 가로줄, 분모 아래).
class InlineFrac extends StatelessWidget {
  const InlineFrac(this.num, this.den, {super.key, required this.style});

  final String num;
  final String den;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final s = style.copyWith(fontSize: (style.fontSize ?? 15) * 1.0, height: 1.1, fontWeight: FontWeight.w800);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(num, textAlign: TextAlign.center, style: s),
            Container(height: 1.3, margin: const EdgeInsets.symmetric(vertical: 1), color: s.color ?? Colors.black87),
            Text(den, textAlign: TextAlign.center, style: s),
          ],
        ),
      ),
    );
  }
}

final RegExp _special = RegExp(r'[①②]|(\d+)/(\d+)');

/// 글을 그린다: ①② 는 원 안의 번호로, [fractions]면 "3/36" 같은 분수는 진짜 분수 모양으로.
Widget yachtRich(String text, TextStyle style, {bool fractions = false, TextAlign align = TextAlign.start}) {
  final spans = <InlineSpan>[];
  var at = 0;
  for (final m in _special.allMatches(text)) {
    final isFrac = m.group(1) != null;
    if (isFrac && !fractions) continue;
    if (m.start > at) spans.add(TextSpan(text: text.substring(at, m.start)));
    if (isFrac) {
      spans.add(WidgetSpan(alignment: PlaceholderAlignment.middle, child: InlineFrac(m.group(1)!, m.group(2)!, style: style)));
    } else {
      final size = (style.fontSize ?? 15) * 0.95;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.middle,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 1.5), child: CircleNum(m.group(0) == '①' ? 1 : 2, size: size, color: style.color ?? const Color(0xFF444444))),
      ));
    }
    at = m.end;
  }
  if (at < text.length) spans.add(TextSpan(text: text.substring(at)));
  return Text.rich(TextSpan(style: style, children: spans), textAlign: align);
}

/// 교과학습 글 한 문단 (①② 를 그려 준다).
Widget richP(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: yachtRich(text, const TextStyle(fontSize: 16, height: 1.6, color: Color(0xFF222222))),
    );

/// 교과학습 글 목록 (①② 를 그려 준다).
Widget richBullets(BuildContext context, List<String> items) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(fontSize: 16, color: LessonAccent.of(context), fontWeight: FontWeight.w900)),
                  Expanded(child: yachtRich(t, const TextStyle(fontSize: 16, height: 1.55, color: Color(0xFF222222)))),
                ],
              ),
            ),
        ],
      ),
    );

/// "사건 A" · "사건 B" 꼬리표.
Widget eventTag(String letter) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: letter == 'A' ? kEventA : kEventB, borderRadius: BorderRadius.circular(8)),
      child: Text('사건 $letter', style: const TextStyle(fontFamily: 'NanumGothic', fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white)),
    );

/// 식 속의 글: A, B 글자를 사건의 색으로 칠한다.
TextSpan _abSpan(String text, TextStyle style) {
  final spans = <TextSpan>[];
  for (final ch in text.split('')) {
    if (ch == 'A' || ch == 'B') {
      spans.add(TextSpan(text: ch, style: style.copyWith(color: ch == 'A' ? kEventA : kEventB, fontWeight: FontWeight.w900)));
    } else {
      spans.add(TextSpan(text: ch));
    }
  }
  return TextSpan(style: style, children: spans);
}

Widget _ab(String text, double size, {TextAlign align = TextAlign.center, FontWeight weight = FontWeight.w800}) =>
    Text.rich(_abSpan(text, TextStyle(fontFamily: 'NanumGothic', fontSize: size, height: 1.3, fontWeight: weight, color: const Color(0xFF222222))), textAlign: align);

Widget _frac(Widget top, Widget bottom) => IntrinsicWidth(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: top),
          Container(height: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: const Color(0xFF333333)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: bottom),
        ],
      ),
    );

/// 조건부 확률의 식을 하얀 상자 안에 표처럼 정리한 카드: 등호(=)가 한 줄로 맞는다.
class ConditionalFormulaCard extends StatelessWidget {
  const ConditionalFormulaCard({super.key});

  @override
  Widget build(BuildContext context) {
    const eq = Padding(padding: EdgeInsets.symmetric(horizontal: 10), child: Text('=', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)));
    TableRow row(Widget lhs, Widget rhs) => TableRow(children: [
          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: lhs),
          eq,
          Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Align(alignment: Alignment.centerLeft, child: rhs)),
        ]);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD84D), width: 2),
        boxShadow: const [BoxShadow(color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.filter_alt_rounded, color: Color(0xFFB88700)),
            const SizedBox(width: 6),
            const Text('조건부 확률', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(width: 10),
            Flexible(child: _ab('P(A|B)', 18, align: TextAlign.left, weight: FontWeight.w900)),
          ]),
          const SizedBox(height: 4),
          _ab('B가 일어났다는 것을 알 때 A가 일어날 확률', 14.5, align: TextAlign.left, weight: FontWeight.w700),
          const Divider(height: 18),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                row(_ab('P(A|B)', 22), _frac(_ab('A와 B가 함께 일어나는 경우의 수', 16), _ab('B가 일어나는 경우의 수', 16))),
                row(const SizedBox.shrink(), _frac(_ab('P(A∩B)', 20), _ab('P(B)', 20))),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Wrap(spacing: 14, runSpacing: 6, children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              eventTag('A'),
              const SizedBox(width: 6),
              const Text('알고 싶은 일', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
            Row(mainAxisSize: MainAxisSize.min, children: [
              eventTag('B'),
              const SizedBox(width: 6),
              const Text('이미 알고 있는 사실', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ]),
          ]),
        ],
      ),
    );
  }
}

/// 조건부 확률의 식을 곱셈정리로 뒤집는 애니메이션.
/// 0: P(A|B) = P(A∩B) / P(B) → 1: 분모 P(B)가 왼쪽으로 넘어가 곱하기가 된다 → 2: 좌우를 바꾼다 P(A∩B) = P(B) × P(A|B).
class FormulaFlipDemo extends StatefulWidget {
  const FormulaFlipDemo({super.key});

  @override
  State<FormulaFlipDemo> createState() => FormulaFlipDemoState();
}

class FormulaFlipDemoState extends State<FormulaFlipDemo> {
  int stage = 0;

  static const _dur = Duration(milliseconds: 1100);
  static const _curve = Curves.easeInOutCubic;
  static const double _mid = 46, _top = 14, _bottom = 80;
  static const Color _pb = Color(0xFFE07A1F); // 움직이는 P(B)를 눈으로 따라가기 쉽게

  // 칸 폭: P(A|B) 100 · P(A∩B) 110 · P(B) 70 · 기호 36
  static const _xs = [
    // P(A|B), =1, P(A∩B), 분수 줄, P(B), ×, (P(A∩B)의 y)
    (pab: 0.0, eq: 100.0, paib: 136.0, bar: 136.0, pb: 156.0, times: 136.0),
    (pab: 106.0, eq: 206.0, paib: 242.0, bar: 242.0, pb: 0.0, times: 70.0),
    (pab: 252.0, eq: 110.0, paib: 0.0, bar: 0.0, pb: 146.0, times: 216.0),
  ];

  Widget _tok(String text, double size, {Color? color}) => SizedBox(
        height: 36,
        child: Center(
          child: color == null
              ? _ab(text, size, weight: FontWeight.w900)
              : Text(text, style: TextStyle(fontFamily: 'NanumGothic', fontSize: size, fontWeight: FontWeight.w900, color: color)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final x = _xs[stage];
    final frac = stage == 0;
    const captions = [
      '조건부 확률의 식이에요. 분모에 P(B)가 있어요.',
      '양쪽에 P(B)를 곱하면, 나누던 P(B)가 등호를 넘어가 곱하기가 돼요.',
      '양쪽을 바꿔 쓰면 곱셈정리: P(A∩B) = P(B) × P(A|B)',
    ];
    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0x22000000))),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: 362,
                height: 128,
                child: Stack(
                  children: [
                    AnimatedPositioned(duration: _dur, curve: _curve, left: x.pab, top: _mid, width: 100, child: _tok('P(A|B)', 24)),
                    AnimatedPositioned(duration: _dur, curve: _curve, left: x.eq, top: _mid, width: 36, child: _tok('=', 26)),
                    AnimatedPositioned(duration: _dur, curve: _curve, left: x.paib, top: frac ? _top : _mid, width: 110, child: _tok('P(A∩B)', 24)),
                    AnimatedPositioned(
                      duration: _dur,
                      curve: _curve,
                      left: x.bar,
                      top: 63,
                      width: 110,
                      height: 2.5,
                      child: AnimatedOpacity(duration: const Duration(milliseconds: 400), opacity: frac ? 1 : 0, child: Container(color: const Color(0xFF333333))),
                    ),
                    AnimatedPositioned(duration: _dur, curve: _curve, left: x.pb, top: frac ? _bottom : _mid, width: 70, child: _tok('P(B)', 24, color: _pb)),
                    AnimatedPositioned(
                      duration: _dur,
                      curve: _curve,
                      left: x.times,
                      top: _mid,
                      width: 36,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 500),
                        opacity: frac ? 0 : 1,
                        child: _tok('×', 26, color: _pb),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(captions[stage], key: ValueKey(stage), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              key: const ValueKey('formula-flip'),
              onPressed: () => setState(() => stage = (stage + 1) % 3),
              icon: Icon(stage == 2 ? Icons.replay_rounded : Icons.play_arrow_rounded),
              label: Text(stage == 0 ? '식 뒤집기' : (stage == 1 ? '양쪽 바꾸기' : '처음부터')),
            ),
          ],
        ),
      ),
    );
  }
}

/// 도박사의 오류 실험: 주사위를 많이 굴려서 "6이 5번 연속 안 나온 바로 다음"만 모아 6이 나온 비율을 센다.
class StreakSimulator extends StatefulWidget {
  const StreakSimulator({super.key, this.seed});

  final int? seed;

  @override
  State<StreakSimulator> createState() => _StreakSimulatorState();
}

class _StreakSimulatorState extends State<StreakSimulator> {
  late final Random _rng = Random(widget.seed);
  int _rolls = 0, _after = 0, _sixAfter = 0, _sixAll = 0, _miss = 0;

  void _run(int n) => setState(() {
        for (var i = 0; i < n; i++) {
          final six = _rng.nextInt(6) == 5;
          if (_miss >= 5) {
            _after++;
            if (six) _sixAfter++;
          }
          _rolls++;
          if (six) _sixAll++;
          _miss = six ? 0 : _miss + 1;
        }
      });

  @override
  Widget build(BuildContext context) {
    final accent = LessonAccent.of(context);
    String pct(int a, int b) => b == 0 ? '-' : '${(a * 100 / b).toStringAsFixed(1)}%';
    const big = TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, height: 1.5);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('굴린 횟수: $_rolls번', style: big),
            Text('전체에서 6이 나온 비율: ${pct(_sixAll, _rolls)}', style: big),
            Text(
              '6이 5번 연속 안 나온 바로 다음 ($_after번): 6이 나온 비율 ${pct(_sixAfter, _after)}',
              key: const ValueKey('streak-result'),
              style: big.copyWith(color: accent),
            ),
            const SizedBox(height: 4),
            const Text('둘 다 1/6(약 16.7%) 근처예요. 오래 안 나왔다고 더 잘 나오지 않아요!', style: TextStyle(fontSize: 13.5, color: Color(0xFF555555))),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final n in const [100, 1000, 10000]) FilledButton.tonal(onPressed: () => _run(n), child: Text('$n번 굴리기')),
                TextButton(
                  onPressed: _rolls == 0 ? null : () => setState(() => _rolls = _after = _sixAfter = _sixAll = _miss = 0),
                  child: const Text('처음부터'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
