import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/game_info.dart';
import '../../../core/give_up.dart';
import '../../../core/win_sound.dart';
import '../../../core/settings_scope.dart';
import '../../../net/lan_connection.dart';
import '../../../records/records_screen.dart';
import '../core/dandelion_ai.dart';
import '../core/dandelion_rules.dart';
import '../data/dandelion_history.dart';
import '../game/dandelion_controller.dart';
import '../tutorial/dandelion_tutorial.dart';
import 'dandelion_art.dart';
import 'dandelion_board.dart';
import 'dandelion_lesson_screen.dart';

/// 민들레 플레이 화면.
class DandelionScreen extends StatefulWidget {
  const DandelionScreen({
    super.key,
    this.mode = PlayMode.local2p,
    this.humanRole = Role.dandelion,
    this.level = DandLevel.normal,
    this.controller,
    this.link,
  });

  final PlayMode mode;
  final Role humanRole;
  final DandLevel level;

  /// 같은 Wi‑Fi 대결([PlayMode.wifi])에서 상대 기기와의 연결. 이 화면이 닫을 때 같이 닫는다.
  final LanConnection? link;

  /// (테스트용) 미리 만든 컨트롤러.
  final DandelionController? controller;

  @override
  State<DandelionScreen> createState() => _DandelionScreenState();
}

class _DandelionScreenState extends State<DandelionScreen> {
  // 화면이 직접 소유한다: 화면이 다시 빌드되어도 판이 사라지지 않는다.
  late final DandelionController c = widget.controller ??
      DandelionController(mode: widget.mode, humanRole: widget.humanRole, level: widget.level);
  bool _resultHandled = false;

  // ── 같은 Wi‑Fi 대결 ──
  LanConnection? get _link => c.online ? widget.link : null;
  StreamSubscription<Map<String, dynamic>>? _linkSub;

  /// 상대 기기와의 연결이 끊겼다 / 이 화면에서 일부러 나가는 중이다.
  bool _opponentGone = false;
  bool _leaving = false;

