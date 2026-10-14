import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import '../../records/record_widgets.dart';
import 'core/getcolor_rules.dart';
import 'data/getcolor_storage.dart';
import 'game/getcolor_controller.dart';
import 'ui/getcolor_menu_screen.dart';
import 'ui/getcolor_screen.dart';

/// 허브(game_registry)에서 겟 컬러를 열 때 쓰는 진입점.
Widget buildGetColor(BuildContext context, PlayMode mode) => const GetColorMenuScreen();

/// 새 판을 시작한다. [replace]면 지금 화면을 새 판으로 바꾼다.
/// [askIfSaved]면 이어하던 판이 있을 때 덮어써도 되는지 먼저 묻는다.
Future<void> startGetColor(
  BuildContext context,
  GcLevel level, {
  bool replace = false,
  bool askIfSaved = false,
}) async {
  final navigator = Navigator.of(context);
  if (askIfSaved) {
    final saved = await GetColorStorage.loadSaved();
    if (saved != null && context.mounted) {
      final ok = await confirmOverwrite(context, gameName: '겟 컬러');
      if (!ok) return;
    }
  }
  await GetColorStorage.saveLevel(level);
  final controller = await GetColorController.create(level);
  final route = MaterialPageRoute<void>(builder: (_) => GetColorScreen(controller: controller));
  if (replace) {
    await navigator.pushReplacement(route);
  } else {
    await navigator.push(route);
  }
}

/// 저장된 판을 이어서 한다.
Future<void> resumeGetColor(BuildContext context, Map<String, dynamic> saved) {
  final controller = GetColorController.fromJson(saved);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => GetColorScreen(controller: controller)),
  );
}

/// 포기했던 판([record])에 같은 병 배치로 다시 도전한다. 이어하던 판이 있으면 먼저 묻는다.
Future<void> retryGetColor(BuildContext context, GetColorRecord record) async {
  final initial = record.initial;
  if (initial == null) return;
  final saved = await GetColorStorage.loadSaved();
  if (saved != null && context.mounted) {
    final ok = await confirmOverwrite(context, gameName: '겟 컬러');
    if (!ok) return;
  }
  if (!context.mounted) return;
  final controller = GetColorController(
    level: record.level,
    initial: WaterState([for (final b in initial) List<int>.of(b)]),
  );
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => GetColorScreen(controller: controller)),
  );
}
