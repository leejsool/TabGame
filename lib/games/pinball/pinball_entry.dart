import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import 'ui/pinball_menu_screen.dart';

export 'pinball_icon.dart';
export 'tutorial/pinball_tutorial.dart';
export 'ui/pinball_records_tab.dart';

/// 허브(game_registry)에서 핀볼을 열 때 쓰는 진입점.
Widget buildPinball(BuildContext context, PlayMode mode) => const PinballMenuScreen();
