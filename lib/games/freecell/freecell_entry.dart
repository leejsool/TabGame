import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import '../../records/record_widgets.dart';
import 'core/freecell_difficulty.dart';
import 'core/freecell_rules.dart';
import 'data/freecell_storage.dart';
import 'ui/freecell_menu_screen.dart';
import 'ui/freecell_screen.dart';
export 'ui/freecell_icon.dart';

/// 허브(game_registry)에서 프리셀을 열 때 쓰는 진입점.
Widget buildFreecell(BuildContext context, PlayMode mode) => const FreecellMenuScreen();

/// 풀 수 있는 무작위 판 번호 (1~32000, 풀 수 없는 11982 제외).
int randomDeal([Random? rng]) {
  rng ??= Random();
  while (true) {
    final n = 1 + rng.nextInt(kMaxDeal);
    if (n != kUnsolvableDeal) return n;
  }
}

/// 난이도에 맞는 무작위 판 번호. [level]이 null이면 아무 난이도나.
Future<int> pickDeal(FcLevel? level) async {
  if (level == null) return randomDeal();
  final table = await FcDifficultyTable.load();
  return table.randomDeal(level);
}

/// 번호 [deal]의 판을 새로 시작한다. [replace]면 지금 화면을 새 판으로 바꾼다.
/// [askIfSaved]면 이어하던 판이 있을 때 덮어써도 되는지 먼저 묻는다.
Future<void> startFreecellDeal(
  BuildContext context,
  int deal, {
  bool replace = false,
  bool askIfSaved = false,
}) async {
  final navigator = Navigator.of(context);
  if (askIfSaved) {
    final saved = await FreecellStorage.loadSaved();
    if (saved != null && context.mounted) {
      final ok = await confirmOverwrite(context, gameName: '프리셀');
      if (!ok) return;
    }
  }
  await FreecellStorage.recordStart();
  final route = MaterialPageRoute<void>(builder: (_) => FreecellScreen(deal: deal));
  if (replace) {
    await navigator.pushReplacement(route);
  } else {
    await navigator.push(route);
  }
}

/// 저장된 판을 이어서 한다.
Future<void> resumeFreecell(BuildContext context, Map<String, dynamic> saved) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => FreecellScreen(saved: saved)),
  );
}
