import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/game_fx.dart';
import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../core/leave_guard.dart';
import '../../../core/win_sound.dart';
import '../../../net/lan_connection.dart';
import '../../../records/records_screen.dart';
import '../core/sprouts_ai.dart';
import '../core/sprouts_board.dart';
import '../data/sprouts_history.dart';
import '../game/sprouts_controller.dart';
import '../tutorial/sprouts_tutorial.dart';
import 'sprouts_board_view.dart';
import 'sprouts_lesson_screen.dart';
import 'sprouts_painter.dart';

/// 콩나물 플레이 화면.
class SproutsScreen extends StatefulWidget {
  const SproutsScreen({
    super.key,
    this.mode = PlayMode.local2p,
    this.dotCount = 3,
    this.humanSide = 0,
    this.level = SproutsLevel.normal,
    this.controller,
    this.link,
    this.isHost = false,
    this.initialBoard,
  });

  final PlayMode mode;
  final int dotCount;
  final int humanSide;
  final SproutsLevel level;

  /// 같은 Wi‑Fi 대결([PlayMode.wifi])에서 상대 기기와의 연결. 이 화면이 닫을 때 같이 닫는다.
  final LanConnection? link;

  /// Wi‑Fi 대결에서 방을 연 쪽인가 (한 판 더 할 때 새 처음 판을 만들어 보내는 쪽).
  final bool isHost;

  /// Wi‑Fi 대결의 처음 판 (방을 연 쪽이 만들어 두 기기가 같은 판으로 시작한다).
  final SproutsBoard? initialBoard;

  /// (테스트용) 미리 만든 컨트롤러.
  final SproutsController? controller;

  @override
  State<SproutsScreen> createState() => _SproutsScreenState();
}

class _SproutsScreenState extends State<SproutsScreen> {
  // 화면이 직접 소유한다: 화면이 다시 빌드되어도 판이 사라지지 않는다.
  late SproutsController c = widget.controller ??
      SproutsController(mode: widget.mode, dotCount: widget.dotCount, humanSide: widget.humanSide, level: widget.level, board: widget.initialBoard);
  bool _resultHandled = false;

  /// 한 기기·CPU 대결을 이어하기용으로 보관하는 도우미 (같은 Wi‑Fi 대결은 보관하지 않는다).
  late final GameSaver _saver = GameSaver(gameId: 'sprouts', snapshot: () => c.savable ? c.toJson() : null);
  int _savedAtMove = -1;

  // ── 같은 Wi‑Fi 대결 ──
  LanConnection? get _link => c.online ? widget.link : null;
  StreamSubscription<Map<String, dynamic>>? _linkSub;

  /// 상대 기기와의 연결이 끊겼다 / 이 화면에서 일부러 나가는 중이다.
  bool _opponentGone = false;
  bool _leaving = false;

  /// 한 판 더: 내가 하자고 했다 / 상대가 하자고 했다 (둘 다 하면 먼저/나중을 바꿔 새로 시작한다).
  bool _rematchAsked = false;
  bool _rematchOffered = false;

  /// 알림 종류 → 진동·소리 (설정의 진동·효과음 스위치를 따른다).
  final GameFx _fx = GameFx({
    'draw': const Fx(haptic: Haptic.select),
    'bad': const Fx(haptic: Haptic.light),
    'win': const Fx(haptic: Haptic.heavy),
  });

