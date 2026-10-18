import '../../../core/win_celebration.dart';
import 'dart:async';

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
    // 대포가 쏠 때의 레이저 (사용자가 고른 소리). 여럿이 잇달아 쏘면 난잡해지니 작게, 0.17초에 한 번까지만
    'hit': const Fx(sound: 'sfx/laser.wav', volume: 0.45, minGap: Duration(milliseconds: 170)),
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

  void _onChanged() {
    if (c.completed || c.stalled) {
      _saver.finish();
    } else if (c.game.deploys != _savedAtDeploys) {
      if (c.untouched) _saver.rearm(); // 처음부터 다시 시작했다
      _savedAtDeploys = c.game.deploys;
      _saver.save();
    }
  }

  void _showBanner(String text) {
    _banner.value = text;
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(milliseconds: 1600), () => _banner.value = null);
  }

  void _feedback(String kind) {
    if (kind == 'full') _showBanner('벨트가 가득 찼거나, 입구가 막혀 있어요');
    _fx.play(context, kind);
  }

  // ── 끝났을 때 ──

  Future<void> _onWon() async {
    WinSound.play(context); showWinCelebration(context, title: '완성!', subtitle: '도트를 모두 채웠어요'); // 이겼을 때 "짜잔"
    final seconds = c.elapsed.value;
    final deploys = c.game.deploys;
    await _saver.finish();
    final best = await DotStorage.recordWin(c.level.id, seconds: seconds, deploys: deploys);
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    final index = dotLevels.indexWhere((l) => l.id == c.level.id);
    final hasNext = !c.level.custom && index >= 0 && index + 1 < dotLevels.length;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('그림 완성! 🎉', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CustomPaint(
                painter: DotArtPainter(c.level.pixels, c.level.width, c.level.height, c.level.colors),
              ),
            ),
            const SizedBox(height: 6),
            Text(c.level.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(formatTime(seconds), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            Text('대포 $deploys대를 썼어요', style: const TextStyle(fontSize: 15)),
            if (best.any)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  best.time && best.deploys
                      ? '시간도, 대포 수도 새 최고 기록이에요!'
                      : best.time
                          ? '새 최고 기록이에요!'
                          : '가장 적은 대포로 깬 새 기록이에요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowAlignment: OverflowBarAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'menu'), child: const Text('메뉴로')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'again'), child: const Text('다시 하기')),
          if (hasNext) FilledButton(onPressed: () => Navigator.pop(ctx, 'next'), child: const Text('다음 그림')),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'next':
        await startDotCannon(context, dotLevels[index + 1], replace: true);
      case 'again':
        await startDotCannon(context, c.level, replace: true);
      default:
        Navigator.of(context).pop();
    }
  }

  Future<void> _onStalled() async {
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.block_rounded, size: 32),
        title: const Text('막혔어요', textAlign: TextAlign.center),
        content: const Text(
          '벨트 위의 대포도, 대기 중인 대포도\n지금 보이는 도트를 맞힐 수 없어요.\n'
          '맞히지 못하는 대포를 먼저 올리면 벨트 자리만 차지해요.\n처음부터 다시 해 볼까요?',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'menu'), child: const Text('메뉴로')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'again'), child: const Text('처음부터')),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'again') {
      await _saver.save(); // (아직 아무것도 안 올린 판이라 보관된 것이 지워진다)
      _restartNow();
    } else {
      await _saver.finish();
      if (mounted) Navigator.of(context).pop();
    }
  }

  void _restartNow() {
    c.restart();
    _saver.rearm();
    _saver.save();
    _savedAtDeploys = 0;
  }

  Future<void> _confirmRestart() async {
    if (c.untouched) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('처음부터 다시 할까요?'),
        content: const Text('같은 그림을 처음 모습으로 되돌려요. 시간도 처음부터 다시 재요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('처음부터')),
        ],
      ),
    );
    if (ok ?? false) _restartNow();
  }

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
                return Column(
                  children: [
                    _topBar(),
                    Expanded(
                      child: landscape
                          ? Row(
                              children: [
                                Expanded(child: board),
                                SizedBox(width: (box.maxWidth * 0.36).clamp(240.0, 380.0), child: queue),
                              ],
                            )
                          : Column(
                              children: [
                                Expanded(flex: 5, child: board),
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

  Widget _board() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: DotBoardPainter(c, c.level.colors))),
          Positioned(
            left: 0,
            right: 0,
            top: 6,
            child: Center(
              child: ValueListenableBuilder<String?>(
                valueListenable: _banner,
                builder: (context, text, _) => AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: text == null ? 0 : 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.75), borderRadius: BorderRadius.circular(20)),
                    child: Text(text ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: ListenableBuilder(
              listenable: c,
              builder: (context, _) => c.paused ? _pauseCover() : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pauseCover() {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => c.setPaused(false),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.play_circle_fill_rounded, size: 72, color: scheme.primary),
              const SizedBox(height: 8),
              const Text('일시정지', style: TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text('눌러서 계속하기', style: TextStyle(color: scheme.onSurface.withValues(alpha: 0.6))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: ListenableBuilder(
        listenable: c,
        builder: (context, _) => Row(
          children: [
            IconButton(
              tooltip: '뒤로',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            Flexible(
              child: Text(
                c.level.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            // 벨트 자리: 올려 둔 대포 / 최대
            Container(
              key: const ValueKey('dot-belt-gauge'),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: scheme.primary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.linear_scale_rounded, size: 17, color: scheme.primary),
                  const SizedBox(width: 3),
                  Text(
                    '${c.game.belt.length}/${c.game.capacity}',
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: scheme.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text('도트 ${c.game.remaining}', style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.7))),
            const Spacer(),
            ValueListenableBuilder<int>(
              valueListenable: c.elapsed,
              builder: (_, sec, _) => Text(
                formatTime(sec),
                style: TextStyle(
                  fontSize: 16,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: scheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('dot-speed'),
              onPressed: c.cycleSpeed,
              style: TextButton.styleFrom(minimumSize: const Size(44, 36), padding: const EdgeInsets.symmetric(horizontal: 8)),
              child: Text('${c.speed}배속', style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            IconButton(
              tooltip: c.paused ? '계속하기' : '일시정지',
              icon: Icon(c.paused ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded, size: 30),
              onPressed: c.completed ? null : () => c.setPaused(!c.paused),
            ),
            PopupMenuButton<String>(
              tooltip: '메뉴',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                if (v == 'restart') _confirmRestart();
                if (v == 'rules') dotTutorial().open(context);
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'restart', enabled: !c.untouched && !c.completed, child: const Text('처음부터 다시')),
                const PopupMenuItem(value: 'rules', child: Text('게임 방법')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 대기열: 열마다 맨 앞 대포를 눌러 벨트에 올린다.
class _QueuePanel extends StatelessWidget {
  const _QueuePanel({required this.controller});

  final DotController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = controller;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            final g = c.game;
            final ex = g.exposedColors();
            return LayoutBuilder(
              builder: (context, box) {
                final cols = g.queue.length;
                final colW = (box.maxWidth - 16) / cols;
                // 태블릿에서는 칸이 넓으니 대포도 크게 (폰은 그대로)
                final maxTile = MediaQuery.sizeOf(context).shortestSide >= kTabletMinSide ? 88.0 : 64.0;
                final tile = colW.clamp(34.0, maxTile) - 6;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 2),
                      child: Row(
                        children: [
                          const Icon(Icons.touch_app_rounded, size: 18),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '맨 앞 대포를 눌러 벨트에 올려요 · 대기 ${g.waiting}대',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (var i = 0; i < cols; i++) _column(context, i, g.queue[i], ex, tile, colW),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }

  /// 한 줄: 맨 앞(위) 대포가 가장 위에 보이게, 뒤쪽 대포부터 먼저 그린다.
  Widget _column(BuildContext context, int col, List<Cannon> cannons, Set<int> ex, double size, double width) {
    if (cannons.isEmpty) return SizedBox(width: width);
    final step = size * 0.82;
    final height = (cannons.length - 1) * step + size + 4;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          for (var k = cannons.length - 1; k >= 0; k--)
            Positioned(
              top: k * step,
              left: 0,
              right: 0,
              child: Center(child: _tile(col, k, cannons[k], ex, size)),
            ),
        ],
      ),
    );
  }

  Widget _tile(int col, int k, Cannon cannon, Set<int> ex, double size) {
    final front = k == 0;
    final tile = CannonTile(
      color: controller.level.colors[cannon.color],
      ammo: cannon.ammo,
      size: size,
      glow: front && ex.contains(cannon.color),
      dim: !front,
    );
    if (!front) return tile;
    return InkWell(
      key: ValueKey('dot-front-$col'),
      customBorder: const CircleBorder(),
      onTap: () => controller.deploy(col),
      child: tile,
    );
  }
}
