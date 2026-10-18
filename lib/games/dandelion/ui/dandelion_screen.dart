import '../../../core/win_celebration.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/game_fx.dart';
import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../core/leave_guard.dart';
import '../../../core/win_sound.dart';
import '../../../core/settings_scope.dart';
import '../../../net/lan_connection.dart';
import '../core/dandelion_ai.dart';
import '../core/dandelion_rules.dart';
import '../data/dandelion_history.dart';
import '../game/dandelion_controller.dart';
import '../tutorial/dandelion_tutorial.dart';
import 'dandelion_art.dart';
import 'dandelion_board.dart';
import 'dandelion_lesson_screen.dart';
import '../../../versus/vs_link.dart';
import '../../../versus/vs_screen_parts.dart';

/// 민들레 플레이 화면.
class DandelionScreen extends StatefulWidget {
  const DandelionScreen({
    super.key,
    this.mode = PlayMode.local2p,
    this.humanRole = Role.dandelion,
    this.level = DandLevel.normal,
    this.controller,
    this.link,
  });

  final PlayMode mode;
  final Role humanRole;
  final DandLevel level;

  /// 같은 Wi‑Fi 대결([PlayMode.wifi])에서 상대 기기와의 연결. 이 화면이 닫을 때 같이 닫는다.
  final LanConnection? link;

  /// (테스트용) 미리 만든 컨트롤러.
  final DandelionController? controller;

  @override
  State<DandelionScreen> createState() => _DandelionScreenState();
}

class _DandelionScreenState extends State<DandelionScreen> with VsTwoPlayer {
  // 화면이 직접 소유한다: 화면이 다시 빌드되어도 판이 사라지지 않는다.
  late final DandelionController c = widget.controller ??
      DandelionController(mode: widget.mode, humanRole: widget.humanRole, level: widget.level);
  bool _resultHandled = false;

  /// 알림 종류 → 진동·소리 (설정의 진동·효과음 스위치를 따른다).
  final GameFx _fx = GameFx({
    'plant': const Fx(haptic: Haptic.select),
    'wind': const Fx(haptic: Haptic.light),
    'win': const Fx(haptic: Haptic.heavy),
  });

