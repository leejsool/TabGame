import 'package:flutter/material.dart';

import '../games/freecell/ui/playing_card.dart';
import '../games/solitaire/ui/card_back.dart';

/// 카드 번호: 숫자(A=0 … K=12) × 4 + 무늬(♣=0 ♦=1 ♥=2 ♠=3). 게임 엔진과 같은 약속이다.
int tcard(String rank, String suit) {
  const ranks = ['A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'];
  const suits = ['♣', '♦', '♥', '♠'];
  return ranks.indexOf(rank) * 4 + suits.indexOf(suit);
}

const double kCardRatio = 1.4;

/// 카드 한 장 그림. [card]가 null이면 뒷면.
class TCard extends StatelessWidget {
  const TCard(this.card, {super.key, this.width = 56, this.glow});

  final int? card;
  final double width;

  /// 눈에 띄게 테두리를 칠할 색.
  final Color? glow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: width * kCardRatio,
      child: CustomPaint(
        painter: card == null
            ? CardBackPainter()
            : PlayingCardPainter(card!, glow: glow),
      ),
    );
  }
}

/// 겹쳐 쌓인 카드 줄 (맨 위가 첫 카드). null은 뒷면. [from]부터는 [glow] 테두리.
class TRun extends StatelessWidget {
  const TRun(
    this.cards, {
    super.key,
    this.width = 56,
    this.backOffset = 0.22,
    this.faceOffset = 0.42,
    this.glow,
    this.glowFrom = 1 << 30,
  });

  final List<int?> cards;
  final double width;

  /// 뒷면 카드끼리 / 앞면 카드끼리 겹치는 간격 (카드 높이 대비).
  final double backOffset;
  final double faceOffset;
  final Color? glow;
  final int glowFrom;

  double get height {
    var y = 0.0;
    for (var i = 0; i < cards.length - 1; i++) {
      y += width * kCardRatio * (cards[i] == null ? backOffset : faceOffset);
    }
    return y + width * kCardRatio;
  }

  @override
  Widget build(BuildContext context) {
    var y = 0.0;
    final children = <Widget>[];
    for (var i = 0; i < cards.length; i++) {
      children.add(
        Positioned(
          top: y,
          left: 0,
          child: TCard(cards[i], width: width, glow: i >= glowFrom ? glow : null),
        ),
      );
      y += width * kCardRatio * (cards[i] == null ? backOffset : faceOffset);
    }
    return SizedBox(width: width, height: height, child: Stack(children: children));
  }
}

/// 카드가 없는 자리 (빈 열 / 프리셀 / 완성 칸). [mark]는 자리 안에 희미하게 쓰는 글자.
class TSlot extends StatelessWidget {
  const TSlot({super.key, this.width = 56, this.mark, this.color, this.child});

  final double width;
  final String? mark;
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35);
    return Container(
      width: width,
      height: width * kCardRatio,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(width * 0.12),
        border: Border.all(color: c, width: 2),
        color: c.withValues(alpha: 0.07),
      ),
      child: child ??
          (mark == null
              ? null
              : Text(
                  mark!,
                  style: TextStyle(fontSize: width * 0.5, fontWeight: FontWeight.w800, color: c),
                )),
    );
  }
}

/// 맞다 / 안 된다 표시.
class VerdictMark extends StatelessWidget {
  const VerdictMark({super.key, required this.ok, this.size = 32});

  final bool ok;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(
      ok ? Icons.check_circle_rounded : Icons.cancel_rounded,
      size: size,
      color: ok ? const Color(0xFF2E9E5B) : const Color(0xFFE5484D),
    );
  }
}
