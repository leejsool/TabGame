import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import 'ui/park_screen.dart';
export 'ui/park_icon.dart';

/// 허브(game_registry)에서 공원 길찾기를 열 때 쓰는 진입점.
Widget buildPark(BuildContext context, PlayMode mode) => const ParkScreen();
