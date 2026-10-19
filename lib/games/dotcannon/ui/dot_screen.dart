import '../../../core/win_celebration.dart';
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/format.dart';
import '../../../core/game_fx.dart';
import '../../../core/leave_guard.dart';
import '../../../core/tablet_scale.dart';
import '../../../core/win_sound.dart';
import '../core/dot_levels.dart';
import '../core/dot_rules.dart';
import '../data/dot_storage.dart';
import '../dotcannon_entry.dart';
import '../game/dot_controller.dart';
import '../tutorial/dot_tutorial.dart';
import 'dot_painter.dart';

part 'dot_screen_belt.dart';
part 'dot_screen_flow.dart';
part 'dot_screen_layout.dart';
part 'dot_screen_queue.dart';

/// 도트 캐논 플레이 화면.
class DotScreen extends StatefulWidget {
  const DotScreen({super.key, required this.controller});

  /// 이 화면이 맡아서 정리한다.
  final DotController controller;

  @override
  State<DotScreen> createState() => _DotScreenState();
}

class _DotScreenState extends State<DotScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  DotController get c => widget.controller;

  late final GameSaver _saver = GameSaver(gameId: dotGameId, snapshot: () => c.savable ? c.toJson() : null);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  int _savedAtDeploys = 0;
  Timer? _bannerTimer;
  final ValueNotifier<String?> _banner = ValueNotifier<String?>(null);

  /// 알림 종류 → 진동·소리 (설정의 진동·효과음 스위치를 따른다).
  final GameFx _fx = GameFx({
    // 대포가 쏠 때의 소리는 없다: 배속으로 하면 너무 많이 쏴서 오디오가 밀려 "짜잔"까지 늦어졌다
    'deploy': const Fx(haptic: Haptic.select),
    'full': const Fx(haptic: Haptic.light),
    'stuck': const Fx(haptic: Haptic.vibrate),
    'win': const Fx(haptic: Haptic.heavy),
  });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _saver.attach();
    _savedAtDeploys = c.game.deploys;
    c.addListener(_onChanged);
    c.onFeedback = _feedback;
    c.onWon = _onWon;
    c.onStalled = _onStalled;
    _ticker = createTicker((elapsed) {
      final dt = (elapsed - _last).inMicroseconds / 1e6;
      _last = elapsed;
      c.advance(dt.clamp(0.0, 0.1));
    })
      ..start();
  }

  @override
  void dispose() {
    _fx.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _ticker.dispose();
    _bannerTimer?.cancel();
    _banner.dispose();
    _saver.detach();
    c.removeListener(_onChanged);
    c.onFeedback = null;
    c.onWon = null;
    c.onStalled = null;
    // 저장은 비동기로 컨트롤러 상태를 읽을 수 있어서, 굳힌 뒤 정리한다.
    Future<void>.microtask(c.dispose);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && !c.completed) c.setPaused(true);
  }




  // ── 끝났을 때 ──

  // ── 화면 ──

  @override
  Widget build(BuildContext context) {
    return SaveLeaveGuard(
      active: () => _saver.active,
      onSave: _saver.save,
      onDiscard: _saver.discard,
      child: Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: Theme.of(context).brightness == Brightness.dark
                  ? const [Color(0xFF1D2430), Color(0xFF151A23)]
                  : const [Color(0xFFE6F0FA), Color(0xFFCFE1F3)],
            ),
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, box) {
                final landscape = box.maxWidth > box.maxHeight * 1.15;
                final board = _board();
                final queue = _QueuePanel(controller: c);
                final belt = _BeltStrip(controller: c);
                return Column(
                  children: [
                    _topBar(),
                    Expanded(
                      child: landscape
                          ? Row(
                              children: [
                                Expanded(child: board),
                                SizedBox(
                                  width: (box.maxWidth * 0.36).clamp(240.0, 380.0),
                                  child: Column(children: [belt, Expanded(child: queue)]),
                                ),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(flex: 5, child: board),
                                belt,
                                Expanded(flex: 3, child: queue),
                              ],
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }



}

/// 대기열: 열마다 맨 앞 대포를 눌러 벨트에 올린다.