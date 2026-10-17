import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../core/settings_scope.dart';
import '../../../net/lan_connection.dart';
import '../../../records/records_screen.dart';
import '../core/davinci_ai.dart';
import '../core/davinci_rules.dart';
import '../data/davinci_history.dart';
import '../game/davinci_controller.dart';
import '../tutorial/davinci_tutorial.dart';
import 'davinci_tiles.dart';

/// 다빈치 코드 플레이 화면.
///
/// 내 타일은 모두 보이고, 남의 숨은 타일은 색만 보인다. 상대(CPU 또는 같은 Wi‑Fi의 사람)의 타일을 눌러 고른 뒤 숫자를 맞힌다.
class DavinciScreen extends StatefulWidget {
  const DavinciScreen({
    super.key,
    this.mode = PlayMode.vsCpu,
    this.players = 2,
    this.humanSeat = 0,
    this.level = DvLevel.normal,
    this.seed,
    this.controller,
    this.link,
    this.links,
    this.linkSeats,
    this.names,
  });

  final PlayMode mode;

  /// 앉은 사람 수 (CPU 포함, 2~4).
  final int players;
  final int humanSeat;
  final DvLevel level;

  /// 패를 나눌 씨앗 (같은 Wi‑Fi 대결에서는 모든 기기가 같은 값으로 시작한다).
  final int? seed;

  /// 같은 Wi‑Fi 대결에서 상대 기기와의 연결 (2명 대결에서 하나뿐일 때). 이 화면이 닫을 때 같이 닫는다.
  final LanConnection? link;

  /// 같은 Wi‑Fi 대결에서 이어진 연결들. 방을 만든 쪽(방장)은 손님마다 하나씩, 손님은 방장과의 연결 하나다.
  /// 3~4명이 할 때는 모든 수가 방장을 거쳐 오간다 (방장이 확인하고 다른 손님들에게 전해 준다).
  final List<LanConnection>? links;

  /// 방장일 때: [links]의 각 손님이 앉은 자리. 이게 있으면 이 기기가 방장이다.
  final List<int>? linkSeats;

  /// 같은 Wi‑Fi 대결에서 자리(0번부터)별 이름. 없으면 2명 대결은 상대의 별명을 쓴다.
  final List<String>? names;

  /// (테스트용) 미리 만든 컨트롤러.
  final DavinciController? controller;

  @override
  State<DavinciScreen> createState() => _DavinciScreenState();
}

class _DavinciScreenState extends State<DavinciScreen> {
  late final DavinciController c = widget.controller ??
      DavinciController(mode: widget.mode, players: widget.players, humanSeat: widget.humanSeat, level: widget.level, seed: widget.seed);
  bool _resultHandled = false;

  // ── 같은 Wi‑Fi 대결 ──
  List<LanConnection> get _links => c.online ? (widget.links ?? [if (widget.link != null) widget.link!]) : const [];
  final List<StreamSubscription<Map<String, dynamic>>> _linkSubs = [];

  /// 방장이고 손님이 여럿인가 (그러면 손님이 보낸 수를 확인해서 다른 손님들에게 전해 준다).
  bool get _hub => widget.linkSeats != null && _links.length > 1;

  bool _opponentGone = false;
  bool _leaving = false;

  /// 아직 보내지 않은 "조커 뽑기" 수 (자리를 정하면 다음 수와 함께 보낸다).
  Map<String, dynamic>? _heldMove;

  // ── 타일을 뽑아 오는 연출 (더미 → 뽑은 사람의 줄) ──

  final GlobalKey _stackKey = GlobalKey();
  final Map<int, GlobalKey> _pileKeys = {};
  final Map<int, GlobalKey> _tileKeys = {};
  final Map<int, GlobalKey> _rowKeys = {};
  GlobalKey _pileKey(int color) => _pileKeys.putIfAbsent(color, GlobalKey.new);
  GlobalKey _tileKey(int id) => _tileKeys.putIfAbsent(id, GlobalKey.new);
  GlobalKey _rowKey(int seat) => _rowKeys.putIfAbsent(seat, GlobalKey.new);

  _Fly? _fly;
  int _flySerial = 0;

  /// 날아오는 중이라 줄에서는 아직 안 보여야 하는 타일.
  int? _hiddenTile;

  /// 이미 날려 보낸 상대의 뽑기 연출 (같은 연출에 두 번 시작하지 않으려고).
  DvEffect? _flownEffect;

