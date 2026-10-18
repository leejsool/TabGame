part of 'rummikub_screen.dart';

/// layout 조각 (화면 코드를 역할별로 나눈 파일)
extension _RkLayout on _RummikubScreenState {
  Widget _scaffold() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Stack(
        key: _stackKey,
        children: [
          Positioned.fill(child: _scaffoldBody(dark)),
          if (_fly != null) _flyOverlay(),
          if (_turnBanner) _turnBannerOverlay(),
          if (_celebrate) Positioned.fill(child: RkCelebration(key: const ValueKey('celebration'), title: '승리!', subtitle: '타일을 모두 내려놓았어요', onDone: () => mounted ? _update(() => _celebrate = false) : null)),
        ],
      ),
    );
  }

  Widget _scaffoldBody(bool dark) {
    return DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark ? const [Color(0xFF2B2118), Color(0xFF1F1812)] : const [Color(0xFFF3E8D4), Color(0xFFE6D5B8)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final landscape = box.maxWidth > box.maxHeight * 1.15 && box.maxWidth >= 640;
              return Column(
                children: [
                  _topBar(),
                  Expanded(child: landscape ? _landscape() : _portrait(box.maxWidth)),
                ],
              );
            },
          ),
        ),
    );
  }

  bool get _isTablet => MediaQuery.sizeOf(context).shortestSide >= kTabletMinSide;

  /// 녹색 판 위 타일 크기. [inner]는 판 안쪽 가로.
  /// 폰 세로 화면은 3장짜리 묶음 셋이 한 줄에 들어가는 크기, 폰 가로 화면은 34.
  /// 태블릿은 더 크게 하되, 3장짜리 묶음이 한 줄에 꼭 맞아 오른쪽에 빈자리가 남지 않는 크기로 한다.
  double _tableTile(double inner, {required bool landscape}) {
    if (_isTablet) return rkTabletTableTileSize(inner);
    return landscape ? 34 : rkTableTileSize(inner);
  }

  Widget _portrait(double width) {
    final rackTile = width < 500 ? 34.0 : 42.0;
    return Column(
      children: [
        _playerChips(),
        _statusBanner(),
        Expanded(child: _tablePanel(landscape: false)),
        _floorPool(height: 0, tileW: 20),
        _bottomPanel(rackTile, width),
      ],
    );
  }

  Widget _landscape() => Row(
        children: [
          Expanded(flex: 5, child: Column(children: [_playerChips(), _statusBanner(), Expanded(child: _tablePanel(landscape: true))])),
          Expanded(
            flex: 4,
            child: LayoutBuilder(
              builder: (context, box) => Column(children: [_floorPool(height: 0, tileW: 24), Expanded(child: SingleChildScrollView(child: _bottomPanel(42, box.maxWidth, maxRows: 4)))]),
            ),
          ),
        ],
      );

  /// 맨 위 줄: 제목 줄은 낮게(34) 줄이고 단추도 작게 해서 판 자리를 아낀다.
  Widget _topBar() {
    Widget icon(IconData data, String tip, VoidCallback onTap) => IconButton(
          tooltip: tip,
          icon: Icon(data, size: 22),
          onPressed: onTap,
          padding: EdgeInsets.zero,
          visualDensity: VisualDensity.compact,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 34),
        );
    return SizedBox(
      height: 34,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Row(
          children: [
            icon(Icons.arrow_back_rounded, '뒤로', () => Navigator.of(context).maybePop()),
            Flexible(
              child: Text('루미큐브', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, fontSize: 17)),
            ),
            const Spacer(),
            icon(Icons.emoji_events_rounded, '내 기록', () => openRecords(context, game: 'rummikub')),
            icon(Icons.help_outline_rounded, '규칙', () => showRummikubRules(context)),
          ],
        ),
      ),
    );
  }

  /// 앉은 사람들 칩: 이름만 보이고, 지금 차례인 쪽이 강조된다. (상대가 손에 몇 장 가졌는지는 보드게임처럼 알 수 없다.
  /// 판이 끝나면 남은 벌점이 드러난다.)
  Widget _playerChips() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        Widget chip(int seat) {
          final active = !c.isOver && !c.halted && c.turn == seat;
          final me = seat == c.humanSeat;
          final color = me ? kRkWood : const Color(0xFF455A64);
          final win = c.isOver && c.state.winner == seat;
          return KeyedSubtree(
            key: _chipKey(seat),
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: active || win ? 0.2 : 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: active || win ? 1 : 0.3), width: active || win ? 2 : 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(me ? Icons.person_rounded : (c.isCpuSeat(seat) || !c.online ? Icons.smart_toy_rounded : Icons.wifi_rounded), size: 15, color: color),
                const SizedBox(width: 4),
                Text(_name(seat), style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: color)),
                if (c.isOver) ...[
                  const SizedBox(width: 8),
                  Text('${c.state.rackPoints(seat)}점', style: TextStyle(fontWeight: FontWeight.w900, color: color)),
                ],
              ],
            ),
          ));
        }

        return Padding(
          padding: const EdgeInsets.only(top: 0, left: _edge, right: _edge),
          child: Wrap(spacing: 8, runSpacing: 4, alignment: WrapAlignment.center, children: [for (var i = 0; i < c.players; i++) chip(i)]),
        );
      },
    );
  }

  /// 한 줄짜리 상태: 긴 안내 글은 없애고, 상대가 하고 있는 일이나 결과처럼 꼭 필요한 것만 짧게 보인다. (설명은 규칙 창과 팝업으로)
  Widget _statusBanner() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final text = _shortStatus;
        if (text == null) return const SizedBox(height: 2);
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.75)),
          ),
        );
      },
    );
  }

  /// 지금 꼭 알려야 할 짧은 상태 (없으면 null).
  String? get _shortStatus {
    final s = c.state;
    if (c.isOver) {
      final w = s.winner;
      if (w == null) return '아무도 낼 수 없어 끝났어요 · 무승부';
      return w == c.humanSeat ? '이겼어요! 🎉' : '${_name(w)}이(가) 이겼어요';
    }
    if (_opponentGone) return '상대와 연결이 끊겼어요';
    if (c.halted) return _rematchAsked ? '상대가 한 판 더를 받아 주기를 기다려요…' : '기권으로 끝난 판이에요';
    // (누가 생각 중이고 무엇을 내려놓았는지는 따로 글로 알리지 않는다: 위의 이름 칩과 판 위의 움직임으로 보이고, 그만큼 녹색 판이 넓어진다)
    return null;
  }
}
