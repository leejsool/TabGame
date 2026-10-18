import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import 'ui/prophecy_setup_screen.dart';
import 'ui/prophecy_wifi_screen.dart';
export 'ui/prophecy_icon.dart';

/// 허브(game_registry)에서 예언을 열 때 쓰는 진입점. 표의 크기를 골라야 해서 언제나 설정 화면부터 연다.
Widget buildProphecy(BuildContext context, PlayMode mode) => mode == PlayMode.wifi ? const ProphecyWifiScreen() : ProphecySetupScreen(mode: mode);
