import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../core/game_info.dart';
import '../core/game_registry.dart' show allGames;

/// 칩으로 연 화면인지 알려 주는 표 ([VsModeSwitch]가 화면을 새로 쌓을지 바꿔 끼울지 정한다).
class _ViaSwitch extends InheritedWidget {
  const _ViaSwitch({required super.child});

  @override
  bool updateShouldNotify(_ViaSwitch old) => false;
}

/// 시작 전 화면 맨 위의 "CPU / 둘이서 / Wi‑Fi" 전환 칩. 허브까지 나가지 않고 그 자리에서 다른 방식으로 바꾼다.
///
/// 허브에서 연 화면에서 처음 바꿀 때는 새 화면을 위에 쌓아서, 뒤로 가면 원래 설정 화면으로 돌아온다
/// (게임 화면만 있는 "한 기기로 둘이서"에서 다시 CPU로 돌아올 길이 된다).
/// 칩으로 연 화면에서 또 바꿀 때는 그 화면을 바꿔 끼워서 화면이 계속 쌓이지 않게 한다.
class VsModeSwitch extends StatelessWidget {
  const VsModeSwitch({super.key, required this.gameId, required this.current});

  /// game_registry의 id.
  final String gameId;

  /// 지금 화면의 방식.
  final PlayMode current;

  static GameInfo? _find(String id) {
    for (final g in allGames) {
      if (g.id == id) return g;
    }
    return null;
  }

  static String _short(PlayMode m) => switch (m) {
        PlayMode.solo => '혼자',
        PlayMode.local2p => '둘이서',
        PlayMode.vsCpu => 'CPU',
        PlayMode.wifi => 'Wi‑Fi',
      };

  void _go(BuildContext context, GameInfo game, PlayMode mode) {
    final via = context.getInheritedWidgetOfExactType<_ViaSwitch>() != null;
    final route = MaterialPageRoute<void>(builder: (ctx) => _ViaSwitch(child: game.builder!(ctx, mode)));
    final navigator = Navigator.of(context);
    via ? navigator.pushReplacement(route) : navigator.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final game = _find(gameId);
    if (game == null || game.builder == null) return const SizedBox.shrink();
    final modes = [for (final m in game.modes) if (m != PlayMode.solo && !(kIsWeb && m == PlayMode.wifi)) m];
    if (modes.length < 2 || !modes.contains(current)) return const SizedBox.shrink();
    return SegmentedButton<PlayMode>(
      segments: [
        for (final m in modes)
          ButtonSegment(
            value: m,
            icon: Icon(m.icon, size: 18),
            label: Text(_short(m), maxLines: 1, softWrap: false, style: const TextStyle(fontFamily: 'NanumGothic', fontSize: 14, fontWeight: FontWeight.w800)),
          ),
      ],
      selected: {current},
      showSelectedIcon: false,
      onSelectionChanged: (v) {
        if (v.first != current) _go(context, game, v.first);
      },
    );
  }
}
