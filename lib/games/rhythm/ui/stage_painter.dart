import 'dart:math';

import 'package:flutter/material.dart';

import '../core/rhythm_chart.dart';
import '../core/rhythm_judge.dart';
import '../game/rhythm_controller.dart';
import 'camp_painter.dart';
import 'rhythm_art.dart';

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

  // ── 허수아비: 맞으면 그쪽으로 기울며 흔들리고, 번쩍인다 ──
  void _drawDummy(Canvas canvas, CampLayout L, int i, SwingState? sw) {
    final base = Offset(L.actorX(i), L.dummyBaseY);
    final centerY = base.dy - L.dummyHeight * 0.58;
    var rotate = 0.0;
    var squashY = 1.0;
    var flash = 0.0;
    if (sw != null && sw.sinceImpact >= 0 && sw.sinceImpact < 0.7) {
      final s = sw.sinceImpact;
      final dir = sw.side == Side.right ? 1.0 : -1.0;
      rotate = dir * 0.24 * exp(-4.5 * s) * cos(24 * s);
      squashY = 1 - 0.05 * exp(-10 * s);
      flash = (1 - s / 0.13).clamp(0.0, 1.0);
    }
    Paint? paint;
    if (flash > 0) {
      paint = Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = ColorFilter.mode(Colors.white.withValues(alpha: 0.85 * flash), BlendMode.srcATop);
    }
    drawSprite(canvas, art, 'dummy', base, L.dummyScale, rotate: rotate, squashY: squashY, paint: paint);

    if (sw == null || sw.sinceImpact < 0 || sw.sinceImpact > 0.5) return;
    final s = sw.sinceImpact;
    final dir = sw.side == Side.right ? 1.0 : -1.0;
    final player = i == 3;

    _drawSlash(canvas, L, base, dir, centerY, L.dummyHeight * 0.1, s);

    // 맞은 자리의 충격 별
    if (s < 0.17) {
      final kk = s / 0.17;
      final r = L.unit * (0.12 + 0.2 * Curves.easeOut.transform(kk)) * (player ? 1.0 : 0.8);
      final star = Path();
      const spikes = 9;
      final c0 = Offset(base.dx + dir * L.dummyHeight * 0.12, centerY);
      for (var k = 0; k < spikes * 2; k++) {
        final a = -pi + (2 * pi * k / (spikes * 2));
        final rr = k.isEven ? r : r * 0.48;
        final o = c0 + Offset(cos(a) * rr, sin(a) * rr);
        k == 0 ? star.moveTo(o.dx, o.dy) : star.lineTo(o.dx, o.dy);
      }
      star.close();
      canvas.drawPath(star, Paint()..color = _gold.withValues(alpha: 1 - kk * 0.6));
      canvas.drawPath(star, Paint()..style = PaintingStyle.stroke..strokeWidth = L.unit * 0.025..strokeJoin = StrokeJoin.round..color = kInk.withValues(alpha: 1 - kk));
    }

    // 나무 조각 (포물선)
    _drawDebris(canvas, L, i, sw, Offset(base.dx + dir * L.dummyHeight * 0.1, centerY),
        colors: const [Color(0xFFE9B96E), Color(0xFFC9482F)], count: 7, round: false);
  }

  // ── 슬라임: 숨 쉬듯 말랑거리다가, 칼이 올라오면 깜짝 놀라고, 맞으면 찌그러지며 튕겨 난다 ──
  void _drawSlime(Canvas canvas, CampLayout L, int i, SwingState? sw, double t, double idle, {bool red = false}) {
    final base = Offset(L.actorX(i), L.dummyBaseY);
    final scale = L.slimeScale;
    final centerY = base.dy - 346 * scale * 0.5;
    var kind = 'idle';
    var mirror = false;
    var offset = Offset.zero;
    var rotate = 0.0;
    final breathe = sin(idle * 3.2 + i * 1.3);
    var squashX = 1 - 0.025 * breathe;
    var squashY = 1 + 0.035 * breathe;
    var flash = 0.0;
    var dir = 1.0;

    if (sw != null && sw.sinceImpact >= 0 && sw.sinceImpact < 0.45) {
      // 맞았다: 칼 맞은 쪽 반대로 튕기며 찌그러졌다 돌아온다
      final s = sw.sinceImpact;
      kind = 'hit';
      mirror = sw.side == Side.left;
      dir = sw.side == Side.right ? 1.0 : -1.0;
      rotate = dir * 0.14 * exp(-5 * s) * cos(22 * s);
      squashX = 1 - 0.1 * exp(-9 * s) * cos(30 * s);
      squashY = 1 + 0.12 * exp(-9 * s) * cos(30 * s);
      offset = Offset(-dir * L.unit * 0.05 * exp(-7 * s), 0);
      flash = (1 - s / 0.12).clamp(0.0, 1.0);
    } else if (sw != null && (sw.sinceImpact < 0 || sw.charge != null)) {
      // 칼이 올라온다: 깜짝 놀라 부르르 떤다
      kind = 'ready';
      squashY = 1.04;
      offset = Offset(sin(idle * 60) * L.unit * 0.004, 0);
    } else if (i == 3 && c.pops.isNotEmpty) {
      // 내가 놓치면 내 앞의 슬라임이 덤벼든다
      final p = c.pops.last;
      final age = t - p.at;
      if ((p.rating == Rating.miss || p.rating == Rating.wrongSide) && age >= 0 && age < 0.45) {
        final k = age / 0.45;
        final lunge = sin(pi * k);
        kind = 'attack';
        mirror = p.side == Side.left;
        offset = Offset((mirror ? -1 : 1) * L.unit * 0.18 * lunge, -L.unit * 0.07 * lunge);
        squashX = 1 + 0.05 * lunge;
        squashY = 1 - 0.04 * lunge;
      }
    }

    Paint? paint;
    if (flash > 0) {
      paint = Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = ColorFilter.mode(Colors.white.withValues(alpha: 0.85 * flash), BlendMode.srcATop);
    }
    drawSprite(canvas, art, RhythmArt.slimeSprite(kind, red: red), base + offset, scale,
        mirror: mirror, squashX: squashX, squashY: squashY, rotate: rotate, paint: paint);

    if (kind != 'hit' || sw == null || sw.sinceImpact > 0.5) return;
    _drawSlash(canvas, L, base, dir, centerY, L.unit * 0.18, sw.sinceImpact);
    _drawDebris(canvas, L, i, sw, Offset(base.dx + dir * L.unit * 0.18, centerY),
        colors: red ? const [Color(0xFFE5484D), Color(0xFFFFC2C4)] : const [Color(0xFF63B6FA), Color(0xFFBFE3FF)], count: 6, round: true);
  }

  /// 칼바람: 검사 쪽에서 맞는 자리로 날아가는 흰 줄.
  void _drawSlash(Canvas canvas, CampLayout L, Offset base, double dir, double centerY, double reach, double s, {Offset? origin}) {
    if (s >= 0.1) return;
    final k = s / 0.1;
    final from = origin ?? Offset(base.dx + dir * L.unit * 0.1, L.feetY - L.unit * 0.25);
    final to = Offset(base.dx + dir * reach, centerY);
    final head = Offset.lerp(from, to, Curves.easeOut.transform(k))!;
    final tail = Offset.lerp(from, to, max(0.0, Curves.easeOut.transform(k) - 0.3))!;
    canvas.drawLine(tail, head, Paint()..color = Colors.white.withValues(alpha: 0.9)..strokeWidth = L.unit * 0.05..strokeCap = StrokeCap.round);
  }

  /// 맞은 자리에서 포물선으로 흩어지는 조각들 (나무 조각 / 물방울).
  void _drawDebris(Canvas canvas, CampLayout L, int i, SwingState sw, Offset c0, {required List<Color> colors, required int count, required bool round}) {
    final s = sw.sinceImpact;
    final dir = sw.side == Side.right ? 1.0 : -1.0;
    final rng = Random(i * 31 + sw.side.index);
    final k = (s / 0.5).clamp(0.0, 1.0);
    for (var n = 0; n < count; n++) {
      final ang = -pi * (0.1 + 0.8 * rng.nextDouble()) + dir * 0.4;
      final sp = L.unit * (0.5 + 0.7 * rng.nextDouble());
      final pos = c0 + Offset(cos(ang) * sp * s, sin(ang) * sp * s + L.unit * 2.2 * s * s);
      final sz = L.unit * (0.014 + 0.016 * rng.nextDouble());
      final paint = Paint()..color = colors[n.isEven ? 0 : 1].withValues(alpha: 1 - k);
      if (round) {
        canvas.drawCircle(pos, sz * 1.3, paint);
        continue;
      }
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(s * (6 + n * 3));
      canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: sz * 2, height: sz * 1.3), paint);
      canvas.restore();
    }
  }

  // ── 보스: 큰 빨간 슬라임 한 마리. 네 검사의 공격을 모두 받고, 가끔 힘을 모아 덮쳐 온다 ──

  // 보스는 항상 검사들보다 뒤(아래)에 그린다: 검사들이 플레이어와 더 가까우니 덮쳐 와도 검사들이 위에 보인다.
  void _drawBoss(Canvas canvas, CampLayout L, double t, double idle) {
    final st = t < 0 ? const BossState(BossPhase.idle, 0) : c.bossState(t);
    final u = L.unit;
    final scale = L.slimeScale * 1.9;
    final bodyH = 346 * scale;
    final home = Offset(L.size.width * 0.5, L.dummyBaseY + u * 0.1);
    final player = Offset(L.actorX(3), L.feetY - u * 0.45);
    var pos = home;
    var kind = 'idle';
    var mirror = false;
    var grow = 1.0;
    var rotate = 0.0;
    var flash = 0.0;
    final breathe = sin(idle * 2.4);
    var squashX = 1 - 0.02 * breathe;
    var squashY = 1 + 0.03 * breathe;
    final p = st.progress;
    int? hitActor;
    SwingState? hit;

    switch (st.phase) {
      case BossPhase.windup:
        // 세 박 동안 점점 커지고 부르르 떨며 붉게 달아오른다
        kind = 'ready';
        grow = 1 + 0.12 * p;
        pos += Offset(sin(idle * 55) * u * 0.014 * p, 0);
        squashY = 1 + 0.05 * p * sin(idle * 18);
      case BossPhase.lunge:
        kind = 'attack';
        final e = Curves.easeIn.transform(p);
        pos = Offset.lerp(home, player, 0.85 * e)!;
        grow = 1.12 + 0.3 * e;
      case BossPhase.slam:
        // 막지 못했다: 내려찍은 채 있다가 천천히 제자리로
        final e = Curves.easeOut.transform(p);
        kind = p < 0.5 ? 'attack' : 'idle';
        pos = Offset.lerp(Offset.lerp(home, player, 0.85)!, home, e)!;
        grow = 1.42 - 0.42 * e;
        squashY = 1 - 0.1 * (1 - e);
      case BossPhase.blocked:
        // 막혔다: 튕겨 나며 비틀거린다
        kind = 'hit';
        pos = home + Offset(0, -u * 0.14 * sin(pi * min(1.0, p * 1.3)));
        grow = 1.12 - 0.12 * p;
        rotate = 0.18 * exp(-5 * p) * cos(20 * p);
        flash = (1 - p / 0.2).clamp(0.0, 1.0);
      case BossPhase.idle:
        // 가만히 있을 때: 가장 최근에 맞은 공격에 반응한다
        for (var i = 0; i < 4; i++) {
          final sw = c.swing(i, t);
          if (sw == null || sw.guard || sw.sinceImpact < 0 || sw.sinceImpact >= 0.45) continue;
          if (hit == null || sw.sinceImpact < hit.sinceImpact) {
            hit = sw;
            hitActor = i;
          }
        }
        if (hit != null) {
          final s = hit.sinceImpact;
          final dir = hit.side == Side.right ? 1.0 : -1.0;
          kind = 'hit';
          mirror = hit.side == Side.left; // 그림은 오른쪽에서 맞는 모습이라, 왼쪽에서 맞으면 뒤집는다
          rotate = dir * 0.1 * exp(-5 * s) * cos(22 * s);
          squashX = 1 - 0.08 * exp(-9 * s) * cos(30 * s);
          squashY = 1 + 0.1 * exp(-9 * s) * cos(30 * s);
          pos += Offset(-dir * u * 0.04 * exp(-7 * s), 0);
          flash = (1 - s / 0.12).clamp(0.0, 1.0);
        }
    }

    final center = pos + Offset(0, -bodyH * grow * 0.5);
    if (st.phase == BossPhase.windup && p > 0.05) {
      // 달아오르는 붉은 기운
      final r = bodyH * grow * (0.75 + 0.1 * sin(idle * 12));
      canvas.drawCircle(
        center,
        r,
        Paint()..shader = RadialGradient(colors: [const Color(0xFFFF2D3D).withValues(alpha: 0.38 * p), const Color(0x00FF2D3D)]).createShader(Rect.fromCircle(center: center, radius: r)),
      );
    }
    Paint? paint;
    if (flash > 0) {
      paint = Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = ColorFilter.mode(Colors.white.withValues(alpha: 0.85 * flash), BlendMode.srcATop);
    }
    drawSprite(canvas, art, RhythmArt.slimeSprite(kind, red: true), pos, scale * grow,
        mirror: mirror, squashX: squashX, squashY: squashY, rotate: rotate, paint: paint);
    if (st.phase == BossPhase.windup && p > 0.3) {
      // 머리 위의 경고 표시
      final pop = 1 + 0.15 * sin(idle * 16);
      _sticker(canvas, '!!', Offset(home.dx, home.dy - bodyH * 1.1), u * 0.3 * pop, const Color(0xFFFF4D5E));
    }
    if (hit != null && hitActor != null) {
      final dir = hit.side == Side.right ? 1.0 : -1.0;
      final from = Offset(L.actorX(hitActor), L.feetY - u * 0.3);
      _drawSlash(canvas, L, home, dir, center.dy, u * 0.3, hit.sinceImpact, origin: from);
      if (hit.sinceImpact <= 0.5) {
        _drawDebris(canvas, L, hitActor, hit, center + Offset(dir * u * 0.3, 0),
            colors: const [Color(0xFFE5484D), Color(0xFFFFC2C4)], count: 6, round: true);
      }
    }
  }

  /// 막지 못해 맞은 뒤 얼마나 아파하는지 1(막 맞음)→0.
  double _hurtAmount(double t) {
    var best = 0.0;
    for (final g in c.chart.guards) {
      final o = c.guardOutcome(g);
      if (o == null || o.blocked) continue;
      final dt = t - o.at;
      if (dt >= 0 && dt < 0.5) best = max(best, 1 - dt / 0.5);
    }
    return best;
  }

  /// 막았을 때: 검 끝에서 푸른 방어 막이 퍼지며 터진다.
  void _drawGuardEffect(Canvas canvas, CampLayout L, double t) {
    final ga = c.lastGuardAt;
    if (ga == null || t < 0) return;
    final age = t - ga;
    if (age < 0 || age > 0.55) return;
    final blocked = c.chart.guards.any((g) {
      final o = c.guardOutcome(g);
      return o != null && o.blocked && (o.at - ga).abs() < 0.02;
    });
    if (!blocked) return;
    final u = L.unit;
    final k = age / 0.55;
    final e = Curves.easeOut.transform(k);
    final center = Offset(L.actorX(3), L.feetY - u * 1.05);
    final fade = 1 - k;
    for (final (radius, width, color) in [
      (0.22 + 0.5 * e, 0.07 * fade, const Color(0xFF9CE7FF)),
      (0.12 + 0.34 * e, 0.045 * fade, Colors.white),
    ]) {
      canvas.drawCircle(center, u * radius, Paint()..style = PaintingStyle.stroke..strokeWidth = u * width + 1..color = color.withValues(alpha: fade));
    }
    for (var n = 0; n < 8; n++) {
      final a = n * pi / 4 + 0.3;
      final d0 = u * (0.3 + 0.35 * e);
      final d1 = u * (0.45 + 0.55 * e);
      canvas.drawLine(
        center + Offset(cos(a), sin(a)) * d0,
        center + Offset(cos(a), sin(a)) * d1,
        Paint()..color = _gold.withValues(alpha: fade)..strokeWidth = u * 0.03 * fade + 1..strokeCap = StrokeCap.round,
      );
    }
  }

  // ── 막기 안내: 시작점에서 링이 줄어든 뒤, 구슬이 위로 달려가 끝에 닿는 순간이 박자 ──
  void _drawGuardGuide(Canvas canvas, CampLayout L, CueInfo cue) {
    final size = L.size;
    final u = L.unit;
    final x = size.width * 0.5;
    final startY = size.height * (L.landscape ? 0.9 : 0.93);
    final endY = size.height * (L.landscape ? 0.5 : 0.55);
    final start = Offset(x, startY);
    final end = Offset(x, endY);
    const accent = Color(0xFFFF9A4D);

    final head = u * 0.16;
    final bodyEnd = Offset(x, endY + head * 0.7);
    final band = Path()..moveTo(x, startY)..lineTo(bodyEnd.dx, bodyEnd.dy);
    final tip = Path()
      ..moveTo(x, endY)
      ..lineTo(x - head * 0.75, endY + head)
      ..lineTo(x + head * 0.75, endY + head)
      ..close();
    canvas.drawPath(band, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.115..strokeCap = StrokeCap.round..color = kInk);
    canvas.drawPath(tip, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.07..strokeJoin = StrokeJoin.round..color = kInk);
    canvas.drawPath(band, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.07..strokeCap = StrokeCap.round..color = Colors.white.withValues(alpha: 0.85));
    canvas.drawPath(tip, Paint()..color = Colors.white.withValues(alpha: 0.85));

    const run = 0.35;
    final ringK = ((cue.remain - run) / (1 - run)).clamp(0.0, 1.0);
    final travel = Curves.easeIn.transform((1 - cue.remain / run).clamp(0.0, 1.0));
    canvas.drawCircle(start, u * 0.15, Paint()..color = Colors.white.withValues(alpha: 0.7));
    canvas.drawCircle(start, u * 0.15, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.03..color = kInk);
    if (ringK > 0) {
      final ring = u * (0.15 + 0.45 * ringK);
      canvas.drawCircle(start, ring, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.075..color = kInk);
      canvas.drawCircle(start, ring, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.045..color = accent);
    }
    final dot = Offset.lerp(start, end, travel)!;
    canvas.drawCircle(dot, u * 0.1, Paint()..color = accent);
    canvas.drawCircle(dot, u * 0.1, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.03..color = kInk);
    _sticker(canvas, '막아!', Offset(x + u * 0.62, (startY + endY) / 2), u * 0.2, const Color(0xFFFFC38A));
  }

  /// 보스가 힘을 모으는 동안 화면 가장자리가 붉게 달아오르고, 하트를 잃으면 한 번 번쩍인다.
  void _drawBossWarning(Canvas canvas, Size size, double t, double idle) {
    final st = c.bossState(t);
    var a = 0.0;
    if (st.phase == BossPhase.windup) {
      a = (0.12 + 0.3 * st.progress) * (0.75 + 0.25 * sin(idle * 14));
    } else if (st.phase == BossPhase.lunge) {
      a = 0.5;
    }
    if (a > 0.01) {
      final w = size.width * 0.28;
      for (final left in [true, false]) {
        final rect = Rect.fromLTWH(left ? 0 : size.width - w, 0, w, size.height);
        canvas.drawRect(
          rect,
          Paint()
            ..shader = LinearGradient(
              begin: left ? Alignment.centerLeft : Alignment.centerRight,
              end: left ? Alignment.centerRight : Alignment.centerLeft,
              colors: [const Color(0xFFFF2D3D).withValues(alpha: a), const Color(0x00FF2D3D)],
            ).createShader(rect),
        );
      }
    }
    final lost = t - c.heartLostAt;
    if (lost >= 0 && lost < 0.3) {
      canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFF2D3D).withValues(alpha: 0.28 * (1 - lost / 0.3)));
    }
  }

  // ── 화면 가장자리 빛: 탭할 쪽 알려주기 ──
  void _drawEdgeGlow(Canvas canvas, Size size, double remain, Side side) {
    final a = (1 - remain.clamp(0.0, 1.0)) * 0.5;
    if (a <= 0.02) return;
    final w = size.width * 0.3;
    final isLeft = side == Side.left;
    final rect = Rect.fromLTWH(isLeft ? 0 : size.width - w, 0, w, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: isLeft ? Alignment.centerLeft : Alignment.centerRight,
          end: isLeft ? Alignment.centerRight : Alignment.centerLeft,
          colors: [Colors.white.withValues(alpha: a), Colors.white.withValues(alpha: 0)],
        ).createShader(rect),
    );
  }

  // ── 안내 링: 실제로 엄지가 닿을 화면 양옆 아래쪽에서 줄어든다 ──
  void _drawRing(Canvas canvas, CampLayout L, CueInfo cue) {
    final size = L.size;
    final pt = Offset(size.width * (cue.side == Side.left ? 0.12 : 0.88), size.height * (L.landscape ? 0.74 : 0.78));
    final u = L.unit;
    final r = cue.remain.clamp(0.0, 1.0);
    final ring = u * (0.2 + 0.45 * r);
    // 꾹 누르기: 누를 때는 금색, 떼야 할 때는 주황색 링
    final ringColor = cue.releasing ? const Color(0xFFFF7A2F) : _gold;
    final centerColor = cue.releasing ? const Color(0xFFFF4D5E) : (cue.isHold ? const Color(0xFF5AA7FF) : const Color(0xFFFF4D5E));
    canvas.drawCircle(pt, u * 0.2, Paint()..color = Colors.white.withValues(alpha: 0.6));
    canvas.drawCircle(pt, u * 0.2, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.035..color = kInk);
    canvas.drawCircle(pt, u * 0.08, Paint()..color = centerColor);
    canvas.drawCircle(pt, u * 0.08, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.025..color = kInk);
    canvas.drawCircle(pt, ring, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.075..color = kInk);
    canvas.drawCircle(pt, ring, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.045..color = ringColor);
    if (cue.isHold) {
      _sticker(canvas, cue.releasing ? '떼!' : '꾹', pt + Offset(0, -u * 0.42), u * 0.17, cue.releasing ? const Color(0xFFFF9A4D) : const Color(0xFF9CCBFF));
    }
  }

  // ── 옆으로 긋기 안내: 시작점에서 링이 줄어든 뒤, 구슬이 화살표를 따라 달려가 끝에 닿는 순간이 박자 ──
  void _drawSwipeGuide(Canvas canvas, CampLayout L, CueInfo cue) {
    final size = L.size;
    final u = L.unit;
    final y = size.height * (L.landscape ? 0.74 : 0.78);
    final toRight = cue.side == Side.right;
    final startX = size.width * (toRight ? 0.2 : 0.8);
    final endX = size.width * (toRight ? 0.8 : 0.2);
    final dirX = toRight ? 1.0 : -1.0;
    final start = Offset(startX, y);
    final end = Offset(endX, y);

    // 화살표 띠: 바깥 검은 선 + 안쪽 흰 선 + 끝의 화살촉
    final head = u * 0.16;
    final bodyEnd = Offset(endX - dirX * head * 0.7, y);
    final band = Path()..moveTo(startX, y)..lineTo(bodyEnd.dx, y);
    final tip = Path()
      ..moveTo(endX, y)
      ..lineTo(endX - dirX * head, y - head * 0.7)
      ..lineTo(endX - dirX * head, y + head * 0.7)
      ..close();
    canvas.drawPath(band, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.115..strokeCap = StrokeCap.round..color = kInk);
    canvas.drawPath(tip, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.07..strokeJoin = StrokeJoin.round..color = kInk);
    canvas.drawPath(band, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.07..strokeCap = StrokeCap.round..color = Colors.white.withValues(alpha: 0.85));
    canvas.drawPath(tip, Paint()..color = Colors.white.withValues(alpha: 0.85));

    // 시작점 + 줄어드는 링 (remain 1 → 0.35), 그 뒤 구슬이 끝까지 달린다 (0.35 → 0)
    const run = 0.35;
    final ringK = ((cue.remain - run) / (1 - run)).clamp(0.0, 1.0);
    final travel = Curves.easeIn.transform((1 - cue.remain / run).clamp(0.0, 1.0));
    canvas.drawCircle(start, u * 0.15, Paint()..color = Colors.white.withValues(alpha: 0.7));
    canvas.drawCircle(start, u * 0.15, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.03..color = kInk);
    if (ringK > 0) {
      final ring = u * (0.15 + 0.45 * ringK);
      canvas.drawCircle(start, ring, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.075..color = kInk);
      canvas.drawCircle(start, ring, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.045..color = const Color(0xFF5AD7FF));
    }
    final dot = Offset.lerp(start, end, travel)!;
    canvas.drawCircle(dot, u * 0.1, Paint()..color = const Color(0xFF5AD7FF));
    canvas.drawCircle(dot, u * 0.1, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.03..color = kInk);
    _sticker(canvas, '쓱!', Offset(size.width * 0.5, y - u * 0.34), u * 0.17, const Color(0xFF8BE3FF));
  }

  // ── 힘 모으기: 칼끝에 에너지 구슬이 커지고, 빛 알갱이가 빨려 든다 ──
  void _drawCharge(Canvas canvas, CampLayout L, int actor, Offset foot, bool mirror, double charge, double idle) {
    final name = RhythmArt.actorSprite(actor, 'windup');
    final info = art.info(name);
    if (info == null || info.tipX == null || info.tipY == null) return;
    final sc = L.charScale * info.scale;
    var dx = (info.tipX! - info.footX) * sc;
    final dy = (info.tipY! - info.footY) * sc;
    if (mirror) dx = -dx;
    final tip = foot + Offset(dx, dy);
    final u = L.unit;
    final ready = charge >= 0.98;
    final pulse = ready ? 1 + 0.15 * sin(idle * 30) : 1.0;
    final r = u * (0.04 + 0.11 * charge) * pulse;
    // 바깥 빛무리
    canvas.drawCircle(tip, r * 2.2, Paint()..color = _gold.withValues(alpha: 0.28 + 0.2 * charge));
    canvas.drawCircle(tip, r * 1.4, Paint()..color = _gold.withValues(alpha: 0.55));
    canvas.drawCircle(tip, r, Paint()..color = Colors.white);
    canvas.drawCircle(tip, r, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.02..color = kInk);
    // 빨려 드는 알갱이
    for (var k = 0; k < 8; k++) {
      final f = (idle * 1.4 + k / 8) % 1.0;
      final a = k * pi / 4 + idle * 2;
      final dist = u * 0.38 * (1 - f) + r * 0.6;
      final pos = tip + Offset(cos(a) * dist, sin(a) * dist);
      final sz = u * 0.018 * (0.4 + f);
      canvas.drawCircle(pos, sz, Paint()..color = (k.isEven ? Colors.white : _gold).withValues(alpha: 0.4 + 0.6 * f));
    }
    if (ready) {
      canvas.drawCircle(tip, r * 2.6, Paint()..style = PaintingStyle.stroke..strokeWidth = u * 0.025..color = Colors.white.withValues(alpha: 0.7));
    }
  }

  // ── 판정 글자: 스티커처럼 통통 튀며 떠오른다 ──
  void _drawPop(Canvas canvas, CampLayout L, RatingPop p, double t) {
    final age = t - p.at;
    if (age < 0 || age > 1.0) return;
    final k = age / 1.0;
    final u = L.unit;
    final (word, color) = switch (p.rating) {
      Rating.perfect => (p.guard ? '완벽 방어!' : '완벽!', _gold),
      Rating.good => (p.guard ? '막았다!' : '좋아요', const Color(0xFF8CFF9E)),
      Rating.miss => (p.guard ? '당했다!' : '놓쳤어요', p.guard ? const Color(0xFFFF8A8A) : const Color(0xFFE0E0E0)),
      Rating.wrongSide => ('반대쪽!', const Color(0xFFFF6B6B)),
      Rating.stray => ('앗!', const Color(0xFFE0E0E0)),
      Rating.holdStart => ('', _gold),
    };
    final pop = k < 0.16 ? 0.5 + 0.7 * Curves.easeOutBack.transform(k / 0.16) : 1.2 - 0.2 * ((k - 0.16) / 0.84).clamp(0.0, 1.0);
    final alpha = k < 0.7 ? 1.0 : 1 - (k - 0.7) / 0.3;
    final center = Offset(L.actorX(3), L.feetY - u * (1.12 + 0.1 * k));
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate((p.side == Side.left ? -1 : 1) * 0.05);
    _sticker(canvas, word, Offset.zero, u * 0.22 * pop, color, alpha: alpha);
    canvas.restore();
  }

  /// 두꺼운 검은 외곽선 + 그림자 + 쨍한 색 글자.
  void _sticker(Canvas canvas, String s, Offset center, double size, Color color, {double alpha = 1}) {
    TextPainter make(Paint? stroke, Color? fill) => TextPainter(
          text: TextSpan(
            text: s,
            style: TextStyle(
              fontFamily: 'NanumGothic',
              fontSize: size,
              fontWeight: FontWeight.w900,
              height: 1.0,
              foreground: stroke,
              color: fill,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
    final outline = make(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.24
        ..strokeJoin = StrokeJoin.round
        ..color = kInk.withValues(alpha: alpha),
      null,
    );
    final shadow = make(
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.24
        ..strokeJoin = StrokeJoin.round
        ..color = Colors.black.withValues(alpha: 0.28 * alpha),
      null,
    );
    final fill = make(null, color.withValues(alpha: color.a * alpha));
    final o = center - Offset(outline.width / 2, outline.height / 2);
    shadow.paint(canvas, o + Offset(size * 0.05, size * 0.09));
    outline.paint(canvas, o);
    fill.paint(canvas, center - Offset(fill.width / 2, fill.height / 2));
  }

  @override
  bool shouldRepaint(StagePainter old) => true;
}
