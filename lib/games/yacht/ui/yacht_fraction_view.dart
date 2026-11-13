import 'package:flutter/material.dart';

import '../core/yacht_fraction.dart';

/// 확률을 퍼센트 글자로 (0.5% 미만은 0%, 99.95% 이상은 100%, 10% 미만은 소수 한 자리).
String yachtPercent(double p) {
  if (p <= 0) return '0%';
  if (p >= 0.9995) return '100%';
  final v = p * 100;
  return v < 10 ? '${v.toStringAsFixed(1)}%' : '${v.round()}%';
}

/// 진짜 분수 모양: 분자 위, 가로줄, 분모 아래. 자연수(분모 1)는 숫자만 그린다.
class YachtFractionView extends StatelessWidget {
  /// 약분된 분수 [frac]을 그린다.
  YachtFractionView(YachtFrac frac, {Key? key, double size = 15, Color? color, bool bold = false})
      : this.raw(frac.num, frac.den, key: key, size: size, color: color, bold: bold);

  /// 약분하지 않고 [num] / [den] 그대로 그린다 ("11/36"을 "22/72"로 바꾸지 않고, 세어 낸 값 그대로 보여 줄 때).
  const YachtFractionView.raw(this.num, this.den, {super.key, this.size = 15, this.color, this.bold = false});

  final int num;
  final int den;

  /// 숫자 글자 크기.
  final double size;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    final style = TextStyle(fontFamily: 'Pretendard', fontSize: size, height: 1.15, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: c);
    if (den == 1) return Text('$num', style: style);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('$num', textAlign: TextAlign.center, style: style),
            Container(height: 1.4, margin: const EdgeInsets.symmetric(vertical: 1), color: c),
            Text('$den', textAlign: TextAlign.center, style: style),
          ],
        ),
      ),
    );
  }
}

/// 눌러서 설명을 열 수 있는 분수: 분수 뒤에 옅은 바탕과 밑줄을 깔아 "누를 수 있다"는 것을 알린다.
class YachtTapFraction extends StatelessWidget {
  const YachtTapFraction({super.key, required this.child, required this.onTap, this.color = const Color(0xFF2D7D5A)});

  final Widget child;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(8),
          border: Border(bottom: BorderSide(color: color.withValues(alpha: 0.55), width: 1.6)),
        ),
        child: child,
      ),
    );
  }
}
