import 'dart:math';

import 'package:flutter/material.dart';

import '../core/pinball_run.dart';
import '../game/pinball_controller.dart';
import 'pinball_hud.dart';

const TextStyle _t = TextStyle(fontFamily: 'NanumGothic', color: Colors.white);
const Color _panel = Color(0xFF1B2747);

/// 라운드 시작 전 3·2·1과 이번 라운드 목표·제한 시간.
class PinballCountdown extends StatelessWidget {
  const PinballCountdown({super.key, required this.run});

  final PinballRun run;

  @override
  Widget build(BuildContext context) {
    final n = max(1, run.countdownLeft.ceil());
    final frac = run.countdownLeft - run.countdownLeft.floor();
    final scale = 1 + frac * 0.35;
    // 판을 어둡게 하는 건 그림 쪽(PinballPainter)이 맡는다: 공만 밝게 보이게.
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('라운드 ${run.round}', style: _t.copyWith(fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 14),
            _goal(Icons.flag_rounded, '목표 점수', fmtNum(run.targetScore), const Color(0xFFFFD84D)),
            const SizedBox(height: 8),
            _goal(Icons.timer_rounded, '제한 시간', '${run.timeLeft.round()}초', const Color(0xFF3FB950)),
            const SizedBox(height: 22),
            Transform.scale(scale: scale, child: Text('$n', style: _t.copyWith(fontSize: 120, fontWeight: FontWeight.w900, height: 1))),
          ],
        ),
      ),
    );
  }

  Widget _goal(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16), border: Border.all(color: color, width: 2)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text('$label  ', style: _t.copyWith(fontSize: 15, color: Colors.white70)),
          Text(value, style: _t.copyWith(fontSize: 24, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

/// 라운드를 깬 뒤 업그레이드 고르기: 공짜 3장 중 하나를 고르고, 유료 카드는 점수로 사고, "다음 라운드 시작"을 눌러요.
class PinballUpgradeSheet extends StatelessWidget {
  const PinballUpgradeSheet({super.key, required this.controller});

  final PinballController controller;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.7),
      child: SafeArea(
        child: Center(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) => LayoutBuilder(builder: (context, box) {
              final run = controller.run;
              if (run.phase != RunPhase.choosing) return const SizedBox.shrink();
              final wide = box.maxWidth > 760;
              final free = _section('공짜 — 하나만 골라요', const Color(0xFF3FB950), [
                for (var i = 0; i < run.freeOffers.length; i++) _OfferTile(offer: run.freeOffers[i], run: run, onTap: run.freePicked ? null : () => run.pickFree(i)),
                if (run.freeOffers.isEmpty) Text('더 고를 공짜 카드가 없어요', style: _t.copyWith(fontSize: 13, color: Colors.white60)),
              ]);
              final paid = _section('상점 — 점수를 내고 사요', const Color(0xFFFFB400), [
                for (var i = 0; i < run.paidOffers.length; i++) _OfferTile(offer: run.paidOffers[i], run: run, onTap: run.canBuy(run.paidOffers[i]) ? () => run.buy(i) : null),
              ]);
              final bonus = run.lastBonus;
              return Container(
                constraints: BoxConstraints(maxWidth: wide ? 860 : 520, maxHeight: box.maxHeight - 24),
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
                decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white24)),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('라운드 ${run.round} 클리어!', style: _t.copyWith(fontSize: 26, fontWeight: FontWeight.w900, color: const Color(0xFFFFD84D))),
                    const SizedBox(height: 4),
                    Text(
                      '내 점수 ${fmtNum(run.score)}점'
                      '${bonus != null && bonus.timePts > 0 ? '  · 시간 보너스 +${fmtNum(bonus.timePts)}' : ''}'
                      '${bonus != null && bonus.interestPts > 0 ? '  · 이자 +${fmtNum(bonus.interestPts)}' : ''}',
                      textAlign: TextAlign.center,
                      style: _t.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '다음은 목표 ${fmtNum(PinballRun.targetFor(run.round + 1))}점 · ${PinballRun.timeFor(run.round + 1).round()}초 (점수를 쓰면 그만큼 더 모아야 해요)',
                      textAlign: TextAlign.center,
                      style: _t.copyWith(fontSize: 12.5, color: Colors.white60),
                    ),
                    const SizedBox(height: 10),
                    Flexible(
                      child: SingleChildScrollView(
                        child: wide
                            ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: free), const SizedBox(width: 14), Expanded(child: paid)])
                            : Column(children: [free, const SizedBox(height: 10), paid]),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          backgroundColor: kPinballColor,
                          disabledBackgroundColor: Colors.white12,
                          disabledForegroundColor: Colors.white54,
                          textStyle: const TextStyle(fontFamily: 'NanumGothic', fontSize: 17, fontWeight: FontWeight.w900),
                        ),
                        onPressed: run.canStartNext ? run.startNextRound : null,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text(run.canStartNext ? '다음 라운드 시작' : '공짜 카드를 먼저 1장 골라요'),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _section(String title, Color color, List<Widget> tiles) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(title, style: _t.copyWith(fontSize: 15, fontWeight: FontWeight.w900, color: color))),
        ...tiles,
      ],
    );
  }
}

class _OfferTile extends StatelessWidget {
  const _OfferTile({required this.offer, required this.run, required this.onTap});

