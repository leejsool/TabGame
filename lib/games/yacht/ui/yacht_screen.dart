import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/game_fx.dart';
import '../../../core/game_info.dart';
import '../../../core/game_speed.dart';
import '../../../core/leave_guard.dart';
import '../../../core/settings_scope.dart';
import '../../../core/tablet_scale.dart';
import '../../../core/win_celebration.dart';
import '../../../core/win_sound.dart';
import '../../../net/lan_connection.dart';
import '../../../net/lan_rejoin.dart';
import '../../../net/lan_rejoin_flow.dart';
import '../../../versus/vs_screen_parts.dart';
import '../core/yacht_cpu.dart';
import '../core/yacht_rules.dart';
import '../data/yacht_history.dart';
import '../game/yacht_controller.dart';
import '../tutorial/yacht_tutorial.dart';
import 'yacht_dice_sound.dart';
import 'yacht_dice_tray.dart';
import 'yacht_hint_sheet.dart';
import 'yacht_look.dart';
import 'yacht_score_table.dart';
import 'yacht_tally.dart';

part 'yacht_screen_net.dart';

/// 야추 플레이 화면 (한 기기로 번갈아 하기 · CPU와 대결 · 같은 Wi‑Fi로 함께).
class YachtScreen extends StatefulWidget {
  const YachtScreen({
    super.key,
    this.mode = PlayMode.local2p,
    this.players = 2,
    this.level = YachtLevel.normal,
    this.controller,
    this.humanSeat = 0,
    this.links,
    this.linkSeats,
    this.names,
    this.cpuSeats,
    this.rejoinDesk,
    this.threeKind = false,
  });

  /// 쓰리카드 칸을 넣고 하는 판인가 (이어하던 판은 컨트롤러가 알고 있다).
  final bool threeKind;

  final PlayMode mode;

  /// 앉은 사람 수 (2~4, CPU 포함).
  final int players;
  final YachtLevel level;

  /// 이어하던 판 · 시험용으로 미리 만든 컨트롤러.
  final YachtController? controller;

  /// 같은 Wi‑Fi 판에서 내 자리.
  final int humanSeat;

  /// 같은 Wi‑Fi 판에서 이어진 연결들. 방장은 손님마다 하나씩, 손님은 방장과의 연결 하나다 (모든 소식이 방장을 거쳐 오간다).
  final List<LanConnection>? links;

  /// 방장일 때: [links]의 각 손님이 앉은 자리. 이게 있으면 이 기기가 방장이다.
  final List<int>? linkSeats;

  /// 같은 Wi‑Fi 판의 자리별 이름과 CPU가 앉은 자리들.
  final List<String>? names;
  final List<int>? cpuSeats;

  /// 방장일 때: 판이 시작된 뒤에도 방 문을 열어 두고 나갔던 손님을 다시 받아 주는 접수처.
  final LanRejoinDesk? rejoinDesk;

  @override
  State<YachtScreen> createState() => _YachtScreenState();
}

class _YachtScreenState extends State<YachtScreen> {
  /// 다른 파일(part)에 나눠 둔 화면 조각에서 상태를 바꿀 때 쓴다.
  void _update(VoidCallback fn) => setState(fn);

  late final YachtController c = widget.controller ??
      YachtController(
        mode: widget.mode,
        players: widget.players,
        level: widget.level,
        humanSeat: widget.humanSeat,
        cpuSeats: widget.cpuSeats,
        cpuHost: widget.linkSeats != null, // (방을 연 기기가 CPU의 차례를 진행한다)
        names: widget.names,
        threeKind: widget.threeKind,
      );
  bool _resultHandled = false;

  // ── 같은 Wi‑Fi 대결 (yacht_screen_net.dart) ──
  List<LanConnection> get _links => c.online ? (widget.links ?? const []) : const [];
  final List<StreamSubscription<Map<String, dynamic>>> _linkSubs = [];

