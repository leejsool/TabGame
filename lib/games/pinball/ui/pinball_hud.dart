import 'package:flutter/material.dart';

import '../core/pinball_run.dart';
import '../core/pinball_upgrades.dart';
import '../game/pinball_controller.dart';

const Color kPinballColor = Color(0xFF1B998B);

/// 1234567 → "1,234,567"
String fmtNum(int n) {
  final s = n.abs().toString();
  final b = StringBuffer(n < 0 ? '-' : '');
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

const TextStyle _base = TextStyle(fontFamily: 'NanumGothic', color: Colors.white);

/// 화면 위(또는 가로 화면의 왼쪽)에 놓이는 점수판: 라운드 · 점수/목표 · 남은 시간 · 콤보 · 틸트.
class PinballHud extends StatelessWidget {
  const PinballHud({super.key, required this.controller, required this.vertical, required this.onPause});

  final PinballController controller;
  final bool vertical;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final run = controller.run;
        final urgent = run.phase == RunPhase.playing && run.timeLeft <= 10;
        final secs = run.timeLeft.clamp(0, 999).toDouble();
        final timeText = secs >= 10 ? secs.ceil().toString() : secs.toStringAsFixed(1);
        final progress = run.targetScore == 0 ? 0.0 : (run.score / run.targetScore).clamp(0.0, 1.0);

        final round = _chip('라운드', '${run.round}', const Color(0xFF2F8FDB));
        final time = _chip('남은 시간', timeText, urgent ? const Color(0xFFE5484D) : const Color(0xFF3FB950), big: true);
        final score = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(fmtNum(run.score), style: _base.copyWith(fontSize: 30, fontWeight: FontWeight.w900, height: 1.05)),
            ),
            Text('목표 ${fmtNum(run.targetScore)}', style: _base.copyWith(fontSize: 13, color: Colors.white70)),
          ],
        );
        final bar = ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(value: progress, minHeight: 9, backgroundColor: Colors.white12, color: progress >= 1 ? const Color(0xFFFFD84D) : kPinballColor),
        );
        final combo = _comboRow(run);

        if (vertical) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [Expanded(child: round), const SizedBox(width: 8), Expanded(child: time)]),
              const SizedBox(height: 14),
              score,
              const SizedBox(height: 8),
              bar,
              const SizedBox(height: 14),
              combo,
              const SizedBox(height: 14),
              _tiltBar(run),
              const SizedBox(height: 18),
              Expanded(child: SingleChildScrollView(child: _owned(run))),
              FilledButton.tonalIcon(onPressed: onPause, icon: const Icon(Icons.pause_rounded), label: const Text('일시정지')),
            ],
          );
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 6, 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 62, child: round),
                  const SizedBox(width: 10),
                  Expanded(child: score),
                  const SizedBox(width: 8),
                  SizedBox(width: 78, child: time),
                  IconButton(tooltip: '일시정지', onPressed: onPause, icon: const Icon(Icons.pause_circle_filled_rounded, color: Colors.white70, size: 30)),
                ],
              ),
              const SizedBox(height: 4),
              bar,
              const SizedBox(height: 4),
              Row(children: [Expanded(child: combo), SizedBox(width: 110, child: _tiltBar(run))]),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String label, String value, Color color, {bool big = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(12), border: Border.all(color: color, width: 1.5)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: _base.copyWith(fontSize: 10.5, color: Colors.white70)),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: _base.copyWith(fontSize: big ? 26 : 22, fontWeight: FontWeight.w900, height: 1.05))),
        ],
      ),
    );
  }

  Widget _comboRow(PinballRun run) {
    if (run.combo < 2) return Text('연속으로 맞히면 점수가 불어나요', maxLines: 1, overflow: TextOverflow.ellipsis, style: _base.copyWith(fontSize: 12, color: Colors.white54));
    final frac = run.comboTimer > 0 ? (run.comboTimer / (2.5 + run.mods.comboExtra)).clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        Text('콤보 ${run.combo}', style: _base.copyWith(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFFFFD84D))),
        const SizedBox(width: 6),
        Text('×${run.multiplier.toStringAsFixed(2)}', style: _base.copyWith(fontSize: 15, fontWeight: FontWeight.w900)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: frac, minHeight: 6, backgroundColor: Colors.white12, color: const Color(0xFFFFD84D)),
          ),
        ),
      ],
    );
  }

  Widget _tiltBar(PinballRun run) {
    final color = run.tilted ? const Color(0xFFFF5252) : Color.lerp(const Color(0xFF8E9AAF), const Color(0xFFFF5252), run.tilt.clamp(0.0, 1.0))!;
    return Row(
      children: [
        Icon(Icons.vibration_rounded, size: 16, color: color),
        const SizedBox(width: 4),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: run.tilted ? 1 : run.tilt.clamp(0.0, 1.0), minHeight: 6, backgroundColor: Colors.white12, color: color),
          ),
        ),
      ],
    );
  }

  Widget _owned(PinballRun run) => OwnedUpgrades(run: run);
}

/// 지금까지 고른 업그레이드 모음 (아이콘 + 겹친 수).
class OwnedUpgrades extends StatelessWidget {
  const OwnedUpgrades({super.key, required this.run});

  final PinballRun run;

  @override
  Widget build(BuildContext context) {
    if (run.stacks.isEmpty && run.bankedTime == 0) {
      return Text('아직 고른 업그레이드가 없어요', style: _base.copyWith(fontSize: 12, color: Colors.white54));
    }
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in run.stacks.entries) _chip(upgradeById(e.key), e.value),
        if (run.bankedTime > 0) _chip(upgradeById('time_pack'), run.bankedTime ~/ 12),
      ],
    );
  }

  Widget _chip(Upgrade u, int n) {
    return Tooltip(
      message: '${u.name}: ${u.desc}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: u.color.withValues(alpha: 0.28), borderRadius: BorderRadius.circular(10), border: Border.all(color: u.color)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(u.icon, size: 15, color: Colors.white),
            const SizedBox(width: 4),
            Text(n > 1 ? '${u.name} ×$n' : u.name, style: _base.copyWith(fontSize: 12, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
