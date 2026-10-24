import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'game_info.dart';

/// 게임 목록(허브·기록 화면의 게임 고르개)을 거르는 분류.
///
/// 분류는 게임 등록 정보([GameInfo])에서 저절로 정해지니, 게임이 늘어나도 등록만 하면 알맞은 분류에 들어간다.
/// 새 분류를 만들 때는 여기에 항목과 [matches]만 더하면 두 화면에 모두 나온다.
enum GameFilter {
  mentoring(Icons.co_present_rounded, '멘토링'),
  all(Icons.apps_rounded, '전체'),
  solo(Icons.person_rounded, '혼자'),
  multi(Icons.groups_rounded, '함께'),
  wifi(Icons.wifi_rounded, 'Wi‑Fi'),
  lesson(Icons.school_rounded, '교과학습');

  const GameFilter(this.icon, this.label);

  final IconData icon;
  final String label;

  /// 분류 막대 알약에 쓰는 짧은 이름.
  String get shortLabel => this == GameFilter.lesson ? '학습' : label;

  /// 멘토링(게임하며 수학 배우기) 시간에 쓰는 게임들. 임시 분류라 나중에 없앨 수 있다.
  static const mentoringGames = {'stones', 'dandelion', 'park', 'goblet_gobblers'};

  bool matches(GameInfo g) => switch (this) {
        GameFilter.mentoring => mentoringGames.contains(g.id),
        GameFilter.all => true,
        GameFilter.solo => g.hasSolo,
        GameFilter.multi => g.hasMulti,
        GameFilter.wifi => g.hasWifi,
        GameFilter.lesson => g.hasLesson,
      };

  /// 이 기기에서 쓸 수 있는 분류들. 같은 Wi‑Fi 연결은 웹에서는 쓸 수 없으니 웹에서는 Wi‑Fi 분류를 뺀다.
  static List<GameFilter> get available => [for (final f in values) if (!(kIsWeb && f == GameFilter.wifi)) f];
}

/// 칸 구분선 없이 알약 모양으로 고르는 분류 막대. 모든 항목에 아이콘과 짧은 이름이 보이고, 고른 항목은 색으로 채워진다.
/// 좁은 화면에서는 통째로 줄어들어 넘치지 않는다.
class GameFilterBar extends StatelessWidget {
  const GameFilterBar({super.key, required this.selected, required this.onChanged, this.alignment = Alignment.centerLeft});

  final GameFilter selected;
  final ValueChanged<GameFilter> onChanged;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: .6),
          borderRadius: BorderRadius.circular(32),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final f in GameFilter.available) _FilterPill(filter: f, selected: f == selected, onTap: () => onChanged(f)),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.filter, required this.selected, required this.onTap});

  final GameFilter filter;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = selected ? scheme.onPrimary : scheme.onSurfaceVariant;
    return Tooltip(
      message: filter.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: selected ? scheme.primary : Colors.transparent, borderRadius: BorderRadius.circular(28)),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(filter.icon, size: 24, color: fg),
              const SizedBox(width: 6),
              Text(filter.shortLabel, softWrap: false, style: TextStyle(fontSize: 16, fontWeight: selected ? FontWeight.w800 : FontWeight.w600, color: fg)),
            ],
          ),
        ),
      ),
    );
  }
}
