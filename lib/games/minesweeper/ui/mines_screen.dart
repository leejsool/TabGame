import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/format.dart';
import '../../../core/settings_scope.dart';
import '../core/mines_rules.dart';
import '../data/mines_storage.dart';
import '../game/mines_controller.dart';
import 'mines_board.dart';

/// 지뢰찾기 플레이 화면.
class MinesScreen extends StatefulWidget {
  const MinesScreen({super.key, this.level = MinesLevel.beginner, this.saved, this.controller});

  final MinesLevel level;

  /// 이어하기: 저장된 판 (있으면 [level]은 무시).
  final Map<String, dynamic>? saved;

  /// (테스트용) 미리 만든 컨트롤러.
  final MinesController? controller;

  @override
  State<MinesScreen> createState() => _MinesScreenState();
}

class _MinesScreenState extends State<MinesScreen> with WidgetsBindingObserver {
  // 화면이 직접 소유한다: 화면이 다시 빌드되어도 판이 사라지지 않는다.
  late final MinesController c = widget.controller ??
      (widget.saved != null ? MinesController.fromJson(widget.saved!) : MinesController(level: widget.level));
  Timer? _ticker;
  Timer? _saveDebounce;
  final Completer<void> _skip = Completer<void>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MinesStorage.setActive(c);
    c.addListener(_onChanged);
    c.onStarted = () => MinesStorage.recordStart(c.level);
    c.onWon = _onWon;
    c.onLost = _onLost;
    c.onFeedback = _feedback;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => c.tick());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _saveDebounce?.cancel();
    c.removeListener(_onChanged);
    c.onStarted = null;
    c.onWon = null;
    c.onLost = null;
    c.onFeedback = null;
    MinesStorage.save(c);
    c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      c.setPaused(true);
      MinesStorage.save(c);
    }
  }

  void _onChanged() {
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () => MinesStorage.save(c));
  }

  void _feedback(String kind) {
    if (!SettingsScope.of(context).haptics) return;
    switch (kind) {
      case 'reveal':
        HapticFeedback.selectionClick();
      case 'flag':
        HapticFeedback.lightImpact();
      case 'boom':
        HapticFeedback.heavyImpact();
      case 'win':
        HapticFeedback.heavyImpact();
    }
  }

  // ── 끝났을 때 ──

  Future<void> _onWon() async {
    final seconds = c.elapsed.value;
    await MinesStorage.clearSave(c);
    final isBest = await MinesStorage.recordWin(MinesRecord(
      at: DateTime.now().millisecondsSinceEpoch,
      level: c.level,
      seconds: seconds,
    ));
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    if (!mounted) return;
    final again = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('클리어! 🎉', textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${c.level.label} · ${c.level.description}', style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 6),
            Text(formatTime(seconds), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
            if (isBest)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '새 최고 기록이에요!',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.primary, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('메뉴로')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('한 판 더')),
        ],
      ),
    );
    if (!mounted) return;
    if (again ?? false) {
      c.restart();
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _onLost() async {
    await MinesStorage.clearSave(c);
    await Future.any([Future<void>.delayed(const Duration(milliseconds: 2600)), _skip.future]);
    if (!mounted || c.status != MinesStatus.lost) return;
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('펑! 💥', textAlign: TextAlign.center),
        content: const Text('지뢰를 밟았어요. 다시 도전해 볼까요?', textAlign: TextAlign.center),
        actionsAlignment: MainAxisAlignment.center,
        actionsOverflowAlignment: OverflowBarAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'menu'), child: const Text('메뉴로')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'look'), child: const Text('판 보기')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'again'), child: const Text('다시 하기')),
        ],
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'again':
        c.restart();
      case 'menu':
        Navigator.of(context).pop();
    }
  }

  Future<void> _confirmRestart() async {
    if (c.status != MinesStatus.playing) {
      c.restart();
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('새 판으로 바꿀까요?'),
        content: const Text('지금 하던 판은 사라지고, 같은 난이도로 새 판이 시작돼요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('새 판')),
        ],
      ),
    );
    if (ok ?? false) {
      await MinesStorage.clearSave(c);
      c.restart();
    }
  }

  // ── 화면 ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
                child: Stack(
                  children: [
                    Positioned.fill(child: MinesBoardView(controller: c)),
                    Positioned(left: 0, right: 0, bottom: 8, child: Center(child: _hintBanner())),
                    Positioned.fill(
                      child: ListenableBuilder(
                        listenable: c,
                        builder: (context, _) => c.paused ? _pauseCover() : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            _bottomBar(),
          ],
        ),
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
                '지뢰찾기',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                c.level.label,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: scheme.primary),
              ),
            ),
            const Spacer(),
            const Icon(Icons.flag_rounded, size: 20, color: Color(0xFFE5484D)),
            const SizedBox(width: 2),
            Text(
              '${c.minesLeft}',
              key: const ValueKey('mines-left'),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 10),
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
            IconButton(
              tooltip: c.paused ? '계속하기' : '일시정지',
              icon: Icon(
                c.paused ? Icons.play_circle_outline_rounded : Icons.pause_circle_outline_rounded,
                size: 30,
              ),
              onPressed: c.isOver || c.status == MinesStatus.ready ? null : () => c.setPaused(!c.paused),
            ),
            PopupMenuButton<String>(
              tooltip: '메뉴',
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (v) {
                if (v == 'new') _confirmRestart();
                if (v == 'rules') showMinesRules(context);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'new', child: Text('새 판으로 시작')),
                PopupMenuItem(value: 'rules', child: Text('규칙 보기')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _hintBanner() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final text = c.hintMessage;
        if (text == null) return const SizedBox.shrink();
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          constraints: const BoxConstraints(maxWidth: 560),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3C4),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFFFD84D)),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 3)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(Icons.lightbulb_rounded, size: 18, color: Color(0xFFB88700)),
              ),
              Flexible(
                child: Text(
                  text,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF3A2F00)),
                ),
              ),
              GestureDetector(
                onTap: c.dismissHint,
                child: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.close_rounded, size: 18)),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _bottomBar() {
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 2, 10, 8),
          child: Row(
            children: [
              _BarButton(icon: Icons.lightbulb_rounded, label: '힌트', onTap: c.canAct ? c.requestHint : null),
              _BarButton(icon: Icons.refresh_rounded, label: '새 판', onTap: _confirmRestart),
            ],
          ),
        );
      },
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.onSurface.withValues(alpha: 0.78);
    final color = onTap == null ? base.withValues(alpha: 0.3) : base;
    return Expanded(
      child: InkResponse(
        onTap: onTap,
        radius: 44,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 28, color: color),
              const SizedBox(height: 3),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12.5, color: color)),
            ],
          ),
        ),
      ),
    );
  }
}