  // ── 공통 대결 동작([VsTwoPlayer])에 알려 주는 것 ──
  /// 한 기기·CPU 대결을 이어하기용으로 보관하는 도우미 (같은 Wi‑Fi 대결은 보관하지 않는다).
  @override
  late final GameSaver vsSaver = GameSaver(gameId: 'dandelion', snapshot: () => c.savable ? c.toJson() : null);
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
    c.restart(swapRoles: true); // (민들레/바람이 바뀐다)
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
    await DandelionHistory.add(DandelionRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: false,
      online: true,
      winner: c.humanRole,
      moves: c.moveCount,
      empties: c.state.emptyCount,
      human: c.humanRole,
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
      if (!c.oneSeat || c.winner == c.humanRole) {
        WinSound.play(context);
        showWinCelebration(context, title: '승리!');
      } // 이겼을 때 "짜잔"
      DandelionHistory.add(DandelionRecord(
        at: DateTime.now().millisecondsSinceEpoch,
        vsCpu: c.vsCpu,
        online: c.online,
        winner: c.winner!,
        moves: c.moveCount,
        empties: c.state.emptyCount,
        level: c.vsCpu ? c.level : null,
        human: c.oneSeat ? c.humanRole : null,
      ));
      Future<void>.delayed(const Duration(milliseconds: 2600), _showResult);
    } else if (!c.isOver) {
      _resultHandled = false;
    }
    vsAutosave();
  }

  /// 하던 판 도중에 "새 판" 단추를 눌렀다: 하던 판이 사라지니 먼저 묻는다.
  Future<void> _newGameNow() async {
    if (!await vsConfirmNewGame()) return;
    _resultHandled = false;
    c.restart();
  }

  Future<void> _resign() async {
    if (!c.canResign) return;
    final role = c.resigningRole;
    final ok = await confirmGiveUp(
      context,
      detail: c.vsCpu
          ? 'CPU의 승리로 기록돼요.'
          : c.online
              ? '상대의 승리로 기록돼요.'
              : '${role.label}이(가) 기권하고, ${role.other.label}의 승리로 기록돼요.',
      retry: false,
      verb: '기권',
    );
    if (!ok || !mounted || !c.resign()) return;
    _resultHandled = true; // (끝난 판으로 한 번 더 기록되지 않게)
    vsLink?.send(const {'t': 'resign'});
    await DandelionHistory.add(DandelionRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: c.vsCpu,
      online: c.online,
      winner: role.other,
      moves: c.moveCount,
      empties: c.state.emptyCount,
      level: c.vsCpu ? c.level : null,
      human: c.oneSeat ? c.humanRole : null,
      resigned: true,
    ));
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: c.vsCpu ? 'CPU ${c.level.label} · ${c.moveCount}수' : '${role.label} 기권 · ${c.moveCount}수',
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
    final w = c.winner!;
    final left = c.state.emptyCount;
    String title, body;
    if (c.oneSeat) {
      final me = w == c.humanRole;
      title = me ? '이겼어요! 🎉' : (c.vsCpu ? 'CPU가 이겼어요' : '상대가 이겼어요');
      body = w == Role.dandelion
          ? (me ? '초원이 꽃과 씨앗으로 가득 찼어요!' : '초원이 꽃과 씨앗으로 가득 찼어요. 다음엔 바람을 잘 골라 봐요!')
          : (me ? '빈칸이 $left칸 남았어요. 바람이 이겼어요!' : '빈칸이 $left칸 남았어요. 다음엔 꽃을 더 잘 심어 봐요!');
    } else {
      title = '${w.label} 승리! 🎉';
      body = w == Role.dandelion ? '초원이 꽃과 씨앗으로 가득 찼어요!' : '빈칸이 $left칸 남았어요!';
    }
    final again = await showDialog<bool>(
      context: context,
      builder: (_) => VsResultDialog(
        title: title,
        body: '$body\n(${c.moveCount}수)',
        art: SizedBox(width: 72, height: 72, child: CustomPaint(painter: _RoleIconPainter(w))),
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
    final s = c.state;
    if (c.isOver) {
      final w = c.winner!;
      if (c.oneSeat) return w == c.humanRole ? '이겼어요! 🎉' : (c.vsCpu ? 'CPU가 이겼어요' : '상대가 이겼어요');
      return '${w.label} 승리!';
    }
    if (opponentGone) return '상대와 연결이 끊겼어요';
    if (c.halted) return rematchAsked ? '상대가 한 판 더를 받아 주기를 기다리는 중이에요…' : '기권으로 끝난 판이에요';
    if (c.thinking) return c.cpuRole == Role.dandelion ? 'CPU가 꽃을 심는 중…' : 'CPU가 바람을 고르는 중…';
    if (c.online && s.turn != c.humanRole) return '상대 차례 · ${s.turn == Role.dandelion ? '상대가 꽃을 심고 있어요…' : '상대가 바람을 고르고 있어요…'}';
    final who = c.oneSeat ? (s.turn == c.humanRole ? '내 차례' : 'CPU 차례') : '${s.turn.label} 차례';
    final what = s.turn == Role.dandelion ? '꽃을 심을 칸을 누르세요' : '불어 보낼 방향을 고르세요';
    return '$who · $what';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => vsLeaveGuard(
        VsGameScaffold(
          light: const [Color(0xFFE9F5D6), Color(0xFFD3EBB2)],
          dark: const [Color(0xFF1F2A24), Color(0xFF18201B)],
          topBar: VsTopBar(title: '민들레', gameId: 'dandelion', onRules: () => showDandelionRules(context), onLesson: () => openDandelionLesson(context)),
          chips: VsPlayerChips(chips: [_chip(Role.dandelion), _chip(Role.wind)]),
          banner: VsStatusBanner(text: _status, color: c.isOver ? Colors.grey : roleColor(c.state.turn)),
          board: _board,
          extras: [_compass()],
          landscapeExtras: [_compass(size: 190), const SizedBox(height: 8)],
          bottom: _bottomBar(),
        ),
      ),
    );
  }

  late final Widget _board = Padding(
    padding: const EdgeInsets.all(10),
    child: Center(
      child: DandelionBoard(
        controller: c,
        onPlant: (cell) {
          if (!c.plant(cell) && SettingsScope.of(context).haptics) HapticFeedback.lightImpact();
        },
      ),
    ),
  );

  Widget _compass({double size = 150}) {
    final canBlow = c.humanCanAct && c.state.turn == Role.wind;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DandelionCompass(
          size: size,
          usedMask: c.state.usedWinds,
          enabled: canBlow,
          windsLeft: c.state.windsLeft,
          onBlow: (d) {
            if (!c.blow(d) && SettingsScope.of(context).haptics) HapticFeedback.lightImpact();
          },
        ),
        const SizedBox(height: 2),
        Text(
          canBlow ? '화살표를 눌러 바람을 불어요' : '바람은 방향마다 한 번씩',
          style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
        ),
      ],
    );
  }

  /// 민들레 / 바람 칩: 지금 차례인 쪽이 강조된다.
  Widget _chip(Role role) {
    final who = c.oneSeat ? (role == c.humanRole ? ' · 나' : (c.vsCpu ? ' · CPU' : ' · ${vsLink?.peerNick ?? '상대'}')) : '';
    return VsPlayerChip(
      icon: SizedBox(width: 24, height: 24, child: CustomPaint(painter: _RoleIconPainter(role))),
      label: '${role.label}$who',
      color: roleColor(role),
      active: !c.isOver && c.state.turn == role,
    );
  }

  Widget _bottomBar() => VsBottomBar(children: [
        if (!c.online) ...[
          VsButton(icon: Icons.undo_rounded, label: '되돌리기', onPressed: c.canUndo ? c.undo : null),
          VsButton(icon: Icons.refresh_rounded, label: '새 판', onPressed: _newGameNow),
        ] else if (c.isOver || c.halted)
          // Wi‑Fi 대결: 판이 끝나면 "한 판 더"를 서로 눌러야 새 판이 시작된다 (민들레/바람이 바뀐다)
          VsRematchButton(asked: rematchAsked, offered: rematchOffered, opponentGone: opponentGone, onPressed: requestRematch),
        VsButton(icon: Icons.flag_outlined, label: '기권', onPressed: c.canResign ? _resign : null),
      ]);
}

