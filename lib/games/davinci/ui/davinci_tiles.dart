import 'package:flutter/material.dart';

import '../core/davinci_rules.dart';

/// 게임 색 (허브 카드 색).
const Color kDavinciColor = Color(0xFF607D8B);

const Color _blackTile = Color(0xFF2A2D32);
const Color _whiteTile = Color(0xFFF6F1E4);

/// 다빈치 코드 타일 한 장.
///
/// 실제 게임처럼 **숨은 타일은 세워져 있고, 공개된 타일은 눕혀져 있다** ([lying]). 눕힌 타일은 낮고 넓게, 숫자가 위로 보이게 그려서
/// 한눈에 구별된다. (내 줄에서도, 상대 줄에서도 같다)
///
///  - [faceUp]: 숫자가 보인다 (내 타일, 공개된 타일). 아니면 뒷면(색만 보인다) — 남의 숨은 타일.
///  - [lying]: 공개되어 눕혀진 타일.
///  - [selected]: 맞히려고 고른 타일 (위로 들리고 테두리가 진해진다).
///  - [lifted]: 상대가 맞히려고 고른 타일 (살짝 떠오른다).
///  - [mark]: 맞히기 결과 표시 (true ○ / false ✕ / null 없음).
///  - [fresh]: 방금 뽑은 타일 (작은 별 표시).
class DvTile extends StatelessWidget {
  const DvTile({
    super.key,
    required this.id,
    this.width = 38,
    this.faceUp = false,
    this.lying = false,
    this.selected = false,
    this.lifted = false,
    this.mark,
    this.fresh = false,
    this.onTap,
  });

  final int id;
  final double width;
  final bool faceUp;
  final bool lying;
  final bool selected;
  final bool lifted;
  final bool? mark;
  final bool fresh;
  final VoidCallback? onTap;

  /// 세워진 타일의 높이와 눕힌 타일의 높이.
  double get standHeight => width * 1.4;
  double get lieHeight => width * 0.82;

  @override
  Widget build(BuildContext context) {
    final black = dvColor(id) == 0;
    final bg = black ? _blackTile : _whiteTile;
    final fg = black ? Colors.white : const Color(0xFF2A2D32);
    final joker = dvIsJoker(id);
    var border = black ? const Color(0xFF5A5F68) : const Color(0xFFBDB29A);
    var borderWidth = 1.2;
    if (selected) {
      border = const Color(0xFF5B8DEF);
      borderWidth = 2.6;
    } else if (lifted) {
      border = const Color(0xFFE0A100);
      borderWidth = 2.4;
    }
    final label = joker ? '‑' : '${dvNumber(id)}';
    final shown = faceUp || lying;
    final dy = selected ? -width * 0.14 : (lifted ? -width * 0.32 : 0.0);

    final face = Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        if (shown)
          // 두 자리 숫자(10, 11)가 타일 폭에 안 들어가도 줄이 바뀌지 않게, 한 줄로 두고 넘치면 글자를 줄여 맞춘다
          SizedBox(
            width: width * 0.86,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(fontSize: width * (joker ? 0.9 : (lying ? 0.58 : 0.66)), fontWeight: FontWeight.w900, color: fg, height: 1.0),
              ),
            ),
          )
        else
          // 뒷면: 색은 보이고 숫자는 안 보인다. 실제 게임처럼 연한 부등호(≤)로 "왼쪽이 작거나 같은 수, 오른쪽이 큰 수"임을 알려 준다
          CustomPaint(size: Size(width * 0.46, width * 0.56), painter: _LessOrEqualPainter(fg.withValues(alpha: 0.3))),
        if (fresh)
          Positioned(top: 1, right: 2, child: Icon(Icons.star_rounded, size: width * 0.3, color: const Color(0xFFE0A100))),
        if (mark != null)
          Positioned(
            top: -width * 0.55,
            child: Container(
              width: width * 0.62,
              height: width * 0.62,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: mark! ? const Color(0xFF2E9E4F) : const Color(0xFFD64545), width: 2.4),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 3)],
              ),
              child: Icon(mark! ? Icons.circle_outlined : Icons.close_rounded, size: width * 0.42, color: mark! ? const Color(0xFF2E9E4F) : const Color(0xFFD64545)),
            ),
          ),
      ],
    );

    // 세워진 타일은 키가 크고 밑동이 두껍게(받침 그림자), 눕힌 타일은 낮고 평평하게 보인다
    final height = lying ? lieHeight : standHeight;
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeInOutCubic,
      width: width,
      height: height,
      transform: Matrix4.translationValues(0, dy, 0),
      decoration: BoxDecoration(
        color: lying ? Color.lerp(bg, Colors.grey, 0.12) : bg,
        borderRadius: BorderRadius.circular(width * (lying ? 0.16 : 0.14)),
        border: Border.all(color: border, width: borderWidth),
        boxShadow: [
          if (!lying) BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 0, offset: Offset(0, width * 0.1)), // 세워진 두께
          BoxShadow(color: Colors.black.withValues(alpha: (selected || lifted) ? 0.3 : 0.18), blurRadius: (selected || lifted) ? 6 : 2, offset: Offset(0, (selected || lifted) ? 4 : 1.5)),
        ],
      ),
      child: face,
    );
    return Semantics(
      label: '${black ? '검정' : '흰색'} ${shown ? (joker ? '조커' : '${dvNumber(id)}') : '숨은 타일'}${lying ? ' (공개됨)' : ''}',
      button: onTap != null,
      selected: selected,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: tile),
    );
  }
}