  /// 방장인가 (그러면 손님이 보낸 소식이 그 손님 차례의 것인지 확인하고 다른 손님들에게 전해 준다).
  bool get _hub => widget.linkSeats != null;
  bool _opponentGone = false;
  bool _leaving = false;

  /// 방장이 나간 손님의 자리를 돌본다 (CPU가 대신하기 · 돌아오면 되찾기). 방장 화면에서만 있다.
  LanHubKeeper? _keeper;
  bool _ticketDropped = false;

  /// 손님: 방장이 일부러 나간다고 알려 왔는가 (그러면 다시 들어갈 방이 없다).
  bool _hostLeft = false;

  /// "한 판 더"를 누른 자리들 (나 포함). 사람이 모두 누르면 새 판이 시작된다.
  final Set<int> _againSeats = {};
  bool get _rematchAsked => _againSeats.contains(c.humanSeat);

  /// 이어하기용으로 보관하는 도우미.
  late final GameSaver _saver = GameSaver(gameId: 'yacht', snapshot: () => c.savable ? c.toJson() : null);
  int _savedAt = -1;

  /// 알림 종류 → 진동·소리 (설정의 진동·효과음 스위치를 따른다).
  final GameFx _fx = GameFx({
    'roll': const Fx(haptic: Haptic.light),
    'land': const Fx(haptic: Haptic.medium),
    'hold': const Fx(haptic: Haptic.select),
    'score': const Fx(haptic: Haptic.light),
    'zero': const Fx(haptic: Haptic.vibrate),
    'yahtzee': const Fx(haptic: Haptic.heavy, sound: 'sfx/tada_short.mp3', volume: 0.85), // 야추 성공 "짜잔"(짧은)
    'end': const Fx(haptic: Haptic.heavy),
  });

  /// 주사위를 굴리는 소리 (4개 이상이면 "여러 개" 소리, 3개 이하면 개수만큼 서로 다른 "한 개" 소리).
  final YachtDiceSound _diceSound = YachtDiceSound();

  /// 굴리기가 시작될 때(아직 판에 적용하기 전) 이번에 굴러가는 주사위 수: 처음엔 5개, 다시 굴릴 땐 고정하지 않은 것만.
  /// 이번에 굴러가는 주사위들이 던져지는 순간(밀리초).
  List<int> _launchDelays = const [];

  int get _rollingCount => c.game.rollsUsed == 0 ? kYachtDice : c.game.held.where((h) => !h).length;

