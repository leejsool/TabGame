import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../core/leave_guard.dart';
import '../../../core/win_sound.dart';
import '../../../core/settings_scope.dart';
import '../../../net/lan_connection.dart';
import '../../../records/records_screen.dart';
import '../core/quoridor_ai.dart';
import '../data/quoridor_history.dart';
import '../game/quoridor_controller.dart';
import '../tutorial/quoridor_tutorial.dart';
import 'quoridor_board.dart';
import 'quoridor_wall_stock.dart';

/// 쿼리도 플레이 화면.
class QuoridorScreen extends StatefulWidget {
  const QuoridorScreen({
    super.key,
    this.mode = PlayMode.local2p,
    this.players = 2,
    this.humanSeat = 0,
    this.level = QLevel.normal,
    this.controller,
    this.link,
    this.links,
    this.linkSeats,
    this.names,
    this.cpuSeats,
  });

  final PlayMode mode;

  /// 앉은 사람 수 (2 또는 4, CPU 포함).
  final int players;
  final int humanSeat;
  final QLevel level;

  /// 같은 Wi‑Fi 대결([PlayMode.wifi])에서 상대 기기와의 연결 (2명 대결에서 하나뿐일 때). 이 화면이 닫을 때 같이 닫는다.
  final LanConnection? link;

  /// 같은 Wi‑Fi 대결에서 이어진 연결들. 방을 만든 쪽(방장)은 손님마다 하나씩, 손님은 방장과의 연결 하나다.
  /// 4명이 할 때는 모든 수가 방장을 거쳐 오간다 (방장이 확인하고 다른 손님들에게 전해 준다).
  final List<LanConnection>? links;

  /// 방장일 때: [links]의 각 손님이 앉은 자리. 이게 있으면 이 기기가 방장이다.
  final List<int>? linkSeats;

  /// 같은 Wi‑Fi 대결에서 자리(0번부터)별 이름. 없으면 2명 대결은 상대의 별명을 쓴다.
  final List<String>? names;

  /// 같은 Wi‑Fi 방에서 CPU가 앉은 자리들 (사람 n명 + CPU m명으로 할 때). CPU의 수는 방장 기기가 정해서 알려 준다.
  final List<int>? cpuSeats;

  /// (테스트용) 미리 만든 컨트롤러.
  final QuoridorController? controller;

  @override
  State<QuoridorScreen> createState() => _QuoridorScreenState();
}

class _QuoridorScreenState extends State<QuoridorScreen> {
  late final QuoridorController c = widget.controller ??
      QuoridorController(
        mode: widget.mode,
        players: widget.players,
        humanSeat: widget.humanSeat,
        level: widget.level,
        cpuSeats: widget.mode == PlayMode.wifi ? (widget.cpuSeats ?? const []) : null,
        cpuHost: widget.linkSeats != null, // (방을 연 기기가 CPU의 수를 정한다)
      );
  bool _resultHandled = false;

  /// 한 기기·CPU 대결을 이어하기용으로 보관하는 도우미 (같은 Wi‑Fi 대결은 보관하지 않는다).
  late final GameSaver _saver = GameSaver(gameId: 'quoridor', snapshot: () => c.savable ? c.toJson() : null);
  int _savedAtMove = -1;

  // ── 같은 Wi‑Fi 대결 ──
  List<LanConnection> get _links => c.online ? (widget.links ?? [if (widget.link != null) widget.link!]) : const [];
  final List<StreamSubscription<Map<String, dynamic>>> _linkSubs = [];

  /// 방장인가 (그러면 손님이 보낸 수가 그 손님 차례의 수인지 확인하고, 손님이 여럿이면 다른 손님들에게 전해 준다).
  bool get _hub => widget.linkSeats != null;

  /// [link]번째 연결의 손님이 지금 앉은 자리 (한 판 더 할 때마다 자리가 한 칸씩 돈다).
  int _seatOfLink(int link) => (widget.linkSeats![link] + c.rotation) % c.players;

  bool _opponentGone = false;
  bool _leaving = false;

  /// "한 판 더"를 누른 자리들 (나 포함). 모두 누르면 새 판이 시작된다.
  final Set<int> _againSeats = {};
  bool get _rematchAsked => _againSeats.contains(c.humanSeat);
  bool get _rematchOffered => _againSeats.any((s) => s != c.humanSeat);

