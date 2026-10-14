import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../core/settings_scope.dart';
import '../../../records/records_screen.dart';
import '../core/sprouts_ai.dart';
import '../data/sprouts_history.dart';
import '../game/sprouts_controller.dart';
import '../tutorial/sprouts_tutorial.dart';
import 'sprouts_board_view.dart';
import 'sprouts_lesson_screen.dart';
import 'sprouts_painter.dart';

/// 콩나물 플레이 화면.
class SproutsScreen extends StatefulWidget {
  const SproutsScreen({
    super.key,
    this.mode = PlayMode.local2p,
    this.dotCount = 3,
    this.humanSide = 0,
    this.level = SproutsLevel.normal,
    this.controller,
  });

  final PlayMode mode;
  final int dotCount;
  final int humanSide;
  final SproutsLevel level;

  /// (테스트용) 미리 만든 컨트롤러.
  final SproutsController? controller;

  @override
  State<SproutsScreen> createState() => _SproutsScreenState();
}

class _SproutsScreenState extends State<SproutsScreen> {
  // 화면이 직접 소유한다: 화면이 다시 빌드되어도 판이 사라지지 않는다.
  late SproutsController c = widget.controller ??
      SproutsController(mode: widget.mode, dotCount: widget.dotCount, humanSide: widget.humanSide, level: widget.level);
  bool _resultHandled = false;

  @override
  void initState() {
    super.initState();
    _attach(c);
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
  }

  void _attach(SproutsController ctl) {
    ctl.onFeedback = _feedback;
    ctl.addListener(_onChanged);
  }

  void _detach(SproutsController ctl) {
    ctl.removeListener(_onChanged);
    ctl.onFeedback = null;
  }

  @override
  void dispose() {
    _detach(c);
    c.dispose();
    super.dispose();
  }

  void _feedback(String kind) {
    if (!SettingsScope.of(context).haptics) return;
    switch (kind) {
      case 'draw':
        HapticFeedback.selectionClick();
      case 'bad':
        HapticFeedback.lightImpact();
      case 'win':
        HapticFeedback.heavyImpact();
    }
  }

  void _onChanged() {
    if (c.isOver && !_resultHandled && !c.resigned) {
      _resultHandled = true;
      SproutsHistory.add(SproutsRecord(
        at: DateTime.now().millisecondsSinceEpoch,
        vsCpu: c.vsCpu,
        winner: c.winner!,
        moves: c.moveCount,
        dots: c.dotCount,
        level: c.vsCpu ? c.level : null,
        human: c.vsCpu ? c.humanSide : null,
      ));
    } else if (!c.isOver) {
      _resultHandled = false;
    }
    if (mounted) setState(() {});
  }

  /// 같은 설정으로 새 판.
  void _newGame({bool swapStart = true}) {
    final old = c;
    _detach(old);
    c = old.fresh(swapStart: swapStart);
    _resultHandled = false;
    _attach(c);
    old.dispose();
    setState(() {});
    c.start();
  }

