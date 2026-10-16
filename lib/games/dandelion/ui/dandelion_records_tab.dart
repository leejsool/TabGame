import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../records/vs_records.dart';
import '../core/dandelion_ai.dart';
import '../core/dandelion_rules.dart';
import '../data/dandelion_history.dart';
import 'dandelion_art.dart';

/// 민들레 기록 보드: CPU 난이도별 전적 + 2인 대결 요약 + 최근 결과.
class DandelionRecordsTab extends StatelessWidget {
  const DandelionRecordsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return VsRecordsBoard<DandelionRecord, DandLevel>(
      load: DandelionHistory.load,
      emptyIcon: Icons.local_florist_rounded,
      levels: DandLevel.values,
      levelLabel: (l) => l.label,
      levelOf: (r) => r.level,
      isCpu: (r) => r.vsCpu,
      humanWon: (r) => r.humanWon,
      twoPlayerTallies: (two, scheme) {
        final local = [for (final r in two) if (!r.online) r]; // Wi‑Fi 대결은 민들레/바람 승 대신 따로 센다
        final online = [for (final r in two) if (r.online) r];
        return [
          VsTally('민들레 승', local.where((r) => r.winner == Role.dandelion).length, kDandelionColor),
          VsTally('바람 승', local.where((r) => r.winner == Role.wind).length, kWindColor),
          if (online.isNotEmpty) VsTally('Wi‑Fi 대결 승', online.where((r) => r.onlineWon == true).length, const Color(0xFFF2A900)),
        ];
      },
      tile: _tile,
    );
  }

  static VsTile _tile(BuildContext context, DandelionRecord r, ColorScheme scheme) {
    final detail = [
      formatDate(r.at),
      if (r.vsCpu || r.online) '${r.human!.label}로 플레이',
      if (r.online) 'Wi‑Fi' else if (!r.vsCpu) '2인',
      '${r.moves}수',
      if (r.winner == Role.wind && !r.resigned) '빈칸 ${r.empties}칸',
    ].join(' · ');
    if (r.vsCpu) {
      return VsTile.cpu(
        scheme: scheme,
        humanWon: r.humanWon,
        resigned: r.resigned,
        levelLabel: r.level!.label,
        detail: detail,
      );
    }
    if (r.online) {
      final won = r.onlineWon!;
      return VsTile(
        icon: won ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded,
        color: won ? const Color(0xFFF2A900) : scheme.error,
        title: '${won ? '이겼어요' : r.resigned ? '기권했어요' : '졌어요'} · Wi‑Fi 대결',
        detail: detail,
        resigned: r.resigned && !won,
      );
    }
    return VsTile(
      icon: Icons.emoji_events_rounded,
      color: roleColor(r.winner),
      title: r.resigned ? '${r.winner.other.label} 기권 · ${r.winner.label} 승리' : '${r.winner.label} 승리',
      detail: detail,
      resigned: r.resigned,
    );
  }
}
