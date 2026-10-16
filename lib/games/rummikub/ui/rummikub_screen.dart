import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../core/settings_scope.dart';
import '../../../net/lan_connection.dart';
import '../../../records/records_screen.dart';
import '../core/rummikub_ai.dart';
import '../core/rummikub_rules.dart';
import '../data/rummikub_history.dart';
import '../game/rummikub_controller.dart';
import '../game/rummikub_layout.dart';
import '../tutorial/rummikub_tutorial.dart';
import 'rummikub_tiles.dart';

/// 루미큐브 플레이 화면.
///
/// 내 손은 이 기기에만 보이고, 상대(CPU 또는 같은 Wi‑Fi의 사람)의 패는 몇 장인지만 보인다.
class RummikubScreen extends StatefulWidget {
  const RummikubScreen({
    super.key,
    this.mode = PlayMode.vsCpu,
    this.players = 2,
    this.humanSeat = 0,
    this.level = RkLevel.normal,
    this.seed,
    this.controller,
    this.link,
  });

  final PlayMode mode;

  /// 앉은 사람 수 (CPU 포함). 같은 Wi‑Fi 대결은 2명.
  final int players;
  final int humanSeat;
  final RkLevel level;

  /// 패를 나눌 씨앗 (같은 Wi‑Fi 대결에서는 두 기기가 같은 값으로 시작한다).
  final int? seed;

  /// 같은 Wi‑Fi 대결에서 상대 기기와의 연결. 이 화면이 닫을 때 같이 닫는다.
  final LanConnection? link;

  /// (테스트용) 미리 만든 컨트롤러.
  final RummikubController? controller;

  @override
  State<RummikubScreen> createState() => _RummikubScreenState();
}

class _RummikubScreenState extends State<RummikubScreen> {
  late final RummikubController c = widget.controller ??
      RummikubController(mode: widget.mode, players: widget.players, humanSeat: widget.humanSeat, level: widget.level, seed: widget.seed);
  bool _resultHandled = false;

  // ── 같은 Wi‑Fi 대결 ──
  LanConnection? get _link => c.online ? widget.link : null;
  StreamSubscription<Map<String, dynamic>>? _linkSub;
  bool _opponentGone = false;
  bool _leaving = false;
  bool _rematchAsked = false;
  bool _rematchOffered = false;

