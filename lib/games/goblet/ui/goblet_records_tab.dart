import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../records/vs_records.dart';
import '../core/goblet_ai.dart';
import '../core/goblet_rules.dart';
import '../data/goblet_history.dart';
import 'goblet_piece.dart';

/// 고블렛 고블러스 기록 보드: CPU 난이도별 전적 + 2인 대결 요약 + 최근 결과.
/// (고블렛은 판을 다시 하는 의미가 적어서 "다시 하기"는 없다.)
class GobbletRecordsTab extends StatelessWidget {
  const GobbletRecordsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return VsRecordsBoard<GobbletRecord, CpuLevel>(
      load: GobbletHistory.load,
      emptyIcon: Icons.layers_rounded,
      levels: CpuLevel.values,
      levelLabel: (l) => l.label,
      levelOf: (r) => r.level,
      isCpu: (r) => r.vsCpu,
      humanWon: (r) => r.humanWon,
      hasDraws: true,
      twoPlayerTallies: (two, scheme) {
        final local = [for (final r in two) if (!r.online) r]; // Wi‑Fi 대결은 팀 승 수에 넣지 않고 따로 센다
        final online = [for (final r in two) if (r.online) r];
        return [
          VsTally('빨강팀 승', local.where((r) => r.winner == Team.red).length, TeamPalette.red.main),
          VsTally('파랑팀 승', local.where((r) => r.winner == Team.blue).length, TeamPalette.blue.main),
          VsTally('무승부', local.where((r) => r.isDraw).length, scheme.outline),
          if (online.isNotEmpty) VsTally('Wi‑Fi 대결 승', online.where((r) => r.onlineWon == true).length, const Color(0xFFF2A900)),
        ];
      },
      tile: _tile,
    );
  }

  static VsTile _tile(BuildContext context, GobbletRecord r, ColorScheme scheme) {
    final detail = [
      formatDate(r.at),
      if (r.vsCpu) '${r.human!.label}로 플레이' else if (r.online) 'Wi‑Fi · ${r.human!.label}' else '2인',
      '${r.moves}수',
      if (r.byReveal) '들어 올려서 드러남',
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
      final won = r.onlineWon;
      return VsTile(
        icon: won == null ? Icons.handshake_rounded : (won ? Icons.emoji_events_rounded : Icons.sentiment_dissatisfied_rounded),
        color: won == null ? scheme.outline : (won ? const Color(0xFFF2A900) : scheme.error),
        title: won == null ? '무승부 · Wi‑Fi 대결' : '${won ? '이겼어요' : r.resigned ? '기권했어요' : '졌어요'} · Wi‑Fi 대결',
        detail: detail,
        resigned: r.resigned && won == false,
      );
    }
    if (r.isDraw) {
      return VsTile(icon: Icons.handshake_rounded, color: scheme.outline, title: '무승부', detail: detail);
    }
    return VsTile(
      icon: Icons.emoji_events_rounded,
      color: TeamPalette.of(r.winner!).main,
      title: r.resigned ? '${r.winner!.other.label} 기권 · ${r.winner!.label} 승리' : '${r.winner!.label} 승리',
      detail: detail,
      resigned: r.resigned,
    );
  }
}
