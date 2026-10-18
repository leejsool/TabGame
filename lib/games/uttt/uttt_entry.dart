import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import '../../core/resume_gate.dart';
import 'game/uttt_controller.dart';
import 'ui/uttt_screen.dart';
import 'ui/uttt_setup_screen.dart' show UtttSetupScreen, utttSavedLabel;
import 'ui/uttt_wifi_screen.dart';
export 'ui/uttt_icon.dart';
export 'ui/uttt_screen.dart' show utttResume;

/// 허브(game_registry)에서 궁극 틱택토를 열 때 쓰는 진입점.
Widget buildUttt(BuildContext context, PlayMode mode) {
  if (mode == PlayMode.vsCpu) return const UtttSetupScreen();
  if (mode == PlayMode.wifi) return const UtttWifiScreen();
  // 한 기기로 둘이서: 이어하던 판이 있으면 이어할지 먼저 묻는다
  return ResumeGate(
    gameId: 'ultimate_tictactoe',
    gameName: '궁극 틱택토',
    fresh: (_) => UtttScreen(mode: mode),
    resumeBuilder: (saved) {
      final controller = UtttController.fromJson(saved);
      return controller == null ? null : UtttScreen(mode: controller.mode, controller: controller);
    },
    describe: utttSavedLabel,
  );
}
