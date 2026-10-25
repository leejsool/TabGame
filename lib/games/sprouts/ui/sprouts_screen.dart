import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/game_fx.dart';
import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../core/leave_guard.dart';
import '../../../core/win_sound.dart';
import '../../../net/lan_connection.dart';
import '../../../net/lan_rejoin.dart';
import '../core/sprouts_ai.dart';
import '../core/sprouts_board.dart';
import '../data/sprouts_history.dart';
import '../game/sprouts_controller.dart';
import '../tutorial/sprouts_tutorial.dart';
import 'sprouts_board_view.dart';
import 'sprouts_lesson_screen.dart';
import 'sprouts_painter.dart';
import '../../../versus/vs_link.dart';
import '../../../versus/vs_screen_parts.dart';

part 'sprouts_screen_effects.dart';

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
    this.rejoinDesk,
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

  /// 방장일 때: 판이 시작된 뒤에도 방 문을 열어 두고 나갔던 상대를 다시 받아 주는 접수처.
  final LanRejoinDesk? rejoinDesk;

  /// (테스트용) 미리 만든 컨트롤러.
  final SproutsController? controller;

  @override
  State<SproutsScreen> createState() => _SproutsScreenState();
}

class _SproutsScreenState extends State<SproutsScreen> with VsTwoPlayer {
  // 화면이 직접 소유한다: 화면이 다시 빌드되어도 판이 사라지지 않는다. (새 판마다 새 컨트롤러로 바뀐다)
  late SproutsController c = widget.controller ??
      SproutsController(mode: widget.mode, dotCount: widget.dotCount, humanSide: widget.humanSide, level: widget.level, board: widget.initialBoard);
  bool _resultHandled = false;

  /// 알림 종류 → 진동·소리 (설정의 진동·효과음 스위치를 따른다).
  final GameFx _fx = GameFx({
    'draw': const Fx(haptic: Haptic.select, sound: 'sprouts/paper.mp3'),
    'bad': const Fx(haptic: Haptic.light),
    'win': const Fx(haptic: Haptic.heavy),
  });

  // ── 공통 대결 동작([VsTwoPlayer])에 알려 주는 것 ──
  /// 한 기기·CPU 대결을 이어하기용으로 보관하는 도우미 (같은 Wi‑Fi 대결은 보관하지 않는다).
  @override
  late final GameSaver vsSaver = GameSaver(gameId: 'sprouts', snapshot: () => c.savable ? c.toJson() : null);
  @override
  LanConnection? get vsLink => c.online ? widget.link : null;
  @override
  bool get vsOnline => c.online;
  @override
  bool get vsOver => c.isOver;
  @override
  bool get vsHalted => false;
  @override
  int get vsMoveCount => c.moveCount;

  @override
  String? get vsLanGame => 'sprouts';
  @override
  LanRejoinDesk? get vsRejoinDesk => widget.rejoinDesk;
  @override
  void vsCoverOpponent() => c.coverOpponent();
  @override
  void vsUncoverOpponent() => c.uncoverOpponent();
  @override
  Map<String, dynamic>? vsSnapshot() => c.online ? c.wifiSnapshot() : null;
  @override
  Widget? Function(Map<String, dynamic> resume, LanConnection conn)? get vsResumeBuilder => sproutsResume;

  /// 둘 다 "한 판 더"를 눌렀다: 방을 연 쪽이 새 처음 판을 만들어 보낸다 (손님은 그 판을 받아 시작한다).
  @override
  void vsRestartForRematch() {
    if (!widget.isHost) return;
    final board = SproutsBoard.fromData(_pack(SproutsBoard.initial(c.dotCount, Random()).toData()).map((v) => v.toDouble()).toList());
    vsLink?.send({'t': 'newboard', 'd': _pack(board.toData())});
    _startRematch(board);
  }

