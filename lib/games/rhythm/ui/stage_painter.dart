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
  StagePainter(this.c, {required this.art, required this.clock, required this.wall, this.foe = Foe.dummy}) : super(repaint: c);

  final RhythmController c;
  final RhythmArt art;

  /// 검사들 앞에 선 상대.
  final Foe foe;

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

    // ── 허수아비 / 슬라임 ──
    for (var i = 0; i < 4; i++) {
      if (foe == Foe.slime) {
        _drawSlime(canvas, L, i, c.swing(i, t), t, idle);
      } else {
        _drawDummy(canvas, L, i, c.swing(i, t));
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
        if (swing.swipe) {
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
      drawSprite(canvas, art, RhythmArt.actorSprite(i, kind), foot, L.charScale,
          mirror: mirror, squashX: squashX, squashY: squashY, rotate: rotate, paint: Paint()..filterQuality = FilterQuality.high);
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

    if (cue != null) cue.isSwipe ? _drawSwipeGuide(canvas, L, cue) : _drawRing(canvas, L, cue);
    for (final p in c.pops) {
      _drawPop(canvas, L, p, t);
    }
    canvas.restore();

    if (cue != null && !cue.isSwipe) _drawEdgeGlow(canvas, size, cue.remain, cue.side);
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
  void _drawSlime(Canvas canvas, CampLayout L, int i, SwingState? sw, double t, double idle) {
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
    drawSprite(canvas, art, RhythmArt.slimeSprite(kind), base + offset, scale,
        mirror: mirror, squashX: squashX, squashY: squashY, rotate: rotate, paint: paint);

    if (kind != 'hit' || sw == null || sw.sinceImpact > 0.5) return;
    _drawSlash(canvas, L, base, dir, centerY, L.unit * 0.18, sw.sinceImpact);
    _drawDebris(canvas, L, i, sw, Offset(base.dx + dir * L.unit * 0.18, centerY),
        colors: const [Color(0xFF63B6FA), Color(0xFFBFE3FF)], count: 6, round: true);
  }

  /// 칼바람: 검사 쪽에서 맞는 자리로 날아가는 흰 줄.
  void _drawSlash(Canvas canvas, CampLayout L, Offset base, double dir, double centerY, double reach, double s) {
    if (s >= 0.1) return;
    final k = s / 0.1;
    final from = Offset(base.dx + dir * L.unit * 0.1, L.feetY - L.unit * 0.25);
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
      Rating.perfect => ('완벽!', _gold),
      Rating.good => ('좋아요', const Color(0xFF8CFF9E)),
      Rating.miss => ('놓쳤어요', const Color(0xFFE0E0E0)),
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
