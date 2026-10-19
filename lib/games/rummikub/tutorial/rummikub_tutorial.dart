import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/tutorial.dart';
import '../core/rummikub_rules.dart';
import '../ui/rummikub_tiles.dart';

int _t(int color, int number) => tileId(color, number);

/// 루미큐브 게임 방법.
GameTutorial rummikubTutorial() => GameTutorial(
  title: '루미큐브',
  color: kRkWood,
  steps: [
    TutorialStep(
      title: '숫자 타일로 묶음을 만들어요',
      body:
          '타일은 숫자 1~13이 검정·파랑·빨강·주황 4가지 색으로 2벌씩 있고, 웃는 얼굴의 조커가 2장 있어요.\n'
          '처음에 14장씩 나눠 받고, 손의 타일을 모두 판에 내려놓는 사람이 이겨요.',
      art: (context, accent) => _art([
        _row([_t(0, 1), _t(1, 5), _t(2, 9), _t(3, 13), kJokerA]),
      ], label: '숫자 · 색 · 조커'),
    ),
    TutorialStep(
      title: '그룹: 같은 숫자, 다른 색',
      body: '숫자는 같고 색이 모두 다른 타일 3장이나 4장이 한 그룹이에요.\n같은 색을 두 번 쓸 수는 없어요.',
      art: (context, accent) => _art([
        _row([_t(1, 7), _t(2, 7), _t(3, 7)]),
        _row([_t(0, 11), _t(1, 11), _t(2, 11), _t(3, 11)]),
      ], label: '파랑·빨강·주황 7'),
    ),
    TutorialStep(
      title: '런: 같은 색, 이어지는 숫자',
      body: '색이 같고 숫자가 차례로 이어지는 타일 3장 이상이 한 런이에요.\n13 다음에 1은 이어지지 않아요.',
      art: (context, accent) => _art([
        _row([_t(1, 4), _t(1, 5), _t(1, 6)]),
        _row([_t(2, 9), _t(2, 10), _t(2, 11), _t(2, 12), _t(2, 13)]),
      ], label: '파랑 4-5-6'),
    ),
    TutorialStep(
      title: '조커는 무엇이든 될 수 있어요',
      body: '조커는 어떤 타일 대신으로도 쓸 수 있어요. 빈 자리를 메우거나, 그룹의 모자란 색을 채워요.\n손에 조커가 남은 채 지면 벌점이 커요 (30점).',
      art: (context, accent) => _art([
        _row([_t(0, 3), kJokerA, _t(0, 5)]),
        _row([_t(1, 8), _t(3, 8), kJokerB]),
      ], label: '조커가 4와 빨강 8이 돼요'),
    ),
    TutorialStep(
      title: '처음에는 30점이 필요해요',
      body: '처음 판에 내려놓을 때는 내 타일만으로 묶음을 만들어 숫자의 합이 30점 이상이어야 해요. 여러 묶음을 합쳐도 돼요.\n이때는 판 위에 있는 다른 사람의 묶음을 건드릴 수 없어요.',
      art: (context, accent) => _art([
        _row([_t(0, 10), _t(1, 10), _t(2, 10)]),
      ], label: '10 + 10 + 10 = 30점'),
    ),
    TutorialStep(
      title: '타일을 판에 올리는 방법',
      body:
          '내 타일을 끌어서 녹색 판 아무 데나 놓으세요. 다른 묶음 가까이 놓으면 자석처럼 착 붙고, 멀리 놓으면 그 자리에 새 묶음이 돼요.\n'
          '판 위의 타일을 그냥 끌면 한 장만 옮겨지고, 꾹 눌렀다가 끌면 그 묶음이 통째로 옮겨져요. 끄는 동안 붙게 될 묶음은 노란 테두리로 미리 알려 주고, 규칙에 맞지 않는 묶음은 주황 테두리로 보여 줘요.',
      art: (context, accent) => _art([
        _row([_t(1, 6), _t(1, 7)], selectedIndex: 1),
        _row([_t(1, 8)], glow: true),
      ], label: '골라서 → 묶음 누르기'),
    ),
    TutorialStep(
      title: '판 위의 타일도 다시 맞춰요',
      body:
          '처음 내려놓은 뒤에는 판 위의 묶음도 풀어서 옮기고, 쪼개고, 합쳐도 돼요. 끝낼 때 판 위의 모든 묶음이 올바르면 돼요.\n'
          '한 장 이상은 내 손에서 내려놓아야 하고, 판 위 타일을 손으로 가져올 수는 없어요. "처음으로"를 누르면 이번 차례에 만진 걸 모두 되돌려요.',
      art: (context, accent) => _art([
        _row([_t(0, 5), _t(1, 5), _t(2, 5)]),
        _row([_t(0, 5), _t(0, 6), _t(0, 7)], glow: true),
      ], label: '그룹을 풀어 런으로'),
    ),
    TutorialStep(
      title: '아래 단추들은 이런 일을 해요',
      body:
          '화면 맨 아래 단추를 꾹 누르면 이름이 떠요.\n'
          '미완성 단추는 이번 차례에 내가 낸 타일 중 묶음을 못 이룬 것만 손으로 가져오고, 잘 만든 묶음은 판에 그대로 둬요. 못 이룬 타일이 없으면 흐리게 보여요.\n'
          '되돌리기는 한 걸음 전으로, 처음으로는 이번 차례에 만진 걸 모두 되돌려요. 정리는 묶음은 그대로 두고 자리만 가지런히 해요.',
      art: (context, accent) => _buttonsArt(),
    ),
    TutorialStep(
      title: '낼 수 없으면 바닥에서 한 장 뽑아요',
      body:
          '맞출 수 없으면 바닥에 엎어 둔 타일 중 마음에 드는 한 장을 직접 골라 뽑고 차례가 넘어가요.\n'
          '손이 먼저 비는 사람이 이겨요. 바닥이 비고 아무도 낼 수 없으면 손에 남은 숫자의 합이 가장 작은 사람이 이겨요. 상대 손에 몇 장 있는지는 알 수 없어요!',
      art: (context, accent) => _art([
        _row([_t(2, 2), _t(0, 12), _t(3, 4), _t(1, 9)]),
      ], label: '남은 타일이 적을수록 좋아요'),
    ),
    TutorialStep(
      title: '누구와 하나요?',
      body:
          '남의 타일이 보이면 안 되니까, 사람과는 같은 Wi‑Fi에서 각자 자기 기기로 해요. 한 사람이 방을 만들고 다른 사람이 들어오면 시작해요.\n'
          '혼자서는 CPU 1~3명과 겨룰 수 있어요.',
      icon: Icons.wifi_rounded,
    ),
  ],
);