/// 규칙 설명.
Future<void> showMinesRules(BuildContext context) {
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
      title: const Text('지뢰찾기 규칙'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            line('목표: 지뢰가 없는 칸을 모두 열면 이겨요. 지뢰를 밟으면 져요.'),
            line('칸을 눌러서 열어요. 첫 칸은 늘 안전해요.'),
            line('숫자는 그 칸 둘레 8칸에 지뢰가 몇 개 있는지 알려줘요.'),
            line('칸을 톡 치면 열려요.'),
            line('칸을 꾹 누르면 동그란 메뉴가 떠요. 손가락을 그대로 밀었다 떼세요: 위쪽은 열기, 오른쪽 아래는 깃발, 왼쪽 아래는 물음표(?)예요. 가운데에서 떼면 취소돼요.'),
            line('물음표는 "잘 모르겠어요" 표시라서 지뢰 수에 들어가지 않고, 눌러서 열 수도 있어요.'),
            line('열린 숫자 둘레에 깃발이 숫자만큼 꽂혀 있으면, 그 숫자를 눌러서 나머지 칸을 한꺼번에 열 수 있어요.'),
            line('힌트 버튼은 지금 보이는 숫자로 "확실한" 칸과 그 이유를 알려줘요.'),
            line('두 손가락으로 벌리면 판을 확대하고, 두 손가락으로 움직여 판을 옮길 수 있어요. (한 손가락 끌기는 깃발·물음표예요)'),
          ],
        ),
      ),
      actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('알겠어요'))],
    ),
  );
}
