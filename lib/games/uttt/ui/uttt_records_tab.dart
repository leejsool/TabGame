import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../core/game_info.dart';
import '../../../records/vs_records.dart';
import '../core/uttt_ai.dart';
import '../core/uttt_rules.dart';
import '../data/uttt_history.dart';
import 'uttt_board.dart';
import 'uttt_screen.dart';

/// 궁극 틱택토 기록 보드: CPU 난이도별 전적 + 2인 대결 요약 + 최근 결과.
class UtttRecordsTab extends StatelessWidget {
  const UtttRecordsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return VsRecordsBoard<UtttRecord, UttLevel>(
      load: UtttHistory.load,
      emptyIcon: Icons.tag_rounded,
      levels: UttLevel.values,
      levelLabel: (l) => l.label,
      levelOf: (r) => r.level,
      isCpu: (r) => r.vsCpu,
      humanWon: (r) => r.humanWon,
      hasDraws: true,
      twoPlayerTallies: (two, scheme) => [
        VsTally('X 승', two.where((r) => r.winner == kX).length, kXColor),
        VsTally('O 승', two.where((r) => r.winner == kO).length, kOColor),
        VsTally('무승부', two.where((r) => r.isDraw).length, scheme.outline),
      ],
      tile: _tile,
      onRetry: (context, r) => r.resigned && r.vsCpu
          ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => UtttScreen(mode: PlayMode.vsCpu, humanSide: r.human!, level: r.level!),
              ))
          : null,
    );
  }

  static VsTile _tile(BuildContext context, UtttRecord r, ColorScheme scheme) {
    final detail = [
      formatDate(r.at),
      if (r.vsCpu) '${sideLabel(r.human!)}로 플레이' else '2인',
      '${r.moves}수',
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
      color: sideColor(r.winner!),
      title: r.resigned ? '${sideLabel(1 - r.winner!)} 기권 · ${sideLabel(r.winner!)} 승리' : '${sideLabel(r.winner!)} 승리',
      detail: detail,
      resigned: r.resigned,
    );
  }
}