  /// 한 판 더: 내가 하자고 했다 / 상대가 하자고 했다 (둘 다 하면 맡은 쪽을 바꿔 새로 시작한다).
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
    await DandelionHistory.add(DandelionRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: false,
      online: true,
      winner: c.humanRole,
      moves: c.moveCount,
      empties: c.state.emptyCount,
      human: c.humanRole,
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

  /// "한 판 더": 상대도 하자고 했으면 바로 (민들레/바람을 바꿔) 시작하고, 아니면 상대를 기다린다.
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
    c.restart(swapRoles: true);
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
      case 'plant':
        HapticFeedback.selectionClick();
      case 'wind':
        HapticFeedback.lightImpact();
      case 'win':
        HapticFeedback.heavyImpact();
    }
  }

  void _onChanged() {
    if (c.isOver && !_resultHandled) {
      _resultHandled = true;
      if (!c.oneSeat || c.winner == c.humanRole) WinSound.play(context); // 이겼을 때 "짜잔"
      DandelionHistory.add(DandelionRecord(
        at: DateTime.now().millisecondsSinceEpoch,
        vsCpu: c.vsCpu,
        online: c.online,
        winner: c.winner!,
        moves: c.moveCount,
        empties: c.state.emptyCount,
        level: c.vsCpu ? c.level : null,
        human: c.oneSeat ? c.humanRole : null,
      ));
      Future<void>.delayed(const Duration(milliseconds: 2600), _showResult);
    } else if (!c.isOver) {
      _resultHandled = false;
    }
  }

  Future<void> _resign() async {
    if (!c.canResign) return;
    final role = c.resigningRole;
    final ok = await confirmGiveUp(
      context,
      detail: c.vsCpu
          ? 'CPU의 승리로 기록돼요.'
          : c.online
              ? '상대의 승리로 기록돼요.'
              : '${role.label}이(가) 기권하고, ${role.other.label}의 승리로 기록돼요.',
      retry: false,
      verb: '기권',
    );
    if (!ok || !mounted || !c.resign()) return;
    _resultHandled = true; // (끝난 판으로 한 번 더 기록되지 않게)
    _link?.send(const {'t': 'resign'});
    await DandelionHistory.add(DandelionRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      vsCpu: c.vsCpu,
      online: c.online,
      winner: role.other,
      moves: c.moveCount,
      empties: c.state.emptyCount,
      level: c.vsCpu ? c.level : null,
      human: c.oneSeat ? c.humanRole : null,
      resigned: true,
    ));
    if (!mounted) return;
    final again = await showGaveUpDialog(
      context,
      summary: c.vsCpu ? 'CPU ${c.level.label} · ${c.moveCount}수' : '${role.label} 기권 · ${c.moveCount}수',
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
    final s = c.state;
    if (c.isOver) {
      final w = c.winner!;
      if (c.oneSeat) return w == c.humanRole ? '이겼어요! 🎉' : (c.vsCpu ? 'CPU가 이겼어요' : '상대가 이겼어요');
      return '${w.label} 승리!';
    }
    if (_opponentGone) return '상대와 연결이 끊겼어요';
    if (c.halted) return _rematchAsked ? '상대가 한 판 더를 받아 주기를 기다리는 중이에요…' : '기권으로 끝난 판이에요';
    if (c.thinking) return c.cpuRole == Role.dandelion ? 'CPU가 꽃을 심는 중…' : 'CPU가 바람을 고르는 중…';
    if (c.online && s.turn != c.humanRole) return '상대 차례 · ${s.turn == Role.dandelion ? '상대가 꽃을 심고 있어요…' : '상대가 바람을 고르고 있어요…'}';
    final who = c.oneSeat ? (s.turn == c.humanRole ? '내 차례' : 'CPU 차례') : '${s.turn.label} 차례';
    final what = s.turn == Role.dandelion ? '꽃을 심을 칸을 누르세요' : '불어 보낼 방향을 고르세요';
    return '$who · $what';
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
                ? const [Color(0xFF1F2A24), Color(0xFF18201B)]
                : const [Color(0xFFE9F5D6), Color(0xFFD3EBB2)],
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
          child: DandelionBoard(
            controller: c,
            onPlant: (cell) {
              if (!c.plant(cell) && SettingsScope.of(context).haptics) HapticFeedback.lightImpact();
            },
          ),
        ),
      );

  Widget _compass({double size = 150}) {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final canBlow = c.humanCanAct && c.state.turn == Role.wind;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DandelionCompass(
              size: size,
              usedMask: c.state.usedWinds,
              enabled: canBlow,
              windsLeft: c.state.windsLeft,
              onBlow: (d) {
                if (!c.blow(d) && SettingsScope.of(context).haptics) HapticFeedback.lightImpact();
              },
            ),
            const SizedBox(height: 2),
            Text(
              canBlow ? '화살표를 눌러 바람을 불어요' : '바람은 방향마다 한 번씩',
              style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
            ),
          ],
        );
      },
    );
  }

  Widget _portrait() => Column(
        children: [
          _playerChips(),
          _statusBanner(),
          Expanded(child: _board()),
          _compass(),
          _bottomBar(),
        ],
      );

  Widget _landscape() => Row(
        children: [
          Expanded(child: _board()),
          SizedBox(
            width: 300,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _playerChips(),
                  _statusBanner(),
                  const SizedBox(height: 8),
                  _compass(size: 190),
                  const SizedBox(height: 8),
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
              '민들레',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '교과학습',
            icon: const Icon(Icons.menu_book_rounded),
            onPressed: () => openDandelionLesson(context),
          ),
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () => openRecords(context, game: 'dandelion'),
          ),
          IconButton(
            tooltip: '규칙',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => showDandelionRules(context),
          ),
        ],
      ),
    );
  }

  /// 민들레 / 바람 두 칩: 지금 차례인 쪽이 강조된다.
  Widget _playerChips() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        Widget chip(Role role) {
          final active = !c.isOver && c.state.turn == role;
          final who = c.oneSeat ? (role == c.humanRole ? ' · 나' : (c.vsCpu ? ' · CPU' : ' · ${_link?.peerNick ?? '상대'}')) : '';
          final color = roleColor(role);
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
                SizedBox(width: 24, height: 24, child: CustomPaint(painter: _RoleIconPainter(role))),
                const SizedBox(width: 8),
                Text('${role.label}$who', style: TextStyle(fontWeight: FontWeight.w800, color: color)),
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
            children: [chip(Role.dandelion), chip(Role.wind)],
          ),
        );
      },
    );
  }

  Widget _statusBanner() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final color = c.isOver ? Colors.grey : roleColor(c.state.turn);
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
              // Wi‑Fi 대결: 판이 끝나면 "한 판 더"를 서로 눌러야 새 판이 시작된다 (민들레/바람이 바뀐다)
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

