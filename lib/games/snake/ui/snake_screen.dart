import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/game_fx.dart';
import '../../../core/settings_scope.dart';
import '../../../net/lan_connection.dart';
import '../../../net/lan_rejoin_flow.dart';
import '../../../versus/vs_screen_parts.dart' show showVsNotice;
import '../game/snake_controller.dart';
import '../data/snake_prefs.dart';
import '../game/snake_host_net.dart';
import '../game/snake_migrate.dart';
import 'snake_hud.dart';
import 'snake_painter.dart';

/// 앱을 껐다 켠 뒤 하던 방에 다시 들어갈 때 (방장이 보낸 `resume`)와, 방 찾기로 처음 들어갈 때 (`start`) 손님 화면.
Widget? snakeResume(Map<String, dynamic> m, LanConnection conn) {
  final c = SnakeControllerRejoin.fromWifiSnapshot(m, conn);
  return c == null ? null : SnakeScreen(controller: c);
}

/// 뱀 게임 화면. 왼쪽을 누르고 끌면 방향, 오른쪽을 꾹 누르면 부스터 ([SnakePrefs.boostLeft]면 반대).
class SnakeScreen extends StatefulWidget {
  const SnakeScreen({super.key, required this.controller, this.openRoomAs, this.showHint = true});

  final SnakeController controller;

  /// 방장: 이 별명으로 같은 Wi‑Fi 방을 연다 (null이면 열지 않는다, 시험용).
  final String? openRoomAs;
  final bool showHint;

  @override
  State<SnakeScreen> createState() => _SnakeScreenState();
}