  @override
  void initState() {
    super.initState();
    _attach(c);
    if (!c.online) {
      _savedAtMove = c.moveCount;
      _saver.attach();
    }
    final link = _link;
    if (link != null) {
      _linkSub = link.messages.listen(_onNet);
      link.closed.then((_) => _onLinkClosed());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
  }

  void _attach(SproutsController ctl) {
    ctl.onFeedback = _feedback;
    ctl.addListener(_onChanged);
    if (ctl.online) ctl.onSync = _sendSync;
  }

  void _detach(SproutsController ctl) {
    ctl.removeListener(_onChanged);
    ctl.onFeedback = null;
    ctl.onSync = null;
  }

  @override
  void dispose() {
    _fx.dispose();
    _saver.detach();
    _leaving = true;
    _linkSub?.cancel();
    final link = _link;
    if (link != null) {
      link.send(const {'t': 'bye'});
      link.close();
    }
    _detach(c);
    c.dispose();
    super.dispose();
  }

  /// 판은 소수점 둘째 자리까지만 보낸다 (선이 많은 판도 작게).
  static List<num> _pack(List<double> data) => [for (final v in data) (v * 100).roundToDouble() / 100];

  void _sendSync(SproutsSync s) => _link?.send({'t': 'board', 'k': s.kind, 'n': s.moveCount, 'd': _pack(s.data)});

  void _onNet(Map<String, dynamic> m) {
    if (!mounted) return;
    switch (m['t']) {
      case 'board':
        final d = m['d'];
        final ok = d is List && m['k'] is String && m['n'] is int && c.receiveSync(SproutsSync(kind: m['k'] as String, moveCount: m['n'] as int, data: [for (final v in d) (v as num).toDouble()]));
        if (!ok) _desync();
      case 'resign':
        _onOpponentResigned();
      case 'again':
        setState(() => _rematchOffered = true);
        if (_rematchAsked && widget.isHost) _hostStartRematch();
      case 'newboard':
        final d = m['d'];
        if (d is List) _startRematch(SproutsBoard.fromData([for (final v in d) (v as num).toDouble()]));
      case 'bye':
        _onLinkClosed();
    }
  }

  /// 판이 서로 어긋났다 (있을 수 없는 일이지만, 어긋난 채로 계속하지는 않는다).
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
    if (c.isOver) return; // 끝난 판이면 결과를 마저 볼 수 있게 두고, "한 판 더"만 막는다
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
    if (c.isOver) return;
    c.opponentResigned();
    _resultHandled = true;
    WinSound.play(context); // 이겼을 때 "짜잔"
    await SproutsHistory.add(SproutsRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: false,
      online: true,
      winner: c.humanSide,
      moves: c.moveCount,
      dots: c.dotCount,
      human: c.humanSide,
      resigned: true,
    ));
    if (mounted) setState(() {});
  }

  /// "한 판 더": 상대도 하자고 했으면 바로(방을 연 쪽이 새 처음 판을 만들어 보내며) 먼저/나중을 바꿔 시작하고, 아니면 상대를 기다린다.
  void _requestRematch() {
    if (_rematchAsked || _opponentGone) return;
    setState(() => _rematchAsked = true);
    _link?.send(const {'t': 'again'});
    if (_rematchOffered && widget.isHost) _hostStartRematch();
  }

  void _hostStartRematch() {
    final board = SproutsBoard.fromData(_pack(SproutsBoard.initial(c.dotCount, Random()).toData()).map((v) => v.toDouble()).toList());
    _link?.send({'t': 'newboard', 'd': _pack(board.toData())});
    _startRematch(board);
  }

  void _startRematch(SproutsBoard board) {
    final old = c;
    _detach(old);
    c = old.fresh(board: board);
    _rematchAsked = false;
    _rematchOffered = false;
    _resultHandled = false;
    _attach(c);
    old.dispose();
    setState(() {});
    c.start();
  }

  /// 나갈 때: 진행 중인 Wi‑Fi 판이면 먼저 물어본다.
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

  void _feedback(String kind) => _fx.play(context, kind);

  void _onChanged() {
    if (c.isOver && !_resultHandled && !c.resigned) {
      _resultHandled = true;
      if (!c.oneSeat || c.winner == c.humanSide) WinSound.play(context); // 이겼을 때 "짜잔"
      SproutsHistory.add(SproutsRecord(
        at: DateTime.now().millisecondsSinceEpoch,
        vsCpu: c.vsCpu,
        winner: c.winner!,
        moves: c.moveCount,
        dots: c.dotCount,
        level: c.vsCpu ? c.level : null,
        human: c.oneSeat ? c.humanSide : null,
        online: c.online,
      ));
    } else if (!c.isOver) {
      _resultHandled = false;
    }
    if (!c.online) _autosave();
    if (mounted) setState(() {});
  }

  /// 수를 둘 때마다 이어하기용으로 보관한다 (끝난 판이면 보관된 것을 지운다).
  void _autosave() {
    if (c.moveCount == 0 && !c.isOver) _saver.rearm(); // 새 판이 시작됐다
    if (c.isOver) {
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
    _newGame();
  }

  /// 같은 설정으로 새 판.
  void _newGame({bool swapStart = true}) {
    final old = c;
    _detach(old);
    c = old.fresh(swapStart: swapStart);
    _resultHandled = false;
    _saver.rearm();
    _savedAtMove = c.moveCount;
    _attach(c);
    old.dispose();
    setState(() {});
    c.start();
  }

  Future<void> _resign() async {
    if (!c.canResign) return;
    final loser = c.oneSeat ? c.humanSide : c.turn;
    final ok = await confirmGiveUp(
      context,
      detail: c.vsCpu
          ? 'CPU의 승리로 기록돼요.'
          : c.online
              ? '상대의 승리로 기록돼요.'
              : '${_name(loser)}이(가) 기권하고, ${_name(1 - loser)}의 승리로 기록돼요.',
      retry: c.vsCpu,
      verb: '기권',
    );
    if (!ok || !mounted || !c.resign()) return;
    _resultHandled = true;
    _link?.send(const {'t': 'resign'});
    await SproutsHistory.add(SproutsRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: c.vsCpu,
      online: c.online,
      winner: c.winner!,
      moves: c.moveCount,
      dots: c.dotCount,
      level: c.vsCpu ? c.level : null,
      human: c.oneSeat ? c.humanSide : null,
      resigned: true,
    ));
    if (mounted) setState(() {});
  }

  /// 선 정리하기: 선과 점을 위상은 그대로 두고 단순하게 정리한다. (안내 문구는 위쪽 상태 줄에 나온다)
  Future<void> _tidy() => c.tidy();

  /// 플레이어 이름: 둘이서는 "플레이어 1/2", CPU 대결은 "나/CPU".
  String _name(int side) => c.oneSeat ? (side == c.humanSide ? '나' : (c.vsCpu ? 'CPU' : (_link?.peerNick ?? '상대'))) : '플레이어 ${side + 1}';

  String get _status {
    if (c.message != null) return c.message!;
    if (c.notice != null && !c.isOver) return '${c.notice!} · ${_name(c.turn)} 차례';
    if (c.isOver) {
      if (c.oneSeat) return c.winner == c.humanSide ? '이겼어요! 🎉' : (c.vsCpu ? 'CPU가 이겼어요' : '상대가 이겼어요');
      return '${_name(c.winner!)} 승리! 🎉';
    }
    if (_opponentGone) return '상대와 연결이 끊겼어요';
    if (c.thinking) return 'CPU가 생각하는 중…';
    if (c.online && c.turn != c.humanSide) return '상대가 선을 긋는 중이에요…';
    if (c.moveCount == 0) return '${_name(c.turn)} 차례 · 점에서 점으로 곡선을 그어 보세요';
    return '${_name(c.turn)} 차례 · 마지막으로 두는 사람이 이겨요';
  }

  @override
  Widget build(BuildContext context) {
    // Wi‑Fi 대결 도중에 나가려 하면 먼저 물어본다 (연결이 끊기니까).
    return ListenableBuilder(
      listenable: c,
      builder: (context, child) {
        if (!c.online) {
          // 한 기기·CPU 대결: 나가기 전에 저장할지 묻는다
          return SaveLeaveGuard(active: () => _saver.active, onSave: _saver.save, onDiscard: _saver.discard, child: child!);
        }
        final askBeforeLeave = c.online && !c.isOver && !_opponentGone;
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
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? const [Color(0xFF1F2430), Color(0xFF181B24)]
                : const [Color(0xFFEAF6EC), Color(0xFFDDEFE3)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              LayoutBuilder(
                builder: (context, box) {
                  final board = Padding(
                    padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                    child: _glow(SproutsBoardView(key: ValueKey(c), controller: c)),
                  );
                  // 가로 화면: 판은 왼쪽에 크게, 선수·안내·단추는 오른쪽 칸에 (다른 대결 게임과 같은 배치)
                  if (box.maxWidth > box.maxHeight * 1.2) {
                    return Column(
                      children: [
                        _topBar(),
                        Expanded(
                          child: Row(
                            children: [
                              Expanded(child: board),
                              SizedBox(
                                width: 340,
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: [_playerChips(), _statusBanner(), const SizedBox(height: 8), _bottomBar()],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      _topBar(),
                      _playerChips(),
                      _statusBanner(),
                      Expanded(child: board),
                      _bottomBar(),
                    ],
                  );
                },
              ),
              // 이기면 색종이가 터진다 (손가락은 그대로 통과한다)
              Positioned.fill(
                child: IgnorePointer(
                  child: ListenableBuilder(
                    listenable: c,
                    builder: (context, _) => _celebrate
                        ? FinishConfetti(key: ValueKey('confetti-${c.moveCount}-${c.winner}'), color: sproutsColor(c.winner!))
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 끝나면 판 둘레가 승자 색으로 반짝인다 (그림은 가리지 않는다).
  Widget _glow(Widget board) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (!c.isOver || c.resigned) return board;
        final color = sproutsColor(c.winner!);
        return _Pulse(
          builder: (context, pulse) => DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35 + 0.3 * pulse), blurRadius: 14 + 16 * pulse, spreadRadius: 2 + 3 * pulse)],
            ),
            child: board,
          ),
        );
      },
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: '뒤로',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Flexible(
            child: Text(
              '콩나물',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '교과학습',
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: () => openSproutsLesson(context),
          ),
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () => openRecords(context, game: 'sprouts'),
          ),
          IconButton(
            tooltip: '규칙',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => showSproutsRules(context),
          ),
        ],
      ),
    );
  }

  Widget _playerChips() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        Widget chip(int side) {
          final active = !c.isOver && c.turn == side;
          final color = sproutsColor(side);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: active ? 0.22 : 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: active ? 1 : 0.3), width: active ? 2.5 : 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 18, height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Text(_name(side), style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [chip(0), const SizedBox(width: 12), chip(1)],
          ),
        );
      },
    );
  }

  Widget _statusBanner() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final bad = c.message != null;
        final color = bad ? const Color(0xFFE5484D) : sproutsColor(c.isOver ? (c.winner ?? 0) : c.turn);
        if (c.isOver && !bad) {
          // 끝났다: 승자 색으로 꽉 채우고 크게
          return _Pulse(
            active: !c.resigned,
            builder: (context, pulse) => Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.white, 0.25)!]),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: color.withValues(alpha: 0.35 + 0.25 * pulse), blurRadius: 10 + 10 * pulse)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(c.resigned ? Icons.flag_rounded : Icons.emoji_events_rounded, color: Colors.white, size: 22),
                  const SizedBox(width: 8),
                  Flexible(child: Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white))),
                ],
              ),
            ),
          );
        }
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        );
      },
    );
  }

  /// 내가 이겼거나(CPU 대결) 둘이서 한 판이면 축하 연출을 한다. CPU에게 졌을 때는 차분하게.
  bool get _celebrate => c.isOver && !c.resigned && (!c.oneSeat || c.winner == c.humanSide);

  /// 판이 끝났을 때 아래에 나오는 안내: 창으로 가리지 않고, 그림은 그대로 보이게 하면서 크고 화려하게 알린다.
  Widget _resultBar() {
    final w = c.winner!;
    final String head, body;
    if (c.resigned) {
      head = '기권했어요';
      body = c.vsCpu
          ? 'CPU ${c.level.label} · 점 ${c.dotCount}개 · ${c.moveCount}수 · 기록에 남겼어요'
          : c.online
              ? '${_name(1 - w)} 기권 · 점 ${c.dotCount}개 · ${c.moveCount}수 · 기록에 남겼어요'
              : '${_name(c.turn)} 기권 · ${c.moveCount}수 · 기록에 남겼어요';
    } else if (c.oneSeat) {
      final me = w == c.humanSide;
      head = me ? '이겼어요! 🎉' : (c.vsCpu ? 'CPU가 이겼어요' : '상대가 이겼어요');
      body = '${me ? '더 이을 곳이 없어요. 내가 마지막으로 두었어요' : '더 이을 곳이 없어졌어요. 다음엔 꼭 이겨 봐요!'} (점 ${c.dotCount}개 · ${c.moveCount}수)';
    } else {
      head = '${_name(w)} 승리! 🎉';
      body = '더 이을 곳이 없어요. 마지막으로 수를 둔 사람이 이겼어요 (점 ${c.dotCount}개 · ${c.moveCount}수)';
    }
    final color = sproutsColor(w);
    final icon = c.resigned
        ? Icons.flag_rounded
        : (_celebrate ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded);
    return TweenAnimationBuilder<double>(
      key: ValueKey('result-${c.moveCount}-${c.winner}'),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 650),
      curve: Curves.elasticOut,
      builder: (context, v, child) => Transform.scale(
        scale: 0.8 + 0.2 * v,
        child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
      ),
      child: _Pulse(
        active: !c.resigned,
        builder: (context, pulse) => Container(
          margin: const EdgeInsets.fromLTRB(14, 2, 14, 10),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [color.withValues(alpha: 0.30), Theme.of(context).colorScheme.surface.withValues(alpha: 0.95)],
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color, width: 2.5),
            boxShadow: [BoxShadow(color: color.withValues(alpha: 0.30 + 0.30 * pulse), blurRadius: 12 + 14 * pulse, spreadRadius: 1 + 2 * pulse)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 34 + 3 * pulse, color: _celebrate ? const Color(0xFFF2A900) : color),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(head, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 10,
                runSpacing: 6,
                children: [
                  if (!c.resigned && !c.online)
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                      onPressed: c.canUndo ? c.undo : null,
                      icon: const Icon(Icons.undo_rounded, size: 20),
                      label: const Text('되돌리기'),
                    ),
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('메뉴로')),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: color),
                    onPressed: c.online ? (_rematchAsked || _opponentGone ? null : _requestRematch) : _newGame,
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
        ),
      ),
    );
  }

  Widget _bottomBar() {
    final compact = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      visualDensity: VisualDensity.compact,
    );
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => c.isOver ? _resultBar() : Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        // 좁은 화면(폰)에서는 단추가 다음 줄로 넘어간다
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            if (!c.online)
              OutlinedButton.icon(
                style: compact,
                onPressed: c.canUndo ? c.undo : null,
                icon: const Icon(Icons.undo_rounded, size: 20),
                label: const Text('되돌리기'),
              ),
            OutlinedButton.icon(
              style: compact,
              onPressed: c.humanCanAct ? c.showHint : null,
              icon: const Icon(Icons.lightbulb_rounded, size: 20),
              label: const Text('힌트'),
            ),
            OutlinedButton.icon(
              style: compact,
              onPressed: c.canTidy ? _tidy : null,
              icon: const Icon(Icons.auto_fix_high_rounded, size: 20),
              label: const Text('선 정리하기'),
            ),
            if (!c.online)
              OutlinedButton.icon(
                style: compact,
                onPressed: _newGameNow,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('새 판'),
              ),
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
}

