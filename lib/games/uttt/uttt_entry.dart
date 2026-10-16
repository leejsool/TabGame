import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import 'ui/uttt_screen.dart';
import 'ui/uttt_setup_screen.dart';
import 'ui/uttt_wifi_screen.dart';

/// 허브(game_registry)에서 궁극 틱택토를 열 때 쓰는 진입점.
Widget buildUttt(BuildContext context, PlayMode mode) {
  if (mode == PlayMode.vsCpu) return const UtttSetupScreen();
  if (mode == PlayMode.wifi) return const UtttWifiScreen();
  return UtttScreen(mode: mode);
}
