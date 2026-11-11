import 'package:flutter/material.dart';

import '../../../core/game_fx.dart';
import '../../../core/game_info.dart';
import '../../../core/game_speed.dart';
import '../../../core/leave_guard.dart';
import '../../../core/tablet_scale.dart';
import '../../../core/win_celebration.dart';
import '../../../core/win_sound.dart';
import '../../../versus/vs_screen_parts.dart';
import '../core/yacht_cpu.dart';
import '../core/yacht_rules.dart';
import '../data/yacht_history.dart';
import '../game/yacht_controller.dart';
import '../tutorial/yacht_tutorial.dart';
import 'yacht_dice_tray.dart';
import 'yacht_hint_sheet.dart';
import 'yacht_look.dart';
import 'yacht_score_table.dart';

/// 야추 플레이 화면 (한 기기로 번갈아 하기 · CPU와 대결).
class YachtScreen extends StatefulWidget {
  const YachtScreen({super.key, this.mode = PlayMode.local2p, this.players = 2, this.level = YachtLevel.normal, this.controller});

  final PlayMode mode;

  /// 앉은 사람 수 (2~4, CPU 포함).
  final int players;
  final YachtLevel level;

  /// 이어하던 판 · 시험용으로 미리 만든 컨트롤러.
  final YachtController? controller;

  @override
  State<YachtScreen> createState() => _YachtScreenState();
}

