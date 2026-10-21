import 'package:flutter/material.dart';

import '../../../core/game_fx.dart';
import '../../../records/records_screen.dart';
import '../core/pinball_run.dart';
import '../game/pinball_controller.dart';
import '../tutorial/pinball_tutorial.dart';
import 'pinball_hud.dart';
import 'pinball_overlays.dart';
import 'pinball_painter.dart';
import 'pinball_sprites.dart';

const double _hudHeight = 112;
const double _sidePanel = 280;

/// 핀볼 플레이 화면: 점수판 + 판 + 조작(왼쪽 절반=왼쪽 플리퍼, 오른쪽 절반=오른쪽 플리퍼, 오른쪽 통로 꾹=발사).
class PinballScreen extends StatefulWidget {
  const PinballScreen({super.key, this.seed, this.controller, this.debugWalls = false});

  final int? seed;

  /// 미리보기·시험에서 판의 상태를 직접 만들어 넣을 때.
  final PinballController? controller;

  /// 충돌하는 벽·부품을 그림 위에 겹쳐 그린다 (판 그림과 맞는지 확인하는 개발용).
  final bool debugWalls;

  @override
  State<PinballScreen> createState() => _PinballScreenState();
}

class _PinballScreenState extends State<PinballScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  late final PinballController _c = widget.controller ?? PinballController(seed: widget.seed);
  final GameFx _fx = GameFx({
    'bumper': const Fx(haptic: Haptic.light, minGap: Duration(milliseconds: 60)),
    'sling': const Fx(haptic: Haptic.light, minGap: Duration(milliseconds: 60)),
    'target': const Fx(haptic: Haptic.medium),
    'jackpot': const Fx(haptic: Haptic.heavy),
    'launch': const Fx(haptic: Haptic.medium),
    'drain': const Fx(haptic: Haptic.heavy),
    'saved': const Fx(haptic: Haptic.medium),
    'clear': const Fx(haptic: Haptic.heavy),
    'nudge': const Fx(haptic: Haptic.light),
    'tilt': const Fx(haptic: Haptic.vibrate),
    'buy': const Fx(haptic: Haptic.select),
    'pick': const Fx(haptic: Haptic.select),
    'over': const Fx(haptic: Haptic.vibrate),
  });

  final Map<int, String> _roles = {};
  bool _left = false, _right = false;
  double _width = 0;
  PinballArt? _art = PinballArt.cached;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _c.onFeedback = (k) {
      if (mounted) _fx.play(context, k);
    };
    _c.attach(this);
    if (_art == null) {
      PinballArt.load().then((a) {
        if (mounted) setState(() => _art = a);
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _c.dispose();
    _fx.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && _c.run.phase == RunPhase.playing) _pause();
  }

  void _pause() {
    _roles.clear();
    _left = _right = false;
    _c.pause(true);
  }

  void _resume() {
    _c.pause(false);
  }

  // ── 손가락 ──

  String _roleAt(Offset p) {
    // 공이 통로에서 기다리는 동안은 화면 오른쪽 가장자리를 누르면 발사 막대를 당긴다
    if (_c.run.phase == RunPhase.playing && _c.run.engine.hasWaitingBall && p.dx > _width * 0.78) return 'launch';
    return p.dx < _width / 2 ? 'L' : 'R';
  }

  void _down(PointerDownEvent e) {
    if (_c.paused) return;
    _roles[e.pointer] = _roleAt(e.localPosition);
    _apply();
  }

  void _up(PointerEvent e) {
    if (_roles.remove(e.pointer) != null) _apply();
  }

  void _apply() {
    final left = _roles.containsValue('L'), right = _roles.containsValue('R');
    if (left != _left) {
      _left = left;
      _c.setFlipper(true, left);
    }
    if (right != _right) {
      _right = right;
      _c.setFlipper(false, right);
    }
    final launching = _roles.containsValue('launch');
    if (launching && !_c.charging) _c.startCharge();
    if (!launching && _c.charging) _c.releaseCharge();
  }

  // ── 나가기 ──

  Future<void> _leave() async {
    if (_c.run.phase == RunPhase.over) {
      Navigator.of(context).pop();
      return;
    }
    _pause();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('도전을 그만둘까요?'),
        content: Text(_c.run.round > 1 ? '지금까지의 기록은 남아요.\n하던 판은 이어할 수 없어요.' : '하던 판은 이어할 수 없어요.', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('계속하기')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('그만두기')),
        ],
      ),
    );
    if (!mounted) return;
    if (ok == true) {
      _c.saveIfProgressed();
      Navigator.of(context).pop();
    }
    // (계속하기를 고르면 일시정지 창이 남아 있어서, 거기서 "계속하기"를 눌러야 다시 시작해요)
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B1226),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final wide = c.maxWidth > c.maxHeight * 1.15;
              _width = c.maxWidth;
              final play = wide ? Rect.fromLTWH(_sidePanel, 0, c.maxWidth - _sidePanel, c.maxHeight) : Rect.fromLTWH(0, _hudHeight, c.maxWidth, c.maxHeight - _hudHeight);
              _c.viewH = pinballViewH(play.size);
              return Stack(
                children: [
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: _down,
                      onPointerUp: _up,
                      onPointerCancel: _up,
                      child: Stack(
                        children: [
                          Positioned.fromRect(
                            rect: play,
                            child: ListenableBuilder(
                              listenable: _c,
                              builder: (context, _) => CustomPaint(painter: PinballPainter(run: _c.run, charge: _c.charge, camY: _c.camY, art: _art, debug: widget.debugWalls, repaint: _c)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (wide)
                    Positioned(left: 0, top: 0, bottom: 0, width: _sidePanel, child: Padding(padding: const EdgeInsets.all(14), child: PinballHud(controller: _c, vertical: true, onPause: _pause)))
                  else
                    Positioned(left: 0, right: 0, top: 0, height: _hudHeight, child: PinballHud(controller: _c, vertical: false, onPause: _pause)),
                  Positioned(left: wide ? null : 10, right: wide ? 24 : null, bottom: wide ? 24 : 10, child: _NudgeButton(controller: _c)),
                  Positioned(left: 0, right: 0, bottom: 14, child: IgnorePointer(child: _Hint(controller: _c))),
                  Positioned.fill(
                    child: ListenableBuilder(
                      listenable: _c,
                      builder: (context, _) {
                        final run = _c.run;
                        if (_c.paused && run.phase != RunPhase.over) {
                          return PinballPauseCard(controller: _c, onResume: _resume, onHelp: () => pinballTutorial().open(context), onLeave: _leave);
                        }
                        return switch (run.phase) {
                          RunPhase.countdown => PinballCountdown(run: run),
                          RunPhase.choosing => PinballUpgradeSheet(controller: _c),
                          RunPhase.over => PinballGameOver(controller: _c, onLeave: () => Navigator.of(context).pop(), onRecords: () => openRecords(context, game: 'pinball')),
                          RunPhase.playing => const SizedBox.shrink(),
                        };
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 판을 흔드는 단추. 너무 자주 누르면 틸트가 나서 잠깐 플리퍼가 멈춰요.
class _NudgeButton extends StatelessWidget {
  const _NudgeButton({required this.controller});

  final PinballController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final run = controller.run;
        final color = run.tilted ? const Color(0xFFFF5252) : Color.lerp(const Color(0xFF5C6B8F), const Color(0xFFFF5252), run.tilt.clamp(0.0, 1.0))!;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => controller.nudge(),
          child: Container(
            width: 68,
            height: 68,
            decoration: BoxDecoration(shape: BoxShape.circle, color: color.withValues(alpha: 0.85), border: Border.all(color: Colors.white54, width: 2)),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.vibration_rounded, color: Colors.white, size: 26),
                Text('흔들기', style: TextStyle(fontFamily: 'NanumGothic', color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 처음 공을 쏠 때 알려 주는 작은 안내.
class _Hint extends StatelessWidget {
  const _Hint({required this.controller});

  final PinballController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final run = controller.run;
        final show = run.phase == RunPhase.playing && run.engine.hasWaitingBall && !controller.paused;
        if (!show) return const SizedBox.shrink();
        return Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.65), borderRadius: BorderRadius.circular(20)),
            child: Text(
              controller.charging ? '손을 떼면 쏴요!' : '화면 오른쪽 끝을 꾹 눌렀다 떼면 공이 나가요',
              style: const TextStyle(fontFamily: 'NanumGothic', color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
        );
      },
    );
  }
}