  @override
  void initState() {
    super.initState();
    c.onFeedback = _feedback;
    c.addListener(_onChanged);
    if (!c.online) {
      _savedAtMove = c.moveCount;
      _saver.attach();
    }
    final links = _links;
    if (links.isNotEmpty) {
      c.onLocalMove = (move) => _sendAll({'t': 'move', 'i': c.moveCount - 1, 'm': move});
      for (var i = 0; i < links.length; i++) {
        _linkSubs.add(links[i].messages.listen((m) => _onNet(i, m)));
        links[i].closed.then((_) => _onLinkClosed());
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
  }

  @override
  void dispose() {
    _saver.detach();
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

  /// 모든 연결로 (방장이면 모든 손님에게, 손님이면 방장에게) 보낸다. [except]번 연결은 빼고.
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
        // 방장은 보낸 손님이 지금 차례인 사람인지도 확인한다
        final fromOk = !_hub || _seatOfLink(from) == c.turn;
        if (!fromOk || m['m'] is! int || !c.receiveMove(m['m'] as int, index: m['i'] as int?)) {
          _desync();
        } else if (_hub) {
          _sendAll(m, except: from);
        }
      case 'resign':
        _onOpponentResigned();
      case 'again':
        final seat = _hub ? _seatOfLink(from) : (m['seat'] is int ? m['seat'] as int : (c.players == 2 ? 1 - c.humanSeat : null));
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

  Future<void> _onOpponentResigned() async {
    if (c.isOver || c.halted) return;
    c.opponentResigned();
    _resultHandled = true;
    WinSound.play(context); // 이겼을 때 "짜잔"
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
    setState(() => _againSeats.add(c.humanSeat));
    _sendAll({'t': 'again', 'seat': c.humanSeat});
    _checkRematch();
  }

  /// 모든 사람이 한 판 더를 눌렀으면 (자리가 한 칸씩 돌아) 새 판을 시작한다.
  void _checkRematch() {
    if (_againSeats.length >= c.humans) _startRematch();
  }

  void _startRematch() {
    setState(_againSeats.clear);
    _resultHandled = false;
    c.restart(rotate: true);
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
      case 'move':
        HapticFeedback.selectionClick();
      case 'wall':
        HapticFeedback.lightImpact();
      case 'bad':
        HapticFeedback.vibrate();
      case 'win':
        HapticFeedback.heavyImpact();
    }
  }

  Future<void> _record({required int winner, bool resigned = false}) {
    return QuoridorHistory.add(QuoridorRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: c.vsCpu,
      online: c.online,
      players: c.players,
      winner: winner,
      moves: c.moveCount,
      human: c.oneSeat ? c.humanSeat : null,
      level: c.vsCpu ? c.level : null,
      resigned: resigned,
    ));
  }

  void _onChanged() {
    if (c.isOver && !_resultHandled) {
      _resultHandled = true;
      if (!c.oneSeat || c.state.winner == c.humanSeat) WinSound.play(context); // 이겼을 때 "짜잔"
      _record(winner: c.state.winner!);
    } else if (!c.isOver && !c.halted) {
      if (_resultHandled) _saver.rearm(); // 한 판 더: 새 판은 다시 보관할 수 있다
      _resultHandled = false;
    }
    if (!c.online) _autosave();
  }

  /// 수를 둘 때마다 이어하기용으로 보관한다 (끝난 판이면 보관된 것을 지운다).
  void _autosave() {
    if (c.moveCount == 0 && !c.isOver) _saver.rearm(); // 새 판이 시작됐다
    if (c.isOver || c.halted) {
      _saver.finish();
    } else if (c.moveCount != _savedAtMove) {
      _savedAtMove = c.moveCount;
      _saver.save();
    }
  }


  /// 하던 판 도중에 "새 판" 단추를 눌렀다: 하던 판이 사라지니 먼저 묻는다.
  Future<void> _newGameNow() async {
    if (_saver.active && !await confirmNewGame(context)) return;
    if (!mounted) return;
    c.restart();
  }

  /// 플레이어 이름: 한 기기는 "플레이어 N", CPU 대결은 "나/CPU N", Wi‑Fi 대결은 "나/상대 별명".
  String _name(int seat) {
    if (!c.oneSeat) return '플레이어 ${seat + 1}';
    if (seat == c.humanSeat) return '나';
    final given = widget.names;
    // (이름표는 처음 앉은 자리 기준이라, 한 판 더 해서 자리가 돈 만큼 되돌려 찾는다)
    if (c.online && given != null && given.length == c.players) return given[(seat - c.rotation) % c.players];
    if (c.online) return _links.isEmpty ? '상대' : _links.first.peerNick;
    return 'CPU ${seat < c.humanSeat ? seat + 1 : seat}';
  }

  /// 기권한 사람이 [seat]일 때 이긴 것으로 기록할 자리: 2명이면 상대, 4명이면 남은 사람 중 가장 앞선 사람.
  int _winnerWhenResigned(int seat) {
    if (c.players == 2) return 1 - seat;
    var best = -1, bestD = 1 << 20;
    for (var p = 0; p < c.players; p++) {
      if (p == seat) continue;
      final d = c.state.distance(p);
      if (d < bestD) {
        bestD = d;
        best = p;
      }
    }
    return best;
  }

  Future<void> _resign() async {
    if (!c.canResign) return;
    final seat = c.resigningSeat;
    final winner = _winnerWhenResigned(seat);
    final ok = await confirmGiveUp(
      context,
      detail: c.vsCpu
          ? '${_name(winner)}의 승리로 기록돼요.'
          : c.online
              ? '상대의 승리로 기록돼요.'
              : '${_name(seat)}이(가) 기권하고, ${_name(winner)}의 승리로 기록돼요.',
      retry: false,
      verb: '기권',
    );
    if (!ok || !mounted || !c.resign()) return;
    _resultHandled = true;
    _sendAll(const {'t': 'resign'});
    await _record(winner: winner, resigned: true);
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: c.vsCpu ? 'CPU ${c.level.label} · ${c.moveCount}수' : '${_name(seat)} 기권 · ${c.moveCount}수',
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
      c.restart(rotate: c.oneSeat);
    } else {
      Navigator.of(context).pop();
    }
  }

