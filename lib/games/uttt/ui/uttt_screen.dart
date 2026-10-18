import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/game_fx.dart';
import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../core/leave_guard.dart';
import '../../../core/win_sound.dart';
import '../../../core/settings_scope.dart';
import '../../../net/lan_connection.dart';
import '../tutorial/uttt_tutorial.dart';
import '../core/uttt_ai.dart';
import '../core/uttt_rules.dart';
import '../data/uttt_history.dart';
import '../game/uttt_controller.dart';
import 'uttt_board.dart';
import 'uttt_lesson_screen.dart';
import '../../../versus/vs_link.dart';
import '../../../versus/vs_screen_parts.dart';

const _boardNames = [
  '왼쪽 위', '가운데 위', '오른쪽 위',
  '왼쪽 가운데', '한가운데', '오른쪽 가운데',
  '왼쪽 아래', '가운데 아래', '오른쪽 아래',
];

/// 궁극 틱택토 플레이 화면.
class UtttScreen extends StatefulWidget {
  const UtttScreen({
    super.key,
    this.mode = PlayMode.local2p,
    this.humanSide = kX,
    this.level = UttLevel.normal,
    this.controller,
    this.link,
  });

  final PlayMode mode;
  final int humanSide;
  final UttLevel level;

  /// 같은 Wi‑Fi 대결([PlayMode.wifi])에서 상대 기기와의 연결. 이 화면이 닫을 때 같이 닫는다.
  final LanConnection? link;

  /// (테스트용) 미리 만든 컨트롤러.
  final UtttController? controller;

  @override
  State<UtttScreen> createState() => _UtttScreenState();
}

class _UtttScreenState extends State<UtttScreen> with VsTwoPlayer {
  // 화면이 직접 소유한다: 화면이 다시 빌드되어도 판이 사라지지 않는다.
  late final UtttController c = widget.controller ??
      UtttController(mode: widget.mode, humanSide: widget.humanSide, level: widget.level);
  bool _resultHandled = false;

  /// 알림 종류 → 진동·소리 (설정의 진동·효과음 스위치를 따른다).
  final GameFx _fx = GameFx({
    'place': const Fx(haptic: Haptic.select),
    'win': const Fx(haptic: Haptic.heavy),
  });

  // ── 공통 대결 동작([VsTwoPlayer])에 알려 주는 것 ──
  /// 한 기기·CPU 대결을 이어하기용으로 보관하는 도우미 (같은 Wi‑Fi 대결은 보관하지 않는다).
  @override
  late final GameSaver vsSaver = GameSaver(gameId: 'ultimate_tictactoe', snapshot: () => c.savable ? c.toJson() : null);
  @override
  LanConnection? get vsLink => c.online ? widget.link : null;
  @override
  bool get vsOnline => c.online;
  @override
  bool get vsOver => c.isOver;
  @override
  bool get vsHalted => c.halted;
  @override
  int get vsMoveCount => c.moveCount;

  @override
  void vsRestartForRematch() {
    _resultHandled = false;
    c.restart(); // (먼저 시작하는 쪽이 바뀐다)
  }

  @override
  bool vsOnMessage(Map<String, dynamic> m) {
    if (m['t'] != 'move') return false;
    if (m['i'] != c.moveCount || m['m'] is! int || !c.receiveMove(m['m'] as int)) vsDesync();
    return true;
  }

  @override
  void initState() {
    super.initState();
    c.onFeedback = _feedback;
    c.addListener(_onChanged);
    vsAttach();
    final link = vsLink;
    if (link != null) c.onLocalMove = (move) => link.send({'t': 'move', 'i': c.moveCount - 1, 'm': move});
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
  }

  @override
  void dispose() {
    _fx.dispose();
    vsDetach();
    c.removeListener(_onChanged);
    c.onFeedback = null;
    c.onLocalMove = null;
    c.dispose();
    super.dispose();
  }

