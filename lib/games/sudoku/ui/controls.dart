import 'package:flutter/material.dart';

import '../../../core/tablet_scale.dart';
import '../../../tutorial/pulse.dart';
import '../game/hint.dart';
import '../game/sudoku_game.dart';
import 'sudoku_colors.dart';

/// 태블릿에서 숫자 패드·도구 단추의 글자와 그림을 키우는 배율 (폰은 1).
double _tabletK(BuildContext context) => MediaQuery.sizeOf(context).shortestSide >= kTabletMinSide ? 1.3 : 1.0;

/// 숫자 패드. 숫자 아래에 남은 개수를 보여주고, 다 놓은 숫자는 숨긴다.
class NumberPad extends StatelessWidget {
  const NumberPad({super.key, required this.game, this.columns = 9, this.spotlight = false});

  final SudokuGame game;

  /// 튜토리얼에서 "이 숫자 패드를 쓰세요" 하고 깜빡여 알려준다.
  final bool spotlight;

  /// 9 = 한 줄, 3 = 3×3 격자 (태블릿 가로 화면).
  final int columns;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) {
        // 메모 모드일 때는 숫자 색도 녹색 계열이 된다
        final colors = SudokuColors.of(context, notes: game.notesMode);
        final rows = 9 ~/ columns;
        return PulseHighlight(
          active: spotlight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var r = 0; r < rows; r++)
                Padding(
                  padding: EdgeInsets.only(bottom: r < rows - 1 ? 8 : 0),
                  child: Row(
                    children: [
                      for (var c = 0; c < columns; c++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: _DigitButton(
                              game: game,
                              digit: r * columns + c + 1,
                              colors: colors,
                              wide: columns < 9,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _DigitButton extends StatelessWidget {
  const _DigitButton({
    required this.game,
    required this.digit,
    required this.colors,
    required this.wide,
  });

  final SudokuGame game;
  final int digit;
  final SudokuColors colors;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final remaining = game.remaining(digit);
    final selected = game.quickMode && game.quickDigit == digit;
    final scheme = Theme.of(context).colorScheme;
    final k = _tabletK(context);
    final done = remaining <= 0;
    return Opacity(
      opacity: done ? 0 : 1,
      child: IgnorePointer(
        ignoring: done,
        child: AspectRatio(
          aspectRatio: wide ? 1.5 : 0.66,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: selected ? scheme.surface : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(12),
              boxShadow: selected
                  ? [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : null,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                key: ValueKey('pad-$digit'),
                borderRadius: BorderRadius.circular(12),
                onTap: () => game.padDigit(digit),
                // 칸이 작아도 넘치지 않도록 내용을 알아서 줄인다.
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$digit',
                          style: TextStyle(
                            fontSize: (wide ? 34 : 30) * k,
                            height: 1.1,
                            fontWeight: FontWeight.w700,
                            color: selected || game.notesMode
                                ? colors.accent
                                : scheme.onSurface.withValues(alpha: 0.72),
                          ),
                        ),
                        Text(
                          '$remaining',
                          style: TextStyle(
                            fontSize: 13 * k,
                            color: scheme.onSurface.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 취소 / 지우기 / 메모 / 빠른 메모 / 힌트.
class ActionBar extends StatelessWidget {
  const ActionBar({super.key, required this.game, this.spotlight = const {}});

  final SudokuGame game;

  /// 튜토리얼에서 깜빡여 알려줄 버튼: 'undo' 'erase' 'notes' 'auto' 'hint'.
  final Set<String> spotlight;

  @override
  Widget build(BuildContext context) {
    final colors = SudokuColors.of(context);
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => Row(
        children: [
          _ActionButton(
            icon: Icons.undo_rounded,
            label: '되돌리기',
            spotlight: spotlight.contains('undo'),
            enabled: game.canUndo,
            onTap: game.undo,
          ),
          _ActionButton(
            icon: Icons.backspace_outlined,
            label: '지우기',
            spotlight: spotlight.contains('erase'),
            onTap: game.erase,
          ),
          _ActionButton(
            icon: Icons.edit_rounded,
            label: '메모',
            spotlight: spotlight.contains('notes'),
            badge: game.notesMode ? 'ON' : null,
            highlight: game.notesMode,
            color: SudokuColors.of(context, notes: true).accent,
            onTap: game.toggleNotes,
          ),
          _ActionButton(
            icon: Icons.auto_fix_high_rounded,
            label: '빠른 메모',
            spotlight: spotlight.contains('auto'),
            onTap: game.autoNotes,
          ),
          _ActionButton(
            icon: Icons.lightbulb_rounded,
            label: '힌트',
            spotlight: spotlight.contains('hint'),
            highlight: game.hint != null && !game.hint!.visualOnly,
            color: colors.accent,
            onTap: game.requestHint,
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.enabled = true,
    this.badge,
    this.highlight = false,
    this.color,
    this.spotlight = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool enabled;
  final String? badge;
  final bool highlight;
  final Color? color;
  final bool spotlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = highlight ? (color ?? scheme.primary) : scheme.onSurface.withValues(alpha: 0.75);
    final fg = enabled ? base : base.withValues(alpha: 0.3);
    final k = _tabletK(context);
    return Expanded(
      child: PulseHighlight(
        active: spotlight,
        child: InkResponse(
          onTap: enabled ? onTap : null,
          radius: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(icon, size: 32 * k, color: fg),
                    if (badge != null)
                      Positioned(
                        right: -16,
                        top: -6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: color ?? scheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badge!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: scheme.onPrimary,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(fontSize: 13 * k, color: fg)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 번개 토글: 켜면 "숫자를 먼저 고르고 칸을 누르는" 빠른 입력 방식.
class QuickInputToggle extends StatelessWidget {
  const QuickInputToggle({super.key, required this.game});

  final SudokuGame game;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: game,
      builder: (context, _) => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Flexible(
            child: Text(
              game.quickMode ? '빠른 입력: 숫자를 고른 뒤 칸을 누르세요' : '빠른 입력',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: game.quickMode ? 0.8 : 0.5),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: game.quickMode,
            onChanged: (_) => game.toggleQuick(),
            thumbIcon: WidgetStateProperty.resolveWith(
              (states) => Icon(
                Icons.bolt_rounded,
                color: states.contains(WidgetState.selected)
                    ? scheme.primary
                    : scheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 힌트 설명 카드.
class HintPanel extends StatelessWidget {
  const HintPanel({super.key, required this.game, required this.hint});

  final SudokuGame game;
  final ActiveHint hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = SudokuColors.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.accent.withValues(alpha: 0.4), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_rounded, color: colors.accent, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  hint.title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: colors.accent,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: '닫기',
                icon: const Icon(Icons.close_rounded),
                onPressed: game.dismissHint,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(hint.message, style: const TextStyle(fontSize: 15, height: 1.5)),
          const SizedBox(height: 12),
          // 좁은 화면이나 큰 글자에서는 버튼이 다음 줄로 내려간다
          Wrap(
            alignment: WrapAlignment.end,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton(onPressed: game.dismissHint, child: const Text('직접 해볼래요')),
              FilledButton(onPressed: game.applyHint, child: Text(hint.applyLabel)),
            ],
          ),
        ],
      ),
    );
  }
}
