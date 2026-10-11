import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/game_info.dart';
import '../../../core/settings_scope.dart';
import '../../../records/records_screen.dart';
import '../core/uttt_ai.dart';
import '../core/uttt_rules.dart';
import '../data/uttt_history.dart';
import '../game/uttt_controller.dart';
import 'uttt_board.dart';

const _boardNames = [
  '왼쪽 위', '가운데 위', '오른쪽 위',
  '왼쪽 가운데', '한가운데', '오른쪽 가운데',
  '왼쪽 아래', '가운데 아래', '오른쪽 아래',
];

/// 얼티밋 틱택토 플레이 화면.
class UtttScreen extends StatefulWidget {
  const UtttScreen({
    super.key,
    this.mode = PlayMode.local2p,
    this.humanSide = kX,
    this.level = UttLevel.normal,
    this.controller,
  });

  final PlayMode mode;
  final int humanSide;
  final UttLevel level;

  /// (테스트용) 미리 만든 컨트롤러.
  final UtttController? controller;

  @override
  State<UtttScreen> createState() => _UtttScreenState();
}

class _UtttScreenState extends State<UtttScreen> {
  // 화면이 직접 소유한다: 화면이 다시 빌드되어도 판이 사라지지 않는다.
  late final UtttController c = widget.controller ??
      UtttController(mode: widget.mode, humanSide: widget.humanSide, level: widget.level);
  bool _resultHandled = false;

