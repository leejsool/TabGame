import 'package:flutter/material.dart';

import '../core/game_info.dart';
import '../core/game_registry.dart';
import '../core/settings.dart';
import 'game_icons.dart';

/// 설정 → "메인 화면에 보일 게임": 게임마다 켜고 끄는 스위치.
///
/// 처음에는 모든 게임이 켜져 있다. 절대 안 할 게임은 꺼서 메인 화면을 정리할 수 있다.
/// (꺼도 게임과 기록은 그대로 남고, 언제든 다시 켤 수 있다)
class GameVisibilityScreen extends StatelessWidget {
  const GameVisibilityScreen({super.key, required this.settings});

  final Settings settings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('메인 화면에 보일 게임'),
        actions: [
          ListenableBuilder(
            listenable: settings,
            builder: (context, _) => TextButton(
              key: const ValueKey('visibility-show-all'),
              onPressed: settings.hiddenGames.isEmpty ? null : settings.showAllGames,
              child: const Text('모두 켜기'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListenableBuilder(
          listenable: settings,
          builder: (context, _) {
            final shown = allGames.where((g) => settings.isGameVisible(g.id)).length;
            return ListView(
              padding: EdgeInsets.only(top: 4, bottom: 16 + MediaQuery.viewPaddingOf(context).bottom),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  child: Text(
                    '꺼 둔 게임은 메인 화면에서 숨겨요. 게임과 기록은 그대로 남아 있고, 언제든 다시 켤 수 있어요.\n'
                    '지금 ${allGames.length}개 중 $shown개가 보여요.',
                    key: const ValueKey('visibility-summary'),
                    style: TextStyle(height: 1.45, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                  ),
                ),
                for (final g in allGames) _GameSwitch(game: g, settings: settings),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _GameSwitch extends StatelessWidget {
  const _GameSwitch({required this.game, required this.settings});

  final GameInfo game;
  final Settings settings;

  @override
  Widget build(BuildContext context) {
    return SwitchListTile(
      key: ValueKey('visible-${game.id}'),
      secondary: Container(
        width: 46,
        height: 46,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(color: game.color, borderRadius: BorderRadius.circular(13)),
        child: GameIcon(game: game, size: 36),
      ),
      title: Text(game.title, style: const TextStyle(fontWeight: FontWeight.w800)),
      subtitle: Text(game.tagline),
      value: settings.isGameVisible(game.id),
      onChanged: (v) => settings.setGameVisible(game.id, v),
    );
  }
}
