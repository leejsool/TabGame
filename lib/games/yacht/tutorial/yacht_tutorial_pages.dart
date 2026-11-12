import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../core/yacht_rules.dart';
import '../ui/yacht_look.dart';
import 'yacht_tutorial_table.dart';

// 게임 방법 1 · 3 · 4쪽 그림: 진짜 게임 점수판에서 칸을 화살표로 이어 설명한다.

const double _w = 600, _h = 450, _tableW = 270, _tableH = 380;

const _ink = TextStyle(fontSize: 15, height: 1.35, fontWeight: FontWeight.w800, color: Colors.black87);
const _sub = TextStyle(fontSize: 13, height: 1.35, fontWeight: FontWeight.w700, color: Color(0xFF555555));

/// 화살표가 가리키는 설명 상자.
Widget _callout(GlobalKey key, List<Widget> children) => Container(
      key: key,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kYachtColor.withValues(alpha: 0.5), width: 1.4),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );

/// 굴린 주사위 한 줄 + 옆 글 (점수판 위에 놓인다).
Widget _rolled(List<int> dice, String text) => Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (final v in dice) Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: YachtDie(value: v, size: 36)),
        const SizedBox(width: 10),
        Text(text, style: _ink),
      ],
    );

/// 1쪽: 점수판의 족보 칸 전체를 괄호로 묶어 "족보의 칸 수만큼 차례가 돌아와요".
class YachtTutorialSheetArt extends StatefulWidget {
  const YachtTutorialSheetArt({super.key});

  @override
  State<YachtTutorialSheetArt> createState() => _SheetArtState();
}

class _SheetArtState extends State<YachtTutorialSheetArt> {
  final _text = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return ArtCanvas(
      width: _w,
      height: _h,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: YachtTutorialTable(
          tableWidth: _tableW,
          tableHeight: _tableH,
          setup: (c) {
            c.game.applyRoll(const [6, 6, 6, 2, 5]);
            c.choose(YachtCategory.sixes);
          },
          top: _rolled(const [6, 6, 6, 2, 5], '→ 식스 칸을 고르면 18점'),
          braceTarget: _text,
          side: Column(
            key: _text,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text('족보의 칸 수만큼\n차례가 돌아와요', style: TextStyle(fontSize: 21, height: 1.35, fontWeight: FontWeight.w900, color: kYachtColor)),
              SizedBox(height: 8),
              Text('12칸이면 12번\n한 차례에 한 칸씩 채워요', style: _sub),
            ],
          ),
        ),
      ),
    );
  }
}

/// 3쪽: 첫 굴림 6·6·6·6·3 → 식스 칸 24점, 포카드 칸 27점.
class YachtTutorialPickArt extends StatefulWidget {
  const YachtTutorialPickArt({super.key});

  @override
  State<YachtTutorialPickArt> createState() => _PickArtState();
}

