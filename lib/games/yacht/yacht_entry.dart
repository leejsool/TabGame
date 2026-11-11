import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import 'ui/yacht_setup_screen.dart';
export 'ui/yacht_icon.dart';

/// 허브(game_registry)에서 야추를 열 때 쓰는 진입점. 인원수를 골라야 해서 설정 화면부터 연다.
Widget buildYacht(BuildContext context, PlayMode mode) => YachtSetupScreen(mode: mode);
