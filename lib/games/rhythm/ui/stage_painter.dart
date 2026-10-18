import 'dart:math';

import 'package:flutter/material.dart';

import '../core/rhythm_chart.dart';
import '../core/rhythm_judge.dart';
import '../game/rhythm_controller.dart';
import 'camp_painter.dart';
import 'rhythm_art.dart';

part 'stage_painter_actors.dart';
part 'stage_painter_boss.dart';
part 'stage_painter_cues.dart';

const _gold = Color(0xFFFFD21F);
const kInk = Color(0xFF1A1523);
const _names = ['교관', '선배', '선배', '나'];

/// 움직이는 부분: 허수아비(또는 슬라임), 검사들, 타격 효과, 안내 링, 이름표, 판정 글자.
class StagePainter extends CustomPainter {
  StagePainter(this.c, {required this.art, required this.clock, required this.wall, this.foe = Foe.dummy, this.iron = false}) : super(repaint: c);

  final RhythmController c;
  final RhythmArt art;

  /// 검사들 앞에 선 상대.
  final Foe foe;

  /// 목검 대신 철검 그림을 쓴다.
  final bool iron;

  /// 지금 곡 시간(초). 시작 전에는 음수.
  final double Function() clock;

  /// 화면을 연 뒤 흐른 시간(초) — 숨쉬기·흔들림처럼 가만히 있을 때의 움직임용.
  final double Function() wall;

