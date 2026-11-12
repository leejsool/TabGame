import 'package:flutter/material.dart';

import '../core/yacht_advisor.dart';
import '../core/yacht_daesung.dart';
import '../core/yacht_rules.dart';
import '../game/yacht_controller.dart';
import 'yacht_chance_popup.dart';
import 'yacht_fraction_view.dart';
import 'yacht_glow_border.dart';
import 'yacht_look.dart';
import 'yacht_odds_popup.dart';
import 'yacht_scale.dart';

/// 힌트 창: 지금 상황에서 추천하는 행동과, 빈 칸마다의 "지금 점수 · 더 굴렸을 때의 확률".
///
/// "이대로 하기"를 누르면 추천대로 주사위를 잡거나 칸을 골라 준다 (굴리기·적기는 사람이 직접 누른다).
Future<void> showYachtHint(BuildContext context, YachtController c) {
  final advisor = c.advisor;
  if (advisor == null) return Future.value();
  final game = c.game;
  final dice = List<int>.of(game.dice);
  final left = game.rollsLeft;
  final advice = advisor.advise(card: game.card, dice: dice, rerollsLeft: left);
  final keep = advice.keep;
  final holds = keep == null ? null : advisor.holdsFor(dice, keep, prefer: game.held);
  final open = [
    for (final cat in game.categories)
      if (game.card.isOpen(cat)) cat,
  ];
  final outlooks = {for (final cat in open) cat: advisor.outlook(cat, dice, left)};
  final color = kYachtSeatColors[game.turn];

  Widget content(BuildContext ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final head = Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);
      final small = TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.86),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ── 추천 ──
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: kYachtColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kYachtColor.withValues(alpha: 0.5)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lightbulb_rounded, color: Color(0xFFF2A900), size: 22),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    holds == null
                                        ? '추천: ‘${game.card.labelOf(advice.bestCategory)}’ 칸에 ${advice.scoreNow[advice.bestCategory.index]}점 적기'
                                        : (holds.contains(true) ? '추천: 표시한 주사위를 고정하고 다시 굴리기' : '추천: 5개 모두 다시 굴리기'),
                                    style: head,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                for (final i in yachtSortedOrder(dice)) // (게임 화면처럼 왼쪽부터 눈이 작은 순서)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3),
                                    child: Opacity(
                                      opacity: holds == null || holds[i] ? 1 : 0.45,
                                      child: YachtDie(value: dice[i], size: 44, held: holds != null && holds[i], accent: color, daesung: game.daesung && i == kDaesungDie),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              holds == null
                                  ? (left > 0 ? '더 굴려도 지금 적는 것보다 좋아지지 않아요.' : '지금 적을 수 있는 칸 중에서 끝까지의 점수가 가장 높아져요.')
                                  : '지금 가장 좋은 칸에 적는 것보다 최종 점수가 평균 ${(advice.rollValue - advice.stopValue).toStringAsFixed(1)}점 높아져요.',
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 13.5, height: 1.35),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      // ── 칸마다 ──
                      Row(
                        children: [
                          Expanded(child: Text('빈 칸', style: small)),
                          SizedBox(
                            width: 72,
                            child: Text('지금 적으면', textAlign: TextAlign.center, style: small),
                          ),
                          SizedBox(
                            width: 124,
                            child: Text(left > 0 ? '$left번 더 굴리면' : '', textAlign: TextAlign.center, style: small),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      for (final cat in open) _row(ctx, cat, advice, outlooks[cat]!, left, best: holds == null && cat == advice.bestCategory, dice: dice, held: List<bool>.of(game.held), advisor: advisor, label: game.card.labelOf(cat)),
                      const SizedBox(height: 6),
                      Text(left > 0 ? '확률은 그 족보 하나만 노리고 가장 잘 굴렸을 때 완성될 확률이에요. 모양이 없는 칸은 받을 점수의 평균을 보여 줘요.${advisor.explains ? ' 줄을 누르면 자세한 계산 과정이 나와요.' : ''}' : '굴릴 기회를 다 썼어요. 빈 칸 하나를 골라 적어야 해요.', style: small),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('yacht-hint-apply'),
                        onPressed: () {
                          Navigator.pop(ctx);
                          c.applyHint(holds: holds, category: holds == null ? advice.bestCategory : null);
                        },
                        child: Text(holds == null ? '이 칸 고르기' : '이대로 고정'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }

  // 큰 화면(전자칠판)에서는 아래에서 올라오는 창 대신 가운데 창으로 띄워 통째로 키운다
  if (YachtScaled.factor(MediaQuery.sizeOf(context)) > 1.05) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => YachtScaled(
        child: Dialog(
          insetPadding: const EdgeInsets.all(12),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: Padding(padding: const EdgeInsets.only(top: 14), child: content(ctx))),
        ),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: content,
  );
}

Widget _row(BuildContext context, YachtCategory cat, YachtAdvice advice, YachtOutlook o, int left,
    {required bool best, required List<int> dice, required List<bool> held, required YachtBrain advisor, required String label}) {
  final scheme = Theme.of(context).colorScheme;
  final chance = o.chance;
  final box = Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: best ? kYachtColor.withValues(alpha: 0.14) : scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        Expanded(
          child: Row(
            children: [
              if (cat.isUpper) ...[YachtDie(value: cat.index + 1, size: 22), const SizedBox(width: 6)],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 72,
          child: Text(
            '${advice.scoreNow[cat.index]}점',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        SizedBox(
          width: 124,
          child: left == 0
              ? const SizedBox.shrink()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      chance != null ? '완성 ${yachtPercent(chance)}' : '평균 ${o.expected.toStringAsFixed(1)}점',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.w700, color: chance != null ? kYachtColor : scheme.onSurfaceVariant),
                    ),
                  ],
                ),
        ),
      ],
    ),
  );
  // 추천하는 족보는 테두리를 따라 빛나는 띠가 빙글빙글 돈다
  final row = Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: best ? YachtGlowBorder(key: ValueKey('yacht-hint-glow-${cat.name}'), color: kYachtColor, child: box) : box,
  );
  // 보이는 모습은 그대로 두고(퍼센트나 평균만), 누르면 자세한 계산 과정 창이 뜬다 (기본 규칙만: 대성One Rule은 계산 과정 창이 없다)
  if (advisor is! YachtAdvisor) return row;
  if (cat.isUpper) {
    return GestureDetector(
      key: ValueKey('yacht-hint-row-${cat.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => showYachtUpperOdds(context, cat: cat, dice: dice, rerollsLeft: left),
      child: row,
    );
  }
  if (chance == null || left == 0) return row;
  return GestureDetector(
    key: ValueKey('yacht-hint-row-${cat.name}'),
    behavior: HitTestBehavior.opaque,
    onTap: () => showYachtChanceDetail(context, advisor: advisor, cat: cat, dice: dice, held: held, rerollsLeft: left),
    child: row,
  );
}
