import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../records/vs_records.dart';
import '../core/quoridor_ai.dart';
import '../data/quoridor_history.dart';
import 'quoridor_board.dart';

/// 쿼리도 기록 보드: CPU 난이도별 전적 + 한 기기·Wi‑Fi 대결 요약 + 최근 결과.
class QuoridorRecordsTab extends StatelessWidget {
  const QuoridorRecordsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return VsRecordsBoard<QuoridorRecord, QLevel>(
      load: QuoridorHistory.load,
      emptyIcon: Icons.border_all_rounded,
      levels: QLevel.values,
      levelLabel: (l) => l.label,
      levelOf: (r) => r.level,
      isCpu: (r) => r.vsCpu,
      humanWon: (r) => r.humanWon,
      twoPlayerTallies: (two, scheme) {
        final local = [for (final r in two) if (!r.online) r];
        final online = [for (final r in two) if (r.online) r];
        final seats = local.any((r) => r.players == 4) ? 4 : 2; // 4명이 한 판이 있으면 4칸
        return [
          for (var s = 0; s < seats; s++) VsTally('플레이어 ${s + 1} 승', local.where((r) => r.winner == s).length, kPawnColors[s]),
          if (online.isNotEmpty) VsTally('Wi‑Fi 대결 승', online.where((r) => r.humanWon == true).length, const Color(0xFFF2A900)),
        ];
      },
      tile: _tile,
    );
  }

  static VsTile _tile(BuildContext context, QuoridorRecord r, ColorScheme scheme) {
    final detail = [
      formatDate(r.at),
      '${r.players}명',
      if (r.online) 'Wi‑Fi' else if (!r.vsCpu) '한 기기',
      '${r.moves}수',
    ].join(' · ');
    if (r.vsCpu) {
      return VsTile.cpu(scheme: scheme, humanWon: r.humanWon, resigned: r.resigned && r.humanWon == false, levelLabel: r.level!.label, detail: detail);
    }
    if (r.online) {
      final won = r.humanWon!;
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
      color: kPawnColors[r.winner],
      title: '플레이어 ${r.winner + 1} 승리',
      detail: detail,
      resigned: r.resigned,
    );
  }
}
