import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/tablet_scale.dart';
import '../game/sudoku_game.dart';
import '../ui/board_widget.dart';
import '../ui/controls.dart';
import '../ui/sudoku_colors.dart';

/// 스도쿠 튜토리얼 화면의 공통 틀: 위쪽 줄 + 판 + 설명 카드 + (필요하면) 입력 버튼.
/// 가로 화면에서는 판이 왼쪽, 나머지가 오른쪽에 놓인다.
class LessonShell extends StatefulWidget {
  const LessonShell({
    super.key,
    required this.game,
    required this.title,
    required this.panel,
    required this.onClose,
    this.actions = const [],
    this.closeLabel = '건너뛰기',
    this.progress,
    this.progressLabel,
    this.showControls = false,
    this.spotlight = const {},
    this.padSpotlight = false,
    this.revealSignal,
    this.quickToggle = false,
  });

  final SudokuGame game;
  final String title;

  /// 판 아래(가로 화면에서는 오른쪽)에 나오는 설명 카드.
  final Widget panel;
  final VoidCallback onClose;
  final String closeLabel;

  /// 화면 아래(가로 화면에서는 오른쪽 아래)에 늘 보이는 버튼들. 설명이 길어서 스크롤해도
  /// "다음" 같은 버튼은 항상 눌러 볼 수 있다.
  final List<Widget> actions;

  /// 0~1. 없으면 진행 막대를 그리지 않는다.
  final double? progress;
  final String? progressLabel;

  /// 숫자 패드와 취소·지우기·메모 버튼을 보여줄지.
  final bool showControls;
  final Set<String> spotlight;
  final bool padSpotlight;

  /// 이 값이 바뀌면 설명 카드를 맨 아래(방금 생긴 안내 문구)까지 스크롤한다.
  final Object? revealSignal;

  /// 입력 버튼 위에 "빠른 입력" 스위치를 둘지 (보통 게임 화면과 같은 자리). 켜면 [actions]도 그 줄 왼쪽에 놓아
  /// 판 아래 자리를 아낀다.
  final bool quickToggle;

  @override
  State<LessonShell> createState() => _LessonShellState();
}

class _LessonShellState extends State<LessonShell> {
  final ScrollController _scroll = ScrollController();

