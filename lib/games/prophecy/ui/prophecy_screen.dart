import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../core/settings_scope.dart';
import '../../../records/records_screen.dart';
import '../core/prophecy_ai.dart';
import '../core/prophecy_rules.dart';
import '../data/prophecy_history.dart';
import '../game/prophecy_controller.dart';
import '../tutorial/prophecy_tutorial.dart';
import 'prophecy_board.dart';
import 'prophecy_lesson_screen.dart';

/// 예언 플레이 화면.
class ProphecyScreen extends StatefulWidget {
  const ProphecyScreen({
    super.key,
    this.mode = PlayMode.local2p,
    this.rows = 5,
    this.cols = 5,
    this.humanSide = 0,
    this.level = ProphLevel.normal,
    this.controller,
  });

  final PlayMode mode;
  final int rows, cols;
  final int humanSide;
  final ProphLevel level;

  /// (테스트용) 미리 만든 컨트롤러.
  final ProphecyController? controller;

  @override
  State<ProphecyScreen> createState() => _ProphecyScreenState();
}

class _ProphecyScreenState extends State<ProphecyScreen> {
  // 화면이 직접 소유한다: 화면이 다시 빌드되어도 판이 사라지지 않는다.
  late final ProphecyController c = widget.controller ??
      ProphecyController(mode: widget.mode, rows: widget.rows, cols: widget.cols, humanSide: widget.humanSide, level: widget.level);
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
    switch (kind) {
      case 'write':
        HapticFeedback.selectionClick();
      case 'cross':
        HapticFeedback.lightImpact();
      case 'bad':
        HapticFeedback.vibrate();
      case 'win':
        HapticFeedback.heavyImpact();
    }
  }

  void _onChanged() {
    if (c.isOver && !_resultHandled) {
      _resultHandled = true;
      final sc = c.state.scores();
      ProphHistory.add(ProphRecord(
        at: DateTime.now().millisecondsSinceEpoch,
        vsCpu: c.vsCpu,
        rows: c.rows,
        cols: c.cols,
        score0: sc[0],
        score1: sc[1],
        winner: c.state.winner,
        moves: c.moveCount,
        level: c.vsCpu ? c.level : null,
        human: c.vsCpu ? c.humanSide : null,
      ));
    } else if (!c.isOver) {
      _resultHandled = false;
    }
  }

  /// 플레이어 이름: 둘이서는 "플레이어 1/2", CPU 대결은 "나/CPU".
  String _name(int side) => c.vsCpu ? (side == c.humanSide ? '나' : 'CPU') : '플레이어 ${side + 1}';

  Future<void> _resign() async {
    if (!c.canResign) return;
    final side = c.resigningSide;
    final ok = await confirmGiveUp(
      context,
      detail: c.vsCpu ? 'CPU의 승리로 기록돼요.' : '${_name(side)}이(가) 기권하고, ${_name(1 - side)}의 승리로 기록돼요.',
      retry: false,
      verb: '기권',
    );
    if (!ok || !mounted || !c.resign()) return;
    _resultHandled = true; // (끝난 판으로 한 번 더 기록되지 않게)
    await ProphHistory.add(ProphRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: c.vsCpu,
      rows: c.rows,
      cols: c.cols,
      score0: 0,
      score1: 0,
      winner: 1 - side,
      moves: c.moveCount,
      level: c.vsCpu ? c.level : null,
      human: c.vsCpu ? c.humanSide : null,
      resigned: true,
    ));
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: c.vsCpu ? 'CPU ${c.level.label} · ${c.moveCount}수' : '${_name(side)} 기권 · ${c.moveCount}수',
      againLabel: '새 판',
      retry: false,
      verb: '기권',
    );
    if (!mounted) return;
    if (again) {
      _resultHandled = false;
      c.restart();
    } else {
      Navigator.of(context).pop();
    }
  }

  // ── 안내 문구 ──

  String get _status {
    final s = c.state;
    if (c.isOver) {
      final w = s.winner;
      if (w == null) return '무승부예요';
      if (c.vsCpu) return w == c.humanSide ? '이겼어요! 🎉' : 'CPU가 이겼어요';
      return '${_name(w)} 승리! 🎉';
    }
    if (c.thinking) return 'CPU가 쓰는 중…';
    final who = c.vsCpu ? (s.turn == c.humanSide ? '내 차례' : 'CPU 차례') : '${_name(s.turn)} 차례';
    String tail;
    if (c.humanCanAct && c.selected >= 0) {
      tail = '${s.rowOf(c.selected) + 1}행 ${s.colOf(c.selected) + 1}열에 쓸 숫자나 X를 고르세요';
    } else {
      tail = '빈칸을 눌러 숫자나 X를 쓰세요';
    }
    final auto = c.lastAuto.isEmpty ? '' : '\n쓸 숫자가 없는 칸 ${c.lastAuto.length}개는 X로 채웠어요 (차례는 그대로)';
    return '$who · $tail$auto';
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
                ? const [Color(0xFF20223A), Color(0xFF191B2E)]
                : const [Color(0xFFEAEDFB), Color(0xFFD6DCF5)],
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
        child: Center(child: ProphBoard(controller: c)),
      );

  Widget _portrait() => Column(
        children: [
          _playerChips(),
          _statusBanner(),
          Expanded(child: _board()),
          _panel(),
          _bottomBar(),
        ],
      );

  Widget _landscape() => Row(
        children: [
          Expanded(child: _board()),
          SizedBox(
            width: 340,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _playerChips(),
                  _statusBanner(),
                  const SizedBox(height: 8),
                  _panel(),
                  _bottomBar(),
                ],
              ),
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
              '예언',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '교과학습',
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: () => openProphecyLesson(context),
          ),
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () => openRecords(context, game: 'prophecy'),
          ),
          IconButton(
            tooltip: '규칙',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => showProphecyRules(context),
          ),
        ],
      ),
    );
  }

  /// 두 사람 칩: 지금 차례인 쪽이 강조되고, 끝나면 점수가 붙는다.
  Widget _playerChips() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final sc = c.isOver ? c.state.scores() : null;
        Widget chip(int side) {
          final active = !c.isOver && c.state.turn == side;
          final color = penColor(side);
          final win = c.isOver && c.state.winner == side;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: active || win ? 0.2 : 0.07),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color.withValues(alpha: active || win ? 1 : 0.3), width: active || win ? 2.5 : 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded, size: 18, color: color),
                const SizedBox(width: 6),
                Text(_name(side), style: TextStyle(fontWeight: FontWeight.w800, color: color)),
                if (sc != null) ...[
                  const SizedBox(width: 8),
                  Text('${sc[side]}점', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: color)),
                ],
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Wrap(spacing: 12, runSpacing: 6, alignment: WrapAlignment.center, children: [chip(0), chip(1)]),
        );
      },
    );
  }

  Widget _statusBanner() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final color = c.isOver ? Colors.grey : penColor(c.state.turn);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
        );
      },
    );
  }

  /// 아래 칸: 진행 중에는 숫자판, 끝나면 점수 풀이.
  Widget _panel() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => c.isOver ? _ScorePanel(controller: c, name: _name, onAgain: c.restart, onMenu: () => Navigator.of(context).pop()) : _numberPad(),
    );
  }

  Widget _numberPad() {
    final s = c.state;
    final scheme = Theme.of(context).colorScheme;
    final active = c.humanCanAct && c.selected >= 0;
    if (!active) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text(
          '오른쪽과 아래의 작은 숫자는 지금 그 줄에 쓰인 숫자(X 빼고)의 개수예요.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.7)),
        ),
      );
    }
    final color = penColor(c.vsCpu ? c.humanSide : s.turn);
    final legal = s.legalNumbers(c.selected).toSet();
    Widget key(String label, int value, {double width = 46}) {
      final ok = value == kCross || legal.contains(value);
      return SizedBox(
        width: width,
        height: 46,
        child: FilledButton(
          style: FilledButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: color.withValues(alpha: ok ? 0.16 : 0.04),
            foregroundColor: color,
            disabledBackgroundColor: scheme.onSurface.withValues(alpha: 0.05),
            disabledForegroundColor: scheme.onSurface.withValues(alpha: 0.28),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: ok ? () => c.write(value) : null,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              decoration: ok ? null : TextDecoration.lineThrough,
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var n = 1; n <= s.maxNumber; n++) key('$n', n),
              key('X', kCross, width: 56),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            legal.length == s.maxNumber ? '같은 행·열에 같은 숫자는 쓸 수 없어요' : '줄이 그어진 숫자는 같은 행이나 열에 이미 있어서 쓸 수 없어요',
            style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.65)),
          ),
        ],
      ),
    );
  }

  Widget _bottomBar() {
    final compact = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      visualDensity: VisualDensity.compact,
    );
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            OutlinedButton.icon(
              style: compact,
              onPressed: c.canUndo ? c.undo : null,
              icon: const Icon(Icons.undo_rounded, size: 20),
              label: const Text('되돌리기'),
            ),
            OutlinedButton.icon(
              style: compact,
              onPressed: () => c.restart(),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('새 판'),
            ),
            OutlinedButton.icon(
              style: compact,
              onPressed: c.canResign ? _resign : null,
              icon: const Icon(Icons.flag_outlined, size: 20),
              label: const Text('기권'),
            ),
          ],
        ),
      ),
    );
  }
}