  @override
  void initState() {
    super.initState();
    c.onFeedback = _feedback;
    c.addListener(_onChanged);
    final link = _link;
    if (link != null) {
      c.onLocalMove = (move) => link.send({'t': 'move', ...move});
      _linkSub = link.messages.listen(_onNet);
      link.closed.then((_) => _onLinkClosed());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
  }

  @override
  void dispose() {
    _leaving = true;
    _linkSub?.cancel();
    final link = _link;
    if (link != null) {
      link.send(const {'t': 'bye'});
      link.close();
    }
    c.removeListener(_onChanged);
    c.onFeedback = null;
    c.onLocalMove = null;
    c.dispose();
    super.dispose();
  }

  void _onNet(Map<String, dynamic> m) {
    if (!mounted) return;
    switch (m['t']) {
      case 'move':
        if (!c.receiveMove(m)) _desync();
      case 'resign':
        _onOpponentResigned();
      case 'again':
        setState(() => _rematchOffered = true);
        if (_rematchAsked) _startRematch();
      case 'bye':
        _onLinkClosed();
    }
  }

  Future<void> _desync() async {
    if (_opponentGone || _leaving) return;
    _opponentGone = true;
    await _link?.close();
    if (!mounted) return;
    await _notice('판이 서로 어긋났어요', '두 기기의 판이 달라져서 여기서 끝낼게요. 다시 방을 만들어 시작해 주세요.');
    if (mounted) Navigator.of(context).pop();
  }

  void _onLinkClosed() {
    if (!mounted || _leaving || _opponentGone) return;
    setState(() => _opponentGone = true);
    if (c.isOver || c.halted) return;
    _notice('상대와 연결이 끊겼어요', 'Wi‑Fi가 끊겼거나 상대가 나갔어요. 이 판은 기록하지 않아요.').then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _notice(String title, String body) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.wifi_off_rounded, size: 32),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(body, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('나가기'))],
        ),
      );

  Future<void> _onOpponentResigned() async {
    if (c.isOver || c.halted) return;
    c.opponentResigned();
    _resultHandled = true;
    await _record(winner: c.humanSeat, resigned: true);
    if (!mounted) return;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.emoji_events_rounded, size: 32, color: Color(0xFFF2A900)),
        title: const Text('상대가 기권했어요', textAlign: TextAlign.center),
        content: const Text('이번 판은 내가 이긴 걸로 기록해 두었어요.', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('메뉴로')),
          if (!_opponentGone) FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('한 판 더')),
        ],
      ),
    );
    if (!mounted) return;
    if (again == true) {
      _requestRematch();
    } else {
      Navigator.of(context).pop();
    }
  }

  void _requestRematch() {
    if (_rematchAsked || _opponentGone) return;
    setState(() => _rematchAsked = true);
    _link?.send(const {'t': 'again'});
    if (_rematchOffered) _startRematch();
  }

  void _startRematch() {
    setState(() {
      _rematchAsked = false;
      _rematchOffered = false;
    });
    _resultHandled = false;
    c.restart();
  }

  Future<void> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('판에서 나갈까요?'),
        content: const Text('나가면 상대와의 연결이 끊기고, 이 판은 기록되지 않아요.\n(이기고 지는 걸 기록하려면 "기권"을 눌러 주세요)', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('계속하기')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('나가기')),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop();
  }

  void _feedback(String kind) {
    if (!SettingsScope.of(context).haptics) return;
    switch (kind) {
      case 'place':
        HapticFeedback.selectionClick();
      case 'draw':
        HapticFeedback.lightImpact();
      case 'bad':
        HapticFeedback.vibrate();
      case 'win':
        HapticFeedback.heavyImpact();
    }
  }

  Future<void> _record({required int? winner, bool resigned = false}) {
    return RkHistory.add(RkRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: c.vsCpu,
      online: c.online,
      players: c.players,
      winner: winner,
      human: c.humanSeat,
      turns: c.moveCount,
      level: c.vsCpu ? c.level : null,
      resigned: resigned,
    ));
  }

  void _onChanged() {
    if (c.isOver && !_resultHandled) {
      _resultHandled = true;
      _record(winner: c.state.winner);
    } else if (!c.isOver && !c.halted) {
      _resultHandled = false;
    }
  }

  String _name(int seat) {
    if (seat == c.humanSeat) return '나';
    if (c.online) return _link?.peerNick ?? '상대';
    return 'CPU ${seat < c.humanSeat ? seat + 1 : seat}';
  }

  Future<void> _resign() async {
    if (!c.canResign) return;
    final ok = await confirmGiveUp(context, detail: c.vsCpu ? 'CPU의 승리로 기록돼요.' : '상대의 승리로 기록돼요.', retry: false, verb: '기권');
    if (!ok || !mounted || !c.resign()) return;
    _resultHandled = true;
    _link?.send(const {'t': 'resign'});
    await _record(winner: (c.humanSeat + 1) % c.players, resigned: true);
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: c.vsCpu ? 'CPU ${c.level.label} · ${c.moveCount}차례' : '${c.moveCount}차례',
      againLabel: c.online ? '한 판 더' : '새 판',
      offerAgain: !_opponentGone,
      retry: false,
      verb: '기권',
    );
    if (!mounted) return;
    if (again && c.online) {
      _requestRematch();
    } else if (again) {
      _resultHandled = false;
      c.restart();
    } else {
      Navigator.of(context).pop();
    }
  }

  // ── 안내 글 ──

  String get _status {
    final s = c.state;
    if (c.isOver) {
      final w = s.winner;
      if (w == null) return '아무도 낼 수 없어 끝났어요 · 무승부예요';
      if (w == c.humanSeat) return '이겼어요! 🎉';
      return '${_name(w)}이(가) 이겼어요';
    }
    if (_opponentGone) return '상대와 연결이 끊겼어요';
    if (c.halted) return _rematchAsked ? '상대가 한 판 더를 받아 주기를 기다리는 중이에요…' : '기권으로 끝난 판이에요';
    if (c.myTurn) {
      if (!s.melded[c.humanSeat]) return '내 차례 · 처음에는 내 타일로만 30점 이상을 내려놓아야 해요';
      return '내 차례 · 타일을 판에 끌어다 맞추거나, 안 되면 바닥에서 한 장 골라 뽑아요';
    }
    if (c.thinking) return '${_name(s.turn)}이(가) 생각하는 중…';
    if (c.animating) return '${_name(s.turn)}이(가) 타일을 옮기는 중…';
    return '${_name(s.turn)} 차례${c.online ? ' · 기다리는 중이에요' : ''}';
  }

  String? get _lastEvent {
    if (c.lastActor < 0 || c.isOver) return null;
    final who = _name(c.lastActor);
    return c.lastDrew ? '$who: 타일을 뽑았어요' : '$who: 타일 ${c.lastCount}장을 내려놓았어요';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, child) {
        final askBeforeLeave = c.online && !c.isOver && !c.halted && !_opponentGone;
        return PopScope(
          canPop: !askBeforeLeave,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmLeave();
          },
          child: child!,
        );
      },
      child: _scaffold(),
    );
  }

  Widget _scaffold() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: DecoratedBox(
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
      ),
    );
  }

  Widget _portrait(double width) {
    final tableTile = width < 500 ? 28.0 : 34.0;
    return Column(
      children: [
        _playerChips(),
        _statusBanner(),
        Expanded(flex: 4, child: _tablePanel(tableTile)),
        _floorPool(height: 92, tileW: 20),
        Expanded(flex: 5, child: _bottomPanel(width < 500 ? 34 : 42)),
      ],
    );
  }

  Widget _landscape() => Row(
        children: [
          Expanded(flex: 5, child: Column(children: [_playerChips(), _statusBanner(), Expanded(child: _tablePanel(34))])),
          Expanded(
            flex: 4,
            child: Column(children: [_floorPool(height: 124, tileW: 24), Expanded(child: _bottomPanel(42))]),
          ),
        ],
      );

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(tooltip: '뒤로', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).maybePop()),
          Flexible(
            child: Text('루미큐브', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const Spacer(),
          IconButton(tooltip: '내 기록', icon: const Icon(Icons.emoji_events_rounded), onPressed: () => openRecords(context, game: 'rummikub')),
          IconButton(tooltip: '규칙', icon: const Icon(Icons.help_outline_rounded), onPressed: () => showRummikubRules(context)),
        ],
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
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: active || win ? 0.2 : 0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: active || win ? 1 : 0.3), width: active || win ? 2.5 : 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(me ? Icons.person_rounded : (c.online ? Icons.wifi_rounded : Icons.smart_toy_rounded), size: 18, color: color),
                const SizedBox(width: 5),
                Text(_name(seat), style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                if (c.isOver) ...[
                  const SizedBox(width: 8),
                  Text('${c.state.rackPoints(seat)}점', style: TextStyle(fontWeight: FontWeight.w900, color: color)),
                ],
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 6, left: 8, right: 8),
          child: Wrap(spacing: 8, runSpacing: 6, alignment: WrapAlignment.center, children: [for (var i = 0; i < c.players; i++) chip(i)]),
        );
      },
    );
  }

  Widget _statusBanner() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final color = c.isOver || c.halted ? Colors.grey : (c.myTurn ? kRkWood : const Color(0xFF455A64));
        final event = _lastEvent;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              if (event != null && !c.myTurn)
                Text(event, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
            ],
          ),
        );
      },
    );
  }

  // ── 끌기와 타일 ──

  /// 끌어 온 타일이 고른 타일이면 고른 것 전부를, 아니면 그 한 장만.
  List<int> _dragged(int id) => c.selected.contains(id) ? c.selected.toList() : [id];

  /// 끌고 있는 타일들의 모습 (손가락 밑에 가운데가 오게 한다).
  Widget _dragFeedback(List<int> ids, double width) {
    final shown = ids.length > 8 ? ids.sublist(0, 8) : ids;
    return Material(
      color: Colors.transparent,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [for (final t in shown) Padding(padding: const EdgeInsets.only(right: 3), child: RkTile(id: t, width: width))],
      ),
    );
  }

  Widget _draggable({required List<int> data, required double width, required Widget child, Widget? whileDragging}) {
    if (!c.canAct) return child;
    final shown = data.length > 8 ? 8 : data.length;
    final fw = shown * (width + 3), fh = width * 1.35;
    return Draggable<List<int>>(
      data: data,
      dragAnchorStrategy: (draggable, context, position) => Offset(fw / 2, fh / 2),
      feedback: _dragFeedback(data, width),
      childWhenDragging: whileDragging ?? Opacity(opacity: 0.5, child: child),
      child: child,
    );
  }

  /// 손이나 판 위의 타일 한 장: 누르면 고르고, 끌어서 옮길 수 있다.
  Widget _tile(int id, double width, {bool fromTable = false}) {
    final selected = c.selected.contains(id);
    final tile = RkTile(
      id: id,
      width: width,
      selected: selected,
      glow: (fromTable && c.placed.contains(id)) || (!fromTable && id == c.lastDrawn),
      onTap: c.canAct ? () => c.toggleSelect(id) : null,
    );
    return _draggable(data: _dragged(id), width: width, child: tile);
  }

  // ── 녹색 판 ──

  final GlobalKey _canvasKey = GlobalKey();

  /// 녹색 판: 묶음을 어디에나 놓을 수 있는 넓은 판. 타일을 끌어다 놓으면 근처 묶음에 자석처럼 붙고, 멀면 그 자리에 새 묶음이 된다.
  /// 묶음 왼쪽의 손잡이를 끌면 묶음 통째로 옮긴다. 상대의 수는 타일이 한 장씩 날아와 놓이는 모습으로 보인다.
  Widget _tablePanel(double tileW) {
    final tileH = tileW * 1.35;
    final ux = tileW + 3, uy = tileH + 8;
    const pad = 8.0;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(10, 8, 10, 4),
      decoration: BoxDecoration(
        color: const Color(0xFF2E6B4A).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1F4A33), width: 3),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: LayoutBuilder(
          builder: (context, box) => ListenableBuilder(
            listenable: c,
            builder: (context, _) {
              final widthUnits = (box.maxWidth - pad * 2) / ux;
              final perRow = max(3, (widthUnits - kSetPad).floor());
              final spots = c.layoutSets(widthUnits, perRow);
              var bottom = 0.0;
              for (var i = 0; i < c.work.length; i++) {
                bottom = max(bottom, setRect(spots[i], c.work[i].length, perRow).bottom);
              }
              final canvasH = max(box.maxHeight, bottom * uy + uy * 1.5 + 8);
              final frames = <Widget>[];
              final tiles = <Widget>[];
              for (var i = 0; i < c.work.length; i++) {
                final set = c.work[i];
                final a = spots[i];
                final ids = arrangeSet(set);
                final cols = min(ids.length, perRow), rows = (ids.length / perRow).ceil();
                final left = pad + a.dx * ux, top = 3 + a.dy * uy;
                final bad = !isValidMeld(set) && c.canAct;
                final touched = !c.state.table.any((o) => o.length == set.length && o.toSet().containsAll(set));
                frames.add(AnimatedPositioned(
                  key: ValueKey('frame$i'),
                  duration: const Duration(milliseconds: 380),
                  curve: Curves.easeInOut,
                  left: left,
                  top: top,
                  width: (cols + kSetPad) * ux,
                  height: rows * uy - 2,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: c.canAct && c.selected.isNotEmpty ? () => c.moveTiles(c.selected.toList(), to: set) : null,
                    // 색이 순간적으로 바뀌면 눈이 아프니, 테두리 색은 부드럽게 바뀌게 하고 올바르지 않은 묶음도 옅은 주황으로만 알려 준다
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: bad ? const Color(0xFFE9B08A) : Colors.white.withValues(alpha: touched && c.canAct ? 0.6 : 0.28),
                          width: bad ? 2 : 1.2,
                        ),
                      ),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: _draggable(
                          data: List.of(ids),
                          width: tileW,
                          child: SizedBox(
                            width: 0.55 * ux,
                            height: double.infinity,
                            child: Icon(Icons.drag_indicator_rounded, size: 16, color: Colors.white.withValues(alpha: c.canAct ? 0.75 : 0.3)),
                          ),
                          whileDragging: SizedBox(width: 0.55 * ux),
                        ),
                      ),
                    ),
                  ),
                ));
                for (var k = 0; k < ids.length; k++) {
                  final id = ids[k];
                  final dest = Offset(left + 0.55 * ux + (k % perRow) * ux, top + 3 + (k ~/ perRow) * uy);
                  final begin = c.flying.contains(id) ? Offset(box.maxWidth / 2 - tileW / 2, -tileH * 2) : dest;
                  tiles.add(TweenAnimationBuilder<Offset>(
                    key: ValueKey('tile$id'),
                    tween: Tween(begin: begin, end: dest),
                    duration: const Duration(milliseconds: 460),
                    curve: Curves.easeInOutCubic,
                    builder: (context, pos, child) => Positioned(left: pos.dx, top: pos.dy, child: child!),
                    child: _tile(id, tileW, fromTable: true),
                  ));
                }
              }
              final empty = c.work.isEmpty;
              return DragTarget<List<int>>(
                onWillAcceptWithDetails: (_) => c.canAct,
                onAcceptWithDetails: (d) {
                  final rb = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                  if (rb == null) return;
                  final local = rb.globalToLocal(d.offset);
                  c.dropTiles(d.data, Offset((local.dx - pad) / ux, (local.dy - 3) / uy));
                },
                builder: (context, candidate, _) => Stack(
                  children: [
                    SingleChildScrollView(
                      child: SizedBox(
                        key: _canvasKey,
                        width: box.maxWidth,
                        height: canvasH,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            if (candidate.isNotEmpty) Positioned.fill(child: ColoredBox(color: Colors.white.withValues(alpha: 0.04))),
                            if (empty)
                              Positioned.fill(
                                child: Center(
                                  child: Text(
                                    c.canAct ? '타일을 여기로 끌어다 놓으세요' : '아직 판 위에 아무것도 없어요',
                                    style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 14),
                                  ),
                                ),
                              ),
                            ...frames,
                            ...tiles,
                          ],
                        ),
                      ),
                    ),
                    if (c.canAct && c.selected.isNotEmpty)
                      Positioned(
                        top: 6,
                        right: 8,
                        child: ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.add_rounded, size: 18),
                          label: const Text('고른 타일로 새 묶음'),
                          onPressed: () => c.moveTiles(c.selected.toList()),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ── 바닥에 깔린 더미 ──

  /// 바닥에 엎어 둔 타일들. 내 차례에 낼 수 없으면 이 중 한 장을 직접 골라 뽑는다.
  Widget _floorPool({required double height, required double tileW}) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final pool = c.state.pool;
        final canPick = c.canAct && !c.isOver;
        final tileH = tileW * 1.35;
        return Container(
          height: height,
          margin: const EdgeInsets.fromLTRB(10, 2, 10, 2),
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 6),
          decoration: BoxDecoration(
            color: const Color(0xFF6B4A2E).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF4A3220).withValues(alpha: 0.7), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.layers_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                  const SizedBox(width: 4),
                  Text('바닥 ${pool.length}장', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pool.isEmpty
                          ? '바닥이 비었어요'
                          : (canPick ? '낼 수 없으면 한 장을 골라 뽑아요' : ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                    ),
                  ),
                ],
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final items = <(int, double, double, double)>[];
                    for (var i = 0; i < pool.length; i++) {
                      var h = (pool[i] * 2654435761 + 40503) & 0x7fffffff;
                      h ^= h >> 13;
                      h = (h * 1274126177) & 0x7fffffff;
                      final fx = (h & 1023) / 1023, fy = ((h >> 10) & 1023) / 1023, ang = (((h >> 20) & 63) - 32) / 100;
                      items.add((i, fx * max(0, box.maxWidth - tileW * 1.4), fy * max(0, box.maxHeight - tileH * 1.15), ang));
                    }
                    items.sort((a, b) => a.$3.compareTo(b.$3)); // 위쪽 것이 아래에 깔리게
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (final (i, x, y, ang) in items)
                          Positioned(
                            key: ValueKey('floor${pool[i]}'),
                            left: x,
                            top: pool[i] == c.opponentPick ? y - 8 : y,
                            child: Transform.rotate(
                              angle: ang,
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: canPick ? () => _pickFloor(i) : null,
                                child: RkTileBack(width: tileW, glow: pool[i] == c.opponentPick, active: canPick),
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 바닥의 [index]번째 타일을 뽑는다. 판을 만져 둔 게 있으면 사라진다고 먼저 알려 준다.
  Future<void> _pickFloor(int index) async {
    if (!c.canAct) return;
    if (c.changed || !_sameAsTable()) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('타일을 뽑을까요?'),
          content: const Text('뽑으면 이번 차례가 끝나고, 지금 판에서 옮겨 둔 것은 모두 처음으로 돌아가요.', textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('계속 맞추기')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('뽑기')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
    }
    c.draw(index: index);
  }

  // ── 내 손 + 단추 ──

  Widget _bottomPanel(double tileWidth) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return Column(
          children: [
            Expanded(child: _rack(tileWidth)),
            if (c.isOver) _resultPanel() else _actions(),
          ],
        );
      },
    );
  }

  /// 내 손: 위쪽 "정렬 칸"은 색/숫자 순서 단추를 따르고, 점선 아래 "내 정리판"은 단추와 상관없이 내가 놓은 그대로 둔다.
  /// 타일은 끌어서 두 칸 사이를 오가거나, 정리판 안에서 순서를 바꿀 수 있다.
  Widget _rack(double tileWidth) {
    final scheme = Theme.of(context).colorScheme;
    final auto = c.autoTiles, custom = c.customTiles;
    return DragTarget<List<int>>(
      onWillAcceptWithDetails: (d) => c.canAct,
      onAcceptWithDetails: (d) => c.moveToAuto(d.data),
      builder: (context, candidate, _) => Container(
        margin: const EdgeInsets.fromLTRB(10, 4, 10, 4),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: (candidate.isNotEmpty ? const Color(0xFFCFA668) : const Color(0xFFC79A5B)).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kRkWood.withValues(alpha: 0.7), width: 2.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('내 타일 ${auto.length + custom.length}장', style: const TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                _sortButton('색 순서', c.sortedByColor, () => c.sortHand(byColor: true)),
                const SizedBox(width: 6),
                _sortButton('숫자 순서', !c.sortedByColor, () => c.sortHand(byColor: false)),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: c.canAct && c.selected.isNotEmpty ? () => c.moveToAuto(c.selected.toList()) : null,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: tileWidth * 1.35 + 8),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Wrap(spacing: 4, runSpacing: 8, children: [for (final t in auto) _tile(t, tileWidth)]),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _customZone(custom, tileWidth, scheme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 점선으로 둘러싼 "내 정리판". 색/숫자 순서 단추의 영향을 받지 않는다.
  Widget _customZone(List<int> tiles, double tileWidth, ColorScheme scheme) {
    return DragTarget<List<int>>(
      onWillAcceptWithDetails: (d) => c.canAct,
      onAcceptWithDetails: (d) => c.moveToCustom(d.data),
      builder: (context, candidate, _) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: c.canAct && c.selected.isNotEmpty ? () => c.moveToCustom(c.selected.toList()) : null,
        child: CustomPaint(
          painter: _DashedBorderPainter(color: kRkWood.withValues(alpha: candidate.isNotEmpty ? 0.9 : 0.7), fill: candidate.isNotEmpty ? Colors.white.withValues(alpha: 0.1) : null),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: tileWidth * 1.35 + 30),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tiles.isEmpty ? '내 정리판 · 타일을 끌어다 마음대로 놓아 두세요' : '내 정리판 (정렬 단추와 상관없어요)',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: scheme.onSurface.withValues(alpha: 0.6)),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 2,
                    runSpacing: 8,
                    children: [
                      for (final t in tiles)
                        DragTarget<List<int>>(
                          onWillAcceptWithDetails: (d) => c.canAct && !d.data.contains(t),
                          onAcceptWithDetails: (d) => c.moveToCustom(d.data, beforeId: t),
                          builder: (context, cand, _) => Container(
                            padding: const EdgeInsets.only(left: 2),
                            decoration: BoxDecoration(border: Border(left: BorderSide(color: cand.isNotEmpty ? kRkWood.withValues(alpha: 0.8) : Colors.transparent, width: 3))),
                            child: _tile(t, tileWidth),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sortButton(String label, bool on, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: on ? kRkWood : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kRkWood.withValues(alpha: 0.6)),
        ),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: on ? Colors.white : kRkWood)),
      ),
    );
  }

  Widget _actions() {
    final compact = OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), visualDensity: VisualDensity.compact);
    final scheme = Theme.of(context).colorScheme;
    final err = c.error;
    final modified = c.canAct && (c.changed || !_sameAsTable());
    String? hint = c.notice;
    if (hint == null && c.canAct && modified && err != null) hint = err.message;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c.canAct && c.selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('${c.selected.length}장을 골랐어요 · 끌어다 놓거나, 놓을 묶음을 눌러요', style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.75))),
            )
          else if (hint != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(hint, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: err == null ? scheme.onSurface.withValues(alpha: 0.75) : scheme.error, fontWeight: FontWeight.w700)),
            ),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              if (c.canAct && c.selected.isNotEmpty && c.selected.any(c.placed.contains))
                OutlinedButton.icon(
                  style: compact,
                  onPressed: () => c.returnToHand(c.selected.toList()),
                  icon: const Icon(Icons.south_west_rounded, size: 18),
                  label: const Text('손으로'),
                ),
              OutlinedButton.icon(
                style: compact,
                onPressed: c.canAct && modified ? c.reset : null,
                icon: const Icon(Icons.undo_rounded, size: 18),
                label: const Text('처음으로'),
              ),
              // 바닥이 비면 뽑을 타일이 없으니 넘기기만 한다 (바닥에 타일이 있으면 그중 한 장을 직접 골라 뽑는다)
              if (c.state.poolCount == 0)
                OutlinedButton.icon(
                  style: compact,
                  onPressed: c.canAct ? c.draw : null,
                  icon: const Icon(Icons.skip_next_rounded, size: 18),
                  label: const Text('넘기기'),
                ),
              FilledButton.icon(
                onPressed: c.canAct ? c.endTurn : null,
                icon: const Icon(Icons.check_rounded, size: 20),
                label: const Text('끝내기'),
                style: FilledButton.styleFrom(backgroundColor: kRkWood, visualDensity: VisualDensity.compact),
              ),
              OutlinedButton.icon(
                style: compact,
                onPressed: c.canResign ? _resign : null,
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('기권'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 판이 처음과 같은 모습인가 (옮기기만 하고 도로 돌려놓았을 때 "처음으로"를 막으려고).
  bool _sameAsTable() {
    String key(List<int> s) => ([...s]..sort()).join(',');
    final a = [for (final s in c.work) key(s)]..sort();
    final b = [for (final s in c.state.table) key(s)]..sort();
    return a.join('|') == b.join('|');
  }

  Widget _resultPanel() {
    final s = c.state;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var p = 0; p < c.players; p++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(s.winner == p ? Icons.emoji_events_rounded : Icons.person_rounded, size: 18, color: s.winner == p ? const Color(0xFFF2A900) : null),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_name(p), style: const TextStyle(fontWeight: FontWeight.w800))),
                  Text(s.racks[p].isEmpty ? '손이 비었어요' : '남은 타일 ${s.racks[p].length}장 · 벌점 ${s.rackPoints(p)}점', style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('메뉴로')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: c.online ? (_rematchAsked || _opponentGone ? null : _requestRematch) : () {
                  _resultHandled = false;
                  c.restart();
                },
                child: Text(!c.online
                    ? '한 판 더'
                    : _opponentGone
                        ? '상대가 나갔어요'
                        : _rematchAsked
                            ? '상대를 기다려요…'
                            : _rematchOffered
                                ? '한 판 더 (상대가 원해요)'
                                : '한 판 더'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 규칙 설명.
Future<void> showRummikubRules(BuildContext context) {
  Widget line(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  '),
            Expanded(child: Text(t, style: const TextStyle(height: 1.4))),
          ],
        ),
      );
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('루미큐브 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('손의 타일을 먼저 모두 판에 내려놓는 사람이 이겨요.'),
            line('그룹: 같은 숫자, 서로 다른 색 3~4장 (예: 파랑 7, 빨강 7, 주황 7).'),
            line('런: 같은 색, 이어지는 숫자 3장 이상 (예: 파랑 4-5-6). 13 다음에 1은 이어지지 않아요.'),
            line('조커는 어떤 타일 대신으로도 쓸 수 있어요.'),
            line('처음 내려놓을 때는 내 타일로만 묶음을 만들어 숫자 합이 30점 이상이어야 해요. 이때는 판 위의 묶음을 건드릴 수 없어요.'),
            line('그다음부터는 판 위 타일을 옮기고 쪼개서 새로 맞춰도 돼요. 끝낼 때 판 위의 모든 묶음이 올바르고, 내 타일을 한 장 이상 내려놓았어야 해요.'),
            line('판 위의 타일을 손으로 가져올 수는 없어요.'),
            line('낼 수 없으면 바닥에 엎어 둔 타일 중 한 장을 직접 골라 뽑고 차례를 넘겨요. 바닥이 비었는데 모두 낼 수 없으면, 손에 남은 타일의 숫자 합이 가장 작은 사람이 이겨요 (조커는 30점).'),
            line('상대가 손에 몇 장 가졌는지는 알 수 없어요. 판이 끝나야 남은 타일의 점수가 드러나요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            rummikubTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}


/// 점선 테두리 (둥근 사각형).
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, this.fill});

  final Color color;
  final Color? fill;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)).deflate(1);
    if (fill != null) canvas.drawRRect(rrect, Paint()..color = fill!);
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = color;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, min(d + 7, m.length)), paint);
        d += 12;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color || old.fill != fill;
}
