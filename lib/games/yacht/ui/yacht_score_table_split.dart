part of 'yacht_score_table.dart';

/// 핸드폰 가로 모드의 점수판: 왼쪽 덩어리는 숫자 칸(에이스~식스 + 보너스), 오른쪽 덩어리는 족보 칸(쓰리카드 · 포카드 … 찬스 + 야추 보너스 + 합계).
/// 두 덩어리의 줄 높이가 같고, 합계는 오른쪽 덩어리 맨 아래에 생긴다.
extension _YachtSplitTable on _YachtScoreTableState {
  /// 숫자 칸(에이스~식스) 6줄 + 보너스 1줄 = 정산에서 앞의 7걸음 (왼쪽 덩어리).
  static const int _upperSteps = 7;

  Widget _splitBuild(BuildContext context, BoxConstraints box, List<YachtCategory> cats) {
    final width = box.maxWidth.clamp(0.0, 900.0);
    const gap = 10.0;
    final blockW = (width - gap) / 2;
    final lower = cats.length - 6; // 쓰리카드(옵션) · 포카드 … 찬스
    final rows = lower + 3; // 이름 줄 + 족보 칸들 + 야추 보너스 + 합계 (오른쪽 덩어리가 더 길다)
    final rowH = ((box.maxHeight - 8 - rows) / rows).clamp(16.0, 46.0);
    final n = c.players;
    // 이름 칸은 가장 긴 이름("라지 스트레이트", "야추 보너스")이 다 들어가는 폭 이상 (글자가 점수 칸으로 삐져나오지 않게)
    final fontSize = (rowH * 0.42).clamp(12.0, 21.0);
    final style = TextStyle(fontFamily: 'Pretendard', fontSize: fontSize, fontWeight: FontWeight.w800);
    var longest = 0.0;
    for (final t in [YachtCategory.largeStraight.label, YachtCategory.smallStraight.label, '야추 보너스']) {
      final p = TextPainter(text: TextSpan(text: t, style: style), textDirection: TextDirection.ltr, textScaler: MediaQuery.textScalerOf(context), maxLines: 1)
        ..layout();
      longest = max(longest, p.width);
    }
    final labelW = max((blockW * 0.40).clamp(86.0, 124.0), longest + 12 + 8);
    final cellW = (blockW - labelW) / n;
    final look = _Look(context, rowH: rowH, cellW: cellW, labelW: labelW, showRule: false, split: true, blockW: blockW, gap: gap);
    final counts = c.game.rollsUsed > 0 && !c.rolling ? yachtCounts(c.game.dice) : null;
    return Center(
      child: SizedBox(
        width: width,
        child: AnimatedBuilder(
          animation: _ctl,
          builder: (context, _) => _table(look, cats, counts, _frame()),
        ),
      ),
    );
  }

  Widget _splitCard(_Look look, List<Widget> rows) => SizedBox(
        width: look.blockW,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: look.scheme.surface.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: look.scheme.outlineVariant),
          ),
          child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Column(mainAxisSize: MainAxisSize.min, children: rows)),
        ),
      );

  Widget _splitTable(_Look look, List<YachtCategory> cats, List<int>? counts, YachtTallyFrame? frame) {
    final hot = frame?.step ?? -1; // 정산 중에 지금 합계로 내려가는 줄
    var step = 0;
    // (정산 중에 매 프레임 바뀌지 않는 줄은 한 번 만든 것을 다시 쓴다: [_memo])
    Widget row(Widget Function(bool hot) make) {
      final k = step++;
      final h = hot == k;
      return _memo(k, h, () => make(h));
    }

    final upper = <Widget>[
      _memo(-1, false, () => _header(look)),
      for (var i = 0; i < 6; i++) row((h) => _categoryRow(look, cats[i], counts, shaded: i.isOdd, hot: h)),
      row((h) => _bonusRow(look, hot: h)),
    ];
    final lowerCats = cats.sublist(6);
    final lowerRows = <Widget>[
      _memo(-2, false, () => _header(look, showTitle: false)),
      for (var i = 0; i < lowerCats.length; i++) row((h) => _categoryRow(look, lowerCats[i], counts, shaded: i.isOdd, hot: h)),
      if (!c.game.daesung) row((h) => _yahtzeeBonusRow(look, hot: h)),
    ];
    final lower = <Widget>[
      RepaintBoundary(child: Column(mainAxisSize: MainAxisSize.min, children: lowerRows)),
      // 합계는 게임이 끝나야 나타난다
      AnimatedSize(
        duration: const Duration(milliseconds: 300),
        alignment: Alignment.topCenter,
        child: c.isOver ? _totalRow(look, frame) : const SizedBox.shrink(),
      ),
    ];
    return Stack(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [RepaintBoundary(child: _splitCard(look, upper)), SizedBox(width: look.gap), _splitCard(look, lower)],
        ),
        if (frame != null && frame.fly != null) ..._splitFlying(look, frame, step),
      ],
    );
  }

  /// 정산 중 한 줄의 점수들이 오른쪽 덩어리 맨 아래 합계 줄까지 내려가는 숫자 (숫자 칸 줄은 왼쪽 덩어리에서 비스듬히 건너온다).
  List<Widget> _splitFlying(_Look look, YachtTallyFrame frame, int stepCount) {
    final step = _tally!.steps[frame.step];
    final f = Curves.easeInCubic.transform(frame.fly!);
    double centerY(int ln) => look.rowH + ln * (look.rowH + 1) + 1 + look.rowH / 2;
    final fromBlock = frame.step < _upperSteps ? 0 : 1;
    final fromLine = frame.step < _upperSteps ? frame.step : frame.step - _upperSteps;
    final totalLine = stepCount - _upperSteps; // 오른쪽 덩어리에서 합계 줄 번호
    final y0 = centerY(fromLine), y1 = centerY(totalLine);
    final y = y0 + (y1 - y0) * f;
    final fade = f < 0.82 ? 1.0 : (1 - (f - 0.82) / 0.18).clamp(0.0, 1.0);
    return [
      for (var seat = 0; seat < c.players; seat++)
        Positioned(
          left: () {
            final x0 = fromBlock * (look.blockW + look.gap) + look.labelW + seat * look.cellW;
            final x1 = (look.blockW + look.gap) + look.labelW + seat * look.cellW;
            return x0 + (x1 - x0) * f;
          }(),
          top: y - look.rowH / 2,
          width: look.cellW,
          height: look.rowH,
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
}