/// 타일 뒷면의 부등호(≤). 같은 숫자(검정·흰색)도 있으니 등호까지 넣는다. 글꼴에 따라 위치가 달라지지 않게 직접 그린다.
class _LessOrEqualPainter extends CustomPainter {
  const _LessOrEqualPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.15
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(w * 0.78, h * 0.1)
        ..lineTo(w * 0.22, h * 0.4)
        ..lineTo(w * 0.78, h * 0.7)
        ..moveTo(w * 0.22, h * 0.92)
        ..lineTo(w * 0.78, h * 0.92),
      paint,
    );
  }

  @override
  bool shouldRepaint(_LessOrEqualPainter old) => old.color != color;
}

/// 말풍선: 상대가 하는 말("7?")과 결과(○ / ✕)를 보여 준다.
class DvBubble extends StatelessWidget {
  const DvBubble({super.key, required this.text, this.result});

  final String text;

  /// 결과: true ○ / false ✕ / null 아직 모름.
  final bool? result;

  @override
  Widget build(BuildContext context) {
    final ok = result == true;
    final color = result == null ? kDavinciColor : (ok ? const Color(0xFF2E9E4F) : const Color(0xFFD64545));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color, width: 1.8),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(text, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: color)),
          if (result != null) ...[
            const SizedBox(width: 4),
            Icon(ok ? Icons.circle_outlined : Icons.close_rounded, size: 18, color: color),
          ],
        ],
      ),
    );
  }
}

/// 더미(바닥에 엎어 둔 타일 더미) 한 색의 모습: 타일 몇 장이 포개진 그림 + 남은 장수.
class DvPile extends StatelessWidget {
  const DvPile({super.key, required this.color, required this.count, this.width = 40});

  final int color;
  final int count;
  final double width;

  @override
  Widget build(BuildContext context) {
    final black = color == 0;
    final bg = black ? _blackTile : _whiteTile;
    final border = black ? const Color(0xFF5A5F68) : const Color(0xFFBDB29A);
    final layers = count.clamp(0, 4);
    return SizedBox(
      width: width + 10,
      height: width * 1.4 + 10,
      child: Stack(
        children: [
          for (var i = 0; i < layers; i++)
            Positioned(
              left: i * 2.5,
              top: (layers - 1 - i) * 2.5,
              child: Container(
                width: width,
                height: width * 1.4,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(width * 0.14),
                  border: Border.all(color: border, width: 1.2),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 2, offset: const Offset(0, 1.5))],
                ),
                child: i == layers - 1 ? Center(child: Text('$count', style: TextStyle(fontSize: width * 0.5, fontWeight: FontWeight.w900, color: black ? Colors.white : const Color(0xFF2A2D32)))) : null,
              ),
            ),
          if (layers == 0)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(width * 0.14), border: Border.all(color: border.withValues(alpha: 0.5), width: 1.5)),
                child: Center(child: Text('0', style: TextStyle(color: border, fontWeight: FontWeight.w800))),
              ),
            ),
        ],
      ),
    );
  }
}
