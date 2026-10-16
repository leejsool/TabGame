import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../core/settings_scope.dart';
import '../../../net/lan_connection.dart';
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
    this.link,
  });

  final PlayMode mode;
  final int rows, cols;
  final int humanSide;
  final ProphLevel level;

  /// 같은 Wi‑Fi 대결([PlayMode.wifi])에서 상대 기기와의 연결. 이 화면이 닫을 때 같이 닫는다.
  final LanConnection? link;

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

  // ── 같은 Wi‑Fi 대결 ──
  LanConnection? get _link => c.online ? widget.link : null;
  StreamSubscription<Map<String, dynamic>>? _linkSub;

  /// 상대 기기와의 연결이 끊겼다 / 이 화면에서 일부러 나가는 중이다.
  bool _opponentGone = false;
  bool _leaving = false;

  /// 한 판 더: 내가 하자고 했다 / 상대가 하자고 했다 (둘 다 하면 쪽을 바꿔 새로 시작한다).
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
    await ProphHistory.add(ProphRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: false,
      online: true,
      rows: c.rows,
      cols: c.cols,
      score0: 0,
      score1: 0,
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

  /// "한 판 더": 상대도 하자고 했으면 바로 (먼저/나중을 바꿔) 시작하고, 아니면 상대를 기다린다.
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
    c.restart(swapSides: true);
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
        online: c.online,
        rows: c.rows,
        cols: c.cols,
        score0: sc[0],
        score1: sc[1],
        winner: c.state.winner,
        moves: c.moveCount,
        level: c.vsCpu ? c.level : null,
        human: c.oneSeat ? c.humanSide : null,
      ));
    } else if (!c.isOver) {
      _resultHandled = false;
    }
  }

  /// 플레이어 이름: 둘이서는 "플레이어 1/2", CPU 대결은 "나/CPU".
  String _name(int side) => c.oneSeat ? (side == c.humanSide ? '나' : (c.vsCpu ? 'CPU' : (_link?.peerNick ?? '상대'))) : '플레이어 ${side + 1}';

  Future<void> _resign() async {
    if (!c.canResign) return;
    final side = c.resigningSide;
    final ok = await confirmGiveUp(
      context,
      detail: c.vsCpu
          ? 'CPU의 승리로 기록돼요.'
          : c.online
              ? '상대의 승리로 기록돼요.'
              : '${_name(side)}이(가) 기권하고, ${_name(1 - side)}의 승리로 기록돼요.',
      retry: false,
      verb: '기권',
    );
    if (!ok || !mounted || !c.resign()) return;
    _resultHandled = true; // (끝난 판으로 한 번 더 기록되지 않게)
    _link?.send(const {'t': 'resign'});
    await ProphHistory.add(ProphRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: c.vsCpu,
      online: c.online,
      rows: c.rows,
      cols: c.cols,
      score0: 0,
      score1: 0,
      winner: 1 - side,
      moves: c.moveCount,
      level: c.vsCpu ? c.level : null,
      human: c.oneSeat ? c.humanSide : null,
      resigned: true,
    ));
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: c.vsCpu ? 'CPU ${c.level.label} · ${c.moveCount}수' : '${_name(side)} 기권 · ${c.moveCount}수',
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

  // ── 안내 문구 ──

  String get _status {
    final s = c.state;
    if (c.isOver) {
      final w = s.winner;
      if (w == null) return '무승부예요';
      if (c.oneSeat) return w == c.humanSide ? '이겼어요! 🎉' : (c.vsCpu ? 'CPU가 이겼어요' : '상대가 이겼어요');
      return '${_name(w)} 승리! 🎉';
    }
    if (_opponentGone) return '상대와 연결이 끊겼어요';
    if (c.halted) return _rematchAsked ? '상대가 한 판 더를 받아 주기를 기다리는 중이에요…' : '기권으로 끝난 판이에요';
    if (c.cpuCell >= 0) {
      final where = '${s.rowOf(c.cpuCell) + 1}행 ${s.colOf(c.cpuCell) + 1}열';
      return c.cpuValue == null ? 'CPU가 $where 칸을 골랐어요…' : 'CPU가 $where에 ${c.cpuValue == kCross ? 'X' : '${c.cpuValue}'}을(를) 써요';
    }
    if (c.thinking) return 'CPU가 쓰는 중…';
    final who = c.oneSeat ? (s.turn == c.humanSide ? '내 차례' : (c.vsCpu ? 'CPU 차례' : '상대 차례')) : '${_name(s.turn)} 차례';
    String tail;
    if (c.humanCanAct && c.selected >= 0) {
      tail = '${s.rowOf(c.selected) + 1}행 ${s.colOf(c.selected) + 1}열에 쓸 숫자나 X를 고르세요';
    } else if (c.online && s.turn != c.humanSide) {
      tail = '상대가 쓰기를 기다리고 있어요';
    } else {
      tail = '빈칸을 눌러 숫자나 X를 쓰세요';
    }
    final auto = c.lastAuto.isEmpty ? '' : '\n쓸 숫자가 없는 칸 ${c.lastAuto.length}개는 X로 채웠어요 (차례는 그대로)';
    return '$who · $tail$auto';
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
      builder: (context, _) => c.isOver
          ? _ScorePanel(
              controller: c,
              name: _name,
              onAgain: c.online ? (_rematchAsked || _opponentGone ? null : _requestRematch) : c.restart,
              againLabel: !c.online
                  ? '한 판 더'
                  : _opponentGone
                      ? '상대가 나갔어요'
                      : _rematchAsked
                          ? '상대를 기다려요…'
                          : _rematchOffered
                              ? '한 판 더 (상대가 원해요)'
                              : '한 판 더',
              onMenu: () => Navigator.of(context).pop(),
            )
          : _numberPad(),
    );
  }

  /// CPU가 숫자를 고르는 동안 보여 주는 숫자판 (누를 수는 없고, 고른 숫자만 진하게 표시한다).
  Widget _cpuPad() {
    final s = c.state;
    final color = penColor(c.cpuSide);
    final legal = s.legalNumbers(c.cpuCell).toSet();
    Widget key(String label, int value, {double width = 46}) {
      final picked = c.cpuValue == value;
      final ok = value == kCross || legal.contains(value);
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: width,
        height: 46,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: picked ? color : color.withValues(alpha: ok ? 0.12 : 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: picked ? color : Colors.transparent, width: 2),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: picked ? Colors.white : color.withValues(alpha: ok ? 0.55 : 0.25),
            decoration: ok ? null : TextDecoration.lineThrough,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var n = 1; n <= s.maxNumber; n++) key('$n', n),
          key('X', kCross, width: 56),
        ],
      ),
    );
  }

  Widget _numberPad() {
    final s = c.state;
    final scheme = Theme.of(context).colorScheme;
    final active = c.humanCanAct && c.selected >= 0;
    if (!active && c.cpuCell >= 0) return _cpuPad();
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
    final color = penColor(c.oneSeat ? c.humanSide : s.turn);
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
            ],
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
  const _ScorePanel({required this.controller, required this.name, required this.onAgain, required this.onMenu, this.againLabel = '한 판 더'});

  final ProphecyController controller;
  final String Function(int side) name;

  /// null이면 "한 판 더"를 누를 수 없다 (상대를 기다리는 중이거나 상대가 나갔을 때).
  final VoidCallback? onAgain;
  final String againLabel;
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
              FilledButton(onPressed: onAgain, child: Text(againLabel)),
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
