import 'package:flutter/material.dart';

import '../core/rummikub_rules.dart';

/// 루미큐브 게임 색 (허브 카드 색).
const Color kRkWood = Color(0xFF8D5A2B);

/// 타일 색 4가지: 검정, 파랑, 빨강, 주황.
const List<Color> kRkColors = [Color(0xFF263238), Color(0xFF1E63C6), Color(0xFFD32F2F), Color(0xFFEF8A17)];
const List<String> kRkColorNames = ['검정', '파랑', '빨강', '주황'];

/// 색을 모양으로도 알아볼 수 있게 숫자 밑에 붙이는 작은 표시.
const List<String> kRkMarks = ['●', '■', '▲', '◆'];

const Color kRkJokerColor = Color(0xFF7B3FA0);

/// 타일 한 장. 가로 [width], 세로는 그 1.35배.
///
/// [selected]면 위로 살짝 들리고 테두리가 차분한 갈색으로 진해지고, [glow]이면 (방금 뽑았거나 방금 놓은 타일) 옅은 금색 테두리가 보인다.
/// (눈이 부시지 않게 밝은 노랑이나 번쩍이는 그림자는 쓰지 않는다.)
class RkTile extends StatelessWidget {
  const RkTile({
    super.key,
    required this.id,
    this.width = 40,
    this.selected = false,
    this.glow = false,
    this.dim = false,
    this.onTap,
  });

  final int id;
  final double width;
  final bool selected;
  final bool glow;
  final bool dim;
  final VoidCallback? onTap;

  double get height => width * 1.35;

  @override
  Widget build(BuildContext context) {
    final joker = isJoker(id);
    final color = joker ? kRkJokerColor : kRkColors[colorOf(id)];
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: width,
      height: height,
      transform: Matrix4.translationValues(0, selected ? -width * 0.14 : 0, 0),
      decoration: BoxDecoration(
        color: dim ? const Color(0xFFD9D2C0) : const Color(0xFFFFF8E6),
        borderRadius: BorderRadius.circular(width * 0.16),
        border: Border.all(
          color: selected ? const Color(0xFF8D5A2B) : (glow ? const Color(0xFFCDA85A) : const Color(0xFFB9AD92)),
          width: selected ? 2 : (glow ? 1.8 : 1),
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: selected ? 0.28 : 0.22), blurRadius: selected ? 4 : 2, offset: Offset(0, selected ? 3 : 1.5)),
        ],
      ),
      child: Center(
        child: joker
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sentiment_very_satisfied_rounded, size: width * 0.62, color: color),
                  Text('조커', style: TextStyle(fontSize: width * 0.22, fontWeight: FontWeight.w900, color: color, height: 1.0)),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${numberOf(id)}',
                    style: TextStyle(fontSize: width * 0.62, fontWeight: FontWeight.w900, color: color, height: 1.0),
                  ),
                  Text(kRkMarks[colorOf(id)], style: TextStyle(fontSize: width * 0.3, color: color, height: 1.1)),
                ],
              ),
      ),
    );
    return Semantics(
      label: joker ? '조커 타일' : '${kRkColorNames[colorOf(id)]} ${numberOf(id)}',
      button: onTap != null,
      selected: selected,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: tile),
    );
  }
}

/// 바닥에 엎어 둔 타일 (뒷면). 누르면 뽑을 수 있을 때는 [active]로 살짝 반짝인다.
class RkTileBack extends StatelessWidget {
  const RkTileBack({super.key, this.width = 24, this.glow = false, this.active = false});

  final double width;

  /// 상대가 고르는 중이라 들어 올려 빛나는 타일.
  final bool glow;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: width * 1.35,
      decoration: BoxDecoration(
        color: const Color(0xFFC9A45C),
        borderRadius: BorderRadius.circular(width * 0.16),
        border: Border.all(color: glow ? const Color(0xFF8D5A2B) : (active ? const Color(0xFF8D5A2B) : const Color(0xFF9A7A3E)), width: glow ? 2 : 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: glow ? 5 : 2, offset: const Offset(0, 1.5)),
        ],
      ),
      child: Center(
        child: Container(
          width: width * 0.5,
          height: width * 0.5,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF8D5A2B).withValues(alpha: 0.6), width: 1.2)),
        ),
      ),
    );
  }
}
