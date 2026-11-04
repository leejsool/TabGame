import 'package:flutter/material.dart';

import 'kt_board.dart';

/// 판 위에 떠 있는 큰 점수 (가운데 위).
class KtScoreText extends StatelessWidget {
  const KtScoreText({super.key, required this.score, this.caption});

  final int score;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    const shadow = [Shadow(color: Color(0xAAFFFFFF), blurRadius: 6)];
    return IgnorePointer(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (caption != null)
            Text(caption!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF6B6680), shadows: shadow)),
          Text('$score', style: const TextStyle(fontSize: 44, height: 1.1, fontWeight: FontWeight.w900, color: kKeytapColor, shadows: shadow)),
        ],
      ),
    );
  }
}

/// 잠깐 떴다 사라지는 안내 ("2바퀴째 · 더 빠르게!").
class KtBanner extends StatelessWidget {
  const KtBanner({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(color: kKeytapColor.withValues(alpha: 0.92), borderRadius: BorderRadius.circular(24)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// 3-2-1 숫자 (다시 시작·경주 출발 전).
class KtCountdown extends StatelessWidget {
  const KtCountdown({super.key, required this.left});
  final double left;

  @override
  Widget build(BuildContext context) {
    final n = left.ceil();
    return IgnorePointer(
      child: Container(
        color: Colors.black.withValues(alpha: 0.18),
        alignment: Alignment.center,
        child: Text(n > 0 ? '$n' : '시작!', style: const TextStyle(fontSize: 88, fontWeight: FontWeight.w900, color: Colors.white, shadows: [Shadow(color: Color(0x88000000), blurRadius: 12)])),
      ),
    );
  }
}

/// 별 0~3개.
class KtStars extends StatelessWidget {
  const KtStars({super.key, required this.stars, this.size = 36});
  final int stars;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Icon(i < stars ? Icons.star_rounded : Icons.star_outline_rounded, size: size, color: i < stars ? const Color(0xFFF2A900) : const Color(0xFFBDB7C9)),
      ],
    );
  }
}

/// 끝났을 때 판 위에 뜨는 결과 카드.
class KtResultCard extends StatelessWidget {
  const KtResultCard({super.key, required this.title, required this.body, required this.actions});

  final String title;
  final List<Widget> body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: Colors.black.withValues(alpha: 0.35),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Material(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(24),
          elevation: 8,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                const SizedBox(height: 12),
                ...body,
                const SizedBox(height: 18),
                Wrap(alignment: WrapAlignment.center, spacing: 10, runSpacing: 8, children: actions),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 판을 가운데에 세운다: 가로로 넓은 화면에서는 너무 넓어지지 않게 폭을 줄인다.
class KtBoardFrame extends StatelessWidget {
  const KtBoardFrame({super.key, required this.child, this.side});

  final Widget child;

  /// 가로 화면에서 판 옆에 둘 것 (경주 점수판).
  final Widget? side;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final maxW = box.maxHeight * 0.78;
      if (box.maxWidth <= maxW) return child;
      final board = SizedBox(width: maxW, child: child);
      final s = side;
      if (s == null) return Center(child: board);
      final room = box.maxWidth - maxW;
      return Row(
        children: [
          SizedBox(width: room / 2),
          board,
          SizedBox(width: room / 2, child: Padding(padding: const EdgeInsets.all(16), child: Align(alignment: Alignment.topLeft, child: s))),
        ],
      );
    });
  }
}
