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
      twoPlayerTallies: (two, scheme) {
        final local = [for (final r in two) if (!r.online) r]; // Wi‑Fi 대결은 "플레이어 1/2"가 없다
        final online = [for (final r in two) if (r.online) r];
        return [
          VsTally('플레이어 1 승', local.where((r) => r.winner == 0).length, kPenPink),
          VsTally('플레이어 2 승', local.where((r) => r.winner == 1).length, kPenTeal),
          VsTally('무승부', local.where((r) => r.isDraw).length, scheme.outline),
          if (online.isNotEmpty) VsTally('Wi‑Fi 대결 승', online.where((r) => r.onlineWon == true).length, const Color(0xFFF2A900)),
        ];
      },
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
      if (r.vsCpu || r.online) (r.human == 0 ? '먼저' : '나중'),
      if (r.online) 'Wi‑Fi' else if (!r.vsCpu) '2인',
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
