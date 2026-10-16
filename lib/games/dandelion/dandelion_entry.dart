import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import 'ui/dandelion_screen.dart';
import 'ui/dandelion_setup_screen.dart';
import 'ui/dandelion_wifi_screen.dart';

/// 허브(game_registry)에서 민들레를 열 때 쓰는 진입점.
Widget buildDandelion(BuildContext context, PlayMode mode) {
  if (mode == PlayMode.vsCpu) return const DandelionSetupScreen();
  if (mode == PlayMode.wifi) return const DandelionWifiScreen();
  return DandelionScreen(mode: mode);
}
