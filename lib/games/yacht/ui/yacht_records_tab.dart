import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../records/vs_records.dart';
import '../core/yacht_cpu.dart';
import '../data/yacht_history.dart';
import 'yacht_look.dart';

/// 야추 기록 보드: CPU 난이도별 전적 + 한 기기 대결 요약 + 최근 결과.
class YachtRecordsTab extends StatelessWidget {
  const YachtRecordsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return VsRecordsBoard<YachtRecord, YachtLevel>(
      load: YachtHistory.load,
      emptyIcon: Icons.casino_rounded,
      levels: YachtLevel.values,
      levelLabel: (l) => l.label,
      levelOf: (r) => r.level,
      isCpu: (r) => r.vsCpu,
      humanWon: (r) => r.humanWon,
      hasDraws: true,
      twoPlayerTallies: (two, scheme) {
        final seats = two.fold(2, (n, r) => r.players > n ? r.players : n);
        return [
          for (var s = 0; s < seats; s++)
            VsTally('플레이어 ${s + 1} 승', two.where((r) => r.winners.length == 1 && r.winners.first == s).length, kYachtSeatColors[s]),
          if (two.isNotEmpty) VsTally('최고 점수', two.map((r) => r.best).reduce((a, b) => a > b ? a : b), kYachtColor),
        ];
      },
      tile: _tile,
    );
  }

  static VsTile _tile(BuildContext context, YachtRecord r, ColorScheme scheme) {
    final detail = [formatDate(r.at), '${r.players}명', r.scores.join(' : ')].join(' · ');
    if (r.vsCpu) {
      return VsTile.cpu(scheme: scheme, humanWon: r.humanWon, resigned: false, levelLabel: r.level!.label, detail: detail);
    }
    final w = r.winners;
    if (w.length > 1) {
      return VsTile(icon: Icons.handshake_rounded, color: scheme.outline, title: '무승부 · ${r.best}점', detail: detail);
    }
    return VsTile(icon: Icons.emoji_events_rounded, color: kYachtSeatColors[w.first], title: '플레이어 ${w.first + 1} 승리 · ${r.best}점', detail: detail);
  }
}