  Offset? _globalCenter(GlobalKey? key) {
    final rb = key?.currentContext?.findRenderObject();
    if (rb is! RenderBox || !rb.attached || !rb.hasSize) return null;
    return rb.localToGlobal(rb.size.center(Offset.zero));
  }

  /// 뽑은 조커가 자리를 정할 때까지 내 손패 한가운데 떠 있는 곳 (화면 스택 좌표).
  Offset? _hover;
  int? _hoverTile;

  bool get _hovering => _hover != null && _hoverTile != null && c.state.phase == DvPhase.placeJoker && c.turn == c.humanSeat;

  /// [tile]이 더미에서 [seat]의 손패 한가운데로 날아갔다가 자기 자리를 찾아간다. (조커든 아니든 똑같이 움직인다)
  /// 아직 줄에 없는 타일(내가 뽑은 조커)은 한가운데에 떠서 자리를 정하기를 기다린다.
  /// 줄에 이미 들어 있는 타일은 도착할 때까지 숨겨 둔다.
  void _flyDraw({required int? tile, required int seat, required Offset? from, required Duration duration}) {
    if (tile == null || from == null) return;
    final inRow = c.state.rows[seat].contains(tile);
    if (!inRow && seat != c.humanSeat) return; // 남의 줄에 없는 타일은 보여 주지 않는다 (조커는 자리를 정한 뒤에야 보인다)
    if (inRow) _hiddenTile = tile;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final me = seat == c.humanSeat;
      final width = me ? 44.0 : 38.0;
      final row = c.state.rows[seat];
      final rowCenter = _globalCenter(_rowKeys[seat]);
      final mid = row.isEmpty ? null : _globalCenter(_tileKeys[row[row.length ~/ 2]]);
      final center = rowCenter == null ? null : Offset(rowCenter.dx, (mid?.dy ?? rowCenter.dy) - width * 0.7);
      final to = inRow ? _globalCenter(_tileKeys[tile]) : null;
      final stack = _stackKey.currentContext?.findRenderObject();
      void arrive() {
        if (mounted && _hiddenTile == tile) setState(() => _hiddenTile = null);
      }

      if (center == null || stack is! RenderBox || (inRow && to == null)) {
        arrive();
        return;
      }
      setState(() {
        _fly = _Fly(
          from: stack.globalToLocal(from),
          via: stack.globalToLocal(center),
          to: to == null ? null : stack.globalToLocal(to),
          tile: tile,
          faceUp: me,
          width: width,
          duration: inRow ? duration : duration * 0.55,
          serial: ++_flySerial,
          onEnd: arrive,
        );
      });
    });
  }

  /// 상대(CPU·다른 기기)가 뽑으면 그 더미에서 상대 손패 한가운데로, 그리고 제 자리로 타일이 날아간다.
  void _maybeFlyOpponentDraw() {
    final e = c.effect;
    if (e == null || e.kind != 0 || identical(e, _flownEffect)) return;
    _flownEffect = e;
    _flyDraw(tile: e.tile, seat: e.actor, from: _globalCenter(_pileKeys[e.number ?? 0]), duration: c.cpuStepDelay * 1.1);
  }

  Widget _flyOverlay() {
    final f = _fly!;
    return TweenAnimationBuilder<double>(
      key: ValueKey('fly${f.serial}'),
      tween: Tween(begin: 0, end: 1),
      duration: f.duration,
      onEnd: () {
        if (!mounted) return;
        setState(() {
          if (_fly?.serial == f.serial) {
            _fly = null;
            if (f.to == null && f.via != null) {
              _hover = f.via;
              _hoverTile = f.tile;
            }
          }
        });
        f.onEnd();
      },
      builder: (context, t, _) {
        final p = f.at(t);
        final w = f.width * (1 + 0.3 * p.pop);
        return Positioned(
          key: const ValueKey('fly'),
          left: p.pos.dx - w / 2,
          top: p.pos.dy - p.lift - w * 1.4 / 2,
          child: IgnorePointer(child: DvTile(id: f.tile, width: w, faceUp: f.faceUp)),
        );
      },
    );
  }

  /// 내가 뽑은 조커가 손패 한가운데 떠서 자리를 기다린다.
  Widget _hoverOverlay() {
    const w = 44.0;
    return Positioned(
      key: const ValueKey('hover'),
      left: _hover!.dx - w / 2,
      top: _hover!.dy - w * 1.4 / 2,
      child: IgnorePointer(child: DvTile(id: _hoverTile!, width: w, faceUp: true)),
    );
  }

  /// 내가 더미에서 뽑는다 (뽑은 타일이 더미에서 내 손패 한가운데로 날아온 뒤 자리를 찾아간다. 조커는 자리를 정할 때까지 떠 있다).
  void _drawFromPile(int color) {
    final from = _globalCenter(_pileKeys[color]);
    if (!c.draw(color) || !c.animate) return;
    _flyDraw(tile: c.state.pendingJoker ?? c.state.drawn, seat: c.humanSeat, from: from, duration: const Duration(milliseconds: 1100));
    if (_hiddenTile != null) setState(() {});
  }

  /// 뽑은 조커를 [pos]번째 칸에 놓는다 (떠 있던 조커가 그 자리로 날아간다).
  void _placeJoker(int pos) {
    final tile = c.state.pendingJoker;
    final from = _hover;
    if (!c.placeJoker(pos)) return;
    _hover = null;
    _hoverTile = null;
    if (!c.animate || tile == null || from == null) {
      setState(() {});
      return;
    }
    _hiddenTile = tile;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final to = _globalCenter(_tileKeys[tile]);
      final stack = _stackKey.currentContext?.findRenderObject();
      void arrive() {
        if (mounted && _hiddenTile == tile) setState(() => _hiddenTile = null);
      }

      if (to == null || stack is! RenderBox) {
        arrive();
        return;
      }
      setState(() {
        _fly = _Fly(from: from, to: stack.globalToLocal(to), tile: tile, faceUp: true, width: 44, duration: const Duration(milliseconds: 500), serial: ++_flySerial, onEnd: arrive);
      });
    });
  }

  /// "한 판 더"를 누른 자리들 (나 포함). 모두 누르면 새 판이 시작된다.
  final Set<int> _againSeats = {};
  bool get _rematchAsked => _againSeats.contains(c.humanSeat);
  bool get _rematchOffered => _againSeats.any((s) => s != c.humanSeat);

  @override
  void initState() {
    super.initState();
    c.onFeedback = _feedback;
    c.addListener(_onChanged);
    final links = _links;
    if (links.isNotEmpty) {
      c.onLocalMove = (move) {
        final msg = {'t': 'move', 'i': c.moveCount - 1, 'mv': move};
        // 조커를 뽑은 수는 자리를 정할 때까지 보내지 않는다. (뽑자마자 상대 화면에 보이면 조커를 뽑은 걸 들킨다)
        if (move[0] == 0 && c.state.phase == DvPhase.placeJoker) {
          _heldMove = msg;
          return;
        }
        final held = _heldMove;
        _heldMove = null;
        if (held != null) _sendAll(held);
        _sendAll(msg);
      };
      for (var i = 0; i < links.length; i++) {
        _linkSubs.add(links[i].messages.listen((m) => _onNet(i, m)));
        links[i].closed.then((_) => _onLinkClosed());
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
  }

  @override
  void dispose() {
    _leaving = true;
    for (final s in _linkSubs) {
      s.cancel();
    }
    for (final link in _links) {
      link.send(const {'t': 'bye'});
      link.close();
    }
    c.removeListener(_onChanged);
    c.onFeedback = null;
    c.onLocalMove = null;
    c.dispose();
    super.dispose();
  }

  void _sendAll(Map<String, dynamic> m, {int? except}) {
    final links = _links;
    for (var i = 0; i < links.length; i++) {
      if (i != except) links[i].send(m);
    }
  }

  void _onNet(int from, Map<String, dynamic> m) {
    if (!mounted) return;
    switch (m['t']) {
      case 'move':
        final raw = m['mv'];
        final move = raw is List && raw.every((e) => e is int) ? raw.cast<int>() : null;
        // 방장은 보낸 손님이 지금 차례인 사람인지도 확인한다
        final fromOk = !_hub || widget.linkSeats![from] == c.turn;
        if (move == null || !fromOk || !c.receiveMove(move, index: m['i'] as int?)) {
          _desync();
        } else if (_hub) {
          _sendAll(m, except: from);
        }
      case 'resign':
        c.opponentResigned();
      case 'again':
        final seat = _hub ? widget.linkSeats![from] : (m['seat'] is int ? m['seat'] as int : (c.players == 2 ? 1 - c.humanSeat : null));
        if (seat == null || seat < 0 || seat >= c.players) return;
        setState(() => _againSeats.add(seat));
        if (_hub) _sendAll({'t': 'again', 'seat': seat}, except: from);
        _checkRematch();
      case 'bye':
        _onLinkClosed();
    }
  }

  Future<void> _desync() async {
    if (_opponentGone || _leaving) return;
    _opponentGone = true;
    for (final link in _links) {
      await link.close();
    }
    if (!mounted) return;
    await _notice('판이 서로 어긋났어요', '기기들의 판이 달라져서 여기서 끝낼게요. 다시 방을 만들어 시작해 주세요.');
    if (mounted) Navigator.of(context).pop();
  }

  void _onLinkClosed() {
    if (!mounted || _leaving || _opponentGone) return;
    setState(() => _opponentGone = true);
    if (c.isOver || c.halted) return;
    _notice('상대와 연결이 끊겼어요', 'Wi‑Fi가 끊겼거나 누군가 나갔어요. 이 판은 기록하지 않아요.').then((_) {
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

  void _requestRematch() {
    if (_rematchAsked || _opponentGone) return;
    setState(() => _againSeats.add(c.humanSeat));
    _sendAll({'t': 'again', 'seat': c.humanSeat});
    _checkRematch();
  }

  void _checkRematch() {
    if (_againSeats.length >= c.players) {
      setState(_againSeats.clear);
      _heldMove = null;
      _hover = null;
      _hoverTile = null;
      _resultHandled = false;
      c.restart();
    }
  }

  Future<void> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('판에서 나갈까요?'),
        content: const Text('나가면 연결이 끊기고, 이 판은 기록되지 않아요.\n(이기고 지는 걸 기록하려면 "기권"을 눌러 주세요)', textAlign: TextAlign.center),
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
      case 'draw':
        HapticFeedback.selectionClick();
      case 'right':
        HapticFeedback.mediumImpact();
      case 'wrong':
        HapticFeedback.vibrate();
      case 'bad':
        HapticFeedback.vibrate();
      case 'win':
        HapticFeedback.heavyImpact();
    }
  }

  Future<void> _record({required int winner, bool resigned = false}) {
    return DvHistory.add(DvRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: c.vsCpu,
      online: c.online,
      players: c.players,
      winner: winner,
      human: c.humanSeat,
      turns: c.state.turnCount,
      level: c.vsCpu ? c.level : null,
      resigned: resigned,
    ));
  }

  void _onChanged() {
    _maybeFlyOpponentDraw();
    if (c.isOver && !_resultHandled) {
      _resultHandled = true;
      _record(winner: c.state.winner!);
    } else if (c.halted && !_resultHandled && c.resignWinner != null) {
      // 상대가 기권해서 끝났을 때 (내가 기권한 경우는 [_resign]이 기록한다)
      if (c.resignWinner == c.humanSeat) {
        _resultHandled = true;
        _record(winner: c.humanSeat, resigned: true);
      }
    } else if (!c.isOver && !c.halted) {
      _resultHandled = false;
    }
  }

  String _name(int seat) {
    if (seat == c.humanSeat) return '나';
    final given = widget.names;
    if (c.online && given != null && seat < given.length) return given[seat];
    if (c.online) return _links.isEmpty ? '상대' : _links.first.peerNick;
    return 'CPU ${seat < c.humanSeat ? seat + 1 : seat}';
  }

  Future<void> _resign() async {
    if (!c.canResign) return;
    final ok = await confirmGiveUp(context, detail: c.vsCpu ? 'CPU의 승리로 기록돼요.' : '상대의 승리로 기록돼요.', retry: false, verb: '기권');
    if (!ok || !mounted || !c.resign()) return;
    _resultHandled = true;
    _sendAll(const {'t': 'resign'});
    await _record(winner: c.resignWinner!, resigned: true);
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: c.vsCpu ? 'CPU ${c.level.label} · ${c.state.turnCount}차례' : '${c.state.turnCount}차례',
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
    if (c.showOver) {
      final w = s.winner!;
      return w == c.humanSeat ? '이겼어요! 🎉' : '${_name(w)}이(가) 이겼어요';
    }
    if (c.halted) {
      final w = c.resignWinner;
      return w == c.humanSeat ? '상대가 기권해서 이겼어요! 🎉' : '기권했어요';
    }
    if (_opponentGone) return '상대와 연결이 끊겼어요';
    if (!c.humanCanAct) {
      final e = c.effect;
      if (e != null && e.actor != c.humanSeat) {
        if (e.kind == 2) return '${_name(e.actor)}이(가) ${e.stage == DvEffectStage.pick ? '타일을 고르는 중…' : '추측하는 중…'}';
        return '${_name(e.actor)}이(가) 두는 중…';
      }
      return c.thinking && c.turn != c.humanSeat ? '${_name(s.turn)}이(가) 생각하는 중…' : '${_name(s.turn)} 차례';
    }
    return switch (s.phase) {
      DvPhase.draw => '내 차례 · 더미에서 타일을 한 장 뽑아요',
      DvPhase.placeJoker => '조커를 뽑았어요 · 내 줄에서 놓을 자리를 골라요',
      DvPhase.guess => c.selSeat < 0 ? '맞힐 상대 타일을 눌러 고르세요' : '고른 타일의 숫자를 골라요',
      DvPhase.decide => c.selSeat < 0 ? '맞혔어요! 계속 맞힐 타일을 고르거나, 멈춰요' : '고른 타일의 숫자를 골라요',
      DvPhase.reveal => '틀렸어요! 내 숨은 타일 하나를 눌러 공개해요',
    };
  }

  /// 가장 최근 맞히기를 한 줄로.
  String? get _lastEvent {
    final g = c.state.lastGuess;
    if (g == null || c.isOver || c.effectsPending) return null;
    if (c.effect != null) return null; // (연출 중에는 결과를 미리 알려 주지 않는다)
    final num = g.number == kJokerGuess ? '조커' : '${g.number}';
    final target = g.target == c.humanSeat ? '내' : '${_name(g.target)}의';
    return '${_name(g.guesser)}: $target ${g.index + 1}번째 타일을 "$num"(이)라고 추측 → ${g.correct ? '맞혔어요!' : '틀렸어요'}';
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
          if (_fly == null && _hovering) _hoverOverlay(),
          if (_fly != null) _flyOverlay(),
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
            colors: dark ? const [Color(0xFF1F262B), Color(0xFF171C20)] : const [Color(0xFFE7ECEF), Color(0xFFD3DBE0)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: ListenableBuilder(
                      listenable: c,
                      builder: (context, _) => SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _statusBanner(),
                            const SizedBox(height: 8),
                            for (var seat = 0; seat < c.players; seat++)
                              if (seat != c.humanSeat) ...[_playerRow(seat), const SizedBox(height: 8)],
                            if (!c.showOver && !c.halted) ...[_pilesStrip(), const SizedBox(height: 8)],
                            _actionPanel(),
                            const SizedBox(height: 8),
                            _playerRow(c.humanSeat),
                            const SizedBox(height: 8),
                            if (c.showOver) _resultPanel() else _bottomBar(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(tooltip: '뒤로', icon: const Icon(Icons.arrow_back_rounded), onPressed: () => Navigator.of(context).maybePop()),
          Expanded(
            child: Text('다빈치 코드', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          IconButton(tooltip: '내 기록', icon: const Icon(Icons.emoji_events_rounded), onPressed: () => openRecords(context, game: 'davinci_code')),
          IconButton(tooltip: '규칙', icon: const Icon(Icons.help_outline_rounded), onPressed: () => showDavinciRules(context)),
        ],
      ),
    );
  }

  /// 위쪽 안내 띠. 글이 한 줄이든 두 줄이든 높이가 늘 같다 (높이가 바뀌면 아래 화면 전체가 출렁여서 어지럽다).
  Widget _statusBanner() {
    final color = c.showOver || c.halted ? Colors.grey : (c.turn == c.humanSeat ? kDavinciColor : const Color(0xFF6B7A85));
    final event = _lastEvent;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_status, textAlign: TextAlign.center, maxLines: 1, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
          ),
          if (event != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(event, textAlign: TextAlign.center, maxLines: 1, style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7))),
              ),
            ),
        ],
      ),
    );
  }

  // ── 타일 줄 ──

  /// 한 사람의 타일 줄. 남의 줄은 숨은 타일이 색만 보이고, 내 줄은 전부 보인다.
  Widget _playerRow(int seat) {
    final s = c.state;
    final row = s.rows[seat];
    final me = seat == c.humanSeat;
    final active = !c.showOver && !c.halted && c.turn == seat;
    // 탈락은 ○ / ✕ 연출이 다 끝난 뒤에 보인다
    final out = s.isOut(seat) && !c.outPendingSeats.contains(seat);
    final scheme = Theme.of(context).colorScheme;
    final canPick = c.humanCanAct && !me && !out && (s.phase == DvPhase.guess || s.phase == DvPhase.decide);
    final placing = me && c.humanCanAct && s.phase == DvPhase.placeJoker;
    final revealing = me && c.humanCanAct && s.phase == DvPhase.reveal;
    final e = c.effect;
    final override = c.hiddenOverride;
    final liftedTile = c.liftedTile;

    return LayoutBuilder(
      builder: (context, box) {
        final n = row.length + (placing ? 1 : 0);
        final tw = (me ? 44.0 : 38.0).clamp(20.0, (box.maxWidth - 34) / max(1, n) - 4);
        Widget slot(int pos) => GestureDetector(
              key: ValueKey('slot$pos'),
              behavior: HitTestBehavior.opaque,
              onTap: () => _placeJoker(pos),
              child: Container(
                width: tw * 0.5,
                height: tw * 1.4,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: const Color(0xFF5B8DEF).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF5B8DEF), width: 1.6),
                ),
                child: const Icon(Icons.add_rounded, size: 16, color: Color(0xFF5B8DEF)),
              ),
            );
        final tiles = <Widget>[];
        for (var i = 0; i < row.length; i++) {
          if (placing) tiles.add(slot(i));
          final t = row[i];
          // 공개된 타일은 눕혀서 보이고, 숨은 타일은 세워서 둔다. (상대의 수를 보여 주는 동안에는 아직 숨은 것으로 보여야 하는 타일이 있다)
          final revealed = s.isRevealed(t) && !override.contains(t);
          final isEffectTile = e != null && e.kind == 2 && e.tile == t && e.target == seat;
          tiles.add(Opacity(
            opacity: t == _hiddenTile ? 0 : 1, // 더미에서 날아오는 동안은 줄에서 숨겨 둔다
            child: Padding(
            key: _tileKey(t),
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: DvTile(
              key: ValueKey('tile-$seat-$i'),
              id: t,
              width: tw,
              faceUp: me || revealed,
              lying: revealed,
              lifted: isEffectTile && liftedTile == t,
              selected: c.selSeat == seat && c.selIndex == i,
              mark: isEffectTile && e.stage == DvEffectStage.result ? e.correct : null,
              fresh: c.drawnBy[seat] == t && !revealed && !s.isOver, // 가장 최근에 가져온 타일 (내 것도, 상대 것도)
              onTap: canPick && !revealed
                  ? () => c.selectTarget(seat, i)
                  : (revealing && !revealed ? () => c.revealOwn(i) : null),
            ),
          )));
        }
        if (placing) tiles.add(slot(row.length));

        return Container(
          key: _rowKey(seat),
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          decoration: BoxDecoration(
            color: (active ? kDavinciColor : Colors.white).withValues(alpha: active ? 0.1 : 0.45),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? kDavinciColor : scheme.outlineVariant, width: 2.2), // (두께가 바뀌면 줄 높이가 움찔한다)
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 32, // 말풍선이 떠도 줄 높이가 변하지 않게 늘 같은 높이
                child: Row(
                children: [
                  Icon(me ? Icons.person_rounded : (c.online ? Icons.wifi_rounded : Icons.smart_toy_rounded), size: 18, color: kDavinciColor),
                  const SizedBox(width: 5),
                  Text(_name(seat), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  if (out)
                    Text('탈락', style: TextStyle(fontWeight: FontWeight.w800, color: scheme.error))
                  else if (active)
                    const Text('차례', style: TextStyle(fontWeight: FontWeight.w800, color: kDavinciColor)),
                  // 이 사람이 지금 하는 일: 말풍선 ("7?" → 맞으면 ○, 틀리면 ✕)
                  // (타일을 고르는 동안에는 아직 말하지 않는다: 고른 다음에 숫자를 말한다)
                  if (e != null && e.actor == seat && !(e.kind == 2 && e.stage == DvEffectStage.pick)) ...[
                    const SizedBox(width: 8),
                    DvBubble(key: ValueKey('bubble$seat'), text: _bubbleText(e), result: e.kind == 2 && e.stage == DvEffectStage.result ? e.correct : null),
                  ],
                  const Spacer(),
                  if (me) Text('숨은 타일 ${s.hiddenCount(seat)}장', style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.65))),
                ],
                ),
              ),
              const SizedBox(height: 4),
              Opacity(
                opacity: out ? 0.6 : 1,
                // 떠오르는 타일과 ○/✕ 표시가 들어갈 위쪽 여유, 눕힌 타일도 바닥에 맞춰 놓이게 아래 정렬
                child: Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: tw * 1.4 + 4),
                    child: Wrap(runSpacing: 10, crossAxisAlignment: WrapCrossAlignment.end, children: tiles),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// 말풍선에 쓸 글: 맞히기는 "7?", 그 밖의 수는 짧은 말.
  String _bubbleText(DvEffect e) => switch (e.kind) {
        0 => '${e.number == 0 ? '검정' : '흰색'} 뽑기',
        // 남이 놓는 타일이 조커인지는 알 수 없어야 한다 (그래서 "조커"라고 말하지 않는다)
        1 => e.actor == c.humanSeat ? '조커 놓기' : '타일 놓기',
        2 => e.number == kJokerGuess ? '‑ ?' : '${e.number} ?',
        3 => '멈춤',
        _ => '타일 공개',
      };

  // ── 지금 할 일 ──

  Widget _actionPanel() {
    final s = c.state;
    if (c.isOver || c.halted || !c.humanCanAct) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    Widget box(Widget child) => Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(16), border: Border.all(color: scheme.outlineVariant)),
          child: child,
        );

    switch (s.phase) {
      case DvPhase.draw:
        return const SizedBox.shrink(); // 위의 더미를 눌러 뽑는다
      case DvPhase.placeJoker:
      case DvPhase.reveal:
        return const SizedBox.shrink(); // 내 줄에서 직접 고른다 (자리 칸 / 숨은 타일)
      case DvPhase.guess:
      case DvPhase.decide:
        final picking = c.selSeat >= 0;
        return box(Column(
          children: [
            if (picking) _numberPicker() else Text(s.phase == DvPhase.decide ? '계속 맞히려면 상대 타일을 고르고, 아니면 멈춰요' : '위에서 맞힐 상대 타일을 눌러요', style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75))),
            if (s.phase == DvPhase.decide) ...[
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: c.stop,
                icon: const Icon(Icons.pan_tool_alt_rounded, size: 18),
                label: const Text('멈추기 (내 타일은 그대로 숨겨요)'),
                style: FilledButton.styleFrom(backgroundColor: kDavinciColor),
              ),
            ],
          ],
        ));
    }
  }

  /// 검정·흰색 더미 (언제나 보인다). 내가 뽑을 차례면 눌러서 뽑고, 누가 뽑든 타일이 여기서 날아간다.
  Widget _pilesStrip() {
    final canDraw = c.humanCanAct && c.state.phase == DvPhase.draw;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: (canDraw ? kDavinciColor : Colors.white).withValues(alpha: canDraw ? 0.12 : 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: canDraw ? kDavinciColor : scheme.outlineVariant.withValues(alpha: 0.6), width: 2), // (두께가 바뀌면 화면이 움찔한다)
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final color in const [0, 1]) ...[
            if (color == 1) const SizedBox(width: 28),
            _pileButton(color, canDraw),
          ],
          if (canDraw) ...[
            const SizedBox(width: 18),
            const Flexible(child: Text('뽑을 더미를\n눌러요', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
          ],
        ],
      ),
    );
  }

  Widget _pileButton(int color, bool canDraw) {
    final count = c.state.poolOf(color);
    return GestureDetector(
      key: ValueKey('pile$color'),
      behavior: HitTestBehavior.opaque,
      onTap: canDraw && count > 0 ? () => _drawFromPile(color) : null,
      child: Opacity(
        opacity: count > 0 ? 1 : 0.45,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyedSubtree(key: _pileKey(color), child: DvPile(color: color, count: count, width: 30)),
            const SizedBox(width: 6),
            Text(color == 0 ? '검정' : '흰색', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  /// 고른 타일의 숫자를 고르는 판. 이미 보여서 그 색 타일일 수 없는 숫자는 흐리게 막는다.
  Widget _numberPicker() {
    final s = c.state;
    final tile = s.rows[c.selSeat][c.selIndex];
    final color = dvColor(tile);
    final seen = <int>{...s.revealed, ...s.rows[c.humanSeat]};
    final black = color == 0;
    return Column(
      children: [
        Text('${_name(c.selSeat)}의 ${c.selIndex + 1}번째 ${black ? '검정' : '흰색'} 타일은?', style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var n = 0; n <= kJokerGuess; n++)
              Builder(builder: (context) {
                final known = n == kJokerGuess ? seen.contains(24 + color) : seen.contains(dvTile(color, n));
                return SizedBox(
                  key: ValueKey('num$n'),
                  width: 44,
                  height: 44,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      backgroundColor: black ? const Color(0xFF2A2D32) : const Color(0xFFF6F1E4),
                      foregroundColor: black ? Colors.white : const Color(0xFF2A2D32),
                      disabledBackgroundColor: Colors.grey.withValues(alpha: 0.25),
                      disabledForegroundColor: Colors.grey,
                      side: BorderSide(color: black ? const Color(0xFF5A5F68) : const Color(0xFFBDB29A)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: known ? null : () => c.guess(n),
                    child: Text(n == kJokerGuess ? '‑' : '$n', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                  ),
                );
              }),
          ],
        ),
      ],
    );
  }

  Widget _bottomBar() {
    final compact = OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), visualDensity: VisualDensity.compact);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        if (c.selSeat >= 0 && c.humanCanAct)
          OutlinedButton.icon(style: compact, onPressed: c.clearSelection, icon: const Icon(Icons.close_rounded, size: 18), label: const Text('고름 풀기')),
        if (c.vsCpu)
          OutlinedButton.icon(style: compact, onPressed: () {
            _resultHandled = false;
            c.restart();
          }, icon: const Icon(Icons.refresh_rounded, size: 20), label: const Text('새 판')),
        if (c.vsCpu || c.players == 2)
          OutlinedButton.icon(style: compact, onPressed: c.canResign ? _resign : null, icon: const Icon(Icons.flag_outlined, size: 20), label: const Text('기권')),
      ],
    );
  }

  Widget _resultPanel() {
    final s = c.state;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events_rounded, color: Color(0xFFF2A900)),
              const SizedBox(width: 8),
              Text('${_name(s.winner!)} 승리 · ${s.turnCount}차례', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('메뉴로')),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: c.online
                    ? (_rematchAsked || _opponentGone ? null : _requestRematch)
                    : () {
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
Future<void> showDavinciRules(BuildContext context) {
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
      title: const Text('다빈치 코드 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('타일은 검정·흰색 0~11, 그리고 조커(‑) 두 장이에요. 각자 타일을 받아 숫자가 작은 쪽부터 왼쪽에서 오른쪽으로 늘어놓아요. 같은 숫자는 검정이 먼저예요.'),
            line('내 타일은 나만 볼 수 있고, 남의 타일은 색과 자리만 보여요.'),
            line('내 차례에 검정이나 흰색 더미에서 타일을 한 장 뽑아요 (순서에 맞는 자리에 저절로 끼워져요).'),
            line('그다음 상대의 숨은 타일 하나를 골라 숫자를 맞혀요.'),
            line('맞히면 그 타일이 공개돼요. 계속 맞히거나, 멈추고 차례를 넘길 수 있어요.'),
            line('틀리면 방금 뽑은 내 타일이 공개되고 차례가 넘어가요.'),
            line('조커는 뽑았을 때 내가 놓을 자리를 골라요. 맞힐 때는 "‑"를 골라요.'),
            line('숨은 타일이 모두 공개되면 탈락이에요. 마지막까지 남은 사람이 이겨요.'),
            line('더미가 다 떨어지면 뽑지 않고 바로 맞혀요. 이때 틀리면 내 숨은 타일 하나를 직접 공개해요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            davinciTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}

/// 날아가는 타일 한 장. [from]에서 [via](손패 한가운데)를 거쳐 [to](제 자리)로 간다.
/// [via]가 없으면 곧장 [to]로 가고, [to]가 없으면 [via]에서 멈춰 떠 있는다.
class _Fly {
  _Fly({required this.from, this.via, this.to, required this.tile, required this.faceUp, required this.width, required this.duration, required this.serial, required this.onEnd})
      : assert(via != null || to != null);

  final Offset from;
  final Offset? via, to;
  final int tile;
  final bool faceUp;
  final double width;
  final Duration duration;
  final int serial;
  final VoidCallback onEnd;

  /// 시간 [t](0~1)의 위치와 떠오른 높이, 커진 정도(0~1).
  ({Offset pos, double lift, double pop}) at(double t) {
    final v = via, d = to;
    var a = from, b = (v ?? d)!;
    var u = t, arc = 30.0;
    if (v != null && d != null) {
      // 먼저 한가운데로 (앞 절반), 잠깐 머물렀다가 (조금), 제 자리로 (뒤쪽)
      if (t < 0.5) {
        u = t / 0.5;
      } else if (t < 0.62) {
        return (pos: v, lift: 0, pop: 0);
      } else {
        a = v;
        b = d;
        u = (t - 0.62) / 0.38;
        arc = 12;
      }
    }
    final e = Curves.easeInOutCubic.transform(u.clamp(0.0, 1.0));
    return (pos: Offset.lerp(a, b, e)!, lift: sin(pi * u) * arc, pop: sin(pi * u));
  }
}
