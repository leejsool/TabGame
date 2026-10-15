import 'package:flutter/material.dart';

import '../records/records_screen.dart';
import '../tutorial/tutorial_button.dart';
import '../tutorial/tutorial.dart';

/// 대결 게임(CPU와 / 둘이서)의 시작 전 설정 화면 틀.
///
/// 위에는 게임마다 다른 선택(내 쪽, 점의 수 …)을 [children]으로 넣고, 아래의 "시작하기",
/// "튜토리얼 보기", (있으면) "교과학습" 버튼과 앱바의 "내 기록" 버튼은 이 틀이 만든다.
class VsSetupScaffold extends StatelessWidget {
  const VsSetupScaffold({
    super.key,
    required this.gameId,
    required this.title,
    required this.children,
    required this.onStart,
    required this.tutorial,
    this.onLesson,
  });

  /// game_registry의 id (내 기록 버튼이 이 게임의 기록을 연다).
  final String gameId;
  final String title;

  /// 시작 버튼 위에 놓일 선택들 ([VsSectionTitle], [VsChoiceCard], [VsLevelPicker] …).
  final List<Widget> children;
  final VoidCallback onStart;
  final GameTutorial Function() tutorial;

  /// 교과학습 화면을 여는 함수. 없으면 교과학습 버튼을 만들지 않는다.
  final VoidCallback? onLesson;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () => openRecords(context, game: gameId),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                ...children,
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('시작하기'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),
                TutorialButton(tutorial: tutorial),
                if (onLesson != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onLesson,
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('교과학습'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 설정 화면의 소제목 + 아래 간격.
class VsSectionTitle extends StatelessWidget {
  const VsSectionTitle(this.text, {super.key, this.topGap = 0});

  final String text;

  /// 앞 구역과의 간격 (첫 구역은 0, 다음 구역은 보통 24).
  final double topGap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: topGap, bottom: 12),
      child: Text(text, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
    );
  }
}

/// 선택 아래에 붙는 작은 안내 글.
class VsHint extends StatelessWidget {
  const VsHint(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6)),
      ),
    );
  }
}

/// "내 쪽" 같은 큰 선택 카드의 틀: [color]로 물들고 [selected]면 테두리가 굵어진다. 안쪽 그림·글은 [child].
class VsChoiceCard extends StatelessWidget {
  const VsChoiceCard({
    super.key,
    required this.color,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: color.withValues(alpha: selected ? 0.20 : 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? color : color.withValues(alpha: 0.25), width: selected ? 3 : 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 16), child: child),
      ),
    );
  }
}

/// 카드 두 장 이상을 한 줄에 나란히 (사이 간격 12).
class VsChoiceRow extends StatelessWidget {
  const VsChoiceRow({super.key, required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }
}

/// "CPU 난이도" 고르기: 난이도마다 이름과 설명이 있는 라디오 타일 목록.
class VsLevelPicker<T> extends StatelessWidget {
  const VsLevelPicker({
    super.key,
    required this.levels,
    required this.selected,
    required this.onChanged,
    required this.label,
    required this.description,
  });

  final List<T> levels;
  final T selected;
  final ValueChanged<T> onChanged;
  final String Function(T level) label;
  final String Function(T level) description;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        for (final l in levels) ...[
          Material(
            color: l == selected ? scheme.primaryContainer : scheme.surface,
            elevation: l == selected ? 0 : 1,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => onChanged(l),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Icon(
                      l == selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                      color: l == selected ? scheme.primary : scheme.outline,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(label(l), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                          Text(description(l), style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}