class _SnakeScreenState extends State<SnakeScreen> with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  final SnakeCamera _camera = SnakeCamera();
  final GameFx _fx = GameFx(const {
    'kill': Fx(haptic: Haptic.medium),
    'die': Fx(haptic: Haptic.heavy),
    // 1등이 됐을 때 짧은 "짜잔" (놀라지 않게 작게)
    'first': Fx(sound: 'sfx/tada_short.mp3', volume: 0.35),
    // 내가 큰 먹이를 먹을 때 "꿀꺽" (잇달아 먹어도 소리가 겹쳐 탁해지지 않게 조금 띄운다)
    'gulp': Fx(sound: 'sfx/gulp.wav', volume: 0.7, minGap: Duration(milliseconds: 140)),
    // 화면 근처에서 다른 뱀이 죽을 때 "탁" (여럿이 한꺼번에 죽어도 시끄럽지 않게)
    'pop': Fx(sound: 'sfx/pop.mp3', volume: 0.5, minGap: Duration(milliseconds: 120)),
  });
  Duration _last = Duration.zero;
  double _clock = 0;
  Size _size = Size.zero;
  bool _hint = true, _leaving = false;
  final List<(String, double)> _toasts = [];

  // 손가락: 왼쪽은 조종기, 오른쪽은 부스터 (설정에서 바꾸면 반대)
  int? _stickPointer;
  Offset? _stickOrigin, _stickNow, _boostAt;
  final Set<int> _boostPointers = {};

  SnakeController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    _hint = widget.showHint;
    c.onToast = _toast;
    c.onFeedback = (kind) {
      if (mounted) _fx.play(context, kind);
    };
    c.onOtherDeath = _otherDied;
    c.onEnded = _hostEnded;
    c.onDropped = _dropped;
    final note = c.startNote;
    if (note != null) _toasts.add((note, 4.5));
    final nick = widget.openRoomAs;
    if (nick != null) c.openRoom(nick: nick).then((_) => mounted ? setState(() {}) : null);
    SnakePrefs.load().then((_) => mounted ? setState(() {}) : null); // (다시 들어오기로 바로 열릴 때도 손 설정·순위표 접기를 읽는다)
    _ticker = createTicker(_tick)..start();
  }

  void _tick(Duration now) {
    final dt = _last == Duration.zero ? 1 / 60 : (now - _last).inMicroseconds / 1e6;
    _last = now;
    _clock += dt;
    c.frame(dt);
    if (_size != Size.zero) _camera.follow(c.me, _size, dt);
    _frame.value++;
    if (_toasts.isNotEmpty && _toasts.first.$2 < _clock) setState(() => _toasts.removeAt(0));
    if (_hint && _clock > 6) setState(() => _hint = false);
  }

  /// 화면에 보이는 곳(조금 바깥까지)에서 다른 뱀이 죽으면 "탁".
  void _otherDied(double x, double y) {
    if (!mounted || _size == Size.zero) return;
    final s = _camera.scale;
    final view = Rect.fromCenter(center: Offset(_camera.x, _camera.y), width: _size.width / s, height: _size.height / s).inflate(60);
    if (view.contains(Offset(x, y))) _fx.play(context, 'pop');
  }

  void _toast(String text) {
    if (!mounted) return;
    setState(() {
      _toasts.add((text, _clock + 2.6));
      if (_toasts.length > 3) _toasts.removeAt(0);
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    _fx.dispose();
    c.dispose(); // (방장이면 방도 닫힌다. 손님은 "나가기"를 눌렀을 때만 방장에게 알리고 표를 버린다)
    super.dispose();
  }

  // ── 손가락 ──

  void _down(PointerDownEvent e) {
    final left = e.localPosition.dx < _size.width / 2;
    if (left != SnakePrefs.boostLeft.value) {
      if (_stickPointer != null) return;
      _stickPointer = e.pointer;
      _stickOrigin = _stickNow = e.localPosition;
    } else {
      _boostPointers.add(e.pointer);
      _boostAt = e.localPosition;
      c.boost = true;
    }
    if (_hint) _hint = false;
    setState(() {});
  }

  void _move(PointerMoveEvent e) {
    if (e.pointer == _stickPointer) {
      final o = _stickOrigin!;
      final d = e.localPosition - o;
      if (d.distance > 8) c.steer(atan2(d.dy, d.dx));
      // 손가락이 원 밖으로 많이 나가면 조종기 가운데가 따라온다
      if (d.distance > SnakeTouchPainter.reach * 1.6) _stickOrigin = e.localPosition - d / d.distance * SnakeTouchPainter.reach * 1.6;
      setState(() => _stickNow = e.localPosition);
    } else if (_boostPointers.contains(e.pointer)) {
      _boostAt = e.localPosition;
    }
  }

  void _up(PointerEvent e) {
    if (e.pointer == _stickPointer) {
      _stickPointer = null;
      _stickOrigin = _stickNow = null;
    }
    if (_boostPointers.remove(e.pointer) && _boostPointers.isEmpty) {
      c.boost = false;
      _boostAt = null;
    }
    setState(() {});
  }

  // ── 나가기 ──

  Future<void> _askLeave() async {
    final guests = c.hostNet?.guests ?? 0;
    final body = c.isHost
        ? (guests > 0 ? '나가도 친구 $guests명의 판은 계속돼요. 친구 중 한 명이 방장을 이어받고, 내 지렁이는 먹이로 흩어져요.' : '이 판을 끝낼까요?')
        : '나가면 내 지렁이는 먹이로 흩어지고, 방에서 나와요.';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('그만할까요?', textAlign: TextAlign.center),
        content: Text(body, textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('계속하기')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('나가기')),
        ],
      ),
    );
    if (ok == true) await _leave();
  }

  Future<void> _leave() async {
    if (_leaving) return;
    _leaving = true;
    await c.leave();
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _hostEnded() async {
    if (!mounted || _leaving) return;
    _leaving = true;
    await RejoinTickets.forget(kSnakeLanGame);
    if (!mounted) return;
    await showVsNotice(context, '판이 끝났어요', '방을 만든 사람이 판을 끝냈어요.');
    if (mounted) Navigator.of(context).pop();
  }

  /// 방장이 사라졌다: 친구 중 한 명이 판을 이어받는다 ([snakeRecoverHost]). 길이 없으면 예전처럼 끊김을 알린다.
  Future<void> _dropped(bool handover) async {
    if (!mounted || _leaving) return;
    _leaving = true;
    final nick = SettingsScope.of(context).nickname;
    final navigator = Navigator.of(context, rootNavigator: true);
    var shown = true;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (ctx) => const PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3)),
              SizedBox(width: 16),
              Expanded(child: Text('방장이 사라졌어요. 판을 이어 가는 중…', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.4))),
            ],
          ),
        ),
      ),
    ).then((_) => shown = false);
    final next = await snakeRecoverHost(c, handover: handover, nick: nick);
    if (shown) navigator.pop();
    if (!mounted) {
      next?.dispose();
      return;
    }
    if (next != null) {
      await Navigator.of(context).pushReplacement(MaterialPageRoute<void>(
        builder: (_) => SnakeScreen(controller: next, openRoomAs: next.isHost ? nick : null, showHint: false),
      ));
      return;
    }
    if (handover) {
      await RejoinTickets.forget(kSnakeLanGame);
      if (mounted) await showVsNotice(context, '판이 끝났어요', '방장이 나갔고, 판을 이어받을 사람이 없어요.');
      if (mounted) Navigator.of(context).pop();
      return;
    }
    await lanGuestDropped(
      context,
      game: kSnakeLanGame,
      build: snakeResume,
      fallbackNotice: () => showVsNotice(context, '연결이 끊겼어요', '방장 기기와의 연결이 끊겼어요.'),
    );
  }

  // ── 화면 ──

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _askLeave();
      },
      child: Scaffold(
        backgroundColor: kSnakeOutside,
        body: LayoutBuilder(builder: (context, box) {
          _size = box.biggest;
          final tablet = box.biggest.shortestSide >= 600;
          return Stack(
            children: [
              Positioned.fill(
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _down,
                  onPointerMove: _move,
                  onPointerUp: _up,
                  onPointerCancel: _up,
                  child: CustomPaint(
                    painter: SnakeFieldPainter(
                      field: c.field,
                      bodies: () => c.bodies,
                      foods: () => c.foods,
                      camera: _camera,
                      mySeat: c.mySeat,
                      clock: () => _clock,
                      repaint: _frame,
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: SnakeTouchPainter(stickOrigin: _stickOrigin, stickNow: _stickNow, boosting: c.boosting, boostAt: _boostAt)),
                ),
              ),
              SafeArea(child: _hud(tablet)),
              if (_hint) Positioned.fill(child: SafeArea(child: SnakeControlHint(swapped: SnakePrefs.boostLeft.value))),
              ValueListenableBuilder<int>(
                valueListenable: c.hud,
                builder: (context, _, _) => c.me == null && !_leaving
                    ? SnakeDeathCard(life: c.lastLife.value, onAgain: c.again, onLeave: _askLeave)
                    : const SizedBox.shrink(),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _hud(bool tablet) {
    final mini = tablet ? 130.0 : 92.0;
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Stack(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filledTonal(
                      tooltip: '나가기',
                      onPressed: _askLeave,
                      icon: const Icon(Icons.close_rounded),
                      style: IconButton.styleFrom(backgroundColor: Colors.black.withValues(alpha: 0.4), foregroundColor: Colors.white),
                    ),
                    const SizedBox(width: 6),
                    ValueListenableBuilder<int>(valueListenable: c.hud, builder: (context, _, _) => _roomChip()),
                  ],
                ),
                const SizedBox(height: 8),
                ValueListenableBuilder<int>(
                  valueListenable: c.hud,
                  builder: (context, _, _) {
                    final ranked = c.ranking();
                    return SizedBox(
                      width: mini,
                      height: mini,
                      child: CustomPaint(painter: SnakeMiniMapPainter(field: c.field, me: c.me, top: ranked.take(5).toList())),
                    );
                  },
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.topRight,
            child: ValueListenableBuilder<int>(
              valueListenable: c.hud,
              builder: (context, _, _) => SnakeLeaderboard(
                ranked: c.ranking(),
                mySeat: c.mySeat,
                width: tablet ? 220 : 172,
                collapsed: SnakePrefs.boardFolded.value,
                cpuLevel: c.cpuLevel,
                onToggle: () => setState(() => SnakePrefs.setBoardFolded(!SnakePrefs.boardFolded.value)),
              ),
            ),
          ),
          Align(
            alignment: const Alignment(0, -0.4),
            child: IgnorePointer(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (text, _) in _toasts)
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(20)),
                      child: Text(text, style: const TextStyle(fontFamily: 'NanumGothic', fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roomChip() {
    final room = c.hostNet?.roomNumber;
    final text = c.isHost
        ? (room == null ? '사람 ${c.people}명' : '방 번호 $room · 사람 ${c.people}명')
        : '사람 ${c.people}명';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_rounded, size: 16, color: Colors.white70),
          const SizedBox(width: 6),
          Text(text, style: const TextStyle(fontFamily: 'NanumGothic', fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
        ],
      ),
    );
  }
}

