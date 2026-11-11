import 'package:flutter/material.dart';

import '../core/yacht_fraction.dart';
import 'yacht_fraction_view.dart';
import '../core/yacht_rules.dart';
import 'yacht_look.dart';
import 'yacht_scale.dart';

/// 에이스~식스 칸을 눌렀을 때 뜨는 자세한 확률 창: 앞으로 그 눈이 몇 개 나올지, 그러면 몇 점인지, 확률은 퍼센트와 분수로.
///
/// 그 눈이 아닌 주사위만 다시 굴린다고 계산한다 (그 칸 하나만 노릴 때 가장 좋은 방법).
Future<void> showYachtUpperOdds(
  BuildContext context, {
  required YachtCategory cat,
  required List<int> dice,
  required int rerollsLeft,
}) {
  assert(cat.isUpper);
  final face = cat.index + 1;
  final have = dice.where((d) => d == face).length;
  final fracs = yachtUpperOddsFrac(have, rerollsLeft);
  final odds = [for (final f in fracs) f.value];
  final average = [for (var k = 0; k <= 5; k++) odds[k] * k * face]
      .fold(0.0, (a, b) => a + b);
  final atLeastThreeFrac = fracs[3] + fracs[4] + fracs[5];
  final atLeastThree = atLeastThreeFrac.value; // 숫자마다 3개씩이면 보너스 63점에 딱 맞는다
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final small = TextStyle(
        fontSize: 13,
        color: scheme.onSurfaceVariant,
        height: 1.4,
      );
      Widget row(int k) {
        final p = odds[k];
        final reachable = k >= have && p > 0;
        return Opacity(
          opacity: reachable ? 1 : 0.35,
          child: Container(
            key: ValueKey('yacht-odds-row-$k'),
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: k == have && rerollsLeft == 0
                  ? kYachtColor.withValues(alpha: 0.14)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 54,
                  child: Text(
                    '$k개',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                SizedBox(
                  width: 50,
                  child: Text(
                    '${k * face}점',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: Text(
                    yachtPercent(p),
                    softWrap: false,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: kYachtColor,
                    ),
                  ),
                ),
                SizedBox(
                  width: 84,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: YachtFractionView(
                      fracs[k],
                      size: 12.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      return YachtScaled(
        child: AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        title: Row(
          children: [
            YachtDie(value: face, size: 34),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '${cat.label} 확률',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  rerollsLeft > 0
                      ? '지금 $face이 $have개예요. $face이 아닌 주사위만 다시 굴리며 $rerollsLeft번 더 굴렸을 때, 마지막에 $face이 몇 개 나올지예요.'
                      : '지금 $face이 $have개예요. 더 굴릴 수 없어서 지금 점수 그대로예요.',
                  key: const ValueKey('yacht-odds-intro'),
                  style: const TextStyle(fontSize: 14.5, height: 1.4),
                ),
                const SizedBox(height: 12),
                for (var k = 0; k <= 5; k++) row(k),
                const SizedBox(height: 10),
                Text(
                  '평균 ${average.toStringAsFixed(1)}점',
                  key: const ValueKey('yacht-odds-average'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  key: const ValueKey('yacht-odds-three'),
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      '3개 이상 나올 확률 ${yachtPercent(atLeastThree)}',
                      style: small,
                    ),
                    if (!atLeastThreeFrac.isWhole)
                      YachtFractionView(
                        atLeastThreeFrac,
                        size: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    Text('· 숫자마다 3개씩이면 보너스 63점에 딱 맞아요', style: small),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ));
    },
  );
}
