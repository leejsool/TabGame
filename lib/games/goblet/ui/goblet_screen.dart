import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/game_info.dart';
import '../../../core/settings_scope.dart';
import '../../../records/records_screen.dart';
import '../core/goblet_ai.dart';
import '../data/goblet_history.dart';
import '../core/goblet_rules.dart';
import '../game/goblet_controller.dart';
import 'goblet_piece.dart';
import 'goblet_stage.dart';

/// 고블렛 고블러스 플레이 화면.
class GobbletScreen extends StatefulWidget {
  const GobbletScreen({
    super.key,
    this.mode = PlayMode.local2p,
    this.humanTeam = Team.red,
    this.level = CpuLevel.normal,
    this.controller,
  });

  final PlayMode mode;
  final Team humanTeam;
  final CpuLevel level;

  /// (테스트용) 미리 만든 컨트롤러를 쓰고 싶을 때.
  final GobbletController? controller;

  @override
  State<GobbletScreen> createState() => _GobbletScreenState();
}

class _GobbletScreenState extends State<GobbletScreen> {
  // 화면이 직접 소유한다: 화면이 다시 빌드되어도 판이 사라지지 않는다.
  late final GobbletController c = widget.controller ??
      GobbletController(
        mode: widget.mode,
        humanTeam: widget.humanTeam,
        level: widget.level,
      );
  bool _resultShown = false;

  @override
  void initState() {
    super.initState();
    c.onFeedback = _feedback;
    c.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
  }

  @override
  void dispose() {
    c.removeListener(_onChanged);
    c.onFeedback = null;
    c.dispose();
    super.dispose();
  }

  void _feedback(String kind) {
    if (!SettingsScope.of(context).haptics) return;
    switch (kind) {
      case 'pick':
        HapticFeedback.selectionClick();
      case 'drop':
        HapticFeedback.lightImpact();
      case 'win':
        HapticFeedback.heavyImpact();
    }
  }

  void _onChanged() {
    final r = c.result;
    if (r != null && !_resultShown) {
      _resultShown = true;
      // 한 판이 끝날 때마다 한 번만 기록한다
      GobbletHistory.add(GobbletRecord(
        at: DateTime.now().millisecondsSinceEpoch,
        vsCpu: c.vsCpu,
        winner: r.winner,
        moves: c.moveCount,
        level: c.vsCpu ? c.level : null,
        human: c.vsCpu ? c.humanTeam : null,
        byReveal: r.byReveal,
      ));
      Future<void>.delayed(const Duration(milliseconds: 1300), _showResult);
    } else if (r == null) {
      _resultShown = false;
    }
  }

  Future<void> _showResult() async {
    if (!mounted || c.result == null) return;
    final again = await showDialog<bool>(
      context: context,
      builder: (_) => _ResultDialog(controller: c),
    );
    if (!mounted) return;
    if (again == true) {
      c.restart();
    } else if (again == false) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? const [Color(0xFF1F2430), Color(0xFF181B24)]
                : const [Color(0xFFFFF3DC), Color(0xFFFFE6C9)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _topBar(scheme),
              _statusBanner(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
                  child: GobbletStage(controller: c),
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: '뒤로',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Text(
            '고블렛 고블러스',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const Spacer(),
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () => openRecords(context, game: 'goblet_gobblers'),
          ),
          IconButton(
            tooltip: '규칙',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => showGobbletRules(context),
          ),
        ],
      ),
    );
  }

  Widget _statusBanner() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final r = c.result;
        final String text;
        final Team? team;
        if (r != null) {
          if (r.kind == ResultKind.draw) {
            text = '무승부예요 (같은 모양이 3번 반복됐어요)';
            team = null;
          } else {
            text = r.byReveal
                ? '${r.winner!.label} 승리! 말을 들어 올리자 줄이 드러났어요'
                : '${r.winner!.label} 승리!';
            team = r.winner;
          }
        } else if (c.thinking) {
          text = 'CPU가 생각하는 중…';
          team = c.turn;
        } else if (c.vsCpu && c.turn == c.humanTeam) {
          text = '내 차례예요. 말을 끌어다 칸에 놓아요';
          team = c.turn;
        } else {
          text = '${c.turn.label} 차례예요';
          team = c.turn;
        }
        final pal = team == null ? null : TeamPalette.of(team);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: (pal?.main ?? Colors.grey).withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: (pal?.main ?? Colors.grey).withValues(alpha: 0.5)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (team != null)
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(color: pal!.main, shape: BoxShape.circle),
                ),
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bottomBar() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: c.canUndo ? c.undo : null,
              icon: const Icon(Icons.undo_rounded),
              label: const Text('되돌리기'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => c.restart(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('새 판'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({required this.controller});

  final GobbletController controller;

  @override
  Widget build(BuildContext context) {
    final r = controller.result!;
    final c = controller;
    String title;
    String body;
    Team? face;
    if (r.kind == ResultKind.draw) {
      title = '무승부';
      body = '같은 모양이 3번 나와서 비겼어요.';
    } else if (c.vsCpu) {
      final me = r.winner == c.humanTeam;
      title = me ? '이겼어요! 🎉' : 'CPU가 이겼어요';
      body = me ? '${r.winner!.label} 승리!' : '다음엔 꼭 이겨 봐요!';
      face = r.winner;
    } else {
      title = '${r.winner!.label} 승리! 🎉';
      body = r.byReveal ? '말을 들어 올리는 바람에 상대 줄이 완성됐어요.' : '축하해요!';
      face = r.winner;
    }
    return AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (face != null)
            SizedBox(
              width: 96,
              height: 96,
              child: CustomPaint(
                painter: GobblerPainter(team: face, size: 3, mood: PieceMood.happy),
              ),
            ),
          const SizedBox(height: 12),
          Text(body, textAlign: TextAlign.center),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('메뉴로')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('한 판 더')),
      ],
    );
  }
}

/// 규칙 설명.
Future<void> showGobbletRules(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('고블렛 고블러스 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _RuleLine('가로·세로·대각선으로 내 말 3개가 "위에서 보이게" 나란히 놓이면 이겨요.'),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final t in Team.values)
                  Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          for (var s = 1; s <= 3; s++)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: SizedBox(
                                width: 22.0 + s * 12,
                                height: 22.0 + s * 12,
                                child: CustomPaint(painter: GobblerPainter(team: t, size: s)),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(t == Team.red ? '빨강팀 (뾰족 귀)' : '파랑팀 (둥근 귀)',
                          style: const TextStyle(fontSize: 12)),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            const _RuleLine('말은 크기가 3가지(점 1·2·3개)이고, 크기마다 2개씩 있어요.'),
            const _RuleLine('큰 말은 작은 말을 덮을 수 있어요. 내 말도, 상대 말도요!'),
            const _RuleLine('덮인 말은 보이지 않아요. 아래 깔린 말은 칸 모서리의 작은 점으로 알 수 있어요.'),
            const _RuleLine('내 차례에 대기 중인 말을 올리거나, 판 위의 내 말(맨 위에 보이는 것)을 옮겨요.'),
            const _RuleLine('조심! 말을 들어 올렸을 때 상대 줄이 드러나면, 막지 못하는 한 상대가 이겨요.'),
            const _RuleLine('같은 모양이 3번 반복되면 무승부예요.'),
          ],
        ),
      ),
      actions: [
        FilledButton(onPressed: () => Navigator.pop(context), child: const Text('알겠어요')),
      ],
    ),
  );
}

class _RuleLine extends StatelessWidget {
  const _RuleLine(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
        ],
      ),
    );
  }
}
