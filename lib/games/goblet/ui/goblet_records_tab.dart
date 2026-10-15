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
      twoPlayerTallies: (two, scheme) => [
        VsTally('빨강팀 승', two.where((r) => r.winner == Team.red).length, TeamPalette.red.main),
        VsTally('파랑팀 승', two.where((r) => r.winner == Team.blue).length, TeamPalette.blue.main),
        VsTally('무승부', two.where((r) => r.isDraw).length, scheme.outline),
      ],
      tile: _tile,
    );
  }

  static VsTile _tile(BuildContext context, GobbletRecord r, ColorScheme scheme) {
    final detail = [
      formatDate(r.at),
      if (r.vsCpu) '${r.human!.label}로 플레이' else '2인',
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
