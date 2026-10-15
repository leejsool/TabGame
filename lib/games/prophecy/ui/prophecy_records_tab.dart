import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../core/game_info.dart';
import '../../../records/vs_records.dart';
import '../core/prophecy_ai.dart';
import '../data/prophecy_history.dart';
import 'prophecy_board.dart';
import 'prophecy_screen.dart';

/// 예언 기록 보드: CPU 난이도별 전적 + 2인 대결 요약 + 최근 결과.
class ProphecyRecordsTab extends StatelessWidget {
  const ProphecyRecordsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return VsRecordsBoard<ProphRecord, ProphLevel>(
      load: ProphHistory.load,
      emptyIcon: Icons.auto_awesome_rounded,
      levels: ProphLevel.values,
      levelLabel: (l) => l.label,
      levelOf: (r) => r.level,
      isCpu: (r) => r.vsCpu,
      humanWon: (r) => r.humanWon,
      hasDraws: true,
      twoPlayerTallies: (two, scheme) => [
        VsTally('플레이어 1 승', two.where((r) => r.winner == 0).length, kPenPink),
        VsTally('플레이어 2 승', two.where((r) => r.winner == 1).length, kPenTeal),
        VsTally('무승부', two.where((r) => r.isDraw).length, scheme.outline),
      ],
      tile: _tile,
      onRetry: (context, r) => r.resigned && r.vsCpu
          ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => ProphecyScreen(mode: PlayMode.vsCpu, rows: r.rows, cols: r.cols, humanSide: r.human!, level: r.level!),
              ))
          : null,
    );
  }

  static VsTile _tile(BuildContext context, ProphRecord r, ColorScheme scheme) {
    final detail = [
      formatDate(r.at),
      '표 ${r.rows}×${r.cols}',
      if (r.vsCpu) (r.human == 0 ? '먼저' : '나중') else '2인',
      if (!r.resigned) '${r.score0} : ${r.score1}',
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
    final w = r.winner!;
    return VsTile(
      icon: Icons.emoji_events_rounded,
      color: penColor(w),
      title: r.resigned ? '플레이어 ${2 - w} 기권 · 플레이어 ${w + 1} 승리' : '플레이어 ${w + 1} 승리',
      detail: detail,
      resigned: r.resigned,
    );
  }
}