  // ── 안내 글 ──

  String get _status {
    final s = c.state;
    if (c.isOver) {
      final w = s.winner!;
      if (c.oneSeat) return w == c.humanSeat ? '이겼어요! 🎉' : '${_name(w)}이(가) 이겼어요';
      return '${_name(w)} 승리! 🎉';
    }
    if (_opponentGone) return '상대와 연결이 끊겼어요';
    if (c.halted) return _rematchAsked ? '상대가 한 판 더를 받아 주기를 기다리는 중이에요…' : '기권으로 끝난 판이에요';
    if (c.autoPlaying) return '모두 벽을 다 썼어요 · 가장 짧은 길로 저절로 움직여요…';
    if (c.thinking) return '${_name(s.turn)}이(가) 생각하는 중…';
    final mine = !c.oneSeat || s.turn == c.humanSeat;
    final who = c.oneSeat ? (mine ? '내 차례' : '${_name(s.turn)} 차례') : '${_name(s.turn)} 차례';
    if (!mine) return c.online ? '$who · 기다리는 중이에요' : who;
    if (c.wallMode) {
      if (!c.hasWallPick) return '$who · 막대를 판에 끌어다 놓아요';
      return c.canConfirmWall ? '$who · 이 자리에 벽을 세울까요? (체크로 확정)' : '$who · 여기에는 벽을 세울 수 없어요';
    }
    return '$who · 점이 찍힌 칸을 눌러 말을 옮기거나, 막대로 벽을 세워요';
  }