  @override
  void didUpdateWidget(LessonShell old) {
    super.didUpdateWidget(old);
    if (old.revealSignal != widget.revealSignal && widget.revealSignal != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, box) {
            final landscape = box.maxWidth > box.maxHeight * 1.1;
            return Column(
              children: [
                _topBar(context),
                Expanded(child: landscape ? _landscape() : _portrait()),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = SudokuColors.of(context).accent;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800, color: accent),
                ),
              ),
              if (widget.progressLabel != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    widget.progressLabel!,
                    style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.55)),
                  ),
                ),
              TextButton(
                onPressed: widget.onClose,
                child: Text(
                  widget.closeLabel,
                  style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75)),
                ),
              ),
            ],
          ),
          if (widget.progress != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: widget.progress!.clamp(0.0, 1.0),
                  minHeight: 5,
                  backgroundColor: scheme.onSurface.withValues(alpha: 0.1),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _board(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SudokuBoard(game: widget.game),
        ),
      ),
    );
  }

  /// 버튼들이 "빠른 입력" 줄에 함께 놓이는가.
  bool get _inlineActions => widget.quickToggle && widget.showControls;

  Widget _controls({int padColumns = 9}) {
    return ListenableBuilder(
      listenable: widget.game,
      builder: (context, _) {
        final hint = widget.game.hint;
        final toggleRow = widget.quickToggle
            ? Row(
                children: [
                  ...widget.actions,
                  const SizedBox(width: 8),
                  Expanded(child: QuickInputToggle(game: widget.game)),
                ],
              )
            : null;
        if (hint != null && !hint.visualOnly) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [?toggleRow, HintPanel(game: widget.game, hint: hint)],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ?toggleRow,
            ActionBar(game: widget.game, spotlight: widget.spotlight),
            const SizedBox(height: 10),
            // 가로 화면의 3×3 패드는 설명 카드 자리가 남도록 조금 작게
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: padColumns == 3 ? 280 : double.infinity),
              child: NumberPad(game: widget.game, columns: padColumns, spotlight: widget.padSpotlight),
            ),
          ],
        );
      },
    );
  }

  Widget _actionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Wrap(
        alignment: WrapAlignment.end,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 6,
        children: widget.actions,
      ),
    );
  }

  /// 설명 카드(스크롤) + 아래에 고정된 입력 버튼과 "다음" 버튼들.
  /// 판이 작아져도 이 영역은 화면 너비를 그대로 쓴다 (넓은 화면에서만 가운데로 모은다).
  Widget _lower(double maxHeight, {int padColumns = 9, double controlsShare = 0.45}) {
    // fit이 true이면 높이는 내용에 맞추고(아래에 고정되는 영역용), 아니면 주어진 높이를 모두 쓴다.
    Widget centered(Widget child, {bool fit = false}) => Align(
          alignment: Alignment.topCenter,
          heightFactor: fit ? 1 : null,
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 560), child: child),
        );
    return Column(
      children: [
        Expanded(
          child: centered(
            SingleChildScrollView(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: widget.panel,
            ),
          ),
        ),
        if (widget.showControls)
          ConstrainedBox(
            // 힌트 설명 카드가 열려도 화면을 넘치지 않도록 높이를 제한하고 스크롤시킨다.
            constraints: BoxConstraints(maxHeight: maxHeight * controlsShare),
            child: centered(
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: _controls(padColumns: padColumns),
              ),
              fit: true,
            ),
          ),
        if (widget.actions.isNotEmpty && !_inlineActions) centered(_actionBar(), fit: true),
      ],
    );
  }

  Widget _portrait() {
    return LayoutBuilder(
      builder: (context, box) {
        // 판 크기는 보통 게임 화면과 같게, 단계(설명 → 직접 해 보기)가 바뀌어도 그대로 둔다.
        // 숫자 패드와 버튼은 아래에 고정되고, 설명 카드는 남는 자리에서 스크롤된다.
        final tablet = MediaQuery.sizeOf(context).shortestSide >= kTabletMinSide;
        final boardSize = min(box.maxWidth - 24, box.maxHeight * (tablet ? 0.64 : 0.56));
        return Column(
          children: [
            const SizedBox(height: 8),
            SizedBox(width: boardSize, child: _board(context)),
            // 아래 영역 높이 기준: 입력 버튼이 많아야 이만큼만 쓰고, 나머지는 설명 카드 몫
            Expanded(child: _lower(box.maxHeight - boardSize - 8, controlsShare: 0.75)),
          ],
        );
      },
    );
  }

  Widget _landscape() {
    return LayoutBuilder(
      builder: (context, box) {
        final boardSize = min(box.maxHeight - 24, box.maxWidth * 0.58);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
              child: SizedBox(width: boardSize, height: boardSize, child: _board(context)),
            ),
            Expanded(child: _lower(box.maxHeight, padColumns: 3, controlsShare: 0.62)),
          ],
        );
      },
    );
  }
}

enum LessonTone { neutral, success, problem }

/// 설명 카드: 제목 + 설명 + (결과 메시지).
class LessonCard extends StatelessWidget {
  const LessonCard({
    super.key,
    required this.title,
    required this.text,
    this.badge,
    this.feedback,
    this.tone = LessonTone.neutral,
  });

  final String title;
  final String text;

  /// 제목 앞에 붙는 작은 꼬리표 (예: "Lv.2").
  final String? badge;

  /// 사용자가 뭔가 했을 때 돌려주는 말 ("정답이에요!" 등).
  final String? feedback;
  final LessonTone tone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = SudokuColors.of(context);
    final toneColor = switch (tone) {
      LessonTone.success => colors.place,
      LessonTone.problem => scheme.error,
      LessonTone.neutral => colors.accent,
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.accent.withValues(alpha: 0.35), width: 1.5),
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
              if (badge != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colors.accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    badge!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: colors.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(text, style: const TextStyle(fontSize: 15, height: 1.55)),
          if (feedback != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: toneColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                feedback!,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  fontWeight: FontWeight.w700,
                  color: toneColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
