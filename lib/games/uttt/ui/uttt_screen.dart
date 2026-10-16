import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../core/settings_scope.dart';
import '../../../net/lan_connection.dart';
import '../tutorial/uttt_tutorial.dart';
import '../../../records/records_screen.dart';
import '../core/uttt_ai.dart';
import '../core/uttt_rules.dart';
import '../data/uttt_history.dart';
import '../game/uttt_controller.dart';
import 'uttt_board.dart';
import 'uttt_lesson_screen.dart';

const _boardNames = [
  '왼쪽 위', '가운데 위', '오른쪽 위',
  '왼쪽 가운데', '한가운데', '오른쪽 가운데',
  '왼쪽 아래', '가운데 아래', '오른쪽 아래',
];

/// 궁극 틱택토 플레이 화면.
class UtttScreen extends StatefulWidget {
  const UtttScreen({
    super.key,
    this.mode = PlayMode.local2p,
    this.humanSide = kX,
    this.level = UttLevel.normal,
    this.controller,
    this.link,
  });

  final PlayMode mode;
  final int humanSide;
  final UttLevel level;

  /// 같은 Wi‑Fi 대결([PlayMode.wifi])에서 상대 기기와의 연결. 이 화면이 닫을 때 같이 닫는다.
  final LanConnection? link;

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

  // ── 같은 Wi‑Fi 대결 ──
  LanConnection? get _link => c.online ? widget.link : null;
  StreamSubscription<Map<String, dynamic>>? _linkSub;

  /// 상대 기기와의 연결이 끊겼다 / 이 화면에서 일부러 나가는 중이다.
  bool _opponentGone = false;
  bool _leaving = false;

  /// 한 판 더: 내가 하자고 했다 / 상대가 하자고 했다 (둘 다 하면 먼저 시작하는 쪽을 바꿔 새로 시작한다).
  bool _rematchAsked = false;
  bool _rematchOffered = false;