class _YachtScreenState extends State<YachtScreen> {
  late final YachtController c = widget.controller ?? YachtController(mode: widget.mode, players: widget.players, level: widget.level);
  bool _resultHandled = false;

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
    'end': const Fx(haptic: Haptic.heavy),
  });

  @override
  void initState() {
    super.initState();
    c.onFeedback = (kind) => _fx.play(context, kind);
    c.addListener(_onChanged);
    _savedAt = c.actions;
    _resultHandled = c.isOver;
    _saver.attach();
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
  }

  @override
  void dispose() {
    _fx.dispose();
    _saver.detach();
    c.removeListener(_onChanged);
    c.onFeedback = null;
    c.dispose();
    super.dispose();
  }

  void _onChanged() {
    if (c.isOver && !_resultHandled) {
      _resultHandled = true;
      final winners = c.game.winners;
      if (!c.vsCpu || winners.contains(c.humanSeat)) {
        WinSound.play(context);
        showWinCelebration(context, title: winners.length > 1 ? '무승부!' : (c.vsCpu ? '승리!' : '${c.name(winners.first)} 승리!'));
      }
      YachtHistory.add(YachtRecord(
        at: DateTime.now().millisecondsSinceEpoch,
        vsCpu: c.vsCpu,
        scores: [for (final card in c.game.cards) card.total],
        level: c.vsCpu ? c.level : null,
      ));
    } else if (!c.isOver) {
      if (_resultHandled) _saver.rearm(); // 한 판 더: 새 판은 다시 보관할 수 있다
      _resultHandled = false;
    }
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
          '한 차례에 주사위 5개를 3번까지 굴려요. 남기고 싶은 주사위는 눌러서 잡아요.',
          '점수판의 빈 칸 하나를 골라 점수를 적어요. 한 칸에는 한 번만 적을 수 있어요.',
          '맞는 족보가 없으면 아무 칸에나 0점을 적어야 해요.',
          '1~6 칸의 합이 63점 이상이면 보너스 35점을 받아요.',
          '12칸을 모두 채우면 끝나고, 합계가 가장 높은 사람이 이겨요.',
        ],
        openTutorial: () => yachtTutorial().open(context),
      );

  String get _who => c.name(c.game.turn);

  String get _status {
    final game = c.game;
    if (game.over) {
      final w = game.winners;
      if (w.length > 1) return '무승부! ${[for (final s in w) c.name(s)].join(', ')} · ${game.cards[w.first].total}점';
      if (c.vsCpu && w.first != c.humanSeat) return '${c.name(w.first)}이(가) 이겼어요 · ${game.cards[w.first].total}점';
      return '${c.vsCpu ? '이겼어요!' : '${c.name(w.first)} 승리!'} · ${game.cards[w.first].total}점';
    }
    if (c.rolling) return '$_who · 주사위를 굴리는 중…';
    if (!c.humanTurn) {
      final pick = c.pick;
      if (pick != null) return '$_who · ‘${pick.title}’ 칸에 적어요';
      return c.thinking ? '$_who · 생각하는 중…' : '$_who 차례';
    }
    final pick = c.pick;
    if (pick != null) return '$_who · ‘${pick.title}’ 칸에 ${yachtScore(pick, yachtCounts(game.dice))}점을 적을까요?';
    if (game.rollsUsed == 0) return '$_who 차례 · 주사위를 굴려요';
    if (game.rollsLeft == 0) return '$_who · 점수판에서 적을 칸을 골라요';
    return '$_who · 남길 주사위를 잡고 다시 굴리거나, 적을 칸을 골라요';
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final game = c.game;
        final color = game.over ? Theme.of(context).colorScheme.outline : kYachtSeatColors[game.turn];
        return SaveLeaveGuard(
          active: () => _saver.active,
          onSave: _saver.save,
          onDiscard: _saver.discard,
          child: VsGameScaffold(
            light: const [Color(0xFFEAF5EE), Color(0xFFD3E9DC)],
            dark: const [Color(0xFF14211B), Color(0xFF0E1713)],
            sideWidth: 420,
            topBar: VsTopBar(title: c.vsCpu ? '야추 · CPU ${c.level.label}' : '야추', gameId: 'yacht', onRules: _showRules),
            chips: const SizedBox.shrink(),
            banner: VsStatusBanner(text: _status, color: color),
            board: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 4), child: YachtScoreTable(c: c)),
            extras: [_tray(color)],
            bottom: VsBottomBar(children: [
              if (game.over)
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(140, 48),
                    textStyle: const TextStyle(fontFamily: 'NanumGothic', fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  onPressed: () => c.restart(),
                  icon: const Icon(Icons.refresh_rounded, size: 22),
                  label: const Text('한 판 더'),
                )
              else ...[
                VsButton(icon: Icons.lightbulb_outline_rounded, label: '힌트', onPressed: c.canHint ? () => showYachtHint(context, c) : null),
                VsButton(icon: Icons.refresh_rounded, label: '새 판', onPressed: _newGame),
              ],
            ]),
          ),
        );
      },
    );
  }

  /// 주사위 줄 + "굴리기" · "적기" 단추.
  Widget _tray(Color color) {
    final game = c.game;
    final human = c.humanTurn && !c.rolling;
    final pick = human ? c.pick : null;
    final tablet = MediaQuery.sizeOf(context).shortestSide >= kTabletMinSide;
    final style = FilledButton.styleFrom(
      minimumSize: Size(0, tablet ? 60 : 50),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      textStyle: TextStyle(fontFamily: 'NanumGothic', fontSize: tablet ? 18 : 15.5, fontWeight: FontWeight.w800),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: tablet ? 600 : 460),
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
              maxDie: tablet ? 92 : 64,
              onTap: human && game.canHold ? c.toggleHold : null,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('yacht-roll'),
                    style: style.copyWith(backgroundColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.disabled) ? null : kYachtColor)),
                    onPressed: human && game.canRoll ? c.roll : null,
                    icon: const Icon(Icons.casino_rounded, size: 22),
                    label: FittedBox(fit: BoxFit.scaleDown, child: Text(game.over ? '굴리기' : '굴리기 (${game.rollsLeft}번 남음)')),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('yacht-confirm'),
                    style: style,
                    onPressed: pick == null ? null : c.confirm,
                    icon: const Icon(Icons.edit_rounded, size: 20),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(pick == null ? '적을 칸을 눌러요' : '${pick.title} · ${yachtScore(pick, yachtCounts(game.dice))}점 적기'),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
