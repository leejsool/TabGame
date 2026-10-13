import 'package:flutter/material.dart';

import '../core/game_info.dart';
import '../core/settings_scope.dart';
import '../games/coming_soon_screen.dart';
import '../tutorial/tutorial_progress.dart';

/// 게임을 시작한다. 모드가 여러 개면 먼저 고르게 하고, 하나뿐이면 바로 들어간다.
Future<void> launchGame(BuildContext context, GameInfo game) async {
  final PlayMode? mode;
  if (game.modes.length == 1) {
    mode = game.modes.first;
  } else {
    mode = await showModalBottomSheet<PlayMode>(
      context: context,
      showDragHandle: true,
      // 화면이 낮아도(가로 모드 폰 등) 넘치지 않고 스크롤되게 한다
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 560),
      builder: (_) => _ModeSheet(game: game),
    );
  }
  if (mode == null || !context.mounted) return;

  // 처음 여는 게임이면 먼저 게임 방법을 안내한다. 언제든 건너뛸 수 있고, 한 번 보여주면
  // (건너뛰어도) 다시 자동으로 뜨지 않는다.
  final tutorial = game.tutorial?.call();
  if (game.isReady && tutorial != null && SettingsScope.of(context).showTutorials) {
    final seen = await TutorialProgress.isSeen(game.id);
    if (!context.mounted) return;
    if (!seen) {
      await TutorialProgress.markSeen(game.id);
      if (!context.mounted) return;
      await tutorial.open(context, firstTime: true);
      if (!context.mounted) return;
    }
  }

  final chosen = mode;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (ctx) =>
          game.builder?.call(ctx, chosen) ??
          ComingSoonScreen(game: game, mode: chosen),
    ),
  );
}

class _ModeSheet extends StatelessWidget {
  const _ModeSheet({required this.game});

  final GameInfo game;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              game.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 4),
            const Text('어떻게 할까요?'),
            const SizedBox(height: 16),
            for (final m in game.modes)
              Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: game.color.withValues(alpha: 0.15),
                    foregroundColor: game.color,
                    child: Icon(m.icon),
                  ),
                  title: Text(m.label,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(m.description),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).pop(m),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