  Future<void> _resign() async {
    if (!c.canResign) return;
    final loser = c.vsCpu ? c.humanSide : c.turn;
    final ok = await confirmGiveUp(
      context,
      detail: c.vsCpu ? 'CPU의 승리로 기록돼요.' : '${_name(loser)}이(가) 기권하고, ${_name(1 - loser)}의 승리로 기록돼요.',
      retry: c.vsCpu,
      verb: '기권',
    );
    if (!ok || !mounted || !c.resign()) return;
    _resultHandled = true;
    await SproutsHistory.add(SproutsRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: c.vsCpu,
      winner: c.winner!,
      moves: c.moveCount,
      dots: c.dotCount,
      level: c.vsCpu ? c.level : null,
      human: c.vsCpu ? c.humanSide : null,
      resigned: true,
    ));
    if (mounted) setState(() {});
  }

  /// 플레이어 이름: 둘이서는 "플레이어 1/2", CPU 대결은 "나/CPU".
  String _name(int side) => c.vsCpu ? (side == c.humanSide ? '나' : 'CPU') : '플레이어 ${side + 1}';

  String get _status {
    if (c.message != null) return c.message!;
    if (c.notice != null && !c.isOver) return '${c.notice!} · ${_name(c.turn)} 차례';
    if (c.isOver) {
      if (c.vsCpu) return c.winner == c.humanSide ? '이겼어요! 🎉' : 'CPU가 이겼어요';
      return '${_name(c.winner!)} 승리! 🎉';
    }
    if (c.thinking) return 'CPU가 생각하는 중…';
    if (c.moveCount == 0) return '${_name(c.turn)} 차례 · 점에서 점으로 곡선을 그어 보세요';
    return '${_name(c.turn)} 차례 · 마지막으로 두는 사람이 이겨요';
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
                : const [Color(0xFFEAF6EC), Color(0xFFDDEFE3)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _topBar(),
              _playerChips(),
              _statusBanner(),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
                  child: SproutsBoardView(key: ValueKey(c), controller: c),
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      ),
    );
  }

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
              '콩나물',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '교과학습',
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: () => openSproutsLesson(context),
          ),
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () => openRecords(context, game: 'sprouts'),
          ),
          IconButton(
            tooltip: '규칙',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => showSproutsRules(context),
          ),
        ],
      ),
    );
  }

  Widget _playerChips() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        Widget chip(int side) {
          final active = !c.isOver && c.turn == side;
          final color = sproutsColor(side);
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
                Container(width: 18, height: 6, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Text(_name(side), style: TextStyle(fontWeight: FontWeight.w800, color: color)),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [chip(0), const SizedBox(width: 12), chip(1)],
          ),
        );
      },
    );
  }

  Widget _statusBanner() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final bad = c.message != null;
        final color = bad ? const Color(0xFFE5484D) : sproutsColor(c.isOver ? (c.winner ?? 0) : c.turn);
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.5)),
          ),
          child: Text(_status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        );
      },
    );
  }

  /// 판이 끝났을 때 아래에 나오는 안내: 창으로 가리지 않고, 그림은 그대로 보이게 한다.
  Widget _resultBar() {
    final w = c.winner!;
    final String head, body;
    if (c.resigned) {
      head = '기권했어요';
      body = c.vsCpu ? 'CPU ${c.level.label} · 점 ${c.dotCount}개 · ${c.moveCount}수 · 기록에 남겼어요' : '${_name(c.turn)} 기권 · ${c.moveCount}수 · 기록에 남겼어요';
    } else if (c.vsCpu) {
      final me = w == c.humanSide;
      head = me ? '더 이을 곳이 없어요!' : '더 이을 곳이 없어졌어요';
      body = '${me ? '내가 마지막으로 두었어요' : 'CPU가 마지막으로 두었어요. 다음엔 꼭 이겨 봐요!'} (점 ${c.dotCount}개 · ${c.moveCount}수)';
    } else {
      head = '더 이을 곳이 없어요!';
      body = '마지막으로 수를 둔 사람: ${_name(w)} (점 ${c.dotCount}개 · ${c.moveCount}수)';
    }
    final color = sproutsColor(w);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 2, 16, 10),
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(head, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13)),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              if (!c.resigned)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: c.canUndo ? c.undo : null,
                  icon: const Icon(Icons.undo_rounded, size: 20),
                  label: const Text('되돌리기'),
                ),
              TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('메뉴로')),
              FilledButton(onPressed: _newGame, child: const Text('한 판 더')),
            ],
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
      builder: (context, _) => c.isOver ? _resultBar() : Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        // 좁은 화면(폰)에서는 단추가 다음 줄로 넘어간다
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
              onPressed: c.humanCanAct ? c.showHint : null,
              icon: const Icon(Icons.lightbulb_rounded, size: 20),
              label: const Text('힌트'),
            ),
            OutlinedButton.icon(
              style: compact,
              onPressed: _newGame,
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

/// 규칙 설명.
Future<void> showSproutsRules(BuildContext context) {
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
      title: const Text('콩나물 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('내 차례에 점에서 점으로 손가락을 끌어 곡선을 그어요. (한 점에서 출발해 그 점으로 돌아오는 고리도 돼요)'),
            line('그은 선 위에 새 점이 저절로 하나 찍혀요. 이것이 한 수예요.'),
            line('선은 다른 선이나 자기 자신과 만나면 안 돼요. 다른 점 위를 지나가도 안 돼요.'),
            line('점 하나에는 선을 3개까지만 이을 수 있어요. 점 안의 숫자가 앞으로 더 이을 수 있는 선의 수예요.'),
            line('새 점은 이미 선이 2개 이어져 있어서 숫자가 1이에요.'),
            line('더 이을 수 없게 되면 끝나고, 마지막으로 수를 둔 사람이 이겨요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            sproutsTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}
