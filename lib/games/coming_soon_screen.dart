import '../hub/game_icons.dart';
import 'package:flutter/material.dart';

import '../core/game_info.dart';

/// 아직 만들지 않은 게임을 눌렀을 때 나오는 임시 화면.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({super.key, required this.game, required this.mode});

  final GameInfo game;
  final PlayMode mode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(game.title)),
      body: SafeArea(top: false, child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GameIcon(id: game.id, fallback: game.icon, size: 120),
            const SizedBox(height: 24),
            Text(
              '${game.title} · ${mode.label}',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text('아직 만드는 중이에요. 곧 만나요!'),
          ],
        ),
      )),
    );
  }
}
