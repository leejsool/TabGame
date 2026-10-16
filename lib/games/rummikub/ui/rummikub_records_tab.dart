import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../records/vs_records.dart';
import '../core/rummikub_ai.dart';
import '../data/rummikub_history.dart';

/// 루미큐브 기록 보드: CPU 난이도별 전적 + Wi‑Fi 대결 요약 + 최근 결과.
/// (사람과는 같은 Wi‑Fi로만 하니, "둘이서" 칸은 Wi‑Fi 대결을 센다.)
class RummikubRecordsTab extends StatelessWidget {
  const RummikubRecordsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return VsRecordsBoard<RkRecord, RkLevel>(
      load: RkHistory.load,
      emptyIcon: Icons.grid_view_rounded,
      levels: RkLevel.values,
      levelLabel: (l) => l.label,
      levelOf: (r) => r.level,
      isCpu: (r) => r.vsCpu,
      humanWon: (r) => r.humanWon,
      hasDraws: true,
      twoPlayerTallies: (two, scheme) => [
        VsTally('이김', two.where((r) => r.humanWon == true).length, const Color(0xFFF2A900)),
        VsTally('짐', two.where((r) => r.humanWon == false).length, scheme.error),
        VsTally('무승부', two.where((r) => r.humanWon == null).length, scheme.outline),
      ],
      tile: _tile,
    );
  }

  static VsTile _tile(BuildContext context, RkRecord r, ColorScheme scheme) {
    final detail = [
      formatDate(r.at),
      if (r.vsCpu) 'CPU ${r.players - 1}명' else 'Wi‑Fi',
      '${r.turns}차례',
    ].join(' · ');
    if (r.vsCpu) {
      return VsTile.cpu(scheme: scheme, humanWon: r.humanWon, resigned: r.resigned && r.humanWon == false, levelLabel: r.level!.label, detail: detail);
    }
    final won = r.humanWon;
    return VsTile(
      icon: won == null ? Icons.handshake_rounded : (won ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded),
      color: won == null ? scheme.outline : (won ? const Color(0xFFF2A900) : scheme.error),
      title: won == null ? '무승부 · Wi‑Fi 대결' : '${won ? '이겼어요' : r.resigned ? '기권했어요' : '졌어요'} · Wi‑Fi 대결',
      detail: detail,
      resigned: r.resigned && won == false,
    );
  }
}
