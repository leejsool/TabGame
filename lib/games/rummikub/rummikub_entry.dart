import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import 'ui/rummikub_setup_screen.dart';
import 'ui/rummikub_wifi_screen.dart';
export 'ui/rummikub_icon.dart';
export 'ui/rummikub_screen.dart' show rummikubResume;

/// 허브(game_registry)에서 루미큐브를 열 때 쓰는 진입점.
/// 남의 패가 보이면 안 되니 사람과는 같은 Wi‑Fi로만 한다 (한 기기 돌려 하기는 없다).
Widget buildRummikub(BuildContext context, PlayMode mode) =>
    mode == PlayMode.wifi ? const RummikubWifiScreen() : RummikubSetupScreen(mode: mode);