  @override
  bool vsOnMessage(Map<String, dynamic> m) {
    switch (m['t']) {
      case 'board':
        final d = m['d'];
        final ok = d is List && m['k'] is String && m['n'] is int && c.receiveSync(SproutsSync(kind: m['k'] as String, moveCount: m['n'] as int, data: [for (final v in d) (v as num).toDouble()]));
        if (!ok) vsDesync();
        return true;
      case 'newboard':
        final d = m['d'];
        if (d is List) _startRematch(SproutsBoard.fromData([for (final v in d) (v as num).toDouble()]));
        return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _attach(c);
    vsAttach();
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
    vsDetach();
    _detach(c);
    c.dispose();
    super.dispose();
  }

  /// 판은 소수점 둘째 자리까지만 보낸다 (선이 많은 판도 작게).
  static List<num> _pack(List<double> data) => [for (final v in data) (v * 100).roundToDouble() / 100];

  void _sendSync(SproutsSync s) => vsLink?.send({'t': 'board', 'k': s.kind, 'n': s.moveCount, 'd': _pack(s.data)});

  @override
  Future<void> vsOnOpponentResigned() async {
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

  void _startRematch(SproutsBoard board) {
    final old = c;
    _detach(old);
    c = old.fresh(board: board);
    rematchAsked = false;
    rematchOffered = false;
    _resultHandled = false;
    _attach(c);
    old.dispose();
    setState(() {});
    c.start();
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
    vsAutosave();
    if (mounted) setState(() {});
  }

  /// 하던 판 도중에 "새 판" 단추를 눌렀다: 하던 판이 사라지니 먼저 묻는다.
  Future<void> _newGameNow() async {
    if (await vsConfirmNewGame()) _newGame();
  }

  /// 같은 설정으로 새 판.
  void _newGame({bool swapStart = true}) {
    final old = c;
    _detach(old);
    c = old.fresh(swapStart: swapStart);
    _resultHandled = false;
    vsSaver.rearm();
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
    vsLink?.send(const {'t': 'resign'});
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
  String _name(int side) => c.oneSeat ? (side == c.humanSide ? '나' : (c.vsCpu ? 'CPU' : (vsLink?.peerNick ?? '상대'))) : '플레이어 ${side + 1}';

  String get _status {
    if (c.message != null) return c.message!;
    if (c.notice != null && !c.isOver) return '${c.notice!} · ${_name(c.turn)} 차례';
    if (c.isOver) {
      if (c.oneSeat) return c.winner == c.humanSide ? '이겼어요! 🎉' : (c.vsCpu ? 'CPU가 이겼어요' : '상대가 이겼어요');
      return '${_name(c.winner!)} 승리! 🎉';
    }
    if (opponentGone) return '상대와 연결이 끊겼어요';
    if (c.thinking) return 'CPU가 생각하는 중…';
    if (c.online && c.turn != c.humanSide) return '상대가 선을 긋는 중이에요…';
    if (c.moveCount == 0) return '${_name(c.turn)} 차례 · 점에서 점으로 곡선을 그어 보세요';
    return '${_name(c.turn)} 차례 · 마지막으로 두는 사람이 이겨요';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => vsLeaveGuard(
        VsGameScaffold(
          light: const [Color(0xFFEAF6EC), Color(0xFFDDEFE3)],
          dark: const [Color(0xFF1F2430), Color(0xFF181B24)],
          topBar: VsTopBar(title: '콩나물', gameId: 'sprouts', onRules: () => showSproutsRules(context), onLesson: () => openSproutsLesson(context)),
          chips: VsPlayerChips(chips: [_chip(0), _chip(1)]),
          banner: _statusBanner(),
          board: Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
            child: _glow(SproutsBoardView(key: ValueKey(c), controller: c)),
          ),
          sideWidth: 340,
          bottom: c.isOver ? _resultBar() : _bottomBar(),
          // 이기면 색종이가 터진다 (손가락은 그대로 통과한다)
          overlay: IgnorePointer(
            child: _celebrate ? FinishConfetti(key: ValueKey('confetti-${c.moveCount}-${c.winner}'), color: sproutsColor(c.winner!)) : const SizedBox.shrink(),
          ),
        ),
      ),
    );
  }

  /// 끝나면 판 둘레가 승자 색으로 반짝인다 (그림은 가리지 않는다).
  Widget _glow(Widget board) {
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
  }

  Widget _chip(int side) {
    final color = sproutsColor(side);
    return VsPlayerChip(
      icon: Container(width: 18, height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
      label: _name(side),
      color: color,
      active: !c.isOver && c.turn == side,
    );
  }

  Widget _statusBanner() {
    final bad = c.message != null;
    final color = bad ? const Color(0xFFE5484D) : sproutsColor(c.isOver ? (c.winner ?? 0) : c.turn);
    if (!c.isOver || bad) return VsStatusBanner(text: _status, color: color);
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
                  if (!c.resigned && !c.online) VsButton(icon: Icons.undo_rounded, label: '되돌리기', onPressed: c.canUndo ? c.undo : null),
                  TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('메뉴로')),
                  FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: color),
                    onPressed: c.online ? (rematchAsked || opponentGone ? null : requestRematch) : _newGame,
                    child: Text(!c.online
                        ? '한 판 더'
                        : opponentGone
                            ? '상대가 나갔어요'
                            : rematchAsked
                                ? '상대를 기다려요…'
                                : rematchOffered
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

  Widget _bottomBar() => VsBottomBar(children: [
        if (!c.online) VsButton(icon: Icons.undo_rounded, label: '되돌리기', onPressed: c.canUndo ? c.undo : null),
        VsButton(icon: Icons.lightbulb_rounded, label: '힌트', onPressed: c.humanCanAct ? c.showHint : null),
        VsButton(icon: Icons.auto_fix_high_rounded, label: '선 정리하기', onPressed: c.canTidy ? _tidy : null),
        if (!c.online) VsButton(icon: Icons.refresh_rounded, label: '새 판', onPressed: _newGameNow),
        VsButton(icon: Icons.flag_outlined, label: '기권', onPressed: c.canResign ? _resign : null),
      ]);
}

/// 규칙 설명.
Future<void> showSproutsRules(BuildContext context) => showVsRules(
      context,
      title: '콩나물 규칙',
      lines: const [
        '내 차례에 점에서 점으로 손가락을 끌어 곡선을 그어요. (한 점에서 출발해 그 점으로 돌아오는 고리도 돼요)',
        '그은 선 위에 새 점이 저절로 하나 찍혀요. 이것이 한 수예요.',
        '선은 다른 선이나 자기 자신과 만나면 안 돼요. 다른 점 위를 지나가도 안 돼요.',
        '점 하나에는 선을 3개까지만 이을 수 있어요. 점 안의 숫자가 앞으로 더 이을 수 있는 선의 수예요.',
        '새 점은 이미 선이 2개 이어져 있어서 숫자가 1이에요.',
        '더 이을 수 없게 되면 끝나고, 마지막으로 수를 둔 사람이 이겨요.',
      ],
      openTutorial: () => sproutsTutorial().open(context),
    );

/// 방장이 보낸 `resume`(나갔다 다시 들어올 때 받는 판의 모습)으로 콩나물 화면을 만든다. 맞지 않는 내용이면 null.
Widget? sproutsResume(Map<String, dynamic> resume, LanConnection conn) {
  final snap = resume['snap'];
  if (snap is! Map<String, dynamic>) return null;
  final c = ScRejoin.fromWifiSnapshot(snap);
  if (c == null) return null;
  return SproutsScreen(mode: PlayMode.wifi, dotCount: c.dotCount, humanSide: c.humanSide, controller: c, link: conn);
}
