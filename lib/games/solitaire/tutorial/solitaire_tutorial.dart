import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/card_art.dart';
import '../../../tutorial/tutorial.dart';

const Color _solitaireColor = Color(0xFF2E7D5B);

/// 솔리테어 게임 방법.
GameTutorial solitaireTutorial() => GameTutorial(
      title: '솔리테어',
      color: _solitaireColor,
      steps: [
        TutorialStep(
          title: '카드를 무늬별로 쌓아요',
          body: '카드 52장을 무늬별로 A부터 K까지 오른쪽 위 네 칸(완성 칸)에 모두 쌓으면 이겨요.\n'
              '아래에는 7개의 열이 있어요. 열에서 카드를 옮겨 가며 뒷면 카드를 뒤집고, '
              '필요한 카드를 찾아내는 게 게임의 핵심이에요.',
          art: (context, accent) => const ArtCanvas(width: 372, height: 372, child: _SolitaireTableArt()),
        ),
        TutorialStep(
          title: '다른 색, 하나 작은 숫자',
          body: '열에서는 다른 색이고 숫자가 하나 작은 카드를 이어 붙여요.\n'
              '예를 들어 검정 7 위에는 빨강 6을 올릴 수 있어요. 같은 색끼리는 안 돼요.',
          art: (context, accent) => const ArtCanvas(width: 340, height: 280, child: _AlternateColorArt()),
        ),
        TutorialStep(
          title: '줄째로 옮기고, 뒷면은 저절로 뒤집혀요',
          body: '앞면이 위로 보이는 카드는 줄째로 한꺼번에 옮길 수 있어요.\n'
              '맨 위에 있던 뒷면 카드는, 그 위의 카드를 옮겨서 치우면 저절로 뒤집혀요.',
          art: (context, accent) => const ArtCanvas(width: 340, height: 300, child: _MoveRunArt()),
        ),
        TutorialStep(
          title: '빈 열에는 K만',
          body: '열이 텅 비면 K(또는 K로 시작하는 줄)만 놓을 수 있어요.\n'
              '빈 열을 만들어 두면 큰 카드를 편하게 옮길 수 있어요.',
          art: (context, accent) => const ArtCanvas(width: 340, height: 250, child: _EmptyColumnArt()),
        ),
        TutorialStep(
          title: '더미에서 카드를 뽑아요',
          body: '왼쪽 위의 더미를 누르면 카드를 뽑아요. (게임을 시작할 때 1장씩 또는 3장씩 뽑기를 골라요)\n'
              '뽑은 카드는 맨 위 한 장만 쓸 수 있어요. 더미가 비면 한 번 더 눌러서 처음부터 다시 넘길 수 있어요.',
          art: (context, accent) => const ArtCanvas(width: 340, height: 250, child: _StockArt()),
        ),
        TutorialStep(
          title: '완성 칸에 A부터 차례로',
          body: '같은 무늬를 A, 2, 3 … K 순서로 완성 칸에 올려요. 카드를 끌어다 놓거나, 맞는 카드를 톡 치면 올라가요.\n'
              '한 무늬를 K까지 다 올리면 그 칸이 완성돼요!',
          art: (context, accent) => const ArtCanvas(width: 340, height: 230, child: _FoundationArt()),
        ),
        TutorialStep(
          title: '손쉬운 조작과 도움',
          body: '카드를 끌어서 놓거나, 카드를 톡 치면 갈 수 있는 곳으로 알아서 가요.\n'
              '막히면 아래 버튼을 쓰세요: 되돌리기, 힌트, 손해 없는 카드를 알아서 올려 주는 "자동 올리기", 처음부터.\n'
              '번호가 같으면 항상 같은 판이에요. (모든 판이 풀리는 건 아니에요)',
          art: (context, accent) => ArtCanvas(
            width: 340,
            height: 250,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ArtBadge(icon: Icons.swipe_rounded, color: _solitaireColor, label: '끌어서 놓기', size: 84),
                    ArtBadge(icon: Icons.touch_app_rounded, color: _solitaireColor, label: '톡 치기', size: 84),
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

/// 판 전체 그림: 위에 더미·버린 더미·완성 칸, 아래에 7개 열.
class _SolitaireTableArt extends StatelessWidget {
  const _SolitaireTableArt();

  @override
  Widget build(BuildContext context) {
    const w = 44.0;
    const gap = 8.0;
    final faces = [
      tcard('K', '♠'), tcard('Q', '♥'), tcard('9', '♣'), tcard('4', '♦'),
      tcard('J', '♠'), tcard('7', '♥'), tcard('2', '♣'),
    ];
    Widget label(String t) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
        );
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(children: [const TCard(null, width: w), label('더미')]),
            const SizedBox(width: gap),
            Column(children: [TCard(tcard('8', '♣'), width: w), label('뽑은 카드')]),
            const Spacer(),
            Column(
              children: [
                Row(
                  children: [
                    for (var i = 0; i < 4; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      const TSlot(width: w, mark: 'A', color: _solitaireColor),
                    ],
                  ],
                ),
                label('완성 칸 (A부터 K까지)'),
              ],
            ),
          ],
        ),
        const SizedBox(height: 26),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < 7; i++) TRun([for (var k = 0; k < i; k++) null, faces[i]], width: w, backOffset: 0.2),
          ],
        ),
        label('7개의 열 (맨 아래 카드만 앞면)'),
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
        pair(tcard('7', '♠'), tcard('6', '♥'), true, '검정 7 + 빨강 6'),
        pair(tcard('7', '♠'), tcard('6', '♣'), false, '같은 색은 안 돼요'),
      ],
    );
  }
}