  final Offer offer;
  final PinballRun run;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final u = offer.upgrade;
    final paid = offer.price > 0;
    final have = run.stacks[u.id] ?? 0;
    final afford = run.score >= offer.price;
    final dim = paid ? (offer.bought || !afford) : (run.freePicked && !offer.bought);
    final stackNote = u.consumable || offer.bought ? '' : (have > 0 ? '  (지금 $have개 → ${have + 1}개)' : '');
    return Opacity(
      opacity: dim ? 0.45 : 1,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: u.color.withValues(alpha: 0.22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: u.color, width: 1.5)),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: offer.bought ? null : onTap,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: u.color, shape: BoxShape.circle),
                    child: Icon(u.icon, color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(u.name, style: _t.copyWith(fontSize: 16, fontWeight: FontWeight.w900))),
                            if (u.tier == 2) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.auto_awesome_rounded, size: 15, color: Color(0xFFFFD84D)),
                            ],
                          ],
                        ),
                        Text('${u.desc}$stackNote', style: _t.copyWith(fontSize: 12.5, color: Colors.white70, height: 1.25)),
                      ],
                    ),
                  ),
                  if (!paid && offer.bought) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle_rounded, color: Color(0xFF3FB950), size: 30),
                  ],
                  if (paid) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: offer.bought ? Colors.white24 : (afford ? const Color(0xFFFFB400) : Colors.white24), borderRadius: BorderRadius.circular(12)),
                      child: Text(
                        offer.bought ? '산 것' : '${fmtNum(offer.price)}점',
                        style: _t.copyWith(fontSize: 14, fontWeight: FontWeight.w900, color: offer.bought || !afford ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 시간이 다 돼서 끝난 뒤의 결과.
class PinballGameOver extends StatelessWidget {
  const PinballGameOver({super.key, required this.controller, required this.onLeave, required this.onRecords});

  final PinballController controller;
  final VoidCallback onLeave;
  final VoidCallback onRecords;

  @override
  Widget build(BuildContext context) {
    final run = controller.run;
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.75),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460),
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(run.outOfBalls ? '공을 다 놓쳤어요!' : '시간 끝!', style: _t.copyWith(fontSize: 30, fontWeight: FontWeight.w900, color: const Color(0xFFFF8A80))),
                  const SizedBox(height: 4),
                  Text(
                    run.outOfBalls ? '라운드 ${run.round}에서 마지막 공이 빠졌어요' : '라운드 ${run.round}에서 목표 ${fmtNum(run.targetScore)}점을 못 채웠어요',
                    textAlign: TextAlign.center,
                    style: _t.copyWith(fontSize: 14, color: Colors.white70),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(child: _stat('도착한 라운드', '${run.round}')),
                      const SizedBox(width: 8),
                      Expanded(child: _stat('마지막 점수', fmtNum(run.score))),
                      const SizedBox(width: 8),
                      Expanded(child: _stat('최고 콤보', '${run.bestCombo}')),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Align(alignment: Alignment.centerLeft, child: Text('이번에 고른 업그레이드', style: _t.copyWith(fontSize: 13, color: Colors.white60))),
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerLeft, child: OwnedUpgrades(run: run)),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: kPinballColor, textStyle: const TextStyle(fontFamily: 'NanumGothic', fontSize: 17, fontWeight: FontWeight.w800)),
                      onPressed: controller.restart,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('다시 도전'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, textStyle: const TextStyle(fontFamily: 'NanumGothic', fontWeight: FontWeight.w700)),
                          onPressed: onRecords,
                          child: const Text('내 기록'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.white, textStyle: const TextStyle(fontFamily: 'NanumGothic', fontWeight: FontWeight.w700)),
                          onPressed: onLeave,
                          child: const Text('나가기'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(14)),
      child: Column(
        children: [
          Text(label, style: _t.copyWith(fontSize: 11.5, color: Colors.white60)),
          FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: _t.copyWith(fontSize: 22, fontWeight: FontWeight.w900))),
        ],
      ),
    );
  }
}

/// 일시정지 창.
class PinballPauseCard extends StatelessWidget {
  const PinballPauseCard({super.key, required this.controller, required this.onResume, required this.onHelp, required this.onLeave});

  final PinballController controller;
  final VoidCallback onResume;
  final VoidCallback onHelp;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    ButtonStyle outlined() => OutlinedButton.styleFrom(foregroundColor: Colors.white, textStyle: const TextStyle(fontFamily: 'NanumGothic', fontWeight: FontWeight.w700));
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.7),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(24), border: Border.all(color: Colors.white24)),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('잠깐 멈춤', style: _t.copyWith(fontSize: 26, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: Text('내 업그레이드', style: _t.copyWith(fontSize: 13, color: Colors.white60))),
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerLeft, child: OwnedUpgrades(run: controller.run)),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: kPinballColor, textStyle: const TextStyle(fontFamily: 'NanumGothic', fontSize: 17, fontWeight: FontWeight.w800)),
                      onPressed: onResume,
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('계속하기'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton(style: outlined(), onPressed: onHelp, child: const Text('게임 방법'))),
                      const SizedBox(width: 8),
                      Expanded(child: OutlinedButton(style: outlined(), onPressed: onLeave, child: const Text('그만두기'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