  @override
  void initState() {
    super.initState();
    c.onFeedback = (kind) {
      _fx.play(context, kind);
      if (kind == 'roll') {
        // 던지는 순간을 주사위마다 어긋나게 정해서 소리와 주사위 움직임이 함께 쓴다
        _launchDelays = _diceSound.launchDelays(_rollingCount);
        if (SettingsScope.of(context).sound) _diceSound.play(_rollingCount, delays: _launchDelays);
      }
    };
    c.addListener(_onChanged);
    _savedAt = c.actions;
    _resultHandled = c.isOver;
    if (c.online) {
      _startNet();
    } else {
      _saver.attach();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
  }

  @override
  void dispose() {
    _fx.dispose();
    _diceSound.dispose();
    _saver.detach();
    _stopNet();
    c.removeListener(_onChanged);
    c.onFeedback = null;
    c.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (c.online && c.isOver) _onNetGameOver();
    if (c.isOver && !_resultHandled) {
      _resultHandled = true;
      final winners = c.game.winners;
      if (c.oneSeat ? winners.contains(c.humanSeat) : winners.any((w) => !c.isCpu(w))) {
        // 점수판이 맨 윗줄부터 합계를 더해 보여 주는 동안은 기다렸다가, 최종 점수가 나온 뒤에 축하한다
        Future<void>.delayed(YachtTally(c.game).duration + YachtTally.holdTime, () {
          if (!mounted || !c.isOver) return;
          WinSound.play(context);
          showWinCelebration(context, title: winners.length > 1 ? '무승부!' : (c.oneSeat ? '승리!' : '${c.name(winners.first)} 승리!'));
        });
      }
      YachtHistory.add(YachtRecord(
        at: DateTime.now().millisecondsSinceEpoch,
        vsCpu: c.vsCpu,
        scores: [for (final card in c.game.cards) card.total],
        level: !c.online && c.cpuSeats.isNotEmpty ? c.level : null,
        bots: c.online ? 0 : c.cpuSeats.length,
        online: c.online,
        seat: c.oneSeat ? c.humanSeat : 0,
      ));
    } else if (!c.isOver) {
      if (_resultHandled) _saver.rearm(); // 한 판 더: 새 판은 다시 보관할 수 있다
      _resultHandled = false;
    }
    if (c.online) return;
    // 굴리거나 적을 때마다 이어하기용으로 보관한다 (끝난 판이면 보관된 것을 지운다)
    if (c.isOver) {
      _saver.finish();
    } else if (c.actions != _savedAt) {
      _savedAt = c.actions;
      _saver.save();
    }
  }

  /// 하던 판 도중에 "새 판"을 눌렀다: 하던 판이 사라지니 먼저 묻는다.
  Future<void> _newGame() async {
    if (_saver.active && !await confirmNewGame(context)) return;
    if (!mounted) return;
    c.restart(rotate: c.isOver);
  }

  void _showRules() => showVsRules(
        context,
        title: '야추 규칙',
        lines: const [
          '한 차례에 주사위 5개를 3번까지 굴려요. 남기고 싶은 주사위는 눌러서 고정해요.',
          '점수판의 빈 칸 하나를 골라 점수를 적어요. 한 칸에는 한 번만 적을 수 있어요.',
          '맞는 족보가 없으면 아무 칸에나 0점을 적어야 해요.',
          '1~6 칸의 합이 63점 이상이면 보너스 35점을 받아요.',
          '풀하우스 25점 · 스몰 스트레이트 30점 · 라지 스트레이트 40점 · 야추 50점은 점수가 정해져 있어요.',
          '야추 칸에 50점을 적은 뒤 야추를 또 굴려 적으면 그때마다 보너스 100점!',
          '쓰는 칸(12칸, 쓰리카드를 넣으면 13칸)을 모두 채우면 끝나고, 합계가 가장 높은 사람이 이겨요.',
        ],
        openTutorial: () => yachtTutorial().open(context),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final game = c.game;
        final color = game.over ? Theme.of(context).colorScheme.outline : kYachtSeatColors[game.turn];
        // 핸드폰 가로 모드: 옆 칸을 좁히고(주사위는 두 줄), 점수판은 가운데에서 둘로 잘라 가로로 놓는다
        final screen = MediaQuery.sizeOf(context);
        final phoneLandscape = screen.width > screen.height * 1.2 && screen.shortestSide < kTabletMinSide;
        return _guard(
          child: VsGameScaffold(
            light: const [Color(0xFFEAF5EE), Color(0xFFD3E9DC)],
            dark: const [Color(0xFF14211B), Color(0xFF0E1713)],
            sideWidth: phoneLandscape ? 214 : 420,
            topBar: VsTopBar(title: c.online ? '야추 · 같은 Wi‑Fi' : (c.cpuSeats.isNotEmpty ? '야추 · CPU ${c.level.label}' : '야추'), gameId: 'yacht', onRules: _showRules),
            chips: const SizedBox.shrink(),
            banner: const SizedBox.shrink(),
            board: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: YachtScoreTable(c: c)),
            extras: [_tray(color, compact: phoneLandscape)],
            bottom: VsBottomBar(children: [
              if (game.over)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(140, 48),
                    textStyle: const TextStyle(fontFamily: 'NanumGothic', fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  onPressed: !c.online ? () => c.restart() : (_rematchAsked || _opponentGone ? null : _requestRematch),
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                  label: Text(c.online ? _rematchLabel : '한 판 더'),
                )
              else ...[
                VsButton(icon: Icons.lightbulb_outline_rounded, label: '힌트', onPressed: c.canHint ? () => showYachtHint(context, c) : null),
                if (!c.online) VsButton(icon: Icons.refresh_rounded, label: '새 판', onPressed: _newGame),
              ],
            ]),
          ),
        );
      },
    );
  }

  /// 나가기 전에: 한 기기·CPU 대결은 보관할지 묻고, 같은 Wi‑Fi 판은 정말 나갈지 묻는다.
  Widget _guard({required Widget child}) {
    if (!c.online) {
      return SaveLeaveGuard(active: () => _saver.active, onSave: _saver.save, onDiscard: _saver.discard, child: child);
    }
    return PopScope(
      canPop: c.isOver || _opponentGone,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: child,
    );
  }

  /// 주사위 줄 + "굴리기" · "적기" 단추.
  Widget _tray(Color color, {bool compact = false}) {
    final game = c.game;
    final human = c.humanTurn && !c.rolling;
    final pick = human ? c.pick : null;
    final tablet = MediaQuery.sizeOf(context).shortestSide >= kTabletMinSide;
    final style = FilledButton.styleFrom(
      minimumSize: Size(0, compact ? 42 : (tablet ? 60 : 50)),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      textStyle: TextStyle(fontFamily: 'NanumGothic', fontSize: compact ? 14 : (tablet ? 18 : 15.5), fontWeight: FontWeight.w800),
    );
    final roll = FilledButton.icon(
      key: const ValueKey('yacht-roll'),
      style: style.copyWith(backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? null : kYachtColor)),
      onPressed: human && game.canRoll ? c.roll : null,
      icon: const Icon(Icons.casino_rounded, size: 22),
      label: FittedBox(fit: BoxFit.scaleDown, child: Text(game.over ? '굴리기' : '굴리기 (${game.rollsLeft}번 남음)')),
    );
    final confirm = FilledButton.icon(
      key: const ValueKey('yacht-confirm'),
      style: style,
      onPressed: pick == null ? null : c.confirm,
      icon: const Icon(Icons.edit_rounded, size: 20),
      label: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(pick == null ? '적을 칸을 눌러요' : '${pick.title} · ${yachtScore(pick, yachtCounts(game.dice))}점 적기'),
      ),
    );
    return Padding(
      padding: EdgeInsets.fromLTRB(compact ? 8 : 16, 4, compact ? 8 : 16, 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: compact ? 220 : (tablet ? 600 : 460)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            YachtDiceTray(
              dice: game.dice,
              held: game.held,
              rolling: c.rolling,
              target: c.rollTarget,
              rollTime: GameSpeed.scale(const Duration(milliseconds: kYachtRollMs)),
              accent: color,
              maxDie: compact ? 54 : (tablet ? 92 : 64),
              twoRows: compact,
              launchDelays: _launchDelays,
              onTap: human && game.canHold ? c.toggleHold : null,
            ),
            const SizedBox(height: 6),
            // 좁은 옆 칸(핸드폰 가로 모드)에서는 단추를 위아래로 쌓는다
            if (compact) ...[
              SizedBox(width: double.infinity, child: roll),
              const SizedBox(height: 6),
              SizedBox(width: double.infinity, child: confirm),
            ] else
              Row(
                children: [
                  Expanded(child: roll),
                  const SizedBox(width: 8),
                  Expanded(child: confirm),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// 방장이 보낸 `resume`(나갔다 다시 들어올 때 받는 판의 모습)으로 야추 화면을 만든다. 맞지 않는 내용이면 null.
Widget? yachtResume(Map<String, dynamic> resume, LanConnection conn) {
  final seat = resume['seat'], snap = resume['snap'];
  if (seat is! int || snap is! Map<String, dynamic>) return null;
  final c = YachtControllerRejoin.fromWifiSnapshot(snap, humanSeat: seat);
  if (c == null) return null;
  return YachtScreen(mode: PlayMode.wifi, players: c.players, humanSeat: seat, names: c.names, controller: c, links: [conn]);
}
