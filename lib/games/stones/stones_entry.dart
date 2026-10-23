import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import 'ui/stones_menu.dart';
export 'ui/stones_icon.dart';

/// 허브(game_registry)에서 바둑돌 옮기기를 열 때 쓰는 진입점.
Widget buildStones(BuildContext context, PlayMode mode) => StonesMenuScreen(mode: mode);