/// 역할을 나타내는 작은 그림 (민들레 = 꽃, 바람 = 휘날리는 선).
class _RoleIconPainter extends CustomPainter {
  const _RoleIconPainter(this.role);

  final Role role;

  @override
  void paint(Canvas canvas, Size size) => paintRoleIcon(canvas, size, role);

  @override
  bool shouldRepaint(_RoleIconPainter old) => old.role != role;
}

/// 민들레는 꽃, 바람은 돌돌 말리는 바람 줄 ([paintWindGust]).
void paintRoleIcon(Canvas canvas, Size size, Role role) {
  if (role == Role.dandelion) {
    drawFlower(canvas, size.center(Offset.zero), size.width * 0.5);
    return;
  }
  paintWindGust(canvas, Offset.zero & size, kWindColor, thickness: 0.1);
}

class _ResultDialog extends StatelessWidget {
  const _ResultDialog({required this.controller, this.canAgain = true});

  final DandelionController controller;

  /// false면 "한 판 더"가 없다 (Wi‑Fi 대결에서 상대가 나갔을 때).
  final bool canAgain;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final w = c.winner!;
    final left = c.state.emptyCount;
    String title, body;
    if (c.oneSeat) {
      final me = w == c.humanRole;
      title = me ? '이겼어요! 🎉' : (c.vsCpu ? 'CPU가 이겼어요' : '상대가 이겼어요');
      body = w == Role.dandelion
          ? (me ? '초원이 꽃과 씨앗으로 가득 찼어요!' : '초원이 꽃과 씨앗으로 가득 찼어요. 다음엔 바람을 잘 골라 봐요!')
          : (me ? '빈칸이 $left칸 남았어요. 바람이 이겼어요!' : '빈칸이 $left칸 남았어요. 다음엔 꽃을 더 잘 심어 봐요!');
    } else {
      title = '${w.label} 승리! 🎉';
      body = w == Role.dandelion ? '초원이 꽃과 씨앗으로 가득 찼어요!' : '빈칸이 $left칸 남았어요!';
    }
    return AlertDialog(
      title: Text(title, textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 72, height: 72, child: CustomPaint(painter: _RoleIconPainter(w))),
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
Future<void> showDandelionRules(BuildContext context) {
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
      title: const Text('민들레 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('민들레는 5×5 초원 전체를 꽃과 씨앗으로 덮는 게 목표예요.'),
            line('바람은 한 칸이라도 덮이지 않게 하는 게 목표예요.'),
            line('민들레가 먼저 아무 칸에나 꽃을 심어요.'),
            line('그다음 바람이 방향을 하나 골라요. 그 방향으로 모든 꽃에서 씨앗이 날아가, 길에 있는 빈칸을 채워요.'),
            line('바람은 8방향 가운데 7방향만 불 수 있고, 같은 방향은 한 번뿐이에요.'),
            line('이어서 민들레가 또 꽃을 심어요. 빈칸이나 씨앗이 있는 칸에 심을 수 있어요.'),
            line('씨앗은 꽃에서만 날아가고, 씨앗에서는 날아가지 않아요.'),
            line('일곱 번째 바람이 지난 뒤 초원이 가득 차 있으면 민들레, 빈칸이 하나라도 있으면 바람의 승리예요.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(ctx);
            dandelionTutorial().open(context);
          },
          child: const Text('게임 방법 자세히'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요')),
      ],
    ),
  );
}
