import 'package:flutter/material.dart';

/// 야추의 대표 색 (주사위 판의 초록 천).
const Color kYachtColor = Color(0xFF2D7D5A);

/// 자리(0~3)별 색.
const List<Color> kYachtSeatColors = [Color(0xFFD1495B), Color(0xFF3F7CAC), Color(0xFFD98A1F), Color(0xFF7B5EA7)];

/// 주사위의 색.
const Color kYachtDieBody = Color(0xFFFDFBF5);
const Color kYachtDiePip = Color(0xFF26222E);
const Color kYachtDieOne = Color(0xFFD1495B);

/// 눈의 자리 (3 x 3 칸의 번호: 0 1 2 / 3 4 5 / 6 7 8).
const List<List<int>> kYachtPips = [
  <int>[],
  [4],
  [2, 6],
  [2, 4, 6],
  [0, 2, 6, 8],
  [0, 2, 4, 6, 8],
  [0, 2, 3, 5, 6, 8],
];

/// 멈춰 있는 주사위 하나 (위에서 본 모습). [value]가 0이면 아직 안 굴린 빈 주사위.
class YachtDie extends StatelessWidget {
  const YachtDie({super.key, required this.value, this.size = 56, this.held = false, this.accent = kYachtColor});

  final int value;
  final double size;

  /// 잡아 둔 주사위면 테두리가 [accent] 색으로 굵어진다.
  final bool held;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size.square(size), painter: _DiePainter(value, held, accent));
  }
}

class _DiePainter extends CustomPainter {
  _DiePainter(this.value, this.held, this.accent);

  final int value;
  final bool held;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(s * 0.04, s * 0.04, s * 0.92, s * 0.92), Radius.circular(s * 0.2));
    final blank = value == 0;
    canvas.drawRRect(body.shift(Offset(0, s * 0.04)), Paint()..color = Colors.black.withValues(alpha: blank ? 0.06 : 0.22));
    canvas.drawRRect(body, Paint()..color = blank ? const Color(0x33FFFFFF) : (held ? Color.lerp(Colors.white, accent, 0.14)! : kYachtDieBody));
    canvas.drawRRect(
      body,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = held ? s * 0.07 : s * 0.03
        ..color = held ? accent : Colors.black.withValues(alpha: blank ? 0.18 : 0.3),
    );
    if (blank) return;
    final pip = Paint()..color = value == 1 ? kYachtDieOne : kYachtDiePip;
    final r = value == 1 ? s * 0.13 : s * 0.085;
    for (final i in kYachtPips[value]) {
      canvas.drawCircle(Offset(s * (0.27 + 0.23 * (i % 3)), s * (0.27 + 0.23 * (i ~/ 3))), r, pip);
    }
  }

  @override
  bool shouldRepaint(_DiePainter old) => old.value != value || old.held != held || old.accent != accent;
}

/// 주사위를 눈이 작은 것부터 왼쪽에서 오른쪽으로 놓는 순서 (눈이 같으면 원래 순서). 게임 화면의 주사위 줄 · 힌트 창이 똑같이 쓴다.
List<int> yachtSortedOrder(List<int> dice) {
  return [for (var i = 0; i < dice.length; i++) i]..sort((a, b) {
      final c = dice[a].compareTo(dice[b]);
      return c != 0 ? c : a.compareTo(b);
    });
}
