import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import '../../records/record_widgets.dart';
import 'core/mines_rules.dart';
import 'data/mines_storage.dart';
import 'ui/mines_menu_screen.dart';
import 'ui/mines_screen.dart';

/// 허브(game_registry)에서 지뢰찾기를 열 때 쓰는 진입점.
Widget buildMinesweeper(BuildContext context, PlayMode mode) => const MinesMenuScreen();

/// 새 판을 시작한다. [replace]면 지금 화면을 새 판으로 바꾼다.
/// [askIfSaved]면 이어하던 판이 있을 때 덮어써도 되는지 먼저 묻는다.
Future<void> startMines(
  BuildContext context,
  MinesLevel level, {
  bool replace = false,
  bool askIfSaved = false,
}) async {
  final navigator = Navigator.of(context);
  if (askIfSaved) {
    final saved = await MinesStorage.loadSaved();
    if (saved != null && context.mounted) {
      final ok = await confirmOverwrite(context, gameName: '지뢰찾기');
      if (!ok) return;
    }
  }
  await MinesStorage.saveLevel(level);
  final route = MaterialPageRoute<void>(builder: (_) => MinesScreen(level: level));
  if (replace) {
    await navigator.pushReplacement(route);
  } else {
    await navigator.push(route);
  }
}

/// 저장된 판을 이어서 한다.
Future<void> resumeMines(BuildContext context, Map<String, dynamic> saved) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => MinesScreen(saved: saved)),
  );
}
