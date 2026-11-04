import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import 'ui/kt_menu_screen.dart';
import 'ui/kt_wifi_screen.dart';

export 'tutorial/kt_tutorial.dart';
export 'ui/kt_icon.dart';
export 'ui/kt_race_screen.dart' show kKeytapLanGame, keytapResume;
export 'ui/kt_records_tab.dart';

/// 허브(game_registry)에서 건반 톡톡을 열 때 쓰는 진입점.
Widget buildKeytap(BuildContext context, PlayMode mode) => mode == PlayMode.wifi ? const KtWifiScreen() : const KtMenuScreen();
