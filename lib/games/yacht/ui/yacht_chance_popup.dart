import 'package:flutter/material.dart';

import '../core/yacht_advisor.dart';
import '../core/yacht_rules.dart';
import 'yacht_explain_popup.dart';
import 'yacht_fraction_view.dart';
import 'yacht_look.dart';

/// 힌트에서 모양 족보(포카드 · 풀하우스 · 스트레이트 · 야추 · 쓰리카드)의 "완성 확률"을 눌렀을 때 뜨는 계산 과정 창.
///
/// 가장 좋게 고정한 주사위를 보이고, 첫 굴림 결과를 묶음으로 나눠 묶음마다 확률을 보인 뒤(1번째 굴림),
/// 한 번 더 굴릴 수 있으면 묶음별로 "확률 × 다음에 완성될 확률"을 보이고(2번째 굴림), 마지막에 모두 더해 분수와 퍼센트로 마무리한다.
/// 길면 창 안에서 스크롤한다.
Future<void> showYachtChanceDetail(
  BuildContext context, {
  required YachtAdvisor advisor,
  required YachtCategory cat,
  required List<int> dice,
  required List<bool> held,
  required int rerollsLeft,
}) {
  final bd = advisor.breakdown(cat, dice, rerollsLeft);
  if (bd == null) return Future.value();
  final holds = yachtHoldsFor(dice, bd.keep, prefer: held);
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final small = TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant, height: 1.4);
      final done = bd.groups.where((g) => g.done).toList();
      final later = bd.later;
      final lastRoll = bd.rerollsLeft <= 1;
      // 밑줄 친 분수를 누르면 한 번 더 팝업으로 "왜 이 값인지" 설명한다
      void explain(YachtBreakdownGroup g) => showYachtGroupExplain(ctx, advisor: advisor, cat: cat, dice: dice, bd: bd, group: g);
      void explainNext(YachtBreakdownGroup g) => showYachtNextChanceExplain(ctx, advisor: advisor, cat: cat, bd: bd, group: g);

      Widget section(String text) => Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          );

      Widget box(Widget child, {Color? color}) => Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 2),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: color ?? scheme.surfaceContainerHighest.withValues(alpha: 0.45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: child,
          );

      // 1번째 굴림: 결과 묶음 → 그 묶음이 나올 확률
      Widget groupRow(YachtBreakdownGroup g) {
        final String label;
        if (g.done) {
          label = '바로 완성';
        } else if (g.next.num > 0) {
          label = '아직 미완성';
        } else {
          label = '완성할 수 없어요';
        }
        return box(
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: g.done ? kYachtColor : null)),
                    if (!g.done && g.next.num > 0)
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text('다음 굴림에서 완성될 확률 ', style: small),
                          YachtTapFraction(onTap: () => explainNext(g), child: YachtFractionView(g.next, size: 13)),
                        ],
                      ),
                  ],
                ),
              ),
              YachtTapFraction(onTap: () => explain(g), child: YachtFractionView(g.prob, size: 15)),
            ],
          ),
          color: g.done ? kYachtColor.withValues(alpha: 0.12) : null,
        );
      }

      // 2번째 굴림: 확률 x 다음 확률 = 보태는 확률
      Widget gainRow(YachtBreakdownGroup g) => box(
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 6,
              children: [
                YachtTapFraction(onTap: () => explain(g), child: YachtFractionView(g.prob, size: 14)),
                const Text('×', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                YachtTapFraction(onTap: () => explainNext(g), child: YachtFractionView(g.next, size: 14)),
                const Text('=', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                YachtFractionView(g.gain, size: 14, bold: true),
              ],
            ),
          );

      final terms = [for (final g in bd.groups) if (g.gain.num > 0) g.gain];

      return AlertDialog(
        key: const ValueKey('yacht-chance-popup'),
        insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
        contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        title: Row(
          children: [
            const Icon(Icons.calculate_rounded, color: kYachtColor),
            const SizedBox(width: 8),
            Flexible(child: Text('${cat.label} 확률은 이렇게 계산해요', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18))),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    for (final i in yachtSortedOrder(dice)) // (게임 화면처럼 왼쪽부터 눈이 작은 순서)
                      Padding(
                        padding: const EdgeInsets.only(right: 5),
                        child: Opacity(opacity: holds[i] ? 1 : 0.5, child: YachtDie(value: dice[i], size: 34, held: holds[i], accent: kYachtColor)),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  bd.rolled == 0
                      ? '이미 ${cat.label}이(가) 완성되어 있어요.'
                      : '밝게 표시한 주사위를 고정하고 나머지 ${bd.rolled}개를 굴려요. ${bd.rerollsLeft}번 더 굴릴 수 있어요.',
                  key: const ValueKey('yacht-chance-intro'),
                  style: const TextStyle(fontSize: 13.5, height: 1.4),
                ),
                if (bd.rolled > 0) Text('초록색 밑줄 분수를 누르면 왜 그런 값인지 설명이 나와요.', style: small),
                section(bd.rolled == 0 ? '지금 모습' : '1번째 굴림 (주사위 ${bd.rolled}개)'),
                for (final g in bd.groups) groupRow(g),
                if (!lastRoll && later.isNotEmpty) ...[
                  section('2번째 굴림에서 완성될 확률'),
                  for (final g in later) gainRow(g),
                ],
                section('모두 더하면'),
                box(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        children: [
                          for (var i = 0; i < terms.length; i++) ...[
                            if (i > 0) const Text('+', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            YachtFractionView(terms[i], size: 14),
                          ],
                          if (terms.length != 1 || terms.first != bd.total) ...[
                            const Text('=', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                            YachtFractionView(bd.total, size: 17, color: kYachtColor, bold: true),
                          ],
                          Text('≈ ${yachtPercent(bd.total.value)}', key: const ValueKey('yacht-chance-total'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kYachtColor)),
                        ],
                      ),
                      if (done.isNotEmpty && later.isNotEmpty) Text('바로 완성될 확률 + 나중에 완성될 확률', style: small),
                    ],
                  ),
                  color: kYachtColor.withValues(alpha: 0.12),
                ),
              ],
            ),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인'))],
      );
    },
  );
}
