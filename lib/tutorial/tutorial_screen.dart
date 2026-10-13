import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'tutorial.dart';

/// 한 장씩 넘겨 보는 "게임 방법" 화면. 언제든 건너뛸 수 있다.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({
    super.key,
    required this.tutorial,
    this.firstTime = false,
  });

  final GameTutorial tutorial;

  /// 게임을 처음 열 때 자동으로 뜬 안내인가 (마지막 버튼 문구만 달라진다).
  final bool firstTime;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _pages = PageController();
  int _page = 0;

  List<TutorialStep> get _steps => widget.tutorial.steps;
  bool get _isLast => _page == _steps.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  void _go(int page) {
    if (page < 0 || page >= _steps.length) return;
    _pages.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  void _next() => _isLast ? Navigator.of(context).pop() : _go(_page + 1);

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.arrowRight) {
      _next();
      return KeyEventResult.handled;
    }
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft) {
      _go(_page - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.tutorial.color;
    final scheme = Theme.of(context).colorScheme;
    return Focus(
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${widget.tutorial.title} 게임 방법',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: accent,
                            ),
                          ),
                        ),
                        // 마지막 장에서는 아래 버튼이 닫는 역할이라 건너뛰기를 숨긴다.
                        if (!_isLast)
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(
                              '건너뛰기',
                              style: TextStyle(
                                color: scheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                          )
                        else
                          const SizedBox(height: 48),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _ProgressBar(
                      count: _steps.length,
                      index: _page,
                      color: accent,
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pages,
                      itemCount: _steps.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (context, i) =>
                          _StepPage(step: _steps[i], accent: accent),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 96,
                          child: _page == 0
                              ? null
                              : Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton.icon(
                                    onPressed: () => _go(_page - 1),
                                    icon: const Icon(
                                      Icons.chevron_left_rounded,
                                    ),
                                    label: const Text('이전'),
                                  ),
                                ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton(
                            onPressed: _next,
                            style: FilledButton.styleFrom(
                              backgroundColor: accent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              textStyle: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              _isLast
                                  ? (widget.firstTime ? '게임 시작하기' : '다 봤어요')
                                  : '다음',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 96,
                          child: Text(
                            '${_page + 1} / ${_steps.length}',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              color: scheme.onSurface.withValues(alpha: 0.5),
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.count,
    required this.index,
    required this.color,
  });

  final int count;
  final int index;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final off = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12);
    return Row(
      children: [
        for (var i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 240),
              height: 5,
              decoration: BoxDecoration(
                color: i <= index ? color : off,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepPage extends StatelessWidget {
  const _StepPage({required this.step, required this.accent});

  final TutorialStep step;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final art = Container(
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      child: step.art != null
          ? Padding(
              padding: const EdgeInsets.all(14),
              child: step.art!(context, accent),
            )
          : Icon(step.icon ?? Icons.lightbulb_rounded, size: 96, color: accent),
    );
    final text = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            step.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            step.body,
            style: TextStyle(
              fontSize: 16.5,
              height: 1.6,
              color: scheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth > box.maxHeight * 1.15;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
          child: wide
              ? Row(
                  children: [
                    Expanded(flex: 5, child: art),
                    const SizedBox(width: 20),
                    Expanded(flex: 4, child: Center(child: text)),
                  ],
                )
              : Column(
                  children: [
                    Expanded(flex: 5, child: art),
                    const SizedBox(height: 16),
                    Expanded(flex: 4, child: text),
                  ],
                ),
        );
      },
    );
  }
}
