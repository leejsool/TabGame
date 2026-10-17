import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import '../../core/game_save.dart';
import '../../records/record_widgets.dart';
import 'core/dot_levels.dart';
import 'game/dot_controller.dart';
import 'ui/dot_menu_screen.dart';
import 'ui/dot_screen.dart';

/// 이어하던 판을 보관하는 이름표 ([GameSave]).
const String dotGameId = 'dot_cannon';

/// 허브(game_registry)에서 도트 캐논을 열 때 쓰는 진입점.
Widget buildDotCannon(BuildContext context, PlayMode mode) => const DotMenuScreen();

/// 새 판을 시작한다. [replace]면 지금 화면을 새 판으로 바꾼다.
/// [askIfSaved]면 이어하던 판이 있을 때 덮어써도 되는지 먼저 묻는다.
Future<void> startDotCannon(
  BuildContext context,
  DotLevel level, {
  bool replace = false,
  bool askIfSaved = false,
}) async {
  final navigator = Navigator.of(context);
  if (askIfSaved) {
    final saved = await GameSave.load(dotGameId);
    if (saved != null && context.mounted) {
      final ok = await confirmOverwrite(context, gameName: '도트 캐논');
      if (!ok) return;
      await GameSave.clear(dotGameId);
    }
  }
  final route = MaterialPageRoute<void>(builder: (_) => DotScreen(controller: DotController(level: level)));
  if (replace) {
    await navigator.pushReplacement(route);
  } else {
    await navigator.push(route);
  }
}

/// 저장된 판을 이어서 한다. 저장이 깨져 있으면 false.
Future<bool> resumeDotCannon(BuildContext context, Map<String, dynamic> saved) async {
  final DotController controller;
  try {
    controller = DotController.fromJson(saved);
  } catch (_) {
    await GameSave.clear(dotGameId);
    return false;
  }
  if (!context.mounted) return false;
  await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DotScreen(controller: controller)));
  return true;
}