  @override
  void initState() {
    super.initState();
    c.onFeedback = _feedback;
    c.addListener(_onChanged);
    final link = _link;
    if (link != null) {
      c.onLocalMove = (move) => link.send({'t': 'move', 'i': c.moveCount - 1, 'm': move});
      _linkSub = link.messages.listen(_onNet);
      link.closed.then((_) => _onLinkClosed());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
  }

  @override
  void dispose() {
    _leaving = true;
    _linkSub?.cancel();
    final link = _link;
    if (link != null) {
      link.send(const {'t': 'bye'});
      link.close();
    }
    c.removeListener(_onChanged);
    c.onFeedback = null;
    c.onLocalMove = null;
    c.dispose();
    super.dispose();
  }

  void _onNet(Map<String, dynamic> m) {
    if (!mounted) return;
    switch (m['t']) {
      case 'move':
        if (m['i'] != c.moveCount || m['m'] is! int || !c.receiveMove(m['m'] as int)) _desync();
      case 'resign':
        _onOpponentResigned();
      case 'again':
        setState(() => _rematchOffered = true);
        if (_rematchAsked) _startRematch();
      case 'bye':
        _onLinkClosed();
    }
  }

  /// 판이 서로 어긋났다 (있을 수 없는 일이지만, 어긋난 채로 계속하지는 않는다).
  Future<void> _desync() async {
    if (_opponentGone || _leaving) return;
    _opponentGone = true;
    await _link?.close();
    if (!mounted) return;
    await _notice('판이 서로 어긋났어요', '두 기기의 판이 달라져서 여기서 끝낼게요. 다시 방을 만들어 시작해 주세요.');
    if (mounted) Navigator.of(context).pop();
  }

  void _onLinkClosed() {
    if (!mounted || _leaving || _opponentGone) return;
    setState(() => _opponentGone = true);
    if (c.isOver || c.halted) return; // 끝난 판이면 결과를 마저 볼 수 있게 두고, "한 판 더"만 막는다
    _notice('상대와 연결이 끊겼어요', 'Wi‑Fi가 끊겼거나 상대가 나갔어요. 이 판은 기록하지 않아요.').then((_) {
      if (mounted) Navigator.of(context).pop();
    });
  }

  Future<void> _notice(String title, String body) => showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.wifi_off_rounded, size: 32),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(body, textAlign: TextAlign.center),
          actionsAlignment: MainAxisAlignment.center,
          actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('나가기'))],
        ),
      );

  Future<void> _onOpponentResigned() async {
    if (c.isOver || c.halted) return;
    c.opponentResigned();
    _resultHandled = true;
    await UtttHistory.add(UtttRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: false,
      online: true,
      winner: c.humanSide,
      moves: c.moveCount,
      human: c.humanSide,
      resigned: true,
    ));
    if (!mounted) return;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.emoji_events_rounded, size: 32, color: Color(0xFFF2A900)),
        title: const Text('상대가 기권했어요', textAlign: TextAlign.center),
        content: const Text('이번 판은 내가 이긴 걸로 기록해 두었어요.', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('메뉴로')),
          if (!_opponentGone) FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('한 판 더')),
        ],
      ),
    );
    if (!mounted) return;
    if (again == true) {
      _requestRematch();
    } else {
      Navigator.of(context).pop();
    }
  }

  /// "한 판 더": 상대도 하자고 했으면 바로 (먼저 시작하는 쪽을 바꿔) 시작하고, 아니면 상대를 기다린다.
  void _requestRematch() {
    if (_rematchAsked || _opponentGone) return;
    setState(() => _rematchAsked = true);
    _link?.send(const {'t': 'again'});
    if (_rematchOffered) _startRematch();
  }

  void _startRematch() {
    setState(() {
      _rematchAsked = false;
      _rematchOffered = false;
    });
    _resultHandled = false;
    c.restart();
  }

  /// 나갈 때: 진행 중인 Wi‑Fi 판이면 먼저 물어본다.
  Future<void> _confirmLeave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('판에서 나갈까요?'),
        content: const Text('나가면 상대와의 연결이 끊기고, 이 판은 기록되지 않아요.\n(이기고 지는 걸 기록하려면 "기권"을 눌러 주세요)', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('계속하기')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('나가기')),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.of(context).pop();
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
        online: c.online,
        winner: o == Outcome.xWins ? kX : o == Outcome.oWins ? kO : null,
        moves: c.moveCount,
        level: c.vsCpu ? c.level : null,
        human: c.oneSeat ? c.humanSide : null,
      ));
      Future<void>.delayed(const Duration(milliseconds: 1500), _showResult);
    } else if (!c.isOver) {
      _resultHandled = false;
    }
  }

  Future<void> _resign() async {
    if (!c.canResign) return;
    final side = c.resigningSide;
    final ok = await confirmGiveUp(
      context,
      detail: c.vsCpu
          ? 'CPU의 승리로 기록돼요.'
          : c.online
              ? '상대의 승리로 기록돼요.'
              : '${sideLabel(side)}가 기권하고, ${sideLabel(1 - side)}의 승리로 기록돼요.',
      retry: c.vsCpu,
      verb: '기권',
    );
    if (!ok || !mounted || !c.resign()) return;
    _resultHandled = true; // (끝난 판으로 한 번 더 기록되지 않게)
    _link?.send(const {'t': 'resign'});
    await UtttHistory.add(UtttRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: c.vsCpu,
      online: c.online,
      winner: 1 - side,
      moves: c.moveCount,
      level: c.vsCpu ? c.level : null,
      human: c.oneSeat ? c.humanSide : null,
      resigned: true,
    ));
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: c.vsCpu ? 'CPU ${c.level.label} · ${c.moveCount}수' : '${sideLabel(side)} 기권 · ${c.moveCount}수',
      againLabel: c.online ? '한 판 더' : '새 판',
      offerAgain: !_opponentGone,
      retry: false,
      verb: '기권',
    );
    if (!mounted) return;
    if (again && c.online) {
      _requestRematch();
    } else if (again) {
      _resultHandled = false;
      c.restart();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _showResult() async {
    if (!mounted || !c.isOver) return;
    final again = await showDialog<bool>(
      context: context,
      builder: (_) => _ResultDialog(controller: c, canAgain: !_opponentGone),
    );
    if (!mounted) return;
    if (again == true) {
      c.online ? _requestRematch() : c.restart();
    } else if (again == false) {
      Navigator.of(context).pop();
    }
  }

  // ── 안내 문구 ──

  String get _status {
    if (c.isOver) {
      String won(int side) => c.oneSeat ? (c.humanSide == side ? '이겼어요! 🎉' : (c.vsCpu ? 'CPU가 이겼어요' : '상대가 이겼어요')) : '${sideLabel(side)} 승리!';
      return switch (c.outcome) {
        Outcome.xWins => won(kX),
        Outcome.oWins => won(kO),
        _ => '무승부예요',
      };
    }
    if (_opponentGone) return '상대와 연결이 끊겼어요';
    if (c.halted) return _rematchAsked ? '상대가 한 판 더를 받아 주기를 기다리는 중이에요…' : '기권으로 끝난 판이에요';
    if (c.thinking) return 'CPU가 생각하는 중…';
    final s = c.state;
    final who = c.oneSeat
        ? (s.turn == c.humanSide ? '내 차례' : (c.vsCpu ? 'CPU 차례' : '상대 차례'))
        : '${sideLabel(s.turn)} 차례';
    final where = s.next >= 0 ? '${_boardNames[s.next]} 판에서 두세요' : '아무 판에서나 두세요';
    return '$who · $where';
  }

  @override
  Widget build(BuildContext context) {
    // Wi‑Fi 대결 도중에 나가려 하면 먼저 물어본다 (연결이 끊기니까).
    return ListenableBuilder(
      listenable: c,
      builder: (context, child) {
        final askBeforeLeave = c.online && !c.isOver && !c.halted && !_opponentGone;
        return PopScope(
          canPop: !askBeforeLeave,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmLeave();
          },
          child: child!,
        );
      },
      child: _scaffold(),
    );
  }

  Widget _scaffold() {
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
              '궁극 틱택토',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '교과학습',
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: () => openUtttLesson(context),
          ),
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
          final name = c.oneSeat ? (side == c.humanSide ? '나' : (c.vsCpu ? 'CPU' : (_link?.peerNick ?? '상대'))) : '플레이어 ${side + 1}';
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
    final compact = OutlinedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      visualDensity: VisualDensity.compact,
    );
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        // 좁은 화면(폰·옆 칸)에서는 단추가 다음 줄로 넘어간다
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 6,
          children: [
            if (!c.online) ...[
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
            ] else if (c.isOver || c.halted)
              // Wi‑Fi 대결: 판이 끝나면 "한 판 더"를 서로 눌러야 새 판이 시작된다
              FilledButton.icon(
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12), visualDensity: VisualDensity.compact),
                onPressed: _rematchAsked || _opponentGone ? null : _requestRematch,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: Text(_opponentGone
                    ? '상대가 나갔어요'
                    : _rematchAsked
                        ? '상대를 기다려요…'
                        : _rematchOffered
                            ? '한 판 더 (상대가 원해요)'
                            : '한 판 더'),
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
  const _ResultDialog({required this.controller, this.canAgain = true});

  final UtttController controller;

  /// false면 "한 판 더"가 없다 (Wi‑Fi 대결에서 상대가 나갔을 때).
  final bool canAgain;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final o = c.outcome;
    final winnerSide = o == Outcome.xWins ? kX : o == Outcome.oWins ? kO : null;
    String title, body;
    if (winnerSide == null) {
      title = '무승부';
      body = '모든 판이 끝났지만 큰 줄이 나오지 않았어요.';
    } else if (c.oneSeat) {
      final me = winnerSide == c.humanSide;
      title = me ? '이겼어요! 🎉' : (c.vsCpu ? 'CPU가 이겼어요' : '상대가 이겼어요');
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
        if (canAgain) FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('한 판 더')),
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
      title: const Text('궁극 틱택토 규칙'),
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
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            utttTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}
