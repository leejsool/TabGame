import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import '../../core/resume_gate.dart';
import 'game/goblet_controller.dart';
import 'ui/goblet_screen.dart';
import 'ui/goblet_setup_screen.dart' show GobbletSetupScreen, gobletSavedLabel;
import 'ui/goblet_wifi_screen.dart';
export 'ui/goblet_icon.dart';

/// 허브(game_registry)에서 고블렛 고블러스를 열 때 쓰는 진입점.
Widget buildGoblet(BuildContext context, PlayMode mode) {
  if (mode == PlayMode.vsCpu) return const GobbletSetupScreen();
  if (mode == PlayMode.wifi) return const GobbletWifiScreen();
  // 한 기기로 둘이서: 이어하던 판이 있으면 이어할지 먼저 묻는다
  return ResumeGate(
    gameId: 'goblet_gobblers',
    gameName: '고블렛 고블러스',
    fresh: (_) => GobbletScreen(mode: mode),
    resumeBuilder: (saved) {
      final controller = GobbletController.fromJson(saved);
      return controller == null ? null : GobbletScreen(mode: controller.mode, controller: controller);
    },
    describe: gobletSavedLabel,
  );
}
