import 'package:flutter/material.dart';

import '../../../core/tablet_scale.dart';
import '../core/yacht_rules.dart';
import '../game/yacht_controller.dart';
import 'yacht_look.dart';

/// 야추 점수판: 족보 12줄 + 보너스 + 합계, 사람마다 한 칸씩.
///
/// 지금 차례인 사람의 빈 칸에는 "지금 적으면 받는 점수"가 흐리게 보이고, 눌러서 고른다.
class YachtScoreTable extends StatelessWidget {
  const YachtScoreTable({super.key, required this.c});

  final YachtController c;

  static const int _rows = 15; // 이름 줄 + 족보 12 + 보너스 + 합계

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      // 태블릿에서는 줄과 글자를 키운다
      final tablet = MediaQuery.sizeOf(context).shortestSide >= kTabletMinSide;
      final width = box.maxWidth.clamp(0.0, tablet ? 760.0 : 640.0);
      final rowH = ((box.maxHeight - 8) / _rows).clamp(24.0, tablet ? 60.0 : 46.0);
      final n = c.players;
      final cellW = (width * 0.52 / n).clamp(50.0, tablet ? 124.0 : 100.0);
      final labelW = width - cellW * n;
      final look = _Look(context, rowH: rowH, cellW: cellW, labelW: labelW, showRule: labelW >= 250);
      final game = c.game;
      final counts = game.rollsUsed > 0 && !c.rolling ? yachtCounts(game.dice) : null;
      return Center(
        child: SizedBox(
          width: width,
          child: SingleChildScrollView(
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: look.scheme.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: look.scheme.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _header(look),
                    for (final cat in YachtCategory.values) ...[
                      if (cat == YachtCategory.choice) _bonusRow(look),
                      _categoryRow(look, cat, counts),
                    ],
                    _totalRow(look),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  bool _active(int seat) => !c.isOver && c.game.turn == seat;

  /// 사람 칸의 바탕: 지금 차례인 줄은 옅게 물든다.
  Widget _seatBox(_Look look, int seat, Widget child, {Key? key}) {
    return Container(
      key: key,
      width: look.cellW,
      height: look.rowH,
      alignment: Alignment.center,
      color: _active(seat) ? kYachtSeatColors[seat].withValues(alpha: 0.1) : null,
      child: child,
    );
  }

  Widget _line(_Look look, Widget label, List<Widget> cells, {Color? color}) {
    return Container(
      decoration: BoxDecoration(color: color, border: Border(top: BorderSide(color: look.scheme.outlineVariant.withValues(alpha: 0.6)))),
      child: Row(children: [SizedBox(width: look.labelW, height: look.rowH, child: label), ...cells]),
    );
  }

  Widget _header(_Look look) {
    final winners = c.isOver ? c.game.winners : const <int>[];
    return Row(
      children: [
        SizedBox(
          width: look.labelW,
          height: look.rowH,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(c.isOver ? '끝!' : '${c.game.round} / 12 라운드', style: look.small.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
        ),
        for (var seat = 0; seat < c.players; seat++)
          _seatBox(
            look,
            seat,
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _active(seat) || winners.contains(seat) ? kYachtSeatColors[seat] : null,
                borderRadius: BorderRadius.circular(10),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (winners.contains(seat)) ...[
                        Icon(Icons.emoji_events_rounded, size: look.label.fontSize! + 2, color: Colors.white),
                        const SizedBox(width: 3),
                      ],
                      Text(
                        look.cellW < 78 ? c.shortName(seat) : c.name(seat),
                        maxLines: 1,
                        style: look.label.copyWith(color: _active(seat) || winners.contains(seat) ? Colors.white : kYachtSeatColors[seat]),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _categoryRow(_Look look, YachtCategory cat, List<int>? counts) {
    final game = c.game;
    return _line(
      look,
      Padding(
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          children: [
            if (cat.isUpper) ...[
              YachtDie(value: cat.index + 1, size: look.rowH * 0.66),
              const SizedBox(width: 6),
            ],
            Text(cat.label, maxLines: 1, style: look.label),
            if (look.showRule) ...[
              const SizedBox(width: 10),
              Expanded(child: Text(cat.rule, maxLines: 1, overflow: TextOverflow.ellipsis, style: look.small)),
            ],
          ],
        ),
      ),
      [
        for (var seat = 0; seat < c.players; seat++)
          _seatBox(look, seat, _cell(look, seat, cat, counts), key: ValueKey('yacht-cell-$seat-${cat.name}')),
      ],
      color: game.over || cat.index.isEven ? null : look.scheme.onSurface.withValues(alpha: 0.025),
    );
  }

  Widget _cell(_Look look, int seat, YachtCategory cat, List<int>? counts) {
    final color = kYachtSeatColors[seat];
    final written = c.game.cards[seat].scores[cat.index];
    final mine = _active(seat);
    final picked = mine && c.pick == cat;
    final preview = mine && written == null && counts != null ? yachtScore(cat, counts) : null;
    final canPick = preview != null && c.humanTurn && c.game.canScore(cat);
    final last = c.lastSeat == seat && c.lastCategory == cat;
    if (written == null && preview == null) return const SizedBox.shrink();
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: picked ? color : (preview != null ? color.withValues(alpha: 0.1) : null),
        borderRadius: BorderRadius.circular(9),
        border: picked || preview != null
            ? Border.all(color: color.withValues(alpha: picked ? 1 : 0.45), width: 1.4)
            : (last ? Border.all(color: color, width: 1.6) : null),
      ),
      child: Text(
        '${written ?? preview}',
        style: look.number.copyWith(
          color: picked ? Colors.white : (written != null ? look.scheme.onSurface : color.withValues(alpha: preview == 0 ? 0.55 : 1)),
          fontWeight: written != null || picked ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
    if (!canPick) return box;
    return GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => c.choose(cat), child: box);
  }

  Widget _bonusRow(_Look look) {
    return _line(
      look,
      Padding(
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          children: [
            Text('보너스', maxLines: 1, style: look.label.copyWith(color: kYachtColor)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(look.showRule ? '1~6 칸의 합이 63점 이상이면 +35점' : '63점 이상 +35', maxLines: 1, overflow: TextOverflow.ellipsis, style: look.small),
            ),
          ],
        ),
      ),
      [
        for (var seat = 0; seat < c.players; seat++)
          _seatBox(
            look,
            seat,
            () {
              final card = c.game.cards[seat];
              final got = card.bonus > 0;
              return Text(
                got ? '+$kYachtBonus' : '${card.upperSum}/$kYachtBonusAt',
                style: got ? look.number.copyWith(color: kYachtColor, fontWeight: FontWeight.w800) : look.small,
              );
            }(),
          ),
      ],
      color: kYachtColor.withValues(alpha: 0.08),
    );
  }

  Widget _totalRow(_Look look) {
    return _line(
      look,
      Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Align(alignment: Alignment.centerLeft, child: Text('합계', style: look.label)),
      ),
      [
        for (var seat = 0; seat < c.players; seat++)
          _seatBox(
            look,
            seat,
            Text('${c.game.cards[seat].total}', key: ValueKey('yacht-total-$seat'), style: look.number.copyWith(fontSize: look.number.fontSize! + 2, fontWeight: FontWeight.w900, color: kYachtSeatColors[seat])),
          ),
      ],
      color: look.scheme.onSurface.withValues(alpha: 0.05),
    );
  }
}

/// 점수판의 치수와 글자 모양.
class _Look {
  _Look(BuildContext context, {required this.rowH, required this.cellW, required this.labelW, required this.showRule})
      : scheme = Theme.of(context).colorScheme {
    final size = (rowH * 0.42).clamp(12.0, 21.0);
    label = TextStyle(fontFamily: 'NanumGothic', fontSize: size, fontWeight: FontWeight.w800, color: scheme.onSurface);
    number = TextStyle(fontFamily: 'NanumGothic', fontSize: size + 1, color: scheme.onSurface);
    small = TextStyle(fontFamily: 'NanumGothic', fontSize: (size - 2.5).clamp(10.5, 15.0), color: scheme.onSurfaceVariant);
  }

  final double rowH;
  final double cellW;
  final double labelW;
  final bool showRule;
  final ColorScheme scheme;
  late final TextStyle label;
  late final TextStyle number;
  late final TextStyle small;
}
