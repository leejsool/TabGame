import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/game_info.dart';
import '../../records/record_widgets.dart';
import 'core/solitaire_rules.dart';
import 'data/solitaire_storage.dart';
import 'ui/solitaire_menu_screen.dart';
import 'ui/solitaire_screen.dart';
export 'ui/solitaire_icon.dart';

/// 허브(game_registry)에서 솔리테어를 열 때 쓰는 진입점.
Widget buildSolitaire(BuildContext context, PlayMode mode) => const SolitaireMenuScreen();

/// 무작위 판 번호.
int randomSolitaireDeal([Random? rng]) => 1 + (rng ?? Random()).nextInt(kMaxSolitaireDeal);

/// 번호 [deal]의 판을 [draw]장 뽑기로 새로 시작한다. [replace]면 지금 화면을 새 판으로 바꾼다.
/// [askIfSaved]면 이어하던 판이 있을 때 덮어써도 되는지 먼저 묻는다.
Future<void> startSolitaireDeal(
  BuildContext context,
  int deal,
  int draw, {
  bool replace = false,
  bool askIfSaved = false,
}) async {
  final navigator = Navigator.of(context);
  if (askIfSaved) {
    final saved = await SolitaireStorage.loadSaved();
    if (saved != null && context.mounted) {
      final ok = await confirmOverwrite(context, gameName: '솔리테어');
      if (!ok) return;
    }
  }
  await SolitaireStorage.recordStart(draw);
  final route = MaterialPageRoute<void>(builder: (_) => SolitaireScreen(deal: deal, draw: draw));
  if (replace) {
    await navigator.pushReplacement(route);
  } else {
    await navigator.push(route);
  }
}

/// 저장된 판을 이어서 한다.
Future<void> resumeSolitaire(BuildContext context, Map<String, dynamic> saved) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => SolitaireScreen(saved: saved)),
  );
}
