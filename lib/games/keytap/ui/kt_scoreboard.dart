import 'package:flutter/material.dart';

import '../core/kt_run.dart';
import '../game/kt_race.dart';
import 'kt_board.dart';

/// 자리마다의 색 (경주 점수판).
const List<Color> kKtSeatColors = [Color(0xFF5A54D6), Color(0xFFE0663A), Color(0xFF1E9E78), Color(0xFFC2459A)];

/// 경주 점수판: 지금 순위대로 이름과 점수. [compact]면 한 줄 칩, 아니면 세로 목록 (가로 화면 옆 칸).
class KtScoreboard extends StatelessWidget {
  const KtScoreboard({super.key, required this.race, this.compact = true});

  final KtRace race;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ranks = ktRanks(race.scores);
    final order = [for (var i = 0; i < race.players; i++) i]..sort((a, b) => ranks[a] != ranks[b] ? ranks[a] - ranks[b] : a - b);
    final tiles = [for (final s in order) _tile(s, ranks[s])];
    if (compact) {
      return Row(children: [for (final t in tiles) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3), child: t))]);
    }
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('지금 순위', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900))),
          for (final t in tiles) Padding(padding: const EdgeInsets.only(bottom: 8), child: t),
        ],
      ),
    );
  }

  Widget _tile(int seat, int rank) {
    final me = seat == race.mySeat;
    final color = kKtSeatColors[seat % kKtSeatColors.length];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 5 : 10),
      decoration: BoxDecoration(
        color: me ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: me ? color : color.withValues(alpha: 0.35), width: me ? 2 : 1),
      ),
      child: Row(
        children: [
          Text('${rank + 1}', style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: compact ? 14 : 18)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              race.names[seat] + (race.isCpu(seat) && !race.names[seat].startsWith('CPU') ? ' (CPU)' : ''),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: compact ? 12 : 15, fontWeight: me ? FontWeight.w900 : FontWeight.w600, color: const Color(0xFF2A2840)),
            ),
          ),
          Text('${race.scores[seat].hits}', style: TextStyle(fontWeight: FontWeight.w900, color: kKeytapColor, fontSize: compact ? 14 : 18)),
        ],
      ),
    );
  }
}
