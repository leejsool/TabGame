import 'package:flutter/material.dart';

import 'yacht_look.dart';

/// 한 기기로 함께 할 때 앉을 사람: "플레이어 (n/4)" 틀 안에서 봇(CPU)과 로컬 플레이어(사람)를 각각 + / − 로 늘리고 줄인다.
/// 아래에 자리별 목록(색 · 이름)이 보인다. 사람이 앞자리, 봇이 뒷자리다.
class YachtPartyPicker extends StatelessWidget {
  const YachtPartyPicker({super.key, required this.humans, required this.bots, required this.onChanged});

  /// 이 기기에서 돌려 가며 하는 사람 수 (1 이상).
  final int humans;

  /// 봇(CPU) 수.
  final int bots;

  final void Function(int humans, int bots) onChanged;

  static const int minPlayers = 2;
  static const int maxPlayers = 4;

  int get _total => humans + bots;

  /// +/− 를 눌렀을 때의 (사람, 봇). 누를 수 없으면 null.
  /// 자리가 꽉 찼을 때(4명) 늘리거나, 최소(2명)일 때 줄이면 다른 쪽과 한 자리를 맞바꾼다:
  /// 봇1·로컬3에서 로컬+ → 봇0·로컬4, 봇1·로컬1에서 봇− → 봇0·로컬2, 봇0·로컬2에서 로컬− → 봇1·로컬1.
  static (int, int)? step(int humans, int bots, {int humanDelta = 0, int botDelta = 0}) {
    final total = humans + bots;
    if (humanDelta > 0) {
      if (total < maxPlayers) return (humans + 1, bots);
      return bots > 0 ? (humans + 1, bots - 1) : null;
    }
    if (humanDelta < 0) {
      if (humans <= 1) return null; // 사람은 적어도 한 명
      return total > minPlayers ? (humans - 1, bots) : (humans - 1, bots + 1);
    }
    if (botDelta > 0) {
      if (total < maxPlayers) return (humans, bots + 1);
      return humans > 1 ? (humans - 1, bots + 1) : null;
    }
    if (botDelta < 0) {
      if (bots <= 0) return null;
      return total > minPlayers ? (humans, bots - 1) : (humans + 1, bots - 1);
    }
    return null;
  }

  /// 자리 [seat]의 이름 (사람이 한 명이면 "나", 봇이 한 명이면 "CPU").
  static String seatName(int seat, int humans, int bots) {
    if (seat < humans) return humans == 1 ? '나' : '플레이어 ${seat + 1}';
    return bots == 1 ? 'CPU' : 'CPU ${seat - humans + 1}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final line = scheme.outlineVariant;
    VoidCallback? press({int h = 0, int b = 0}) {
      final next = step(humans, bots, humanDelta: h, botDelta: b);
      return next == null ? null : () => onChanged(next.$1, next.$2);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  const Text('플레이어', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(color: kYachtColor.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                    child: Text('$_total/$maxPlayers', key: const ValueKey('yacht-party-total'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kYachtColor)),
                  ),
                ],
              ),
            ),
            _stepRow(
              context,
              id: 'bots',
              label: '봇',
              info: '컴퓨터(CPU)가 대신 굴려요',
              count: bots,
              onPlus: press(b: 1),
              onMinus: press(b: -1),
            ),
            _stepRow(
              context,
              id: 'humans',
              label: '로컬 플레이어',
              info: '이 기기를 돌려 가며 하는 사람이에요',
              count: humans,
              onPlus: press(h: 1),
              onMinus: press(h: -1),
            ),
            Divider(height: 1, color: line),
            for (var seat = 0; seat < _total; seat++) _seatRow(context, seat),
          ],
        ),
      ),
    );
  }

  Widget _stepRow(
    BuildContext context, {
    required String id,
    required String label,
    required String info,
    required int count,
    required VoidCallback? onPlus,
    required VoidCallback? onMinus,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final line = scheme.outlineVariant;
    return Container(
      decoration: BoxDecoration(border: Border(top: BorderSide(color: line))),
      height: 56,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 16),
              child: Row(
                children: [
                  Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
                  const SizedBox(width: 6),
                  Tooltip(
                    message: info,
                    triggerMode: TooltipTriggerMode.tap,
                    child: Icon(Icons.info_rounded, size: 20, color: scheme.outline),
                  ),
                  const SizedBox(width: 10),
                  Text('$count', key: ValueKey('yacht-$id-count'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
          ),
          _stepButton(context, ValueKey('yacht-$id-plus'), Icons.add_rounded, onPlus),
          _stepButton(context, ValueKey('yacht-$id-minus'), Icons.remove_rounded, onMinus),
        ],
      ),
    );
  }

  Widget _stepButton(BuildContext context, Key key, IconData icon, VoidCallback? onTap) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      key: key,
      onTap: onTap,
      child: Container(
        width: 64,
        height: double.infinity,
        decoration: BoxDecoration(border: Border(left: BorderSide(color: scheme.outlineVariant))),
        child: Icon(icon, size: 28, color: onTap == null ? scheme.outlineVariant : scheme.onSurface),
      ),
    );
  }

  Widget _seatRow(BuildContext context, int seat) {
    final scheme = Theme.of(context).colorScheme;
    final bot = seat >= humans;
    final color = kYachtSeatColors[seat];
    return Container(
      key: ValueKey('yacht-party-seat-$seat'),
      height: 54,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: bot ? null : color.withValues(alpha: 0.06),
        border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6))),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
            child: Icon(bot ? Icons.smart_toy_rounded : Icons.person_rounded, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Text(seatName(seat, humans, bots), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          if (seat == 0) ...[
            const SizedBox(width: 8),
            Text('먼저 시작', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ],
        ],
      ),
    );
  }
}
