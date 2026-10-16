import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/tutorial.dart';
import '../core/davinci_rules.dart';
import '../ui/davinci_tiles.dart';

int _b(int n) => dvTile(0, n);
int _w(int n) => dvTile(1, n);

/// 다빈치 코드 게임 방법.
GameTutorial davinciTutorial() => GameTutorial(
      title: '다빈치 코드',
      color: kDavinciColor,
      steps: [
        TutorialStep(
          title: '검정과 흰색 숫자 타일',
          body: '타일은 검정 0~11, 흰색 0~11 이렇게 24장과, 어디든 끼는 조커(‑) 2장이에요.\n'
              '각자 처음에 몇 장씩 받고, 숫자가 작은 쪽부터 왼쪽에서 오른쪽으로 늘어놓아요.',
          art: (context, accent) => _art([
            _row([_b(2), _w(2), _b(5), _w(8), _b(11)], faceUp: true),
          ], label: '같은 숫자면 검정이 먼저'),
        ),
        TutorialStep(
          title: '내 타일은 나만 볼 수 있어요',
          body: '내 타일은 숫자가 다 보이지만, 상대의 숨은 타일은 색과 자리만 보여요.\n'
              '"검정 타일 다음에 흰색 타일이 있구나" 하는 단서로 숫자를 추리해요.',
          art: (context, accent) => _art([
            _row([_b(1), _w(4), _b(6), _w(9)], faceUp: false),
            _row([_b(0), _w(3), _b(7), _w(10)], faceUp: true),
          ], label: '위: 상대(색만 보여요) · 아래: 나'),
        ),
        TutorialStep(
          title: '내 차례: 뽑고 맞혀요',
          body: '검정이나 흰색 더미에서 타일을 한 장 뽑으면 순서에 맞는 자리에 저절로 끼워져요.\n'
              '그다음 상대의 숨은 타일 하나를 눌러 고르고, 그 숫자를 맞혀요.',
          art: (context, accent) => _art([
            _row([_b(1), _w(4), _b(6), _w(9)], faceUp: false, selectedIndex: 2),
          ], label: '이 타일은 몇일까?'),
        ),
        TutorialStep(
          title: '맞히면 공개, 틀리면 내 타일이 공개',
          body: '맞히면 그 타일이 모두에게 공개돼요. 계속 맞히거나 멈출 수 있어요 (멈추면 내 새 타일은 숨은 채로 남아요).\n'
              '틀리면 방금 뽑은 내 타일이 공개되고 차례가 넘어가요. 조심해서 계속할지 정해요!',
          art: (context, accent) => _art([
            _row([_b(1), _w(4), _b(6), _w(9)], faceUp: false, marks: {2: true}, revealedIndex: 2),
          ], label: '맞히면 공개!'),
        ),
        TutorialStep(
          title: '조커(‑)',
          body: '조커를 뽑으면 내 줄의 어느 자리에 놓을지 내가 골라요. 상대가 조커를 맞히려면 숫자 대신 "‑"를 골라야 해요.',
          art: (context, accent) => _art([
            _row([_b(2), 24, _w(7), _w(9)], faceUp: true),
          ], label: '조커는 아무 자리나'),
        ),
        TutorialStep(
          title: '끝까지 남으면 이겨요',
          body: '숨은 타일이 모두 공개되면 탈락이에요. 마지막까지 숨은 타일이 남은 사람이 이겨요.\n'
              '더미가 다 떨어지면 뽑지 않고 바로 맞혀요. 이때 틀리면 내 숨은 타일 하나를 직접 공개해요.',
          art: (context, accent) => _art([
            _row([_b(1), _w(4), _b(6), _w(9)], faceUp: true, revealedIndex: 0),
          ], label: '남은 숨은 타일이 있어야 해요'),
        ),
        TutorialStep(
          title: '누구와 하나요?',
          body: '남의 타일이 보이면 안 되니까, 사람과는 같은 Wi‑Fi에서 각자 자기 기기로 해요 (2~4명). 한 사람이 방을 만들고 나머지가 들어오면 시작해요.\n'
              '혼자서는 CPU 1~3명과 겨룰 수 있어요.',
          icon: Icons.wifi_rounded,
        ),
      ],
    );

Widget _row(List<int> ids, {required bool faceUp, int? selectedIndex, Map<int, bool> marks = const {}, int? revealedIndex}) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < ids.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: DvTile(
              id: ids[i],
              width: ids.length > 4 ? 46 : 54,
              faceUp: faceUp || revealedIndex == i,
              lying: revealedIndex == i,
              selected: selectedIndex == i,
              mark: marks[i],
            ),
          ),
      ],
    );

Widget _art(List<Widget> rows, {required String label}) {
  return ArtCanvas(
    width: 340,
    height: 250,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          rows[i],
        ],
        const SizedBox(height: 16),
        ArtLabel(label, color: kDavinciColor),
      ],
    ),
  );
}
