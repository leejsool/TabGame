import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import 'ui/quoridor_setup_screen.dart';
import 'ui/quoridor_wifi_screen.dart';

/// 허브(game_registry)에서 쿼리도를 열 때 쓰는 진입점. 2명/4명을 골라야 해서 한 기기 · CPU 대결은 설정 화면부터 연다.
Widget buildQuoridor(BuildContext context, PlayMode mode) {
  if (mode == PlayMode.wifi) return const QuoridorWifiScreen();
  return QuoridorSetupScreen(mode: mode);
}
