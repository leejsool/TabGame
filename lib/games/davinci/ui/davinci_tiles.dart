import 'package:flutter/material.dart';

import '../core/davinci_rules.dart';

/// 게임 색 (허브 카드 색).
const Color kDavinciColor = Color(0xFF607D8B);

const Color _blackTile = Color(0xFF2A2D32);
const Color _whiteTile = Color(0xFFF6F1E4);

/// 다빈치 코드 타일 한 장.
///
///  - [faceUp]: 숫자가 보인다 (내 타일, 공개된 타일). 아니면 뒷면(색만 보인다) — 남의 숨은 타일.
///  - [revealed]: 이미 공개된 타일이라는 표시 (내 줄에서 내 타일 중 남들에게 공개된 것을 구별하려고 테두리를 바꾼다).
///  - [selected]: 맞히려고 고른 타일 (위로 들리고 테두리가 진해진다).
///  - [mark]: 방금 맞히기의 결과 표시 (true 맞혔다 / false 틀렸다 / null 없음).
///  - [fresh]: 방금 뽑은 타일 (작은 별 표시).
class DvTile extends StatelessWidget {
  const DvTile({
    super.key,
    required this.id,
    this.width = 38,
    this.faceUp = false,
    this.revealed = false,
    this.selected = false,
    this.mark,
    this.fresh = false,
    this.onTap,
  });

  final int id;
  final double width;
  final bool faceUp;
  final bool revealed;
  final bool selected;
  final bool? mark;
  final bool fresh;
  final VoidCallback? onTap;

  double get height => width * 1.4;

  @override
  Widget build(BuildContext context) {
    final black = dvColor(id) == 0;
    final bg = black ? _blackTile : _whiteTile;
    final fg = black ? Colors.white : const Color(0xFF2A2D32);
    final joker = dvIsJoker(id);
    Color border = black ? const Color(0xFF5A5F68) : const Color(0xFFBDB29A);
    var borderWidth = 1.2;
    if (revealed) {
      border = const Color(0xFFC0742A);
      borderWidth = 2;
    }
    if (mark != null) {
      border = mark! ? const Color(0xFF2E9E4F) : const Color(0xFFD64545);
      borderWidth = 2.6;
    }
    if (selected) {
      border = const Color(0xFF5B8DEF);
      borderWidth = 2.6;
    }
    final label = joker ? '‑' : '${dvNumber(id)}';

    final face = Stack(
      alignment: Alignment.center,
      children: [
        if (faceUp)
          Text(label, style: TextStyle(fontSize: width * (joker ? 0.9 : 0.66), fontWeight: FontWeight.w900, color: fg, height: 1.0))
        else
          // 뒷면: 색은 보이고 숫자는 안 보인다
          Icon(Icons.help_outline_rounded, size: width * 0.5, color: fg.withValues(alpha: 0.28)),
        if (revealed && faceUp)
          Positioned(
            bottom: width * 0.08,
            child: Container(width: width * 0.5, height: 3, decoration: BoxDecoration(color: const Color(0xFFC0742A), borderRadius: BorderRadius.circular(2))),
          ),
        if (fresh)
          Positioned(top: 1, right: 2, child: Icon(Icons.star_rounded, size: width * 0.3, color: const Color(0xFFE0A100))),
      ],
    );

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      width: width,
      height: height,
      transform: Matrix4.translationValues(0, selected ? -width * 0.14 : 0, 0),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(width * 0.14),
        border: Border.all(color: border, width: borderWidth),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: selected ? 0.3 : 0.2), blurRadius: selected ? 4 : 2, offset: Offset(0, selected ? 3 : 1.5))],
      ),
      child: face,
    );
    return Semantics(
      label: '${black ? '검정' : '흰색'} ${faceUp ? (joker ? '조커' : '${dvNumber(id)}') : '숨은 타일'}',
      button: onTap != null,
      selected: selected,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: tile),
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
