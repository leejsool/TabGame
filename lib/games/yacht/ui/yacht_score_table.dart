import 'dart:math' show max;

import 'package:flutter/material.dart';

import '../../../core/game_speed.dart';
import '../../../core/tablet_scale.dart';
import '../core/yacht_rules.dart';
import '../game/yacht_controller.dart';
import 'yacht_help.dart';
import 'yacht_look.dart';
import 'yacht_tally.dart';

part 'yacht_score_table_split.dart';

/// 야추 점수판: 족보 12줄(쓰리카드를 켜면 13줄) + 보너스 + 야추 보너스, 사람마다 한 칸씩. 스크롤 없이 한 화면에 다 보인다.
///
/// 지금 차례인 사람의 빈 칸에는 "지금 적으면 받는 점수"가 흐리게 보이고, 눌러서 고른다.
/// 합계는 게임이 끝난 뒤에야 나타난다: 맨 윗줄(에이스)부터 차례로 그 줄의 점수가 합계로 내려와 더해지고,
/// 다 더해지면 이긴 사람이 표시된다 ([YachtTally]). "야추 빠른 진행"이면 정산 중에 점수판을 눌러 끝까지 건너뛸 수 있다.
class YachtScoreTable extends StatefulWidget {
  const YachtScoreTable({super.key, required this.c, this.onTallyDone});

  final YachtController c;

  /// 정산이 끝났을 때 (다 보았거나 눌러서 건너뛰었을 때).
  final VoidCallback? onTallyDone;

  @override
  State<YachtScoreTable> createState() => _YachtScoreTableState();
}

class _YachtScoreTableState extends State<YachtScoreTable> with SingleTickerProviderStateMixin {
  YachtController get c => widget.c;

  late final AnimationController _ctl = AnimationController(vsync: this);
  YachtTally? _tally;

  /// 직전에 판이 끝나 있었는가 (끝나는 순간을 알아채려고).
  bool _wasOver = false;

