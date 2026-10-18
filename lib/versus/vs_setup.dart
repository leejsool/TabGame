import 'package:flutter/material.dart';

import '../core/game_save.dart';
import '../core/game_widgets.dart';
import '../records/record_widgets.dart' show confirmOverwrite;
import '../records/records_screen.dart';
import '../tutorial/tutorial_button.dart';
import '../tutorial/tutorial.dart';

/// 이어하던 판이 있는 대결 게임의 이어하기 설정.
class VsResume {
  const VsResume({required this.gameName, required this.describe, required this.onResume});

  /// "이어하던 ○○ 판은 사라져요" 같은 안내에 쓰는 게임 이름.
  final String gameName;

  /// 저장된 판을 한 줄로 설명한다 (예: "CPU 2명 · 보통 · 12번째 차례").
  final String Function(Map<String, dynamic> saved) describe;

  /// 저장된 판을 열어 이어서 한다.
  final void Function(Map<String, dynamic> saved) onResume;
}

/// 대결 게임(CPU와 / 둘이서)의 시작 전 설정 화면 틀.
///
/// 위에는 게임마다 다른 선택(내 쪽, 점의 수 …)을 [children]으로 넣고, 아래의 "시작하기",
/// "튜토리얼 보기", (있으면) "교과학습" 버튼과 앱바의 "내 기록" 버튼은 이 틀이 만든다.
/// [resume]이 있으면 이어하던 판이 있을 때 맨 위에 "이어하기" 카드를 보여 주고,
/// 그 상태에서 새로 시작하려 하면 이어하던 판이 사라져도 되는지 먼저 묻는다.
class VsSetupScaffold extends StatefulWidget {
  const VsSetupScaffold({
    super.key,
    required this.gameId,
    required this.title,
    required this.children,
    required this.onStart,
    required this.tutorial,
    this.onLesson,
    this.startLabel = '시작하기',
    this.resume,
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

  /// 시작 버튼의 글자.
  final String startLabel;

  /// 이어하기 (같은 Wi‑Fi 방 만들기처럼 이어할 수 없는 설정이면 null).
  final VsResume? resume;

  @override
  State<VsSetupScaffold> createState() => _VsSetupScaffoldState();
}

class _VsSetupScaffoldState extends State<VsSetupScaffold> {
  Map<String, dynamic>? _saved;

  @override
  void initState() {
    super.initState();
    if (widget.resume != null) {
      GameSave.changes.addListener(_load);
      _load();
    }
  }

  @override
  void dispose() {
    if (widget.resume != null) GameSave.changes.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final saved = await GameSave.load(widget.gameId);
    if (mounted) setState(() => _saved = saved);
  }

  Future<void> _start() async {
    final resume = widget.resume;
    if (resume != null) {
      // 판이 끝나는 순간에 지워지니, 눌린 시점에 보관된 것이 있는지 다시 본다
      final saved = await GameSave.load(widget.gameId);
      if (saved != null) {
        if (!mounted) return;
        final ok = await confirmOverwrite(context, gameName: resume.gameName);
        if (!ok) return;
        await GameSave.clear(widget.gameId);
      }
    }
    widget.onStart();
  }

  @override
  Widget build(BuildContext context) {
    final resume = widget.resume;
    final saved = _saved;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () => openRecords(context, game: widget.gameId),
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
                if (resume != null && saved != null) ...[
                  _ResumeCard(describe: resume.describe(saved), onTap: () => resume.onResume(saved)),
                  const SizedBox(height: 20),
                ],
                ...widget.children,
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _start,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(widget.startLabel),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontFamily: 'NanumGothic', fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(height: 10),
                TutorialButton(tutorial: widget.tutorial),
                if (widget.onLesson != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: widget.onLesson,
                    icon: const Icon(Icons.menu_book_rounded),
                    label: const Text('교과학습'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      textStyle: const TextStyle(fontFamily: 'NanumGothic', fontSize: 16, fontWeight: FontWeight.w800),
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

/// 맨 위의 "이어하기" 카드.
class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.describe, required this.onTap});

  final String describe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ResumeCard(key: const ValueKey('vs-resume'), compact: true, detail: describe, onTap: onTap);
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
