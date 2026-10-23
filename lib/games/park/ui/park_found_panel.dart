import 'package:flutter/material.dart';

import '../core/park_rules.dart';
import 'park_board.dart';

/// 찾은 길 목록: "찾은 길 k가지" + 길마다 작은 그림 (누르면 큰 판에 보여 준다).
class ParkFoundPanel extends StatelessWidget {
  const ParkFoundPanel({
    super.key,
    required this.stage,
    required this.found,
    required this.allFound,
    required this.highlight,
    required this.onPick,
    required this.onClear,
    required this.onSort,
    this.horizontal = false,
  });

  final ParkStage stage;
  final List<List<Walk>> found;
  final bool allFound;

  /// 강조할 길 번호 (방금 찾았거나 "이미 찾았던 길"이었던 것).
  final int? highlight;
  final ValueChanged<int> onPick;
  final VoidCallback? onClear;

  /// 사전식(R·D)으로 줄 세우기. 이미 줄 서 있거나 2개 미만이면 null.
  final VoidCallback? onSort;

  /// 세로 화면: 한 줄로 옆으로 넘기기. 가로 화면: 여러 줄로 쌓기.
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final header = Row(children: [
      Icon(allFound ? Icons.emoji_events_rounded : Icons.route_rounded, color: allFound ? const Color(0xFFF2A900) : kParkColor),
      const SizedBox(width: 8),
      Expanded(
        child: Text(
          allFound ? '모두 찾았어요! 전부 ${found.length}가지' : '찾은 길 ${found.length}가지',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
      ),
      if (found.length >= 2)
        TextButton.icon(onPressed: onSort, icon: const Icon(Icons.sort_by_alpha_rounded), label: const Text('정렬')),
      if (onClear != null) TextButton.icon(onPressed: onClear, icon: const Icon(Icons.delete_sweep_rounded), label: const Text('지우기')),
    ]);
    final tiles = [for (var i = 0; i < found.length; i++) _tile(context, i, scheme)];
    final Widget body;
    if (found.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text('아직 없어요. 조건에 맞는 길을 완성하면 여기에 모여요.', style: TextStyle(color: scheme.onSurfaceVariant)),
      );
    } else if (horizontal) {
      body = SizedBox(
        height: 118,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tiles.length,
          separatorBuilder: (_, _) => const SizedBox(width: 8),
          itemBuilder: (_, i) => tiles[i],
        ),
      );
    } else {
      body = Wrap(spacing: 8, runSpacing: 8, children: tiles);
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [header, const SizedBox(height: 6), body]);
  }

  Widget _tile(BuildContext context, int i, ColorScheme scheme) {
    final on = i == highlight;
    return Material(
      color: on ? kParkColor.withValues(alpha: 0.18) : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onPick(i),
        child: Container(
          width: 84,
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: on ? kParkColor : Colors.transparent, width: 2.5),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 72, height: 72, child: ParkBoard(stage: stage, steps: found[i], compact: true)),
            Text('${i + 1}번', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            FittedBox(child: Text(pathKey(found[i]), style: const TextStyle(fontSize: 12, letterSpacing: 0.5))),
          ]),
        ),
      ),
    );
  }
}