  /// 정산이 다 끝났는가 (이미 끝난 판을 열었을 때도 true).
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _wasOver = c.isOver;
    _done = c.isOver;
    c.addListener(_onGame);
  }

  @override
  void didUpdateWidget(YachtScoreTable old) {
    super.didUpdateWidget(old);
    if (old.c != c) {
      old.c.removeListener(_onGame);
      c.addListener(_onGame);
    }
  }

  @override
  void dispose() {
    c.removeListener(_onGame);
    _ctl.dispose();
    super.dispose();
  }

  void _onGame() {
    final over = c.isOver;
    if (over && !_wasOver) {
      _startTally();
    } else if (!over && _wasOver) {
      _ctl.stop(); // 한 판 더: 정산을 멈추고 합계를 다시 숨긴다
      _tally = null;
      _done = false;
    }
    _wasOver = over;
  }

  void _startTally() {
    final tally = YachtTally(c.game);
    _tally = tally;
    _done = false;
    _ctl
      ..duration = tally.duration + YachtTally.holdTime
      ..forward(from: 0).whenComplete(_finishTally);
  }

  void _finishTally() {
    if (!mounted || !c.isOver || _done) return;
    setState(() => _done = true);
    widget.onTallyDone?.call();
  }

  /// 정산 중에 누르면 최종 합계로 바로 간다.
  void _skipTally() {
    if (!_tallying || !GameSpeed.yachtQuick) return;
    _ctl.stop();
    _finishTally();
  }

  /// 정산 중인가.
  bool get _tallying => c.isOver && !_done && _tally != null;

  YachtTallyFrame? _frame() {
    final tally = _tally;
    if (!_tallying || tally == null) return null;
    final total = _ctl.duration!.inMicroseconds;
    return tally.frameAt(Duration(microseconds: (_ctl.value * total).round()));
  }

  @override
  Widget build(BuildContext context) {
    _rows.clear(); // 판의 모습이 바뀌었을 수 있다 (정산이 끝났거나, 굴렸거나): 담아 둔 줄을 버린다
    return GestureDetector(
      key: const ValueKey('yacht-tally-skip'),
      behavior: HitTestBehavior.translucent,
      onTap: _skipTally,
      // 주사위가 구르거나 정산 숫자가 움직이는 매 프레임마다 점수판까지 다시 그리지 않게 따로 떼어 둔다
      // (저성능 기기에서 프레임이 떨어지던 원인)
      child: RepaintBoundary(
      child: LayoutBuilder(
      builder: (context, box) {
        _rows.clear(); // 판이 바뀌었거나 크기가 바뀌었다: 줄을 새로 만든다
        // 태블릿에서는 줄과 글자를 키운다
        final tablet = MediaQuery.sizeOf(context).shortestSide >= kTabletMinSide;
        final cats = c.game.categories;
        // 폭에 비해 높이가 낮은 화면(핸드폰 가로 모드)에서는 숫자 칸 · 족보 칸을 잘라 가로로 나란히 놓는다
        // (넓기만 하고 높이가 넉넉한 PC 화면에서는 나누지 않는다: 한 줄로 세워도 줄 높이가 충분하면 그대로)
      final fullRows = c.game.categories.length + 4;
      final fullRowH = (box.maxHeight - 8 - fullRows) / fullRows;
      final split = box.maxWidth.isFinite && box.maxWidth >= box.maxHeight * 1.5 && fullRowH < 30;
        if (split) return _splitBuild(context, box, cats);
        final width = box.maxWidth.clamp(0.0, tablet ? 900.0 : 640.0);
        final rows = cats.length + 4; // 이름 줄 + 족보 칸들 + 보너스 + 야추 보너스 + 합계
        // 스크롤 없이 한 화면에 다 들어가도록 줄 높이를 칸 수에 맞춘다 (줄마다 선 1px)
        final rowH = ((box.maxHeight - 8 - rows) / rows).clamp(16.0, tablet ? 60.0 : 46.0);
        final n = c.players;
        final cellW = (width * 0.52 / n).clamp(50.0, tablet ? 124.0 : 100.0);
        final labelW = width - cellW * n;
        final look = _Look(context, rowH: rowH, cellW: cellW, labelW: labelW, showRule: labelW >= 250);
        final game = c.game;
        final counts = game.rollsUsed > 0 && !c.rolling ? yachtCounts(game.dice) : null;
        return Center(
          child: SizedBox(
            width: width,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: look.scheme.surface.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: look.scheme.outlineVariant),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AnimatedBuilder(animation: _ctl, builder: (context, _) => _table(look, cats, counts, _frame())),
              ),
            ),
          ),
        );
      },
      ),
      ),
    );
  }

  /// 정산 중에 매 프레임 바뀌지 않는 줄들을 담아 둔다: 줄 번호 → (빛나는 줄이었는가, 만든 줄).
  /// 같은 위젯을 다시 돌려주면 그 줄은 다시 만들지도, 다시 배치하지도 않는다 (정산 내내 점수판 전체를 매 프레임 새로 만들던 것을 줄인다).
  final Map<int, (bool, Widget)> _rows = {};

  Widget _memo(int key, bool hot, Widget Function() make) {
    final m = _rows[key];
    if (m != null && m.$1 == hot) return m.$2;
    final w = make();
    _rows[key] = (hot, w);
    return w;
  }

  Widget _table(_Look look, List<YachtCategory> cats, List<int>? counts, YachtTallyFrame? frame) {
    if (c.isOver && _tally == null) _done = true; // (정산을 못 본 채 끝난 판은 바로 최종 모습)
    if (look.split) return _splitTable(look, cats, counts, frame);
    final hot = frame?.step ?? -1; // 정산 중에 지금 합계로 내려가는 줄
    var line = 0;
    Widget row(Widget Function(bool hot) make) {
      final k = line++;
      final h = hot == k;
      return _memo(k, h, () => make(h));
    }

    final rowsList = <Widget>[
      _memo(-1, false, () => _header(look)),
      for (var i = 0; i < cats.length; i++) ...[
        row((h) => _categoryRow(look, cats[i], counts, shaded: i.isOdd, hot: h)),
        if (cats[i] == YachtCategory.sixes) row((h) => _bonusRow(look, hot: h)), // 숫자 칸 6개 바로 아래 (진짜 점수표처럼)
      ],
      if (!c.game.daesung) row((h) => _yahtzeeBonusRow(look, hot: h)), // (대성One Rule에는 야추 보너스가 없다)
    ];
    return Stack(
      children: [
        Column(mainAxisSize: MainAxisSize.min, children: [
          RepaintBoundary(child: Column(mainAxisSize: MainAxisSize.min, children: rowsList)),
          // 합계는 게임이 끝나야 나타난다 (정산 중에 매 프레임 바뀌는 건 이 줄과 내려오는 숫자뿐)
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            alignment: Alignment.topCenter,
            child: c.isOver ? _totalRow(look, frame) : const SizedBox.shrink(),
          ),
        ]),
        if (frame != null && frame.fly != null) ..._flying(look, frame, line),
      ],
    );
  }

  /// 정산 중 한 줄의 점수들이 합계 줄까지 내려가는 숫자 (자리마다 하나씩).
  List<Widget> _flying(_Look look, YachtTallyFrame frame, int totalLine) {
    final step = _tally!.steps[frame.step];
    final f = Curves.easeInCubic.transform(frame.fly!);
    double centerY(int ln) => look.rowH + ln * (look.rowH + 1) + 1 + look.rowH / 2;
    final y = centerY(frame.step) + (centerY(totalLine) - centerY(frame.step)) * f;
    final fade = f < 0.82 ? 1.0 : (1 - (f - 0.82) / 0.18).clamp(0.0, 1.0);
    return [
      for (var seat = 0; seat < c.players; seat++)
        // 0점인 자리도 "0"이 같이 내려온다: 모든 자리가 같은 줄에서 같은 순간에 움직인다
        Positioned(
          left: look.labelW + seat * look.cellW,
          top: y - look.rowH / 2,
          width: look.cellW,
          height: look.rowH,
          // (Opacity 대신 글자색의 투명도로 흐리게: 매 프레임 따로 그리는 층을 만들지 않는다)
          child: IgnorePointer(
            child: Center(
              child: Transform.scale(
                scale: 1.15,
                child: Text(
                  step.values[seat] == 0 ? '0' : '+${step.values[seat]}',
                  key: ValueKey('yacht-fly-$seat'),
                  style: look.number.copyWith(
                    color: kYachtSeatColors[seat].withValues(alpha: step.values[seat] == 0 ? fade * 0.5 : fade),
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ),
        ),
    ];
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

  /// 한 줄. [onLabelTap]이 있으면 이름 쪽을 눌러 설명 창을 띄운다 (점수 칸은 따로 눌러서 고른다).
  Widget _line(_Look look, Widget label, List<Widget> cells, {Color? color, VoidCallback? onLabelTap, Key? labelKey, bool hot = false}) {
    final name = SizedBox(width: look.labelW, height: look.rowH, child: label);
    return Container(
      decoration: BoxDecoration(
        color: hot ? look.scheme.primary.withValues(alpha: 0.16) : color,
        border: Border(top: BorderSide(color: look.scheme.outlineVariant.withValues(alpha: 0.6))),
      ),
      child: Row(
        children: [
          if (onLabelTap == null) name else GestureDetector(key: labelKey, behavior: HitTestBehavior.opaque, onTap: onLabelTap, child: name),
          ...cells,
        ],
      ),
    );
  }

  Widget _header(_Look look, {bool showTitle = true}) {
    final winners = _done ? c.game.winners : const <int>[];
    final String title;
    if (_done) {
      title = '끝!';
    } else if (c.isOver) {
      title = '점수 계산!';
    } else {
      title = '${c.game.round} / ${c.game.rounds} 라운드';
    }
    // 시간 제한이 있는 판: 이름 줄 바로 밑(에이스 위)에 남은 시간만큼의 가로줄이 줄어든다
    final total = c.turnSeconds;
    final row = _headerRow(look, title, winners, showTitle);
    // (나뉜 점수판에서는 앞 덩어리에만 막대를 단다)
    if (total == null || c.isOver || !showTitle) return row;
    final seat = kYachtSeatColors[c.game.turn];
    return Stack(
      children: [
        row,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 5,
          // 1초마다 이 막대만 다시 그린다 (점수판 전체는 그대로)
          child: RepaintBoundary(
            child: ValueListenableBuilder<int?>(
              valueListenable: c.clock,
              builder: (context, left, _) {
                if (left == null) return const SizedBox.shrink();
                final color = left <= 10 ? const Color(0xFFD1373F) : seat;
                return TweenAnimationBuilder<double>(
                  key: const ValueKey('yacht-clock'),
                  tween: Tween(end: left / total),
                  duration: const Duration(milliseconds: 1000),
                  builder: (context, v, _) => Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: v.clamp(0.0, 1.0),
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _headerRow(_Look look, String title, List<int> winners, bool showTitle) {
    return Row(
      children: [
        SizedBox(
          width: look.labelW,
          height: look.rowH,
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(showTitle ? title : '', style: look.small.copyWith(fontWeight: FontWeight.w700)),
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

  Widget _categoryRow(_Look look, YachtCategory cat, List<int>? counts, {required bool shaded, required bool hot}) {
    final game = c.game;
    return _line(
      look,
      Padding(
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          children: [
            if (cat.isUpper) ...[YachtDie(value: cat.index + 1, size: look.rowH * 0.66), const SizedBox(width: 6)],
            // 설명 글이 모든 줄에서 같은 자리에서 시작하도록, 이름 칸을 가장 긴 이름 폭에 맞춘다
            if (look.showRule)
              SizedBox(
                width: look.nameW - (cat.isUpper ? look.rowH * 0.66 + 6 : 0),
                child: Text(c.game.card.labelOf(cat), maxLines: 1, style: look.label),
              )
            else
              Text(c.game.card.labelOf(cat), maxLines: 1, style: look.label),
            if (look.showRule) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(c.game.card.ruleOf(cat), maxLines: 1, overflow: TextOverflow.ellipsis, style: look.small),
              ),
            ],
          ],
        ),
      ),
      [for (var seat = 0; seat < c.players; seat++) _seatBox(look, seat, _cell(look, seat, cat, counts), key: ValueKey('yacht-cell-$seat-${cat.name}'))],
      color: game.over || !shaded ? null : look.scheme.onSurface.withValues(alpha: 0.025),
      onLabelTap: () => showYachtCategoryHelp(look.context, cat, card: c.game.card),
      labelKey: ValueKey('yacht-help-${cat.name}'),
      hot: hot,
    );
  }

  Widget _cell(_Look look, int seat, YachtCategory cat, List<int>? counts) {
    final color = kYachtSeatColors[seat];
    final written = c.game.cards[seat].scores[cat.index];
    final mine = _active(seat);
    final picked = mine && c.pick == cat;
    final preview = mine && written == null && counts != null ? c.game.cards[seat].scoreOf(cat, c.game.dice) : null;
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
            : (last && !c.isOver ? Border.all(color: color, width: 1.6) : null),
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

  Widget _bonusRow(_Look look, {required bool hot}) {
    return _line(
      look,
      Padding(
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          children: [
            if (look.showRule)
              SizedBox(
                width: look.nameW,
                child: Text('보너스', maxLines: 1, style: look.label.copyWith(color: kYachtColor)),
              )
            else
              Text('보너스', maxLines: 1, style: look.label.copyWith(color: kYachtColor)),
            if (!look.split) ...[
              SizedBox(width: look.showRule ? 10 : 8),
              Expanded(
                child: Text(
                  look.showRule
                      ? '${c.game.daesung ? '원즈~식스' : '1~6 칸'}의 합이 ${c.game.card.bonusAt}점 이상이면 +${c.game.card.bonusPoints}점'
                      : '${c.game.card.bonusAt}점 이상 +${c.game.card.bonusPoints}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: look.small,
                ),
              ),
            ],
          ],
        ),
      ),
      [
        for (var seat = 0; seat < c.players; seat++)
          _seatBox(look, seat, () {
            final card = c.game.cards[seat];
            final got = card.bonus > 0;
            return Text(
              got ? '+${card.bonusPoints}' : '${card.upperSum}/${card.bonusAt}',
              style: got ? look.number.copyWith(color: kYachtColor, fontWeight: FontWeight.w800) : look.small,
            );
          }()),
      ],
      color: kYachtColor.withValues(alpha: 0.16), // 보너스 줄은 특수한 줄이라 다른 줄보다 진하게
      onLabelTap: () => showYachtUpperBonusHelp(look.context, card: c.game.card),
      labelKey: const ValueKey('yacht-help-bonus'),
      hot: hot,
    );
  }

  /// 야추 칸에 50점을 적은 뒤 야추를 또 굴려 적을 때마다 +100 (진짜 점수표의 "YAHTZEE BONUS" 줄).
  Widget _yahtzeeBonusRow(_Look look, {required bool hot}) {
    return _line(
      look,
      Padding(
        padding: const EdgeInsets.only(left: 12, right: 4),
        child: Row(
          children: [
            if (look.showRule)
              SizedBox(
                width: look.nameW,
                child: Text('야추 보너스', maxLines: 1, style: look.label.copyWith(color: kYachtColor)),
              )
            else
              Text('야추 보너스', maxLines: 1, style: look.label.copyWith(color: kYachtColor)),
            if (!look.split) ...[
              SizedBox(width: look.showRule ? 10 : 8),
              Expanded(
                child: Text(look.showRule ? '야추를 또 굴려 적으면 +100점씩' : '+100씩', maxLines: 1, overflow: TextOverflow.ellipsis, style: look.small),
              ),
            ],
          ],
        ),
      ),
      [
        for (var seat = 0; seat < c.players; seat++)
          _seatBox(look, seat, () {
            final n = c.game.cards[seat].yahtzeeBonuses;
            return Text(
              n > 0 ? '+${n * kYachtYahtzeeBonus}' : '–',
              key: ValueKey('yacht-ybonus-$seat'),
              style: n > 0 ? look.number.copyWith(color: kYachtColor, fontWeight: FontWeight.w800) : look.small,
            );
          }()),
      ],
      color: kYachtColor.withValues(alpha: 0.16), // 보너스 줄은 특수한 줄이라 다른 줄보다 진하게
      onLabelTap: () => showYachtYahtzeeBonusHelp(look.context),
      labelKey: const ValueKey('yacht-help-yahtzee-bonus'),
      hot: hot,
    );
  }

  /// 합계 줄 (게임이 끝난 뒤에만). 정산 중에는 [frame]의 점수가, 끝나면 최종 점수가 보이고 이긴 사람이 표시된다.
  Widget _totalRow(_Look look, YachtTallyFrame? frame) {
    final winners = _done ? c.game.winners : const <int>[];
    return _line(
      look,
      Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('합계', style: look.label),
        ),
      ),
      [
        for (var seat = 0; seat < c.players; seat++)
          SizedBox(
            width: look.cellW,
            height: look.rowH,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 2),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: winners.contains(seat) ? const Color(0xFFF2A900).withValues(alpha: 0.28) : null,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                '${frame?.shown[seat] ?? c.game.cards[seat].total}',
                key: ValueKey('yacht-total-$seat'),
                style: look.number.copyWith(fontSize: look.number.fontSize! + 2, fontWeight: FontWeight.w900, color: kYachtSeatColors[seat]),
              ),
            ),
          ),
      ],
      color: look.scheme.onSurface.withValues(alpha: 0.05),
    );
  }
}

/// 점수판의 치수와 글자 모양.
class _Look {
  _Look(
    this.context, {
    required this.rowH,
    required this.cellW,
    required this.labelW,
    required this.showRule,
    this.split = false,
    this.blockW = 0,
    this.gap = 0,
  }) : scheme = Theme.of(context).colorScheme {
    final size = (rowH * 0.42).clamp(12.0, 21.0);
    label = TextStyle(fontFamily: 'NanumGothic', fontSize: size, fontWeight: FontWeight.w800, color: scheme.onSurface);
    number = TextStyle(fontFamily: 'NanumGothic', fontSize: size + 1, color: scheme.onSurface);
    small = TextStyle(fontFamily: 'NanumGothic', fontSize: (size - 2.5).clamp(10.5, 15.0), color: scheme.onSurfaceVariant);
  }

  final BuildContext context;
  final double rowH;
  final double cellW;
  final double labelW;
  final bool showRule;

  /// 숫자 칸과 족보 칸을 두 덩어리로 잘라 가로로 놓는 모드 (핸드폰 가로 모드). 덩어리 하나의 폭 [blockW], 사이 간격 [gap].
  final bool split;
  final double blockW;
  final double gap;
  final ColorScheme scheme;

  /// 이름 칸의 폭: 가장 긴 족보 이름("스몰 스트레이트")에 맞춘다 (숫자 칸은 주사위 그림 폭까지 더해서).
  /// 설명 글이 모든 줄에서 같은 자리에서 시작하게 한다.
  late final double nameW = _nameWCache.putIfAbsent((label.fontSize!, rowH, MediaQuery.textScalerOf(context).scale(100)), _measureNameW);

  /// 글자 크기 · 줄 높이가 같으면 이름 칸 폭도 같으니 한 번만 잰다 (점수판은 굴릴 때마다 다시 그려진다).
  static final Map<(double, double, double), double> _nameWCache = {};

  double _measureNameW() {
    {
      double textW(String t) {
        final p = TextPainter(
          text: TextSpan(text: t, style: label),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
          maxLines: 1,
        )..layout();
        return p.width;
      }

      final die = rowH * 0.66 + 6;
      var w = max(textW('보너스'), textW('야추 보너스'));
      for (final c in YachtCategory.values) {
        w = max(w, textW(c.label) + (c.isUpper ? die : 0));
      }
      return w + 2;
    }
  }

  late final TextStyle label;
  late final TextStyle number;
  late final TextStyle small;
}