  @override
  void initState() {
    super.initState();
    c.onFeedback = _feedback;
    c.addListener(_onChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
  }

  @override
  void dispose() {
    c.removeListener(_onChanged);
    c.onFeedback = null;
    c.dispose();
    super.dispose();
  }

  void _feedback(String kind) {
    if (!SettingsScope.of(context).haptics) return;
    if (kind == 'place') {
      HapticFeedback.selectionClick();
    } else if (kind == 'win') {
      HapticFeedback.heavyImpact();
    }
  }

  void _onChanged() {
    if (c.isOver && !_resultHandled) {
      _resultHandled = true;
      final o = c.outcome;
      UtttHistory.add(UtttRecord(
        at: DateTime.now().millisecondsSinceEpoch,
        vsCpu: c.vsCpu,
        winner: o == Outcome.xWins ? kX : o == Outcome.oWins ? kO : null,
        moves: c.moveCount,
        level: c.vsCpu ? c.level : null,
        human: c.vsCpu ? c.humanSide : null,
      ));
      Future<void>.delayed(const Duration(milliseconds: 1500), _showResult);
    } else if (!c.isOver) {
      _resultHandled = false;
    }
  }

  Future<void> _showResult() async {
    if (!mounted || !c.isOver) return;
    final again = await showDialog<bool>(
      context: context,
      builder: (_) => _ResultDialog(controller: c),
    );
    if (!mounted) return;
    if (again == true) {
      c.restart();
    } else if (again == false) {
      Navigator.of(context).pop();
    }
  }

  // ── 안내 문구 ──

  String get _status {
    if (c.isOver) {
      return switch (c.outcome) {
        Outcome.xWins => c.vsCpu ? (c.humanSide == kX ? '이겼어요! 🎉' : 'CPU가 이겼어요') : 'X 승리!',
        Outcome.oWins => c.vsCpu ? (c.humanSide == kO ? '이겼어요! 🎉' : 'CPU가 이겼어요') : 'O 승리!',
        _ => '무승부예요',
      };
    }
    if (c.thinking) return 'CPU가 생각하는 중…';
    final s = c.state;
    final who = c.vsCpu
        ? (s.turn == c.humanSide ? '내 차례' : 'CPU 차례')
        : '${sideLabel(s.turn)} 차례';
    final where = s.next >= 0 ? '${_boardNames[s.next]} 판에서 두세요' : '아무 판에서나 두세요';
    return '$who · $where';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? const [Color(0xFF1F2430), Color(0xFF181B24)]
                : const [Color(0xFFFFF3DC), Color(0xFFFFE6C9)],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              final landscape = box.maxWidth > box.maxHeight * 1.2;
              return Column(
                children: [
                  _topBar(),
                  Expanded(child: landscape ? _landscape() : _portrait()),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _board() => Padding(
        padding: const EdgeInsets.all(10),
        child: Center(
          child: UtttBoard(
            controller: c,
            onMove: (m) {
              if (!c.play(m)) {
                // 둘 수 없는 칸이면 살짝 알려준다
                if (SettingsScope.of(context).haptics) HapticFeedback.lightImpact();
              }
            },
          ),
        ),
      );

  Widget _portrait() => Column(
        children: [
          _playerChips(),
          _statusBanner(),
          Expanded(child: _board()),
          _bottomBar(),
        ],
      );

  Widget _landscape() => Row(
        children: [
          Expanded(child: _board()),
          SizedBox(
            width: 300,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _playerChips(),
                _statusBanner(),
                const SizedBox(height: 12),
                _bottomBar(),
              ],
            ),
          ),
        ],
      );

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: '뒤로',
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          Flexible(
            child: Text(
              '얼티밋 틱택토',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () => openRecords(context, game: 'ultimate_tictactoe'),
          ),
          IconButton(
            tooltip: '규칙',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => showUtttRules(context),
          ),
        ],
      ),
    );
  }

  /// X / O 두 칩: 지금 차례인 쪽이 강조된다.
  Widget _playerChips() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        Widget chip(int side) {
          final active = !c.isOver && c.state.turn == side;
          final name = c.vsCpu ? (side == c.humanSide ? '나' : 'CPU') : '플레이어 ${side + 1}';
          final color = sideColor(side);
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: active ? 0.22 : 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: active ? 1 : 0.3), width: active ? 2.5 : 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CustomPaint(painter: _MarkIconPainter(side)),
                ),
                const SizedBox(width: 8),
                Text(name, style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [chip(kX), chip(kO)],
          ),
        );
      },
    );
  }

  Widget _statusBanner() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final turn = c.isOver ? null : c.state.turn;
        final color = turn == null ? Colors.grey : sideColor(turn);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(
            _status,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        );
      },
    );
  }

  Widget _bottomBar() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: c.canUndo ? c.undo : null,
              icon: const Icon(Icons.undo_rounded),
              label: const Text('되돌리기'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: () => c.restart(),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('새 판'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkIconPainter extends CustomPainter {
  const _MarkIconPainter(this.side);

  final int side;

  @override
  void paint(Canvas canvas, Size size) {
    drawMark(canvas, side, Offset.zero & size, 1, strokeWidth: size.width * 0.16);
  }

  @override
  bool shouldRepaint(_MarkIconPainter old) => old.side != side;
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({required this.controller});

  final UtttController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final o = c.outcome;
    final winnerSide = o == Outcome.xWins ? kX : o == Outcome.oWins ? kO : null;
    String title, body;
    if (winnerSide == null) {
      title = '무승부';
      body = '모든 판이 끝났지만 큰 줄이 나오지 않았어요.';
    } else if (c.vsCpu) {
      final me = winnerSide == c.humanSide;
      title = me ? '이겼어요! 🎉' : 'CPU가 이겼어요';
      body = me ? '${sideLabel(winnerSide)}로 큰 줄을 만들었어요!' : '다음엔 꼭 이겨 봐요!';
    } else {
      title = '${sideLabel(winnerSide)} 승리! 🎉';
      body = '축하해요!';
    }
    return AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (winnerSide != null)
            SizedBox(
              width: 80,
              height: 80,
              child: CustomPaint(painter: _MarkIconPainter(winnerSide)),
            ),
          const SizedBox(height: 12),
          Text('$body\n(${c.moveCount}수)', textAlign: TextAlign.center),
        ],
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('메뉴로')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('한 판 더')),
      ],
    );
  }
}

/// 규칙 설명.
Future<void> showUtttRules(BuildContext context) {
  Widget line(String t) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('•  '),
            Expanded(child: Text(t, style: const TextStyle(height: 1.4))),
          ],
        ),
      );
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('얼티밋 틱택토 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('큰 판 안에 작은 틱택토 판이 9개 있어요.'),
            line('내가 둔 칸의 위치가 곧 상대가 다음에 둘 작은 판이에요. (예: 오른쪽 위 칸에 두면, 상대는 오른쪽 위 판에서 둬요)'),
            line('보내진 판이 이미 끝났으면, 상대는 아무 판에서나 둘 수 있어요.'),
            line('작은 판에서 세 칸을 한 줄로 만들면 그 판을 차지해요.'),
            line('차지한 판 세 개를 큰 판에서 한 줄로 이으면 이겨요!'),
            line('작은 판이 가득 차도 줄이 없으면 무승부 판이라 아무도 못 가져요.'),
            line('반짝이는 판이 지금 둘 수 있는 판이에요.'),
          ],
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요'))],
    ),
  );
}
