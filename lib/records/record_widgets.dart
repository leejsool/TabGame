import 'package:flutter/material.dart';

import 'favorites.dart';

/// 기록 화면에서 쓰는 요약 카드 (제목 / 큰 값 / 보조 설명).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.sub,
    required this.color,
  });

  final String title;
  final String value;
  final String sub;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );
  }
}

/// 기록이 하나도 없을 때.
class EmptyRecords extends StatelessWidget {
  const EmptyRecords({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(icon, size: 56, color: scheme.outline),
          const SizedBox(height: 14),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.5, color: scheme.onSurface.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Text(
          text,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
      );
}

/// 이어하던 판이 있는데 다른 판을 새로 시작하려 할 때 확인한다. 계속하면 true.
Future<bool> confirmOverwrite(BuildContext context, {required String gameName}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('이어하던 판이 있어요'),
      content: Text('지금 새 판을 시작하면 이어하던 $gameName 판은 사라져요. 그래도 시작할까요?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('새로 시작')),
      ],
    ),
  );
  return ok ?? false;
}

/// 기록 탭들의 공통 바탕: 가운데 정렬 + 최대 폭 제한 + 위아래 여백.
class RecordsList extends StatelessWidget {
  const RecordsList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: children,
        ),
      ),
    );
  }
}

/// 다시 할 수 있는 완성 기록 한 줄: 왼쪽 그림, 제목(최고 기록이면 트로피), 설명, 즐겨찾기 별, 다시 하기 단추.
/// 좁은 화면(폰)에서는 다시 하기 단추가 아이콘만 보인다.
class ReplayRecordTile extends StatelessWidget {
  const ReplayRecordTile({
    super.key,
    required this.leading,
    required this.title,
    required this.detail,
    this.best = false,
    this.favorite = false,
    this.onToggleFavorite,
    this.replayLabel = '다시 하기',
    required this.onReplay,
  });

  /// 왼쪽 그림. 보통은 [ReplayRecordTile.badge] (색 동그라미 + 아이콘).
  final Widget leading;
  final String title;
  final String detail;

  /// 같은 갈래에서 가장 빠른 기록이면 제목 옆에 트로피.
  final bool best;
  final bool favorite;

  /// 없으면 별을 보이지 않는다 (다시 할 수 없는 기록).
  final VoidCallback? onToggleFavorite;
  final String replayLabel;
  final VoidCallback? onReplay;

  /// 색 동그라미 안의 아이콘.
  static Widget badge(Color color, IconData icon) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
        child: Icon(icon, color: color),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(title, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                      if (best) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.emoji_events_rounded, size: 18, color: Color(0xFFF2A900)),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(detail, style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.65))),
                ],
              ),
            ),
            if (onToggleFavorite != null) FavoriteStar(on: favorite, onTap: onToggleFavorite!),
            if (MediaQuery.sizeOf(context).width < 460)
              IconButton.filledTonal(tooltip: replayLabel, onPressed: onReplay, icon: const Icon(Icons.replay_rounded))
            else
              FilledButton.tonalIcon(onPressed: onReplay, icon: const Icon(Icons.replay_rounded, size: 18), label: Text(replayLabel)),
          ],
        ),
      ),
    );
  }
}
