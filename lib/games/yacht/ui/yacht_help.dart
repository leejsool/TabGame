import 'package:flutter/material.dart';

import '../core/yacht_daesung.dart';
import '../core/yacht_rules.dart';
import 'yacht_look.dart';
import 'yacht_scale.dart';

/// 점수판에서 족보 이름을 눌렀을 때 뜨는 설명 창 (예: 에이스 → "1이 나온 주사위 눈의 총합 (최대 5점)").
Future<void> showYachtHelp(BuildContext context, {required String title, required String body, int? dieFace}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => YachtScaled(
      child: AlertDialog(
      title: Row(
        children: [
          if (dieFace != null) ...[YachtDie(value: dieFace, size: 34), const SizedBox(width: 10)],
          Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w900))),
        ],
      ),
      content: Text(body, key: const ValueKey('yacht-help-body'), style: const TextStyle(fontSize: 16, height: 1.45)),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인'))],
    )),
  );
}

/// [cat] 칸의 설명 창. [card]가 있으면 그 판의 규칙(대성One Rule 등)으로 설명한다.
Future<void> showYachtCategoryHelp(BuildContext context, YachtCategory cat, {YachtCard? card}) => showYachtHelp(
      context,
      title: card?.labelOf(cat) ?? cat.label,
      body: card?.helpOf(cat) ?? cat.help,
      dieFace: cat.isUpper ? cat.index + 1 : null,
    );

/// 숫자 칸 보너스 설명 창.
Future<void> showYachtUpperBonusHelp(BuildContext context, {YachtCard? card}) => showYachtHelp(
      context,
      title: '보너스',
      body: card != null && card.daesung
          ? '원즈~식스 여섯 칸의 합이 $kDaesungBonusAt점 이상이면 보너스 $kDaesungBonus점! 숫자마다 3개씩 모으면 63점이라 조금 여유가 있어요.'
          : '에이스~식스 여섯 칸의 합이 $kYachtBonusAt점 이상이면 보너스 $kYachtBonus점! 숫자마다 3개씩 모으면 딱 $kYachtBonusAt점이에요.',
    );

/// 대성One Rule 설명 창 (설정 화면의 물음표).
Future<void> showDaesungRuleHelp(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      key: const ValueKey('yacht-daesung-help'),
      title: const Row(
        children: [
          YachtDie(value: 1, size: 34, daesung: true),
          SizedBox(width: 10),
          Flexible(child: Text('대성One Rule', style: TextStyle(fontWeight: FontWeight.w900))),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in kDaesungRuleLines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('•  ', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900, color: kYachtColor)),
                    Expanded(child: Text(line, style: const TextStyle(fontSize: 15.5, height: 1.45))),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('확인'))],
    ),
  );
}

/// 야추 보너스 설명 창.
Future<void> showYachtYahtzeeBonusHelp(BuildContext context) => showYachtHelp(
      context,
      title: '야추 보너스',
      body: '야추 칸에 $kYachtYacht점을 적은 뒤, 야추(같은 눈 5개)를 또 굴려서 아무 칸에나 적으면 그때마다 $kYachtYahtzeeBonus점을 더 받아요.',
    );
