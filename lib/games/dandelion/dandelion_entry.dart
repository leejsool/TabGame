import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import '../../core/resume_gate.dart';
import 'game/dandelion_controller.dart';
import 'ui/dandelion_screen.dart';
import 'ui/dandelion_setup_screen.dart' show DandelionSetupScreen, dandelionSavedLabel;
import 'ui/dandelion_wifi_screen.dart';
export 'ui/dandelion_icon.dart';

/// 허브(game_registry)에서 민들레를 열 때 쓰는 진입점.
Widget buildDandelion(BuildContext context, PlayMode mode) {
  if (mode == PlayMode.vsCpu) return const DandelionSetupScreen();
  if (mode == PlayMode.wifi) return const DandelionWifiScreen();
  // 한 기기로 둘이서: 이어하던 판이 있으면 이어할지 먼저 묻는다
  return ResumeGate(
    gameId: 'dandelion',
    gameName: '민들레',
    fresh: (_) => DandelionScreen(mode: mode),
    resumeBuilder: (saved) {
      final controller = DandelionController.fromJson(saved);
      return controller == null ? null : DandelionScreen(mode: controller.mode, controller: controller);
    },
    describe: dandelionSavedLabel,
  );
}
