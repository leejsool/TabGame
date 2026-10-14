import 'package:flutter/material.dart';

import 'date_format.dart';
import 'format.dart';

/// 포기한 판을 알리는 색 (기록 화면의 "포기" 표시).
const Color kGiveUpColor = Color(0xFFD9822B);

/// "이 판을 포기할까요?" 확인창. 포기하면 true.
/// [retry]가 false면(상대와 겨루는 게임 등 같은 판을 되풀이할 수 없는 경우) 다시 도전 안내를 뺀다.
Future<bool> confirmGiveUp(BuildContext context, {String? detail, bool retry = true, String verb = '포기'}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.flag_outlined, size: 32, color: kGiveUpColor),
      title: Text('이 판을 $verb할까요?'),
      content: Text(
        '${detail == null ? '' : '$detail\n\n'}$verb한 판은 기록에 남아요.'
        '${retry ? '\n기록 화면의 "포기한 판"에서 같은 판에 다시 도전할 수 있어요.' : ''}',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('계속하기')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: kGiveUpColor),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(verb),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// 포기한 뒤 보여주는 안내창. [again]이 있으면 "새 판" 단추도 보여준다. 새 판을 고르면 true.
Future<bool> showGaveUpDialog(
  BuildContext context, {
  required String summary,
  String againLabel = '새 판',
  bool offerAgain = true,
  bool retry = true,
  String verb = '포기',
}) async {
  final again = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.flag_rounded, size: 32, color: kGiveUpColor),
      title: Text('$verb했어요', textAlign: TextAlign.center),
      content: Text(
        '$summary\n기록에 남겨 두었어요.${retry ? ' 나중에 "내 기록 → 포기한 판"에서 다시 도전할 수 있어요.' : ''}',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('메뉴로')),
        if (offerAgain) FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(againLabel)),
      ],
    ),
  );
  return again ?? false;
}

/// 기록 화면의 "포기" 딱지.
class GiveUpChip extends StatelessWidget {
  const GiveUpChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: kGiveUpColor.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('포기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kGiveUpColor)),
    );
  }
}

/// 기록 화면의 "포기한 판" 한 줄: 제목 / 보조 설명 / "다시 도전" 단추.
class GiveUpTile extends StatelessWidget {
  const GiveUpTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.at,
    required this.onRetry,
    this.seconds,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;

  /// 포기한 시각 (epoch ms).
  final int at;

  /// 포기하기까지 걸린 시간(초). 없으면 보여주지 않는다.
  final int? seconds;

  /// 다시 도전할 수 없는 기록이면 null.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: kGiveUpColor.withValues(alpha: 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                        ),
                      ),
                      const SizedBox(width: 6),
                      const GiveUpChip(),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (seconds != null) '${formatTime(seconds!)} 하다가',
                      if (subtitle.isNotEmpty) subtitle,
                      formatDate(at),
                    ].join(' · '),
                    style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.65)),
                  ),
                ],
              ),
            ),
            if (onRetry != null)
              // 좁은 화면(폰)에서는 아이콘만 보여준다
              if (MediaQuery.sizeOf(context).width < 460)
                IconButton.filledTonal(tooltip: '다시 도전', onPressed: onRetry, icon: const Icon(Icons.replay_rounded))
              else
                FilledButton.tonalIcon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.replay_rounded, size: 18),
                  label: const Text('다시 도전'),
                ),
          ],
        ),
      ),
    );
  }
}