  @override
  void paint(Canvas canvas, Size size) {
    final L = CampLayout(size);
    final t = c.status == RhythmStatus.playing ? clock() : -1.0;
    final idle = wall();
    final phase = c.beatPhase(t);
    final pulse = t < 0 ? 0.0 : pow(1 - phase, 3).toDouble();
    final bounce = -pulse;

    // ── 타격 충격량 (화면 흔들림·번쩍임용) ──
    var impact = 0.0;
    for (var i = 0; i < 4; i++) {
      final sw = c.swing(i, t);
      if (sw == null || sw.sinceImpact < 0 || sw.sinceImpact > 0.16) continue;
      final amp = (i == 3 ? 1.0 : 0.3) * (1 - sw.sinceImpact / 0.16);
      impact = max(impact, amp);
    }

    canvas.save();
    if (impact > 0) {
      final k = L.unit * 0.012 * impact;
      canvas.translate(sin(idle * 131) * k * 1.3, cos(idle * 107) * k);
    }

    // ── 허수아비 / 슬라임 / 보스 ──
    if (foe == Foe.bossSlime) {
      _drawBoss(canvas, L, t, idle);
    } else {
      for (var i = 0; i < 4; i++) {
        if (foe == Foe.slime) {
          _drawSlime(canvas, L, i, c.swing(i, t), t, idle);
        } else {
          _drawDummy(canvas, L, i, c.swing(i, t));
        }
      }
    }

    // 내 자리 표시: 바닥의 금빛 타원
    final px = L.actorX(3);
    final spot = Rect.fromCenter(center: Offset(px, L.feetY), width: L.unit * 0.95, height: L.unit * 0.18);
    canvas.drawOval(spot, Paint()..color = _gold.withValues(alpha: 0.5));
    canvas.drawOval(spot, Paint()..style = PaintingStyle.stroke..strokeWidth = 4..color = kInk);

    final cue = c.cue(t);
    final active = c.activeActor(t);

    // ── 검사들 ──
    for (var i = 0; i < 4; i++) {
      final swing = c.swing(i, t);
      var kind = 'idle';
      var mirror = false;
      var squashY = 1 + 0.03 * bounce;
      var squashX = 1 - 0.02 * bounce;
      var rotate = 0.0;
      final foot = Offset(L.actorX(i), L.feetY);
      if (swing != null) {
        final s = swing.sinceImpact;
        mirror = swing.side == Side.left;
        if (swing.guard) {
          // 검을 들어 막는 자세 (전용 그림이 없으면 칼을 치켜든 자세로 대신한다)
          kind = 'guard';
          mirror = false;
          final k = s < 0 ? 0.6 : (1 - s / 0.5).clamp(0.0, 1.0);
          squashY = 1 + 0.02 * k;
        } else if (swing.swipe) {
          // 옆으로 휘두르기: 칼을 뒤로 빼 들었다가 쓱 휘두른다 (칼끝에 푸른 궤적)
          if (s >= 0 && s < 0.3) {
            kind = 'side_swing';
            final e = exp(-s * 18);
            squashY = 1 - 0.04 * e;
            squashX = 1 + 0.04 * e;
          } else if (s < 0 && (s > -0.2 || i == 3)) {
            kind = 'side_ready';
            final k = i == 3 ? 1.0 : (1 + s / 0.2).clamp(0.0, 1.0);
            squashY = 1 + 0.02 * k;
            rotate = (mirror ? 1 : -1) * 0.02 * k;
          } else {
            mirror = false;
          }
        } else if (swing.charge != null) {
          // 꾹 눌러 힘을 모으는 중: 칼을 치켜든 채 점점 떨린다
          kind = 'windup';
          final ch = swing.charge!;
          rotate = (mirror ? 1 : -1) * 0.03 + sin(idle * 70) * 0.012 * ch;
          squashY = 1 + 0.02 + 0.015 * ch;
        } else if (s >= 0 && s < 0.3) {
          kind = 'strike';
          final e = exp(-s * 18);
          squashY = 1 - 0.07 * e;
          squashX = 1 + 0.05 * e;
        } else if (s < 0 && s > -0.2 && i != 3) {
          kind = 'windup';
          final k = (1 + s / 0.2).clamp(0.0, 1.0);
          rotate = (mirror ? 1 : -1) * 0.03 * k;
          squashY = 1 + 0.02 * k;
        } else {
          mirror = false;
        }
      }
      var spriteName = RhythmArt.actorSprite(i, kind, iron: iron);
      if (kind == 'guard' && art.image(spriteName) == null) spriteName = RhythmArt.actorSprite(i, 'windup', iron: iron);
      var drawFoot = foot;
      final spritePaint = Paint()..filterQuality = FilterQuality.high;
      if (i == 3) {
        final hurt = _hurtAmount(t);
        if (hurt > 0) {
          // 막지 못해 맞았다: 붉게 번쩍이며 부르르 떤다
          drawFoot += Offset(sin(idle * 90) * L.unit * 0.025 * hurt, 0);
          spritePaint.colorFilter = ColorFilter.mode(const Color(0xFFFF3B3B).withValues(alpha: 0.6 * hurt), BlendMode.srcATop);
        }
      }
      drawSprite(canvas, art, spriteName, drawFoot, L.charScale,
          mirror: mirror, squashX: squashX, squashY: squashY, rotate: rotate, paint: spritePaint);
      if (swing?.charge != null) {
        _drawCharge(canvas, L, i, foot, mirror, swing!.charge!, idle);
      }

      // 이름표: 지금 차례인 사람은 노란색으로 커진다
      final on = active == i;
      _sticker(
        canvas,
        _names[i],
        Offset(L.actorX(i), min(size.height * 0.972, L.feetY + L.unit * 0.1)),
        L.unit * (on ? 0.15 : 0.12),
        on ? _gold : Colors.white,
      );
    }

    if (foe == Foe.bossSlime) _drawGuardEffect(canvas, L, t);
    if (cue != null) {
      if (cue.isGuard) {
        _drawGuardGuide(canvas, L, cue);
      } else if (cue.isSwipe) {
        _drawSwipeGuide(canvas, L, cue);
      } else {
        _drawRing(canvas, L, cue);
      }
    }
    for (final p in c.pops) {
      _drawPop(canvas, L, p, t);
    }
    canvas.restore();

    if (cue != null && !cue.isSwipe && !cue.isGuard) _drawEdgeGlow(canvas, size, cue.remain, cue.side);
    if (foe == Foe.bossSlime && t >= 0) _drawBossWarning(canvas, size, t, idle);
    if (impact > 0) {
      canvas.drawRect(Offset.zero & size, Paint()..color = Colors.white.withValues(alpha: 0.14 * impact));
    }
  }

  // ── 보스: 큰 빨간 슬라임 한 마리. 네 검사의 공격을 모두 받고, 가끔 힘을 모아 덮쳐 온다 ──


  @override
  bool shouldRepaint(StagePainter old) => true;
}
