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
      twoPlayerTallies: (two, scheme) {
        final local = [for (final r in two) if (!r.online) r]; // Wi‑Fi 대결은 X/O 승 대신 따로 센다
        final online = [for (final r in two) if (r.online) r];
        return [
          VsTally('X 승', local.where((r) => r.winner == kX).length, kXColor),
          VsTally('O 승', local.where((r) => r.winner == kO).length, kOColor),
          VsTally('무승부', local.where((r) => r.isDraw).length, scheme.outline),
          if (online.isNotEmpty) VsTally('Wi‑Fi 대결 승', online.where((r) => r.onlineWon == true).length, const Color(0xFFF2A900)),
        ];
      },
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
      if (r.vsCpu || r.online) '${sideLabel(r.human!)}로 플레이',
      if (r.online) 'Wi‑Fi' else if (!r.vsCpu) '2인',
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
      color: sideColor(r.winner!),
      title: r.resigned ? '${sideLabel(1 - r.winner!)} 기권 · ${sideLabel(r.winner!)} 승리' : '${sideLabel(r.winner!)} 승리',
      detail: detail,
      resigned: r.resigned,
    );
  }
}
