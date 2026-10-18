part of 'freecell_screen.dart';

/// bars 조각 (화면 코드를 역할별로 나눈 파일)
extension _FsBars on _FreecellScreenState {
  Widget _hintBanner() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final text = c.thinkingHint
            ? '풀이를 찾는 중…'
            : c.hintMessage ?? (c.hint != null ? '노란 카드를 표시된 곳으로 옮겨 보세요' : null);
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
              if (c.thinkingHint)
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2.4),
                  ),
                )
              else
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.lightbulb_rounded, size: 18, color: Color(0xFFB88700)),
                ),
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF3A2F00)),
                ),
              ),
              if (!c.thinkingHint)
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
          child: Row(children: _barButtons(settings)),
        );
      },
    );
  }

  /// 되돌리기·힌트·자동 올리기·처음부터 버튼 (아래 줄에서는 가로로, 가로 폰 화면에서는 세로로 놓인다).
  List<Widget> _barButtons(Settings settings) {
    return [
      GameBarButton(
        icon: Icons.undo_rounded,
        label: '되돌리기',
        onTap: c.canUndo ? c.undo : null,
      ),
      GameBarButton(
        icon: Icons.lightbulb_rounded,
        label: '힌트',
        onTap: c.canAct && !c.thinkingHint ? c.requestHint : null,
      ),
      GameBarButton(
        icon: Icons.auto_awesome_rounded,
        label: c.autoMoveEnabled ? '자동 올리기 켬' : '자동 올리기 끔',
        highlight: c.autoMoveEnabled,
        onTap: () {
          c.autoMoveEnabled = !c.autoMoveEnabled;
          settings.freecellAutoMove = c.autoMoveEnabled;
          c.start(); // 켰을 때 바로 올릴 카드가 있으면 올린다
        },
      ),
      GameBarButton(
        icon: Icons.refresh_rounded,
        label: '처음부터',
        onTap: _confirmRestart,
      ),
    ];
  }
}