/// 역할을 나타내는 작은 그림 (민들레 = 꽃, 바람 = 휘날리는 선).
class _RoleIconPainter extends CustomPainter {
  const _RoleIconPainter(this.role);

  final Role role;

  @override
  void paint(Canvas canvas, Size size) => paintRoleIcon(canvas, size, role);

  @override
  bool shouldRepaint(_RoleIconPainter old) => old.role != role;
}

/// 민들레는 꽃, 바람은 돌돌 말리는 바람 줄 ([paintWindGust]).
void paintRoleIcon(Canvas canvas, Size size, Role role) {
  if (role == Role.dandelion) {
    drawFlower(canvas, size.center(Offset.zero), size.width * 0.5);
    return;
  }
  paintWindGust(canvas, Offset.zero & size, kWindColor, thickness: 0.1);
}

/// 규칙 설명.
Future<void> showDandelionRules(BuildContext context) => showVsRules(
      context,
      title: '민들레 규칙',
      lines: const [
        '민들레는 5×5 초원 전체를 꽃과 씨앗으로 덮는 게 목표예요.',
        '바람은 한 칸이라도 덮이지 않게 하는 게 목표예요.',
        '민들레가 먼저 아무 칸에나 꽃을 심어요.',
        '그다음 바람이 방향을 하나 골라요. 그 방향으로 모든 꽃에서 씨앗이 날아가, 길에 있는 빈칸을 채워요.',
        '바람은 8방향 가운데 7방향만 불 수 있고, 같은 방향은 한 번뿐이에요.',
        '이어서 민들레가 또 꽃을 심어요. 빈칸이나 씨앗이 있는 칸에 심을 수 있어요.',
        '씨앗은 꽃에서만 날아가고, 씨앗에서는 날아가지 않아요.',
        '일곱 번째 바람이 지난 뒤 초원이 가득 차 있으면 민들레, 빈칸이 하나라도 있으면 바람의 승리예요.',
      ],
      openTutorial: () => dandelionTutorial().open(context),
    );