  @override
  Future<void> vsOnOpponentResigned() async {
    if (c.isOver || c.halted) return;
    c.opponentResigned();
    _resultHandled = true;
    await UtttHistory.add(UtttRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: false,
      online: true,
      winner: c.humanSide,
      moves: c.moveCount,
      human: c.humanSide,
      resigned: true,
    ));
    if (!mounted) return;
    final again = await showOpponentResigned(context, canAgain: !opponentGone);
    if (!mounted) return;
    again ? requestRematch() : Navigator.of(context).pop();
  }

  void _feedback(String kind) => _fx.play(context, kind);

  void _onChanged() {
    if (c.isOver && !_resultHandled) {
      _resultHandled = true;
      final o = c.outcome;
      if (o != Outcome.draw && (!c.oneSeat || (o == Outcome.xWins ? kX : kO) == c.humanSide)) WinSound.play(context); // 이겼을 때 "짜잔"
      UtttHistory.add(UtttRecord(
        at: DateTime.now().millisecondsSinceEpoch,
        vsCpu: c.vsCpu,
        online: c.online,
        winner: o == Outcome.xWins ? kX : o == Outcome.oWins ? kO : null,
        moves: c.moveCount,
        level: c.vsCpu ? c.level : null,
        human: c.oneSeat ? c.humanSide : null,
      ));
      Future<void>.delayed(const Duration(milliseconds: 1500), _showResult);
    } else if (!c.isOver) {
      if (_resultHandled) vsSaver.rearm(); // 한 판 더: 새 판은 다시 보관할 수 있다
      _resultHandled = false;
    }
    vsAutosave();
  }

  /// 하던 판 도중에 "새 판" 단추를 눌렀다: 하던 판이 사라지니 먼저 묻는다.
  Future<void> _newGameNow() async {
    if (await vsConfirmNewGame()) c.restart();
  }

  Future<void> _resign() async {
    if (!c.canResign) return;
    final side = c.resigningSide;
    final ok = await confirmGiveUp(
      context,
      detail: c.vsCpu
          ? 'CPU의 승리로 기록돼요.'
          : c.online
              ? '상대의 승리로 기록돼요.'
              : '${sideLabel(side)}가 기권하고, ${sideLabel(1 - side)}의 승리로 기록돼요.',
      retry: c.vsCpu,
      verb: '기권',
    );
    if (!ok || !mounted || !c.resign()) return;
    _resultHandled = true; // (끝난 판으로 한 번 더 기록되지 않게)
    vsLink?.send(const {'t': 'resign'});
    await UtttHistory.add(UtttRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: c.vsCpu,
      online: c.online,
      winner: 1 - side,
      moves: c.moveCount,
      level: c.vsCpu ? c.level : null,
      human: c.oneSeat ? c.humanSide : null,
      resigned: true,
    ));
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: c.vsCpu ? 'CPU ${c.level.label} · ${c.moveCount}수' : '${sideLabel(side)} 기권 · ${c.moveCount}수',
      againLabel: c.online ? '한 판 더' : '새 판',
      offerAgain: !opponentGone,
      retry: false,
      verb: '기권',
    );
    if (!mounted) return;
    if (again && c.online) {
      requestRematch();
    } else if (again) {
      _resultHandled = false;
      c.restart();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showResult() async {
    if (!mounted || !c.isOver) return;
    final o = c.outcome;
    final winnerSide = o == Outcome.xWins ? kX : o == Outcome.oWins ? kO : null;
    String title, body;
    if (winnerSide == null) {
      title = '무승부';
      body = '모든 판이 끝났지만 큰 줄이 나오지 않았어요.';
    } else if (c.oneSeat) {
      final me = winnerSide == c.humanSide;
      title = me ? '이겼어요! 🎉' : (c.vsCpu ? 'CPU가 이겼어요' : '상대가 이겼어요');
      body = me ? '${sideLabel(winnerSide)}로 큰 줄을 만들었어요!' : '다음엔 꼭 이겨 봐요!';
    } else {
      title = '${sideLabel(winnerSide)} 승리! 🎉';
      body = '축하해요!';
    }
    final again = await showDialog<bool>(
      context: context,
      builder: (_) => VsResultDialog(
        title: title,
        body: '$body\n(${c.moveCount}수)',
        art: winnerSide == null ? null : SizedBox(width: 80, height: 80, child: CustomPaint(painter: _MarkIconPainter(winnerSide))),
        canAgain: !opponentGone,
      ),
    );
    if (!mounted) return;
    if (again == true) {
      c.online ? requestRematch() : c.restart();
    } else if (again == false) {
      Navigator.of(context).pop();
    }
  }

  // ── 안내 문구 ──

  String get _status {
    if (c.isOver) {
      String won(int side) => c.oneSeat ? (c.humanSide == side ? '이겼어요! 🎉' : (c.vsCpu ? 'CPU가 이겼어요' : '상대가 이겼어요')) : '${sideLabel(side)} 승리!';
      return switch (c.outcome) {
        Outcome.xWins => won(kX),
        Outcome.oWins => won(kO),
        _ => '무승부예요',
      };
    }
    if (opponentGone) return '상대와 연결이 끊겼어요';
    if (c.halted) return rematchAsked ? '상대가 한 판 더를 받아 주기를 기다리는 중이에요…' : '기권으로 끝난 판이에요';
    if (c.thinking) return 'CPU가 생각하는 중…';
    final s = c.state;
    final who = c.oneSeat
        ? (s.turn == c.humanSide ? '내 차례' : (c.vsCpu ? 'CPU 차례' : '상대 차례'))
        : '${sideLabel(s.turn)} 차례';
    final where = s.next >= 0 ? '${_boardNames[s.next]} 판에서 두세요' : '아무 판에서나 두세요';
    return '$who · $where';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => vsLeaveGuard(
        VsGameScaffold(
          light: const [Color(0xFFFFF3DC), Color(0xFFFFE6C9)],
          dark: const [Color(0xFF1F2430), Color(0xFF181B24)],
          topBar: VsTopBar(title: '궁극 틱택토', gameId: 'ultimate_tictactoe', onRules: () => showUtttRules(context), onLesson: () => openUtttLesson(context)),
          chips: VsPlayerChips(chips: [_chip(kX), _chip(kO)]),
          banner: VsStatusBanner(text: _status, color: c.isOver ? Colors.grey : sideColor(c.state.turn)),
          board: _board,
          bottom: _bottomBar(),
        ),
      ),
    );
  }

  late final Widget _board = Padding(
    padding: const EdgeInsets.all(10),
    child: Center(
      child: UtttBoard(
        controller: c,
        onMove: (m) {
          if (!c.play(m)) {
            // 둘 수 없는 칸이면 살짝 알려준다
            if (SettingsScope.of(context).haptics) HapticFeedback.lightImpact();
          }
        },
      ),
    ),
  );

  /// X / O 칩: 지금 차례인 쪽이 강조된다.
  Widget _chip(int side) => VsPlayerChip(
        icon: SizedBox(width: 22, height: 22, child: CustomPaint(painter: _MarkIconPainter(side))),
        label: c.oneSeat ? (side == c.humanSide ? '나' : (c.vsCpu ? 'CPU' : (vsLink?.peerNick ?? '상대'))) : '플레이어 ${side + 1}',
        color: sideColor(side),
        active: !c.isOver && c.state.turn == side,
      );

  Widget _bottomBar() => VsBottomBar(children: [
        if (!c.online) ...[
          VsButton(icon: Icons.undo_rounded, label: '되돌리기', onPressed: c.canUndo ? c.undo : null),
          VsButton(icon: Icons.refresh_rounded, label: '새 판', onPressed: _newGameNow),
        ] else if (c.isOver || c.halted)
          // Wi‑Fi 대결: 판이 끝나면 "한 판 더"를 서로 눌러야 새 판이 시작된다
          VsRematchButton(asked: rematchAsked, offered: rematchOffered, opponentGone: opponentGone, onPressed: requestRematch),
        VsButton(icon: Icons.flag_outlined, label: '기권', onPressed: c.canResign ? _resign : null),
      ]);
}

