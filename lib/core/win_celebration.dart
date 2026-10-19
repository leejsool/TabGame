import 'dart:math';

import 'package:flutter/material.dart';


/// 이겼을 때(또는 퍼즐을 풀었을 때) 모든 게임이 같이 쓰는 축하 연출: 화면 위에서 색종이와 별이 쏟아지고, 가운데에 "승리!" 현판이 튀어 오른다.
///
/// 눌림을 막지 않는다. 화면 어디든 닿으면 바로 사라지고(눌린 것은 그대로 아래로 전해진다), 저절로 끝나도 [onDone]을 부른다.
class WinCelebration extends StatefulWidget {
  const WinCelebration({super.key, this.title = '승리!', this.subtitle, this.onDone});

  final String title;
  final String? subtitle;
  final VoidCallback? onDone;

  @override
  State<WinCelebration> createState() => _WinCelebrationState();
}

class _WinCelebrationState extends State<WinCelebration> with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 5200);
  late final AnimationController _c = AnimationController(vsync: this, duration: _duration)
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) _finish();
    })
    ..forward();
  bool _closed = false;

  /// 끝났다고 한 번만 알린다 (저절로 끝났거나 눌려서 끝났거나).
  void _finish() {
    if (_closed) return;
    _closed = true;
    widget.onDone?.call();
  }
  late final List<_Piece> _pieces = _makePieces(Random(7));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  static List<_Piece> _makePieces(Random rng) {
    const colors = [Color(0xFF1E63C6), Color(0xFFD32F2F), Color(0xFFEF8A17), Color(0xFF263238), Color(0xFFFFC83D), Color(0xFFFF6FB5), Color(0xFF7BE0C3)];
    return [
      for (var i = 0; i < 150; i++)
        _Piece(
          x: rng.nextDouble(),
          delay: rng.nextDouble() * 0.55, // 터지듯 차례로 쏟아진다
          speed: 0.55 + rng.nextDouble() * 0.6,
          sway: 0.02 + rng.nextDouble() * 0.05,
          phase: rng.nextDouble() * pi * 2,
          spin: (rng.nextDouble() - 0.5) * 14,
          size: 6 + rng.nextDouble() * 8,
          color: colors[rng.nextInt(colors.length)],
          star: rng.nextInt(7) == 0,
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _finish(),
      child: IgnorePointer(
      child: Material(
        type: MaterialType.transparency, // (글꼴·글자 스타일을 화면의 테마대로 받으려고)
        child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          // 현판: 0~0.12 튀어 오르며 나타나고, 0.8 이후 사라진다
          final pop = Curves.elasticOut.transform((t / 0.16).clamp(0.0, 1.0));
          final fade = t < 0.78 ? 1.0 : (1 - (t - 0.78) / 0.22).clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _ConfettiPainter(_pieces, t)),
              Center(
                child: Opacity(
                  opacity: fade,
                  child: Transform.scale(
                    scale: 0.3 + 0.7 * pop,
                    child: Transform.rotate(
                      angle: -0.06 * (1 - pop) + sin(t * 9) * 0.015,
                      child: _Banner(title: widget.title, subtitle: widget.subtitle, shine: t),
                    ),
                  ),
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

class _Banner extends StatelessWidget {
  const _Banner({required this.title, required this.subtitle, required this.shine});

  final String title;
  final String? subtitle;
  final double shine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFE08A), Color(0xFFF2A900), Color(0xFFFFD35C)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [
          BoxShadow(color: const Color(0xFFF2A900).withValues(alpha: 0.55 + 0.25 * sin(shine * 20)), blurRadius: 28, spreadRadius: 4),
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🏆', style: TextStyle(fontSize: 44)),
          Text(
            title,
            style: const TextStyle(
              fontSize: 40,
              fontWeight: FontWeight.w900,
              color: Color(0xFF5A3A12),
              height: 1.1,
              shadows: [Shadow(color: Colors.white, blurRadius: 6)],
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF5A3A12))),
          ],
        ],
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.x,
    required this.delay,
    required this.speed,
    required this.sway,
    required this.phase,
    required this.spin,
    required this.size,
    required this.color,
    required this.star,
  });

  final double x, delay, speed, sway, phase, spin, size;
  final Color color;
  final bool star;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in pieces) {
      final local = (t - p.delay) / (1 - p.delay);
      if (local <= 0) continue;
      final fall = local * p.speed * 1.5; // 1.0 = 화면 높이
      final y = -20 + fall * (size.height + 40);
      if (y > size.height + 20) continue;
      final x = (p.x + sin(local * 7 + p.phase) * p.sway) * size.width;
      final fadeOut = local > 0.85 ? (1 - (local - 0.85) / 0.15).clamp(0.0, 1.0) : 1.0;
      final paint = Paint()..color = p.color.withValues(alpha: fadeOut);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * local);
      if (p.star) {
        _star(canvas, p.size * 0.9, paint);
      } else {
        // 팔랑팔랑 뒤집히는 색종이
        canvas.scale(1, 0.35 + 0.65 * cos(local * 10 + p.phase).abs());
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), const Radius.circular(1.5)), paint);
      }
      canvas.restore();
    }
  }

  void _star(Canvas canvas, double r, Paint paint) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final rad = i.isEven ? r : r * 0.45;
      final a = -pi / 2 + i * pi / 5;
      final pt = Offset(cos(a) * rad, sin(a) * rad);
      i == 0 ? path.moveTo(pt.dx, pt.dy) : path.lineTo(pt.dx, pt.dy);
    }
    canvas.drawPath(path..close(), paint);
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

OverlayEntry? _shown;

/// 지금 화면 위에 축하 연출을 한 번 띄운다. 끝나면 저절로 사라지고, 눌림을 막지 않는다.
///
/// 이긴 순간에 `WinSound.play(context)`와 함께 부른다. 이미 떠 있으면 새로 띄우지 않는다.
/// (카드 게임·루미큐브·콩나물·지뢰찾기는 자기 연출이 있어 부르지 않는다.)
void showWinCelebration(BuildContext context, {String title = '승리!', String? subtitle}) {
  if (_shown != null) return;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  void remove() {
    if (_shown == entry) _shown = null;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (_) => Positioned.fill(
      child: WinCelebration(key: const ValueKey('win-celebration'), title: title, subtitle: subtitle, onDone: remove),
    ),
  );
  _shown = entry;
  overlay.insert(entry);
}
