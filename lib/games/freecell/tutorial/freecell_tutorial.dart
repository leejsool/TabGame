import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/card_art.dart';
import '../../../tutorial/tutorial.dart';

const Color _freecellColor = Color(0xFF6A4C93);

/// 프리셀 게임 방법.
GameTutorial freecellTutorial() => GameTutorial(
      title: '프리셀',
      color: _freecellColor,
      steps: [
        TutorialStep(
          title: '카드를 무늬별로 쌓아요',
          body: '카드 52장을 무늬별로 A부터 K까지 오른쪽 위 네 칸(완성 칸)에 모두 쌓으면 이겨요.\n'
              '카드는 처음부터 전부 앞면이에요. 아래 8개의 열에서 맨 아래 카드를 옮기며 차근차근 풀어요.',
          art: (context, accent) => const ArtCanvas(width: 372, height: 360, child: _FreecellTableArt()),
        ),
        TutorialStep(
          title: '다른 색, 하나 작은 숫자',
          body: '열에서는 다른 색이고 숫자가 하나 작은 카드 위에 올릴 수 있어요.\n'
              '예를 들어 빨강 7 위에는 검정 6을 올릴 수 있어요. 같은 색끼리는 안 돼요.',
          art: (context, accent) => const ArtCanvas(width: 340, height: 280, child: _AlternateColorArt()),
        ),
        TutorialStep(
          title: '프리셀: 잠깐 맡겨 두는 곳',
          body: '위쪽 왼쪽 네 칸이 프리셀이에요. 카드를 한 장씩 잠깐 맡겨 둘 수 있어요.\n'
              '하지만 꽉 차면 아무것도 맡길 수 없으니, 아껴서 쓰는 게 승리의 비결이에요!',
          art: (context, accent) => const ArtCanvas(width: 340, height: 330, child: _FreeCellArt()),
        ),
        TutorialStep(
          title: '여러 장도 한꺼번에',
          body: '빈 프리셀이 많을수록 여러 장을 한꺼번에 옮길 수 있어요. 실제로는 카드를 프리셀에 한 장씩 '
              '맡기며 옮기는 것과 같아서, 빈 프리셀이 하나 늘 때마다 한 장씩 더 옮길 수 있어요.\n'
              '빈 열이 있으면 옮길 수 있는 장수가 두 배가 돼요!',
          art: (context, accent) => const ArtCanvas(width: 340, height: 330, child: _CapacityArt()),
        ),
        TutorialStep(
          title: '빈 열은 보물',
          body: '열이 텅 비면 아무 카드나(줄째로도) 올릴 수 있어요.\n'
              '빈 열은 카드를 잠깐 쌓아 둘 수 있어서 프리셀보다 훨씬 강력해요. 일부러 한 줄을 비워 보세요!',
          art: (context, accent) => const ArtCanvas(width: 340, height: 250, child: _EmptyColumnArt()),
        ),
        TutorialStep(
          title: '완성 칸과 자동 올리기',
          body: '같은 무늬를 A, 2, 3 … K 순서로 완성 칸에 올려요.\n'
              '손해 없는 카드는 알아서 완성 칸으로 올라가요. 마음에 안 들면 설정이나 화면 아래 버튼으로 끌 수 있어요.',
          art: (context, accent) => ArtCanvas(
            width: 340,
            height: 230,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final (i, c) in [
                      tcard('A', '♠'),
                      tcard('2', '♠'),
                      tcard('3', '♠'),
                      tcard('4', '♠'),
                    ].indexed) ...[
                      if (i > 0) const Icon(Icons.chevron_right_rounded, size: 26, color: _freecellColor),
                      TCard(c, width: 56),
                    ],
                  ],
                ),
                const SizedBox(height: 22),
                const ArtLabel('같은 무늬를 A부터 차례로', color: _freecellColor, filled: false),
              ],
            ),
          ),
        ),
        TutorialStep(
          title: '손쉬운 조작과 도움',
          body: '카드를 끌어서 놓거나, 카드를 톡 치면 갈 수 있는 곳으로 알아서 가요.\n'
              '막히면 되돌리기와 힌트 버튼을 쓰세요.\n'
              '판에는 번호가 있어요 (1~32000번). 번호가 같으면 항상 같은 판이고, 11982번만 풀 수 없는 판이라 빠져 있어요.',
          art: (context, accent) => ArtCanvas(
            width: 340,
            height: 250,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ArtBadge(icon: Icons.swipe_rounded, color: _freecellColor, label: '끌어서 놓기', size: 84),
                    ArtBadge(icon: Icons.touch_app_rounded, color: _freecellColor, label: '톡 치기', size: 84),
                  ],
                ),
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (final (icon, label) in const [
                      (Icons.undo_rounded, '되돌리기'),
                      (Icons.lightbulb_rounded, '힌트'),
                      (Icons.auto_awesome_rounded, '자동 올리기'),
                      (Icons.refresh_rounded, '처음부터'),
                    ])
                      Column(
                        children: [
                          Icon(icon, size: 34, color: accent),
                          const SizedBox(height: 4),
                          Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );

/// 판 전체 그림: 위 왼쪽 프리셀 4칸, 오른쪽 완성 칸 4칸, 아래 8개의 열 (전부 앞면).
class _FreecellTableArt extends StatelessWidget {
  const _FreecellTableArt();

  @override
  Widget build(BuildContext context) {
    const w = 38.0;
    const gap = 6.0;
    final cols = [
      [tcard('9', '♣'), tcard('4', '♦'), tcard('K', '♥')],
      [tcard('2', '♠'), tcard('J', '♦'), tcard('7', '♣')],
      [tcard('Q', '♠'), tcard('5', '♥'), tcard('8', '♦')],
      [tcard('3', '♣'), tcard('10', '♥'), tcard('6', '♠')],
      [tcard('J', '♣'), tcard('A', '♦'), tcard('4', '♠')],
      [tcard('8', '♠'), tcard('K', '♣'), tcard('9', '♥')],
      [tcard('5', '♣'), tcard('Q', '♦'), tcard('2', '♥')],
      [tcard('10', '♠'), tcard('7', '♦'), tcard('3', '♥')],
    ];
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        );
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      const TSlot(width: w, color: _freecellColor),
                    ],
                  ],
                ),
                label('프리셀 (임시 보관)'),
              ],
            ),
            Column(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      const TSlot(width: w, mark: 'A', color: Color(0xFF2E7D5B)),
                    ],
                  ],
                ),
                label('완성 칸'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final col in cols) TRun(col, width: 40, faceOffset: 0.34),
          ],
        ),
        label('8개의 열'),
      ],
    );
  }
}

