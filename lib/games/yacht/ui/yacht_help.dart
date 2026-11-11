import 'package:flutter/material.dart';

import '../core/yacht_rules.dart';
import 'yacht_look.dart';

/// 점수판에서 족보 이름을 눌렀을 때 뜨는 설명 창 (예: 에이스 → "1이 나온 주사위 눈의 총합 (최대 5점)").
Future<void> showYachtHelp(BuildContext context, {required String title, required String body, int? dieFace}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          if (dieFace != null) ...[YachtDie(value: dieFace, size: 34), const SizedBox(width: 10)],
          Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
        ],
      ),
      content: Text(body, key: const ValueKey('yacht-help-body'), style: const TextStyle(fontSize: 16, height: 1.45)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인'))],
    ),
  );
}

/// [cat] 칸의 설명 창.
Future<void> showYachtCategoryHelp(BuildContext context, YachtCategory cat) =>
    showYachtHelp(context, title: cat.label, body: cat.help, dieFace: cat.isUpper ? cat.index + 1 : null);

/// 1~6 칸 보너스 설명 창.
Future<void> showYachtUpperBonusHelp(BuildContext context) => showYachtHelp(
      context,
      title: '보너스',
      body: '에이스~식스 여섯 칸의 합이 $kYachtBonusAt점 이상이면 보너스 $kYachtBonus점! 숫자마다 3개씩 모으면 딱 $kYachtBonusAt점이에요.',
    );

/// 야추 보너스 설명 창.
Future<void> showYachtYahtzeeBonusHelp(BuildContext context) => showYachtHelp(
      context,
      title: '야추 보너스',
      body: '야추 칸에 $kYachtYacht점을 적은 뒤, 야추(같은 눈 5개)를 또 굴려서 아무 칸에나 적으면 그때마다 $kYachtYahtzeeBonus점을 더 받아요.',
    );