class _PickArtState extends State<YachtTutorialPickArt> {
  final _sixes = GlobalKey(), _four = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return ArtCanvas(
      width: _w,
      height: _h,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: YachtTutorialTable(
          tableWidth: _tableW,
          tableHeight: _tableH,
          setup: (c) => c.game.applyRoll(const [6, 6, 6, 6, 3]),
          top: _rolled(const [6, 6, 6, 6, 3], '같은 주사위도 칸마다 점수가 달라요'),
          arrows: [
            YachtTableArrow(const YachtTableSpot.cell(YachtCategory.sixes), _sixes),
            YachtTableArrow(const YachtTableSpot.cell(YachtCategory.fourKind), _four),
          ],
          side: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _callout(_sixes, const [
                YachtTutorialDice([6, 6, 6, 6, 3], marks: [true, true, true, true, false], size: 28),
                SizedBox(height: 4),
                Text('식스 칸에 적으면 24점', style: _ink),
                Text('6이 나온 주사위만 더해요\n6+6+6+6 = 24', style: _sub),
              ]),
              const SizedBox(height: 40),
              _callout(_four, const [
                YachtTutorialDice([6, 6, 6, 6, 3], marks: [true, true, true, true, true], size: 28),
                SizedBox(height: 4),
                Text('포카드 칸에 적으면 27점', style: _ink),
                Text('같은 눈 4개 이상이면 5개를 모두 더해요\n6+6+6+6+3 = 27', style: _sub),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// 4쪽: 앞서 적은 포 12점 · 파이브 10점과 보너스 줄(22/63).
class YachtTutorialUpperArt extends StatefulWidget {
  const YachtTutorialUpperArt({super.key});

  @override
  State<YachtTutorialUpperArt> createState() => _UpperArtState();
}

class _UpperArtState extends State<YachtTutorialUpperArt> {
  final _fours = GlobalKey(), _fives = GlobalKey(), _bonus = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return ArtCanvas(
      width: _w,
      height: _h,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: YachtTutorialTable(
          tableWidth: _tableW,
          tableHeight: _tableH + 40,
          setup: (c) {
            // 두 차례가 지난 판: 나는 포 12 · 파이브 10, CPU는 트레이 9 · 찬스 22
            final me = c.game.cards[0].scores, cpu = c.game.cards[1].scores;
            me[YachtCategory.fours.index] = 12;
            me[YachtCategory.fives.index] = 10;
            cpu[YachtCategory.threes.index] = 9;
            cpu[YachtCategory.choice.index] = 22;
          },
          arrows: [
            YachtTableArrow(const YachtTableSpot.cell(YachtCategory.fours), _fours),
            YachtTableArrow(const YachtTableSpot.cell(YachtCategory.fives), _fives),
            YachtTableArrow(const YachtTableSpot.bonus(), _bonus),
          ],
          side: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _callout(_fours, const [
                YachtTutorialDice([4, 4, 4, 1, 6], marks: [true, true, true, false, false], size: 28),
                SizedBox(height: 4),
                Text('포 칸: 4+4+4 = 12점', style: _ink),
              ]),
              const SizedBox(height: 16),
              _callout(_fives, const [
                YachtTutorialDice([5, 5, 2, 3, 3], marks: [true, true, false, false, false], size: 28),
                SizedBox(height: 4),
                Text('파이브 칸: 5+5 = 10점', style: _ink),
              ]),
              const SizedBox(height: 16),
              _callout(_bonus, const [
                Text('보너스: 1~6 칸의 합 12+10 = 22', style: _ink),
                Text('합이 63점 이상이 되면 +35점!\n숫자마다 3개씩 모으면 딱 63점', style: _sub),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

/// 주사위 한 줄. [marks]의 주사위는 노란 테두리로 빛나고 나머지는 흐리다 (점수에 들어가는 주사위를 보여 줄 때).
class YachtTutorialDice extends StatelessWidget {
  const YachtTutorialDice(this.dice, {super.key, this.held, this.marks, this.caption, this.rule, this.size = 56});

  final List<int> dice;
  final List<bool>? held;
  final List<bool>? marks;
  final String? caption;

  /// 캡션 아래에 작게 적는 그 칸의 규칙.
  final String? rule;
  final double size;

  Widget _mark(int i, Widget die) {
    final m = marks;
    if (m == null) return die;
    // 빛나는 테두리만큼 흐린 주사위에도 여백을 줘서 줄 높이·간격이 같게
    if (!m[i]) return Padding(padding: const EdgeInsets.all(5.5), child: Opacity(opacity: 0.35, child: die));
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: const Color(0xFFF2A900), width: 3),
        boxShadow: const [BoxShadow(color: Color(0x99FFC83D), blurRadius: 10, spreadRadius: 1)],
      ),
      child: die,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < dice.length; i++)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: size < 40 ? 1.5 : 3),
                child: _mark(i, YachtDie(value: dice[i], size: size, held: held?[i] ?? false)),
              ),
          ],
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(caption!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        if (rule != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(rule!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12.5, height: 1.3, fontWeight: FontWeight.w700, color: Color(0xFF555555))),
          ),
      ],
    );
  }
}
