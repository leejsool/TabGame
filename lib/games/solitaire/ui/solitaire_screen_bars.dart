part of 'solitaire_screen.dart';

/// bars 조각 (화면 코드를 역할별로 나눈 파일)
extension _SsBars on _SolitaireScreenState {
  Widget _hintBanner() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final text = c.hintMessage ?? (c.hint != null ? '노란 카드를 표시된 곳으로 옮겨 보세요' : null);
        if (text == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3C4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD84D)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: c.hintThinking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFFB88700)),
                      )
                    : const Icon(Icons.lightbulb_rounded, size: 18, color: Color(0xFFB88700)),
              ),
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF3A2F00)),
                ),
              ),
              GestureDetector(
                onTap: c.dismissHint,
                child: const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.close_rounded, size: 18),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bottomBar() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final settings = SettingsScope.of(context);
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Row(
            children: [
              GameBarButton(icon: Icons.undo_rounded, label: '되돌리기', onTap: c.canUndo ? c.undo : null),
              GameBarButton(icon: Icons.lightbulb_rounded, label: '힌트', onTap: c.canAct ? c.requestHint : null),
              GameBarButton(
                icon: Icons.auto_awesome_rounded,
                label: c.autoMoveEnabled ? '자동 올리기 켬' : '자동 올리기 끔',
                highlight: c.autoMoveEnabled,
                onTap: () {
                  c.autoMoveEnabled = !c.autoMoveEnabled;
                  settings.solitaireAutoMove = c.autoMoveEnabled;
                  c.start();
                },
              ),
              GameBarButton(icon: Icons.refresh_rounded, label: '처음부터', onTap: _confirmRestart),
            ],
          ),
        );
      },
    );
  }
}