/// 규칙 설명.
Future<void> showSproutsRules(BuildContext context) {
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
      title: const Text('콩나물 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('내 차례에 점에서 점으로 손가락을 끌어 곡선을 그어요. (한 점에서 출발해 그 점으로 돌아오는 고리도 돼요)'),
            line('그은 선 위에 새 점이 저절로 하나 찍혀요. 이것이 한 수예요.'),
            line('선은 다른 선이나 자기 자신과 만나면 안 돼요. 다른 점 위를 지나가도 안 돼요.'),
            line('점 하나에는 선을 3개까지만 이을 수 있어요. 점 안의 숫자가 앞으로 더 이을 수 있는 선의 수예요.'),
            line('새 점은 이미 선이 2개 이어져 있어서 숫자가 1이에요.'),
            line('더 이을 수 없게 되면 끝나고, 마지막으로 수를 둔 사람이 이겨요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            sproutsTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}

/// 0~1~0을 되풀이하는 숨쉬기 값을 만들어 [builder]에 넘긴다 (끝 표시가 살아 있는 느낌이 나게).
class _Pulse extends StatefulWidget {
  const _Pulse({required this.builder, this.active = true});

  final Widget Function(BuildContext context, double pulse) builder;

  /// false면 숨쉬지 않고 가만히 있다 (기권처럼 차분해야 할 때).
  final bool active;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    if (widget.active) _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => widget.builder(context, widget.active ? Curves.easeInOut.transform(_c.value) : 0.0),
      );
}

/// 이겼을 때 판 위로 터졌다가 떨어지는 색종이. 짧게(약 3초) 흩날리고 사라진다.
class FinishConfetti extends StatefulWidget {
  const FinishConfetti({super.key, required this.color});

  final Color color;

  @override
  State<FinishConfetti> createState() => _FinishConfettiState();
}

class _FinishConfettiState extends State<FinishConfetti> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _ConfettiPainter(_c.value, widget.color)),
      );
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.t, this.color) : _pieces = _make(color);

  final double t;
  final Color color;
  final List<_Piece> _pieces;

  static List<_Piece> _make(Color base) {
    final rng = Random(7);
    final palette = [base, const Color(0xFFFFC21A), const Color(0xFFFF6FAE), const Color(0xFF3DD6A5), const Color(0xFF5AA9FF), Colors.white];
    return [
      for (var i = 0; i < 90; i++)
        _Piece(
          x: 0.12 + rng.nextDouble() * 0.76,
          vx: (rng.nextDouble() - 0.5) * 0.9,
          vy: -(0.9 + rng.nextDouble() * 1.1),
          size: 6 + rng.nextDouble() * 7,
          spin: (rng.nextDouble() - 0.5) * 14,
          phase: rng.nextDouble() * 6.28,
          circle: rng.nextBool(),
          color: palette[rng.nextInt(palette.length)],
          delay: rng.nextDouble() * 0.12,
        ),
    ];
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in _pieces) {
      final u = ((t - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
      if (u <= 0) continue;
      final time = u * 2.6;
      final x = size.width * (p.x + p.vx * time * 0.35) + sin(time * 3 + p.phase) * 14;
      // 아래 가운데에서 위로 솟았다가 중력으로 떨어진다
      final y = size.height * (0.9 + p.vy * time * 0.45 + 0.95 * time * time * 0.45);
      final alpha = u > 0.78 ? (1 - u) / 0.22 : 1.0;
      if (alpha <= 0 || y > size.height + 20) continue;
      final paint = Paint()..color = p.color.withValues(alpha: alpha.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * time + p.phase);
      if (p.circle) {
        canvas.drawCircle(Offset.zero, p.size * 0.45, paint);
      } else {
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.55), const Radius.circular(1.5)), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

class _Piece {
  const _Piece({
    required this.x,
    required this.vx,
    required this.vy,
    required this.size,
    required this.spin,
    required this.phase,
    required this.circle,
    required this.color,
    required this.delay,
  });

  final double x, vx, vy, size, spin, phase, delay;
  final bool circle;
  final Color color;
}
