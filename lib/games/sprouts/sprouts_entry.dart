import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import 'ui/sprouts_setup_screen.dart';
import 'ui/sprouts_wifi_screen.dart';

/// 허브(game_registry)에서 콩나물을 열 때 쓰는 진입점: 점의 수를 고르는 화면으로 간다.
Widget buildSprouts(BuildContext context, PlayMode mode) => mode == PlayMode.wifi ? const SproutsWifiScreen() : SproutsSetupScreen(mode: mode);
