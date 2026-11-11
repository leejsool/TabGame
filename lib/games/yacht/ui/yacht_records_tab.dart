import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../records/vs_records.dart';
import '../core/yacht_cpu.dart';
import '../data/yacht_history.dart';
import 'yacht_look.dart';

/// 야추 기록 보드: CPU 난이도별 전적 + 한 기기·Wi‑Fi 대결 요약 + 최근 결과.
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
      localTitle: '로컬 플레이 (한 기기)',
      twoPlayerTallies: (two, scheme) {
        final local = [for (final r in two) if (!r.online) r];
        final online = [for (final r in two) if (r.online) r];
        final seats = local.fold(2, (n, r) => r.humans > n ? r.humans : n);
        final botWins = local.where((r) => r.winners.length == 1 && r.winners.first >= r.humans).length;
        return [
          for (var s = 0; s < seats; s++)
            VsTally('플레이어 ${s + 1} 승', local.where((r) => r.winners.length == 1 && r.winners.first == s && s < r.humans).length, kYachtSeatColors[s]),
          if (local.any((r) => r.bots > 0)) VsTally('CPU 승', botWins, scheme.outline),
          if (online.isNotEmpty) VsTally('Wi‑Fi 대결 승', online.where((r) => r.humanWon == true).length, const Color(0xFFF2A900)),
          if (two.isNotEmpty) VsTally('최고 점수', two.map((r) => r.best).reduce((a, b) => a > b ? a : b), kYachtColor),
        ];
      },
      tile: _tile,
    );
  }

  static VsTile _tile(BuildContext context, YachtRecord r, ColorScheme scheme) {
    final detail = [formatDate(r.at), '${r.players}명${r.bots > 0 ? ' (CPU ${r.bots})' : ''}', if (r.online) 'Wi‑Fi', r.scores.join(' : ')].join(' · ');
    if (r.vsCpu) {
      return VsTile.cpu(scheme: scheme, humanWon: r.humanWon, resigned: false, levelLabel: r.level!.label, detail: detail);
    }
    if (r.online) {
      final won = r.humanWon;
      return VsTile(
        icon: won == true ? Icons.emoji_events_rounded : (won == null ? Icons.handshake_rounded : Icons.sentiment_dissatisfied_rounded),
        color: won == true ? const Color(0xFFF2A900) : (won == null ? scheme.outline : scheme.error),
        title: '${won == true ? '이겼어요' : (won == null ? '무승부' : '졌어요')} · 내 점수 ${r.scores[r.seat]}점',
        detail: detail,
      );
    }
    final w = r.winners;
    if (w.length > 1) {
      return VsTile(icon: Icons.handshake_rounded, color: scheme.outline, title: '무승부 · ${r.best}점', detail: detail);
    }
    if (w.first >= r.humans) {
      return VsTile(icon: Icons.smart_toy_rounded, color: kYachtSeatColors[w.first], title: 'CPU 승리 · ${r.best}점', detail: detail);
    }
    return VsTile(icon: Icons.emoji_events_rounded, color: kYachtSeatColors[w.first], title: '플레이어 ${w.first + 1} 승리 · ${r.best}점', detail: detail);
  }
}