/// 맨 아래 단추들의 아이콘과 뜻 (게임 화면의 단추와 같은 아이콘).
Widget _buttonsArt() {
  const items = [
    (Icons.south_west_rounded, '고른 타일을 손으로'),
    (Icons.rule_rounded, '미완성 타일만 손으로'),
    (Icons.undo_rounded, '한 걸음 되돌리기'),
    (Icons.restart_alt_rounded, '처음으로'),
    (Icons.auto_fix_high_rounded, '자리 정리'),
    (Icons.check_rounded, '끝내기'),
    (Icons.flag_outlined, '기권'),
  ];
  return ArtCanvas(
    width: 340,
    height: 270,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final (icon, name) in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 44,
                  height: 30,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: kRkWood, width: 1.5),
                    color: icon == Icons.check_rounded ? kRkWood : null,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: icon == Icons.check_rounded ? Colors.white : kRkWood,
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 170,
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kRkWood,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}

Widget _row(List<int> ids, {int? selectedIndex, bool glow = false}) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    for (var i = 0; i < ids.length; i++)
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: RkTile(
          id: ids[i],
          width: ids.length > 4 ? 46 : 54,
          selected: selectedIndex == i,
          glow: glow,
        ),
      ),
  ],
);

Widget _art(List<Widget> rows, {required String label}) {
  return ArtCanvas(
    width: 340,
    height: 270,
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF2E6B4A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF1F4A33), width: 3),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                rows[i],
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        ArtLabel(label, color: kRkWood),
      ],
    ),
  );
}