  /// 벽을 못 세우는 이유 (고른 자리가 있을 때).
  String? get _wallProblem {
    if (!c.wallMode || !c.hasWallPick || c.canConfirmWall) return null;
    final s = c.state;
    final o = c.wallOrientPick, r = c.wallRowPick, col = c.wallColPick;
    if (s.wallsLeft[s.turn] <= 0) return '남은 벽이 없어요';
    // 겹침/십자인지, 길이 막히는지 가린다
    final fits = !(o == 0
        ? (s.hWallAt(r, col) || s.vWallAt(r, col) || s.hWallAt(r, col - 1) || s.hWallAt(r, col + 1))
        : (s.vWallAt(r, col) || s.hWallAt(r, col) || s.vWallAt(r - 1, col) || s.vWallAt(r + 1, col)));
    return fits ? '모든 길을 막는 벽은 세울 수 없어요' : '이미 있는 벽과 겹치거나 엇갈려요';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, child) {
        if (!c.online) {
          // 한 기기·CPU 대결: 나가기 전에 저장할지 묻는다
          return SaveLeaveGuard(active: () => _saver.active, onSave: _saver.save, onDiscard: _saver.discard, child: child!);
        }
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
            colors: dark ? const [Color(0xFF2E2128), Color(0xFF241A20)] : const [Color(0xFFF8E9EF), Color(0xFFEBD0DC)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final landscape = box.maxWidth > box.maxHeight * 1.2;
              return Column(
                children: [
                  _topBar(),
                  Expanded(child: landscape ? _landscape() : _portrait()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// 판과, 각자 앞에 쌓인 나무막대 더미. 막대를 판으로 끌어다 놓으면 가장 가까운 격자점에 붙고, 놓아 둔 막대 위의 돌리기·체크 아이콘으로 확정한다.
  /// 더미 자리: 아래 = 0번, 2명이면 위 = 1번, 4명이면 왼쪽 = 1번, 위 = 2번, 오른쪽 = 3번 (말이 시작하는 자리와 같다).
  Widget _boardArea() => Padding(
        padding: const EdgeInsets.all(10),
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) => LayoutBuilder(
            builder: (context, box) {
              const t = 52.0; // 더미 한 줄의 두께
              final four = c.players == 4;
              final side = max(80.0, min(box.maxWidth - (four ? 2 * t : 0), box.maxHeight - 2 * t));

              Widget stock(int seat, {required bool vertical}) => QWallStock(
                    key: ValueKey('wall-stock-$seat'),
                    seat: seat,
                    count: c.state.wallsLeft[seat],
                    boardSide: side,
                    vertical: vertical,
                    active: c.humanCanAct && c.turn == seat && c.state.wallsLeft[seat] > 0,
                    orient: c.wallOrientPick,
                  );

              final board = SizedBox(
                width: side,
                height: side,
                child: QBoardView(
                  state: c.state,
                  targets: c.targets,
                  lastMove: c.lastMove,
                  animate: true,
                  moveCount: c.moveCount,
                  lastMover: c.lastMover,
                  wallMode: c.wallMode,
                  wallOrient: c.wallOrientPick,
                  pickRow: c.wallRowPick,
                  pickCol: c.wallColPick,
                  pickOk: c.canConfirmWall,
                  // 칸을 누르면 말이 움직인다 (막대를 놓아 둔 채로 누르면 막대를 거둔다)
                  onCell: (cell) => c.wallMode ? c.cancelWall() : c.tapCell(cell),
                  onAnchor: c.pickWall,
                  onWallDrop: c.humanCanAct ? c.placeWall : null,
                  onWallCancel: c.cancelWall,
                  onRotate: c.toggleWallOrient,
                  onConfirm: c.confirmWall,
                  onCancel: c.cancelWall,
                  confirmEnabled: c.canConfirmWall,
                ),
              );
              final bottom = stock(0, vertical: false);
              final top = stock(four ? 2 : 1, vertical: false);
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: t, child: Center(child: top)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (four) SizedBox(width: t, height: side, child: Center(child: stock(1, vertical: true))),
                      board,
                      if (four) SizedBox(width: t, height: side, child: Center(child: stock(3, vertical: true))),
                    ],
                  ),
                  SizedBox(height: t, child: Center(child: bottom)),
                ],
              );
            },
          ),
        ),
      );

  Widget _portrait() => Column(
        children: [
          _playerChips(),
          _statusBanner(),
          Expanded(child: _boardArea()),
          _panel(),
          _bottomBar(),
        ],
      );

  Widget _landscape() => Row(
        children: [
          Expanded(child: _boardArea()),
          SizedBox(
            width: 360,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _playerChips(),
                  _statusBanner(),
                  const SizedBox(height: 8),
                  _panel(),
                  _bottomBar(),
                ],
              ),
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
            child: Text('쿼리도', maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const Spacer(),
          IconButton(tooltip: '내 기록', icon: const Icon(Icons.emoji_events_rounded), onPressed: () => openRecords(context, game: 'quoridor')),
          IconButton(tooltip: '규칙', icon: const Icon(Icons.help_outline_rounded), onPressed: () => showQuoridorRules(context)),
        ],
      ),
    );
  }

  /// 사람마다 칩: 이름과 남은 벽 수. 지금 차례인 사람이 강조된다.
  Widget _playerChips() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        Widget chip(int seat) {
          final active = !c.isOver && !c.halted && c.turn == seat;
          final win = c.isOver && c.state.winner == seat;
          final color = kPawnColors[seat];
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
                Container(width: 14, height: 14, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(_name(seat), style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                const SizedBox(width: 8),
                Icon(Icons.horizontal_rule_rounded, size: 16, color: color.withValues(alpha: 0.9)),
                Text('${c.state.wallsLeft[seat]}', style: TextStyle(fontWeight: FontWeight.w900, color: color)),
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
        final color = c.isOver || c.halted ? Colors.grey : kPawnColors[c.turn];
        final problem = _wallProblem;
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
              if (problem != null) Text(problem, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w700)),
            ],
          ),
        );
      },
    );
  }

  /// 아래 칸: 진행 중에는 조작 안내 글, 끝나면 결과.
  Widget _panel() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (c.isOver) return _resultPanel();
        return _controls();
      },
    );
  }

  /// 안내 글: 말은 점이 찍힌 칸을 누르고, 벽은 내 앞의 나무막대를 끌어다 놓는다.
  Widget _controls() {
    final scheme = Theme.of(context).colorScheme;
    final String text;
    if (c.wallMode && c.humanCanAct) {
      text = '막대의 돌리기로 방향을 바꾸고, 체크(✓)로 세워요. 막대를 끌어서 옮기거나 판 밖으로 끌면 취소돼요';
    } else if (c.humanCanAct && c.state.wallsLeft[c.turn] > 0) {
      text = '벽을 세우려면 내 앞의 나무막대를 판으로 끌어다 놓으세요';
    } else {
      text = '가장 먼저 맞은편 줄에 닿으면 이겨요';
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
      child: Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, height: 1.3, color: scheme.onSurface.withValues(alpha: 0.7))),
    );
  }

  Widget _bottomBar() {
    final compact = OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), visualDensity: VisualDensity.compact);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            if (!c.online) ...[
              OutlinedButton.icon(
                style: compact,
                onPressed: c.canUndo ? c.undo : null,
                icon: const Icon(Icons.undo_rounded, size: 20),
                label: const Text('되돌리기'),
              ),
              OutlinedButton.icon(
                style: compact,
                onPressed: _newGameNow,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('새 판'),
              ),
            ],
            if (c.oneSeat || c.players == 2)
              OutlinedButton.icon(
                style: compact,
                onPressed: c.canResign ? _resign : null,
                icon: const Icon(Icons.flag_outlined, size: 20),
                label: const Text('기권'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _resultPanel() {
    final s = c.state;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.emoji_events_rounded, color: kPawnColors[s.winner!]),
              const SizedBox(width: 8),
              Text('${_name(s.winner!)} 승리 · ${c.moveCount}수', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
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
                        c.restart(rotate: c.oneSeat);
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
Future<void> showQuoridorRules(BuildContext context) {
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
      title: const Text('쿼리도 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('2명 또는 4명이 해요. 각자 판 가장자리 가운데에서 시작해서, 맞은편 줄에 가장 먼저 닿으면 이겨요.'),
            line('자기 차례에 말을 한 칸 옮기거나(앞뒤 양옆), 벽을 하나 세워요.'),
            line('바로 옆에 다른 말이 있으면 그 말을 뛰어넘어요. 뒤가 벽이나 판 끝이면 그 말의 양옆으로 비껴 갈 수 있어요.'),
            line('벽은 두 칸 길이예요. 말은 벽을 넘거나 뚫고 갈 수 없어요.'),
            line('벽은 겹치거나 십자로 엇갈리게 세울 수 없어요. 그리고 어느 말이든 도착 줄로 가는 길이 하나는 꼭 남아 있어야 해요.'),
            line('벽은 2명이면 10개씩, 4명이면 5개씩 가져요. 다 쓰면 말만 옮길 수 있어요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            quoridorTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}