class _MarkIconPainter extends CustomPainter {
  const _MarkIconPainter(this.side);

  final int side;

  @override
  void paint(Canvas canvas, Size size) {
    drawMark(canvas, side, Offset.zero & size, 1, strokeWidth: size.width * 0.16);
  }

  @override
  bool shouldRepaint(_MarkIconPainter old) => old.side != side;
}

/// 규칙 설명.
Future<void> showUtttRules(BuildContext context) => showVsRules(
      context,
      title: '궁극 틱택토 규칙',
      lines: const [
        '큰 판 안에 작은 틱택토 판이 9개 있어요.',
        '내가 둔 칸의 위치가 곧 상대가 다음에 둘 작은 판이에요. (예: 오른쪽 위 칸에 두면, 상대는 오른쪽 위 판에서 둬요)',
        '보내진 판이 이미 끝났으면, 상대는 아무 판에서나 둘 수 있어요.',
        '작은 판에서 세 칸을 한 줄로 만들면 그 판을 차지해요.',
        '차지한 판 세 개를 큰 판에서 한 줄로 이으면 이겨요!',
        '작은 판이 가득 차도 줄이 없으면 무승부 판이라 아무도 못 가져요.',
        '반짝이는 판이 지금 둘 수 있는 판이에요.',
      ],
      openTutorial: () => utttTutorial().open(context),
    );