class _AlternateColorArt extends StatelessWidget {
  const _AlternateColorArt();

  @override
  Widget build(BuildContext context) {
    Widget pair(int a, int b, bool ok, String caption) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TRun([a, b], width: 78, faceOffset: 0.3),
          const SizedBox(height: 8),
          VerdictMark(ok: ok),
          const SizedBox(height: 4),
          Text(caption, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        pair(tcard('7', '♦'), tcard('6', '♠'), true, '빨강 7 + 검정 6'),
        pair(tcard('7', '♦'), tcard('6', '♥'), false, '같은 색은 안 돼요'),
      ],
    );
  }
}

class _FreeCellArt extends StatelessWidget {
  const _FreeCellArt();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TCard(tcard('9', '♣'), width: 62, glow: const Color(0xFFE2A400)),
            const SizedBox(width: 10),
            for (var i = 0; i < 3; i++) ...[
              const TSlot(width: 62, color: _freecellColor),
              const SizedBox(width: 10),
            ],
          ],
        ),
        const SizedBox(height: 10),
        const ArtLabel('프리셀 4칸 — 한 칸에 한 장', color: _freecellColor, filled: false),
        const SizedBox(height: 18),
        const Icon(Icons.arrow_upward_rounded, size: 34, color: _freecellColor),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TRun([tcard('J', '♦'), tcard('5', '♥'), tcard('9', '♣')], width: 62, faceOffset: 0.26),
            const SizedBox(width: 14),
            const Text(
              '맨 아래 카드를\n위로 올려 맡겨요',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ],
    );
  }
}

class _CapacityArt extends StatelessWidget {
  const _CapacityArt();

  @override
  Widget build(BuildContext context) {
    Widget row(int free) {
      final n = free + 1;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 128,
              child: Text('빈 프리셀 $free개', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
            SizedBox(
              width: 130,
              height: 28 * kCardRatio,
              child: Stack(
                children: [
                  for (var i = 0; i < n; i++)
                    Positioned(left: i * 21.0, child: const TCard(null, width: 28)),
                ],
              ),
            ),
            Text('$n장', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _freecellColor)),
          ],
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var f = 0; f <= 4; f++) row(f),
        const SizedBox(height: 14),
        const ArtLabel('빈 열이 하나 있으면 ×2', color: _freecellColor),
      ],
    );
  }
}

class _EmptyColumnArt extends StatelessWidget {
  const _EmptyColumnArt();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            TRun([tcard('8', '♣'), tcard('7', '♦')], width: 70, faceOffset: 0.3, glow: const Color(0xFFE2A400), glowFrom: 0),
            const SizedBox(height: 8),
            const ArtLabel('아무 줄이나', color: _freecellColor, filled: false),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 44),
          child: Icon(Icons.arrow_forward_rounded, size: 38, color: _freecellColor),
        ),
        Column(
          children: [
            const TSlot(width: 70, mark: '빈 열', color: _freecellColor),
            const SizedBox(height: 8),
            const ArtLabel('빈 열', color: _freecellColor, filled: false),
          ],
        ),
      ],
    );
  }
}
