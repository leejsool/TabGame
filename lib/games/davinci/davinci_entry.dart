import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import 'ui/davinci_setup_screen.dart';
import 'ui/davinci_wifi_screen.dart';
export 'ui/davinci_icon.dart';

/// 허브(game_registry)에서 다빈치 코드를 열 때 쓰는 진입점.
/// 남의 타일이 보이면 안 되니 사람과는 같은 Wi‑Fi로만 한다 (한 기기 돌려 하기는 없다).
Widget buildDavinci(BuildContext context, PlayMode mode) =>
    mode == PlayMode.wifi ? const DavinciWifiScreen() : DavinciSetupScreen(mode: mode);
