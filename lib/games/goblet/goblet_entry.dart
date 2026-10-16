import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import 'ui/goblet_screen.dart';
import 'ui/goblet_setup_screen.dart';
import 'ui/goblet_wifi_screen.dart';

/// 허브(game_registry)에서 고블렛 고블러스를 열 때 쓰는 진입점.
Widget buildGoblet(BuildContext context, PlayMode mode) {
  if (mode == PlayMode.vsCpu) return const GobbletSetupScreen();
  if (mode == PlayMode.wifi) return const GobbletWifiScreen();
  return GobbletScreen(mode: mode);
}
