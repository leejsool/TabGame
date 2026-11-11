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
  const YachtFractionView(this.frac, {super.key, this.size = 15, this.color, this.bold = false});

  final YachtFrac frac;

  /// 숫자 글자 크기.
  final double size;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface;
    final style = TextStyle(fontFamily: 'NanumGothic', fontSize: size, height: 1.15, fontWeight: bold ? FontWeight.w900 : FontWeight.w700, color: c);
    if (frac.isWhole) return Text('${frac.num}', style: style);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${frac.num}', textAlign: TextAlign.center, style: style),
            Container(height: 1.4, margin: const EdgeInsets.symmetric(vertical: 1), color: c),
            Text('${frac.den}', textAlign: TextAlign.center, style: style),
          ],
        ),
      ),
    );
  }
}
