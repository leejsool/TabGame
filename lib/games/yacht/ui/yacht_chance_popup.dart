import 'package:flutter/material.dart';

import '../core/yacht_advisor.dart';
import '../core/yacht_rules.dart';
import 'yacht_explain_popup.dart';
import 'yacht_fraction_view.dart';
import 'yacht_look.dart';
import 'yacht_scale.dart';

/// 지금 주사위 줄: 고정하는 주사위는 노란 테두리 + "고정", 다시 굴리는 주사위는 흐리게 + "다시".
class YachtKeepRow extends StatelessWidget {
  const YachtKeepRow({super.key, required this.dice, required this.holds, this.size = 36});

  final List<int> dice;
  final List<bool> holds;
  final double size;

  static const Color _keep = Color(0xFFF2A900);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget tag(String text, IconData icon, Color fg, Color bg) => Container(
          margin: const EdgeInsets.only(top: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 2),
            Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w900, color: fg)),
          ]),
        );
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        for (final i in yachtSortedOrder(dice)) // (게임 화면처럼 왼쪽부터 눈이 작은 순서)
          Column(
            key: ValueKey('yacht-keep-$i-${holds[i] ? 'hold' : 'roll'}'),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (holds[i])
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(size * 0.26),
                    border: Border.all(color: _keep, width: 3),
                    boxShadow: const [BoxShadow(color: Color(0x80FFC83D), blurRadius: 8)],
                  ),
                  child: YachtDie(value: dice[i], size: size),
                )
              else
                Padding(padding: const EdgeInsets.all(5), child: Opacity(opacity: 0.4, child: YachtDie(value: dice[i], size: size))),
              holds[i]
                  ? tag('고정', Icons.push_pin_rounded, const Color(0xFF7A5200), const Color(0xFFFFE9A8))
                  : tag('다시', Icons.refresh_rounded, scheme.onSurfaceVariant, scheme.surfaceContainerHighest),
            ],
          ),
      ],
    );
  }
}

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

      return YachtScaled(
        child: AlertDialog(
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
          width: yachtPopupWidth(ctx),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                YachtKeepRow(dice: dice, holds: holds),
                const SizedBox(height: 8),
                Text(
                  bd.rolled == 0
                      ? '이미 ${cat.label}이(가) 완성되어 있어요.'
                      : bd.rolled == kYachtDice
                          ? '남겨 둘 주사위가 없어요. 주사위 5개를 모두 다시 굴려요. ${bd.rerollsLeft}번 더 굴릴 수 있어요.'
                          : '노란 테두리 주사위 ${kYachtDice - bd.rolled}개는 그대로 두고(고정), 나머지 ${bd.rolled}개를 다시 굴려요. ${bd.rerollsLeft}번 더 굴릴 수 있어요.',
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
                          Text('약 ${yachtPercent(bd.total.value)}', key: const ValueKey('yacht-chance-total'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kYachtColor)),
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
      ));
    },
  );
}