class _MoveRunArt extends StatelessWidget {
  const _MoveRunArt();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            TRun(
              [null, null, tcard('8', '♠'), tcard('7', '♥'), tcard('6', '♣')],
              width: 70,
              faceOffset: 0.3,
              glow: const Color(0xFFE2A400),
              glowFrom: 2,
            ),
            const SizedBox(height: 8),
            const ArtLabel('앞면 줄은 통째로', color: _solitaireColor, filled: false),
          ],
        ),
        const Padding(
          padding: EdgeInsets.only(top: 40),
          child: Icon(Icons.arrow_forward_rounded, size: 40, color: _solitaireColor),
        ),
        Column(
          children: [
            TRun([tcard('9', '♦')], width: 70),
            const SizedBox(height: 8),
            const ArtLabel('9 위로!', color: _solitaireColor, filled: false),
          ],
        ),
      ],
    );
  }
}

class _EmptyColumnArt extends StatelessWidget {
  const _EmptyColumnArt();

  @override
  Widget build(BuildContext context) {
    Widget item(Widget child, bool ok, String caption) => Column(
          children: [
            child,
            const SizedBox(height: 8),
            VerdictMark(ok: ok),
            Text(caption, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ],
        );
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TSlot(width: 70, mark: '빈 열', color: _solitaireColor),
        const Padding(
          padding: EdgeInsets.only(top: 40),
          child: Icon(Icons.arrow_back_rounded, size: 36, color: _solitaireColor),
        ),
        item(TCard(tcard('K', '♥'), width: 70), true, 'K는 OK'),
        item(TCard(tcard('Q', '♠'), width: 70), false, 'Q는 안 돼요'),
      ],
    );
  }
}

class _StockArt extends StatelessWidget {
  const _StockArt();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Stack(
              children: [
                Positioned(left: 8, top: 8, child: TCard(null, width: 74)),
                Positioned(left: 4, top: 4, child: TCard(null, width: 74)),
                TCard(null, width: 74),
              ],
            ),
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: TapPulse(size: 70, color: _solitaireColor),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 74 + 2 * 26.0,
              height: 74 * kCardRatio,
              child: Stack(
                children: [
                  Positioned(left: 0, child: TCard(tcard('5', '♦'), width: 74)),
                  Positioned(left: 26, child: TCard(tcard('J', '♣'), width: 74)),
                  Positioned(left: 52, child: TCard(tcard('3', '♥'), width: 74, glow: const Color(0xFFE2A400))),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const ArtLabel('3장 뽑기: 맨 위 한 장만 쓸 수 있어요', color: _solitaireColor, filled: false),
      ],
    );
  }
}

class _FoundationArt extends StatelessWidget {
  const _FoundationArt();

  @override
  Widget build(BuildContext context) {
    final run = [tcard('A', '♥'), tcard('2', '♥'), tcard('3', '♥'), tcard('4', '♥')];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final (i, c) in run.indexed) ...[
              if (i > 0) const Icon(Icons.chevron_right_rounded, size: 26, color: _solitaireColor),
              TCard(c, width: 56),
            ],
          ],
        ),
        const SizedBox(height: 22),
        const ArtLabel('같은 무늬를 A부터 차례로', color: _solitaireColor, filled: false),
      ],
    );
  }
}