/// 판이 끝난 뒤 점수 풀이: 누가 어떤 예언을 맞혀 몇 점을 얻었는지.
class _ScorePanel extends StatelessWidget {
  const _ScorePanel({required this.controller, required this.name, required this.onAgain, required this.onMenu});

  final ProphecyController controller;
  final String Function(int side) name;
  final VoidCallback onAgain;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final s = controller.state;
    final parts = s.scoreParts();
    final sc = s.scores();
    final scheme = Theme.of(context).colorScheme;
    Widget row(int side) {
      final color = penColor(side);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(Icons.edit_rounded, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(child: Text(name(side), style: TextStyle(fontWeight: FontWeight.w800, color: color))),
            Text('행 ${parts.rowPts[side]} + 열 ${parts.colPts[side]}', style: const TextStyle(fontSize: 13)),
            const SizedBox(width: 10),
            SizedBox(
              width: 48,
              child: Text('${sc[side]}점', textAlign: TextAlign.right, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          row(0),
          row(1),
          const SizedBox(height: 4),
          Text(
            '동그라미: 맞힌 예언 · 좌우 화살표는 행, 위아래 화살표는 열에서 맞힌 거예요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.65)),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(onPressed: onMenu, child: const Text('메뉴로')),
              const SizedBox(width: 8),
              FilledButton(onPressed: onAgain, child: const Text('한 판 더')),
            ],
          ),
        ],
      ),
    );
  }
}

/// 규칙 설명.
Future<void> showProphecyRules(BuildContext context) {
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
      title: const Text('예언 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('두 사람이 번갈아 빈칸에 숫자나 X를 써요.'),
            line('숫자는 "이 줄(행·열)에 숫자가 모두 몇 개 나타날까"에 대한 예언이에요. X는 칸을 채우기만 하고 숫자가 아니에요.'),
            line('쓸 수 있는 숫자는 1부터 가장 긴 줄의 칸 수까지예요.'),
            line('한 행이나 열에는 같은 숫자를 두 번 쓸 수 없어요.'),
            line('어떤 숫자도 쓸 수 없는 칸은 저절로 X가 돼요. 이건 차례로 세지 않아요.'),
            line('표가 가득 차면 행마다 숫자가 몇 개인지 세요. 그 개수와 같은 숫자를 쓴 사람이 그 숫자만큼 점수를 얻어요. 열도 똑같이 세요.'),
            line('한 숫자가 행과 열에서 모두 맞으면 두 번 점수가 돼요. 점수가 더 높은 사람이 이겨요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            prophecyTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}
