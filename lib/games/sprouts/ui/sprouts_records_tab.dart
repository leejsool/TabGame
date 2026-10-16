import 'package:flutter/material.dart';

import '../../../core/date_format.dart';
import '../../../core/game_info.dart';
import '../../../records/vs_records.dart';
import '../core/sprouts_ai.dart';
import '../data/sprouts_history.dart';
import 'sprouts_painter.dart';
import 'sprouts_screen.dart';

/// 콩나물 기록 보드: CPU 난이도별 전적 + 둘이서 요약 + 최근 결과.
class SproutsRecordsTab extends StatelessWidget {
  const SproutsRecordsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return VsRecordsBoard<SproutsRecord, SproutsLevel>(
      load: SproutsHistory.load,
      emptyIcon: Icons.scatter_plot_rounded,
      levels: SproutsLevel.values,
      levelLabel: (l) => l.label,
      levelOf: (r) => r.level,
      isCpu: (r) => r.vsCpu,
      humanWon: (r) => r.humanWon,
      twoPlayerTallies: (two, scheme) {
        final local = [for (final r in two) if (!r.online) r]; // Wi‑Fi 대결은 "플레이어 1/2"가 없다
        final online = [for (final r in two) if (r.online) r];
        return [
          VsTally('플레이어 1 승', local.where((r) => r.winner == 0).length, sproutsColor(0)),
          VsTally('플레이어 2 승', local.where((r) => r.winner == 1).length, sproutsColor(1)),
          if (online.isNotEmpty) VsTally('Wi‑Fi 대결 승', online.where((r) => r.onlineWon == true).length, const Color(0xFFF2A900)),
        ];
      },
      tile: _tile,
      onRetry: (context, r) => r.resigned && r.vsCpu
          ? () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => SproutsScreen(mode: PlayMode.vsCpu, dotCount: r.dots, humanSide: r.human!, level: r.level!),
              ))
          : null,
    );
  }

  static VsTile _tile(BuildContext context, SproutsRecord r, ColorScheme scheme) {
    final detail = [
      formatDate(r.at),
      '점 ${r.dots}개',
      if (r.vsCpu || r.online) (r.human == 0 ? '먼저' : '나중'),
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
      color: sproutsColor(r.winner),
      title: r.resigned ? '플레이어 ${2 - r.winner} 기권 · 플레이어 ${r.winner + 1} 승리' : '플레이어 ${r.winner + 1} 승리',
      detail: detail,
      resigned: r.resigned,
    );
  }
}
