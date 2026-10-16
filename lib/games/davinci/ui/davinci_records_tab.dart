import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../records/vs_records.dart';
import '../core/davinci_ai.dart';
import '../data/davinci_history.dart';

/// 다빈치 코드 기록 보드: CPU 난이도별 전적 + Wi‑Fi 대결 요약 + 최근 결과.
/// (사람과는 같은 Wi‑Fi로만 하니, "둘이서" 칸은 Wi‑Fi 대결을 센다.)
class DavinciRecordsTab extends StatelessWidget {
  const DavinciRecordsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return VsRecordsBoard<DvRecord, DvLevel>(
      load: DvHistory.load,
      emptyIcon: Icons.psychology_rounded,
      levels: DvLevel.values,
      levelLabel: (l) => l.label,
      levelOf: (r) => r.level,
      isCpu: (r) => r.vsCpu,
      humanWon: (r) => r.humanWon,
      twoPlayerTallies: (two, scheme) => [
        VsTally('이김', two.where((r) => r.humanWon).length, const Color(0xFFF2A900)),
        VsTally('짐', two.where((r) => !r.humanWon).length, scheme.error),
      ],
      tile: _tile,
    );
  }

  static VsTile _tile(BuildContext context, DvRecord r, ColorScheme scheme) {
    final detail = [
      formatDate(r.at),
      if (r.vsCpu) 'CPU ${r.players - 1}명' else 'Wi‑Fi ${r.players}명',
      '${r.turns}차례',
    ].join(' · ');
    if (r.vsCpu) {
      return VsTile.cpu(scheme: scheme, humanWon: r.humanWon, resigned: r.resigned && !r.humanWon, levelLabel: r.level!.label, detail: detail);
    }
    final won = r.humanWon;
    return VsTile(
      icon: won ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
      color: won ? const Color(0xFFF2A900) : scheme.error,
      title: '${won ? '이겼어요' : r.resigned ? '기권했어요' : '졌어요'} · Wi‑Fi 대결',
      detail: detail,
      resigned: r.resigned && !won,
    );
  }
}
