import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import 'ui/snake_menu_screen.dart';

export 'game/snake_host_net.dart' show kSnakeLanGame;
export 'tutorial/snake_tutorial.dart';
export 'ui/snake_icon.dart';
export 'ui/snake_records_tab.dart';
export 'ui/snake_screen.dart' show snakeResume;

/// 허브(game_registry)에서 지렁이의 모험을 열 때 쓰는 진입점. 늘 같은 Wi‑Fi 방을 열고 CPU들과 시작한다.
Widget buildSnake(BuildContext context, PlayMode mode) => const SnakeMenuScreen();
