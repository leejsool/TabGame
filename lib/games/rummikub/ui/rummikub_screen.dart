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
import 'rummikub_celebration.dart';
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

  /// 처음 내 차례에 "처음 내려놓을 때" 팝업을 띄우는가 (시험에서는 끈다).
  static bool showFirstHint = true;

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      c.start();
      _maybeFirstHint();
    });
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
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
      case 'turn':
        HapticFeedback.mediumImpact();
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

  bool _hintShown = false;

  /// 처음 내 차례가 되면 (아직 처음 내려놓기 전이면) 규칙을 한 번만 팝업으로 알려 준다. 화면에 긴 안내 글을 두지 않으려고.
  void _maybeFirstHint() {
    if (!RummikubScreen.showFirstHint || _hintShown || !mounted || !c.myTurn || c.state.melded[c.humanSeat]) return;
    _hintShown = true;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.info_outline_rounded),
        title: const Text('처음 내려놓을 때'),
        content: const Text(
          '내 타일로만 묶음을 만들어 숫자 합이 30점 이상이어야 해요.\n\n'
          '• 타일은 끌어서 녹색 판 아무 데나 놓아요 (한 장씩 먼저 놓아 둬도 돼요)\n'
          '• 꾹 눌렀다가 끌면 묶음 통째로 옮겨요\n'
          '• 낼 수 없으면 바닥에서 한 장을 골라 뽑아요',
          style: TextStyle(height: 1.45),
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요'))],
      ),
    );
  }

  // ── 내 차례 알림 ──

  bool _prevCanAct = false;
  bool _turnBanner = false;
  Timer? _turnTimer;

  /// 내 차례가 되면(상대의 수가 다 보여진 뒤) 잠깐 "내 차례예요!"가 뜨고 살짝 진동한다. 눌러서 닫을 필요 없이 저절로 사라진다.
  void _maybeAnnounceTurn() {
    final can = c.canAct && !c.isOver;
    final arrived = can && !_prevCanAct;
    _prevCanAct = can;
    if (!arrived || !c.animate || !mounted || c.moveCountForBanner == 0) return;
    _feedback('turn');
    _turnTimer?.cancel();
    setState(() => _turnBanner = true);
    _turnTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _turnBanner = false);
    });
  }

  Widget _turnBannerOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        child: Center(
          child: TweenAnimationBuilder<double>(
            key: const ValueKey('turn-banner'),
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutBack,
            builder: (context, t, child) => Opacity(opacity: t.clamp(0.0, 1.0), child: Transform.scale(scale: 0.8 + 0.2 * t, child: child)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
              decoration: BoxDecoration(
                color: kRkWood.withValues(alpha: 0.94),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_active_rounded, color: Colors.white),
                  SizedBox(width: 8),
                  Text('내 차례예요!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onChanged() {
    _maybeAnnounceTurn();
    _maybeFlyOpponentPick();
    if (c.isOver && !_resultHandled) {
      _resultHandled = true;
      _record(winner: c.state.winner);
      if (c.state.winner == c.humanSeat) _celebrateWin();
    } else if (!c.isOver && !c.halted) {
      _resultHandled = false;
      _celebrate = false;
    }
  }

  // ── 승리 축하 ──

  bool _celebrate = false;

  /// 내가 이기면 색종이가 쏟아지고 "승리!" 현판이 튀어 오르며 진동이 길게 울린다.
  void _celebrateWin() {
    if (!c.animate || !mounted) return;
    setState(() => _celebrate = true);
    if (SettingsScope.of(context).haptics) {
      HapticFeedback.heavyImpact();
      Future<void>.delayed(const Duration(milliseconds: 180), HapticFeedback.mediumImpact);
      Future<void>.delayed(const Duration(milliseconds: 360), HapticFeedback.lightImpact);
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
      body: Stack(
        key: _stackKey,
        children: [
          Positioned.fill(child: _scaffoldBody(dark)),
          if (_fly != null) _flyOverlay(),
          if (_turnBanner) _turnBannerOverlay(),
          if (_celebrate) Positioned.fill(child: RkCelebration(key: const ValueKey('celebration'), title: '승리!', subtitle: '타일을 모두 내려놓았어요', onDone: () => mounted ? setState(() => _celebrate = false) : null)),
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

  /// 화면 바깥 좌우 여백 (가능한 한 좁게).
  static const double _edge = 2;

  Widget _portrait(double width) {
    // 녹색 판에는 3장짜리 묶음 셋이 한 줄에 들어가도록 타일 크기를 정한다
    final inner = width - 2 * _edge - 2 * 2 - 2 * _tablePad;
    final tableTile = (inner / (3 * (3 + kSetPad) + 0.45)).clamp(20.0, 34.0).floorToDouble();
    final rackTile = width < 500 ? 34.0 : 42.0;
    return Column(
      children: [
        _playerChips(),
        _statusBanner(),
        Expanded(child: _tablePanel(tableTile)),
        _floorPool(height: 0, tileW: 20),
        _bottomPanel(rackTile, width),
      ],
    );
  }

  Widget _landscape() => Row(
        children: [
          Expanded(flex: 5, child: Column(children: [_playerChips(), _statusBanner(), Expanded(child: _tablePanel(34))])),
          Expanded(
            flex: 4,
            child: LayoutBuilder(
              builder: (context, box) => Column(children: [_floorPool(height: 0, tileW: 24), Expanded(child: SingleChildScrollView(child: _bottomPanel(42, box.maxWidth, maxRows: 4)))]),
            ),
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
                Icon(me ? Icons.person_rounded : (c.online ? Icons.wifi_rounded : Icons.smart_toy_rounded), size: 15, color: color),
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
          padding: const EdgeInsets.only(top: 3, left: _edge, right: _edge),
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
    if (c.thinking) return '${_name(s.turn)}이(가) 생각하는 중…';
    if (c.animating) return '${_name(s.turn)}이(가) 타일을 옮기는 중…';
    if (!c.myTurn) return _lastEvent ?? '${_name(s.turn)} 차례';
    return null;
  }

  // ── 타일이 날아가는 연출 (바닥 → 손, 바닥 → 상대) ──

  final GlobalKey _stackKey = GlobalKey();
  final GlobalKey _rackAreaKey = GlobalKey();
  final Map<int, GlobalKey> _tileKeys = {};
  final Map<int, GlobalKey> _floorKeys = {};
  final Map<int, GlobalKey> _chipKeys = {};
  GlobalKey _tileKey(int id) => _tileKeys.putIfAbsent(id, GlobalKey.new);
  GlobalKey _floorKey(int id) => _floorKeys.putIfAbsent(id, GlobalKey.new);
  GlobalKey _chipKey(int seat) => _chipKeys.putIfAbsent(seat, GlobalKey.new);

  /// 날아가는 중인 뒷면 타일 (없으면 null)과 연출 번호.
  _Fly? _fly;
  int _flySerial = 0;

  /// 내가 뽑아서 아직 날아오는 중인 타일 (손에서는 숨겨 둔다).
  int? _hiddenTile;

  /// 상대가 뽑는 타일에 대해 이미 날려 보낸 번호 (같은 타일에 연출을 두 번 시작하지 않으려고).
  int? _flownPick;

  Offset? _globalCenter(GlobalKey? key) {
    final rb = key?.currentContext?.findRenderObject();
    if (rb is! RenderBox || !rb.attached || !rb.hasSize) return null;
    return rb.localToGlobal(rb.size.center(Offset.zero));
  }

  void _startFly({required Offset fromGlobal, required Offset toGlobal, required double width, required Duration duration, VoidCallback? onEnd}) {
    final stack = _stackKey.currentContext?.findRenderObject();
    if (stack is! RenderBox || !mounted) {
      onEnd?.call();
      return;
    }
    setState(() {
      _fly = _Fly(
        from: stack.globalToLocal(fromGlobal),
        to: stack.globalToLocal(toGlobal),
        width: width,
        duration: duration,
        serial: ++_flySerial,
        onEnd: onEnd,
      );
    });
  }

  /// 날아가는 타일 한 장: 바닥에서 도착 자리까지 살짝 위로 휘어서 날아간다.
  Widget _flyOverlay() {
    final f = _fly!;
    return TweenAnimationBuilder<double>(
      key: ValueKey('fly${f.serial}'),
      tween: Tween(begin: 0, end: 1),
      duration: f.duration,
      curve: Curves.easeInOutCubic,
      onEnd: () {
        if (!mounted) return;
        setState(() {
          if (_fly?.serial == f.serial) _fly = null;
        });
        f.onEnd?.call();
      },
      builder: (context, t, _) {
        final pos = Offset.lerp(f.from, f.to, t)! - Offset(0, sin(pi * t) * 36);
        final w = f.width * (1 + 0.35 * sin(pi * t));
        return Positioned(
          key: const ValueKey('fly'),
          left: pos.dx - w / 2,
          top: pos.dy - w * 1.35 / 2,
          child: IgnorePointer(child: RkTileBack(width: w, glow: true)),
        );
      },
    );
  }

  /// 상대가 바닥에서 타일을 고르면, 그 타일이 상대 표시 쪽으로 날아간다.
  void _maybeFlyOpponentPick() {
    final pick = c.opponentPick;
    if (pick == null) {
      _flownPick = null;
      return;
    }
    if (_flownPick == pick) return;
    _flownPick = pick;
    final seat = c.turn;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final from = _globalCenter(_floorKeys[pick]);
      final to = _globalCenter(_chipKeys[seat]);
      if (from == null || to == null) return;
      _startFly(fromGlobal: from, toGlobal: to, width: 22, duration: c.stepDelay * 1.1);
    });
  }

  /// 끌고 있는 타일들이 지금 놓이면 붙게 될 묶음 (없으면 null). 놓기 전에 미리 강조해서 보여 준다.
  List<int>? _hoverTarget;

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
        children: [for (final t in shown) RkTile(id: t, width: width)],
      ),
    );
  }

  Widget _draggable({required List<int> data, required double width, required Widget child, Widget? whileDragging}) {
    if (!c.canAct) return child;
    final shown = data.length > 8 ? 8 : data.length;
    final fw = shown * width, fh = width * 1.35;
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
    final single = _draggable(data: _dragged(id), width: width, child: tile);
    if (!fromTable || !c.canAct) return Opacity(opacity: fromTable && _setDrag.contains(id) ? 0.35 : 1, child: single);
    // 판 위 타일: 그냥 끌면 낱개 한 장, 꾹 눌렀다가 끌면 그 묶음 통째로 옮긴다
    final set = c.work.firstWhere((x) => x.contains(id), orElse: () => [id]);
    final setIds = arrangeSet(set);
    final shown = setIds.length > 8 ? 8 : setIds.length;
    final fw = shown * width, fh = width * 1.35;
    return Opacity(
      opacity: _setDrag.contains(id) ? 0.35 : 1,
      child: LongPressDraggable<List<int>>(
        data: setIds,
        delay: const Duration(milliseconds: 350),
        dragAnchorStrategy: (d, ctx, pos) => Offset(fw / 2, fh / 2),
        feedback: _dragFeedback(setIds, width),
        childWhenDragging: const SizedBox.shrink(),
        onDragStarted: () => setState(() => _setDrag = setIds.toSet()),
        onDragEnd: (_) => setState(() => _setDrag = {}),
        child: single,
      ),
    );
  }

  /// 묶음 통째로 끌고 있는 동안 그 묶음의 타일들 (흐리게 보인다).
  Set<int> _setDrag = {};

  // ── 녹색 판 ──

  static const double _tablePad = 3;

  final GlobalKey _canvasKey = GlobalKey();

  /// 녹색 판: 묶음을 어디에나 놓을 수 있는 넓은 판. 타일을 끌어다 놓으면 근처 묶음에 자석처럼 붙고, 멀면 그 자리에 새 묶음이 된다.
  /// 판 위 타일을 꾹 눌렀다가 끌면 묶음 통째로 옮긴다. 상대의 수는 타일이 한 장씩 날아와 놓이는 모습으로 보인다.
  Widget _tablePanel(double tileW) {
    final tileH = tileW * 1.35;
    final ux = tileW, uy = tileH + 8; // 묶음 안의 타일은 딱 붙인다
    const pad = _tablePad;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(_edge, 6, _edge, 3),
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
                final hover = identical(_hoverTarget, set);
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
                        // 평소에는 묶음 틀을 그리지 않는다 (타일만 보인다). 붙을 묶음(끌 때)과 올바르지 않은 묶음만 테두리로 알려 준다.
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: hover ? const Color(0xFFFFE08A) : (bad ? const Color(0xFFE9B08A) : Colors.transparent),
                          width: hover ? 3 : 2,
                        ),
                      ),
                    ),
                  ),
                ));
                for (var k = 0; k < ids.length; k++) {
                  final id = ids[k];
                  final dest = Offset(left + kSetPad / 2 * ux + (k % perRow) * ux, top + 3 + (k ~/ perRow) * uy);
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
              Offset? unitsOf(Offset globalTopLeft) {
                final rb = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
                if (rb == null) return null;
                final local = rb.globalToLocal(globalTopLeft);
                return Offset((local.dx - pad) / ux, (local.dy - 3) / uy);
              }

              void preview(List<int>? target) {
                if (identical(_hoverTarget, target)) return;
                setState(() => _hoverTarget = target);
              }

              return DragTarget<List<int>>(
                onWillAcceptWithDetails: (_) => c.canAct,
                onMove: (d) {
                  final u = unitsOf(d.offset);
                  preview(u == null ? null : c.dropTargetFor(d.data, u));
                },
                onLeave: (_) => preview(null),
                onAcceptWithDetails: (d) {
                  final u = unitsOf(d.offset);
                  preview(null);
                  if (u != null) c.dropTiles(d.data, u);
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
        final rowH = tileH + 8;
        return Container(
          height: rowH + 10,
          margin: const EdgeInsets.fromLTRB(_edge, 2, _edge, 2),
          padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
          decoration: BoxDecoration(
            color: const Color(0xFF6B4A2E).withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF4A3220).withValues(alpha: 0.7), width: 1.5),
          ),
          // 바닥 n장 + 엎어 둔 타일들을 한 줄에 (타일이 많으면 겹쳐 놓고, 그래도 넘치면 옆으로 밀어서 본다)
          child: Row(
            children: [
              Icon(Icons.layers_rounded, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text('바닥 ${pool.length}장', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
              const SizedBox(width: 10),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final n = pool.length;
                    const minStep = 11.0;
                    final fit = n <= 1 ? tileW + 3 : (box.maxWidth - tileW - 4) / (n - 1);
                    final step = fit.clamp(minStep, tileW + 3).toDouble();
                    final width = n == 0 ? box.maxWidth : (n - 1) * step + tileW + 4;
                    final children = <Widget>[];
                    for (var i = 0; i < n; i++) {
                      var h = (pool[i] * 2654435761 + 40503) & 0x7fffffff;
                      h ^= h >> 13;
                      h = (h * 1274126177) & 0x7fffffff;
                      final dy = ((h & 1023) / 1023) * 4, ang = (((h >> 20) & 63) - 32) / 260;
                      children.add(Positioned(
                        key: ValueKey('floor${pool[i]}'),
                        left: i * step,
                        top: 1 + dy,
                        // 상대가 고른 타일은 상대 쪽으로 날아가니 바닥에서는 보이지 않게 한다
                        child: Opacity(
                          opacity: pool[i] == c.opponentPick ? 0 : 1,
                          child: Transform.rotate(
                            angle: ang,
                            child: KeyedSubtree(
                              key: _floorKey(pool[i]),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: canPick ? () => _pickFloor(i) : null,
                                child: RkTileBack(width: tileW, active: canPick),
                              ),
                            ),
                          ),
                        ),
                      ));
                    }
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(width: max(width, box.maxWidth), height: rowH, child: Stack(clipBehavior: Clip.none, children: children)),
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

  /// 끝내기: 안 되면 이유를 짧은 알림으로 보여 준다 (화면 자리를 쓰지 않으려고 글을 따로 두지 않는다).
  void _endTurn() {
    if (c.endTurn()) return;
    final msg = c.notice;
    if (msg == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(milliseconds: 2200), behavior: SnackBarBehavior.floating));
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
    final id = c.state.pool[index];
    final from = _globalCenter(_floorKeys[id]);
    c.draw(index: index);
    final drawn = c.lastDrawn;
    if (!c.animate || drawn == null || from == null) return;
    // 뽑은 타일이 바닥에서 내 손으로 날아온다 (도착할 때까지 손의 그 타일은 숨겨 둔다)
    setState(() => _hiddenTile = drawn);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final to = _globalCenter(_tileKeys[drawn]);
      if (!mounted) return;
      if (to == null) {
        setState(() => _hiddenTile = null);
        return;
      }
      _startFly(fromGlobal: from, toGlobal: to, width: 22, duration: const Duration(milliseconds: 650), onEnd: () {
        if (mounted) setState(() => _hiddenTile = null);
      });
    });
  }

  // ── 내 손 + 단추 ──

  Widget _bottomPanel(double tileWidth, double width, {int maxRows = 2}) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _rack(tileWidth, width, maxRows),
            if (c.isOver) _resultPanel() else _actions(),
          ],
        );
      },
    );
  }

  /// 손 타일을 늘어놓는 계획: 가로로 딱 붙여 한 줄, 한 줄이 넘치면 [maxRows]줄까지, 그래도 넘치면 그 줄 안에서 겹쳐 놓는다.
  /// 타일이 한 줄에 들어갈 만큼 줄면 저절로 한 줄로 줄어들어 자리를 녹색 판에 내준다.
  ({int rows, int perRow, double step}) _rackPlan(int n, double innerW, double tw, int maxRows) {
    final fit = max(1, (innerW / tw).floor());
    if (n <= fit) return (rows: 1, perRow: max(1, n), step: tw);
    if (n <= fit * maxRows) return (rows: (n / fit).ceil(), perRow: fit, step: tw);
    final perRow = (n / maxRows).ceil();
    return (rows: maxRows, perRow: perRow, step: perRow <= 1 ? tw : (innerW - tw) / (perRow - 1));
  }

  /// 내 손: 타일을 끌어서 마음대로 순서를 바꿀 수 있다 (다른 타일 앞에 놓으면 그 앞에 끼고, 빈 곳에 놓으면 맨 뒤로 간다).
  /// 위의 정렬 단추는 한 번 색/숫자 순서로 가지런히 늘어놓아 주는 단추일 뿐이다.
  Widget _rack(double tileWidth, double width, int maxRows) {
    final tiles = c.rackTiles;
    const pad = 4.0, border = 2.0;
    final innerW = width - 2 * (_edge + pad + border);
    final plan = _rackPlan(tiles.length, innerW, tileWidth, maxRows);
    final th = tileWidth * 1.35, rowH = th + 3, lift = 6.0;
    final bodyH = lift + plan.rows * rowH;
    return DragTarget<List<int>>(
      onWillAcceptWithDetails: (d) => c.canAct,
      onAcceptWithDetails: (d) => c.moveInHand(d.data),
      builder: (context, candidate, _) => Container(
        key: _rackAreaKey,
        margin: const EdgeInsets.fromLTRB(_edge, 3, _edge, 3),
        padding: const EdgeInsets.fromLTRB(pad, 3, pad, 3),
        decoration: BoxDecoration(
          color: (candidate.isNotEmpty ? const Color(0xFFCFA668) : const Color(0xFFC79A5B)).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kRkWood.withValues(alpha: 0.7), width: border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('내 타일 ${tiles.length}장', style: const TextStyle(fontWeight: FontWeight.w800)),
                const Spacer(),
                _sortButton('색 정렬', () => c.sortHand(byColor: true)),
                const SizedBox(width: 6),
                _sortButton('숫자 정렬', () => c.sortHand(byColor: false)),
              ],
            ),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: c.canAct && c.selected.isNotEmpty ? () => c.moveInHand(c.selected.toList()) : null,
              child: SizedBox(
                height: bodyH,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var i = 0; i < tiles.length; i++)
                      Positioned(
                        key: ValueKey('slot${tiles[i]}'),
                        left: (i % plan.perRow) * plan.step,
                        top: lift + (i ~/ plan.perRow) * rowH,
                        child: DragTarget<List<int>>(
                          onWillAcceptWithDetails: (d) => c.canAct && !d.data.contains(tiles[i]),
                          onAcceptWithDetails: (d) => c.moveInHand(d.data, beforeId: tiles[i]),
                          builder: (context, cand, _) => Stack(
                            clipBehavior: Clip.none,
                            children: [
                              // 방금 뽑은 타일은 바닥에서 날아오는 동안 숨겨 둔다
                              Opacity(
                                key: ValueKey('hand${tiles[i]}'),
                                opacity: tiles[i] == _hiddenTile ? 0 : 1,
                                child: KeyedSubtree(key: _tileKey(tiles[i]), child: _tile(tiles[i], tileWidth)),
                              ),
                              if (cand.isNotEmpty) Positioned(left: -2, top: 0, bottom: 0, width: 3, child: ColoredBox(color: kRkWood.withValues(alpha: 0.9))),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sortButton(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kRkWood.withValues(alpha: 0.6)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kRkWood)),
      ),
    );
  }

  /// 맨 아래 단추들: 글자가 두 줄로 꺾여 자리를 먹지 않도록 아이콘으로만 만들고, 이름은 길게 누르면 뜨는 설명으로 알려 준다.
  Widget _actions() {
    final modified = c.canAct && (c.changed || !_sameAsTable());
    final style = IconButton.styleFrom(
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: Theme.of(context).colorScheme.outline),
      minimumSize: const Size(44, 38),
    );
    Widget icon(IconData data, String tip, VoidCallback? onTap) => IconButton.outlined(style: style, tooltip: tip, onPressed: onTap, icon: Icon(data, size: 22));
    return Padding(
      padding: const EdgeInsets.fromLTRB(_edge, 0, _edge, 3),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (c.canAct && c.selected.isNotEmpty && c.selected.any(c.placed.contains))
            icon(Icons.south_west_rounded, '손으로', () => c.returnToHand(c.selected.toList())),
          icon(Icons.undo_rounded, '되돌리기', c.canUndoStep ? c.undoStep : null),
          icon(Icons.restart_alt_rounded, '처음으로', c.canAct && modified ? c.reset : null),
          icon(Icons.auto_fix_high_rounded, '정리 (묶음은 그대로, 자리만 가지런히)', c.canAct && c.work.isNotEmpty ? c.tidySets : null),
          // 바닥이 비면 뽑을 타일이 없으니 넘기기만 한다 (바닥에 타일이 있으면 그중 한 장을 직접 골라 뽑는다)
          if (c.state.poolCount == 0) icon(Icons.skip_next_rounded, '넘기기', c.canAct ? c.draw : null),
          IconButton.filled(
            tooltip: '끝내기',
            onPressed: c.canAct ? _endTurn : null,
            icon: const Icon(Icons.check_rounded, size: 24),
            style: IconButton.styleFrom(backgroundColor: kRkWood, visualDensity: VisualDensity.compact, minimumSize: const Size(52, 38)),
          ),
          icon(Icons.flag_outlined, '기권', c.canResign ? _resign : null),
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
      margin: const EdgeInsets.fromLTRB(_edge, 0, _edge, 6),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
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

/// 날아가는 타일 한 장의 연출 정보 (화면 좌표).
class _Fly {
  const _Fly({required this.from, required this.to, required this.width, required this.duration, required this.serial, this.onEnd});

  final Offset from, to;
  final double width;
  final Duration duration;
  final int serial;
  final VoidCallback? onEnd;
}
