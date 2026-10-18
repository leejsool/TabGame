import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/tutorial.dart';

const Color _rhythmColor = Color(0xFFE2793A);
const Color _ink = Color(0xFF3B2F2F);

/// 리듬 검사단 게임 방법.
GameTutorial rhythmTutorial() => GameTutorial(
      title: '리듬 검사단',
      color: _rhythmColor,
      steps: [
        TutorialStep(
          title: '선배를 한 박 뒤에 따라 해요',
          body: '선배 검사 세 명이 한 박자씩 차례로 검을 내려쳐요. 그리고 네 번째가 바로 나예요!\n'
              '앞사람이 내려친 것을, 바로 다음 박자에 똑같이 따라 하면 돼요.',
          art: (context, accent) => const ArtCanvas(width: 360, height: 310, child: _SquadArt()),
        ),
        TutorialStep(
          title: '왼쪽? 오른쪽? 같은 쪽을 탭!',
          body: '앞사람이 검을 내려친 쪽을 잘 보세요. 화면의 같은 쪽 절반을 톡 탭하면 내가 내려쳐요.\n'
              '왼쪽을 쳤으면 왼쪽, 오른쪽을 쳤으면 오른쪽! 타이밍이 맞을수록 "완벽!"이 나와요.',
          art: (context, accent) => const ArtCanvas(width: 340, height: 280, child: _SideTapArt()),
        ),
        TutorialStep(
          title: '따다닥! 2연속',
          body: '선배가 빠르게 두 번 내려치면, 나도 같은 쪽을 빠르게 두 번 탭해요.\n'
              '쪽을 번갈아 치는 동작도 나와요. 앞사람이 친 순서를 그대로 따라 해 보세요.',
          art: (context, accent) => const ArtCanvas(width: 340, height: 280, child: _DoubleTapArt()),
        ),
        TutorialStep(
          title: '꾹 눌러 힘을 모아요 (2코스)',
          body: '화면을 꾹 누르고 있으면 검에 힘이 모여요. 선배가 내려칠 때 손을 떼면 쾅!\n'
              '짧게 탭하는 것과 꾹 누르는 것을 잘 구분해 보세요.',
          art: (context, accent) => const ArtCanvas(width: 340, height: 300, child: _HoldArt()),
        ),
        TutorialStep(
          title: '옆으로 쓱 긋기 (3코스)',
          body: '화면을 가로로 쓱 그으면 검을 옆으로 휘둘러요. 화살표가 가리키는 쪽으로 그으면 돼요.\n'
              '손가락이 일정 거리를 간 순간이 박자예요. 박자에 맞춰 시원하게 그어 보세요!',
          art: (context, accent) => const ArtCanvas(width: 340, height: 280, child: _SwipeArt()),
        ),
        TutorialStep(
          title: '보스의 공격을 막아요 (4코스)',
          body: '큰 슬라임이 힘을 모으면 화면 가장자리가 붉어져요. 덮치는 순간에 맞춰 화면을 위로 쓱 밀면 '
              '검을 들어 막아요. 왼손이든 오른손이든 상관없어요!\n'
              '막지 못하면 하트가 하나 깎이고, 하트 3개를 다 잃으면 점수와 상관없이 게임 오버예요.',
          art: (context, accent) => const ArtCanvas(width: 340, height: 300, child: _GuardArt()),
        ),
        TutorialStep(
          title: '별을 모아 다음 코스로',
          body: '정확하게 칠수록 별이 많아져요. 별 2개 이상이면 다음 코스가 열려요.\n'
              '소리를 켜고 박자를 들으면서 하면 훨씬 쉬워요. 소리가 화면과 어긋나는 느낌이 들면 '
              '메뉴 아래의 "박자 보정"을 해 보세요.',
          art: (context, accent) => const ArtCanvas(width: 340, height: 280, child: _StarsArt()),
        ),
      ],
    );

/// 그림별 "인게임에서 그려지는 높이" (그림 높이 × art.json의 scale). 튜토리얼에서도 인게임과 같은 비율로 그리려고 쓴다.
/// (그림마다 원래 키가 달라서, 높이를 똑같이 맞춰 그리면 교관이 제일 크다는 비율이 깨진다.)
const Map<String, double> _gameHeight = {
  'c0_idle': 451.1,
  'c0_side_ready': 363.5,
  'c0_side_swing': 360.6,
  'c0_strike': 402.0,
  'c0_windup': 529.0,
  'c1_idle': 416.4,
  'c1_side_ready': 348.4,
  'c1_side_swing': 342.4,
  'c1_strike': 372.0,
  'c1_windup': 537.0,
  'c2_idle': 443.5,
  'c2_side_ready': 354.2,
  'c2_side_swing': 348.2,
  'c2_strike': 395.0,
  'c2_windup': 538.0,
  'c3_idle': 437.7,
  'c3_side_ready': 364.7,
  'c3_side_swing': 355.3,
  'c3_strike': 390.0,
  'c3_windup': 538.0,
  'slime_attack': 364.0,
  'slime_hit': 371.0,
  'slime_idle': 346.0,
  'slime_ready': 355.0,
  'slime_red_attack': 364.0,
  'slime_red_hit': 371.0,
  'slime_red_idle': 346.0,
  'slime_red_ready': 355.0,
};

/// 인게임 그림 한 픽셀이 튜토리얼 그림에서 차지하는 크기.
const double _spriteK = 0.27;

/// 캐릭터 그림 (없으면 아이콘으로 대신한다). 모든 그림이 인게임과 같은 비율로 그려진다.
/// [mult]는 한 장면의 그림들을 함께 키울 때 쓴다 (서로의 비율은 그대로).
Widget _sprite(String name, {double mult = 1}) {
  final height = (_gameHeight[name] ?? 400) * _spriteK * mult;
  return Image.asset(
    'assets/rhythm/art/$name.png',
    height: height,
    fit: BoxFit.contain,
    alignment: Alignment.bottomCenter,
    errorBuilder: (_, _, _) => Icon(Icons.person_rounded, size: height * 0.5, color: _ink),
  );
}

Widget _numberBadge(String t, {bool me = false}) => Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: me ? _rhythmColor : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: _ink, width: 3),
      ),
      child: Text(
        t,
        style: TextStyle(fontSize: me ? 16 : 20, fontWeight: FontWeight.w900, color: me ? Colors.white : _ink),
      ),
    );

class _SquadArt extends StatelessWidget {
  const _SquadArt();

  @override
  Widget build(BuildContext context) {
    Widget member(String sprite, String badge, {bool me = false}) => SizedBox(
          width: 78,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(height: 150, child: Align(alignment: Alignment.bottomCenter, child: _sprite(sprite, mult: 1.2))),
              const SizedBox(height: 8),
              _numberBadge(badge, me: me),
            ],
          ),
        );
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            member('c0_idle', '1'),
            member('c1_idle', '2'),
            member('c2_idle', '3'),
            member('c3_idle', '나', me: true),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 4; i++) ...[
              if (i > 0) const Icon(Icons.chevron_right_rounded, color: _ink, size: 26),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: i == 3 ? _rhythmColor : const Color(0xFFCFC3A8),
                  shape: BoxShape.circle,
                  border: Border.all(color: _ink, width: 2.5),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        const ArtLabel('한 박씩 차례로 → 마지막이 내 차례', color: _rhythmColor, filled: false),
      ],
    );
  }
}

/// 가로로 놓인 화면 그림: 왼쪽 절반 / 오른쪽 절반.
Widget _phoneHalves({required Widget left, required Widget right, bool leftOn = false, bool rightOn = false}) {
  Widget half(Widget child, String label, bool on) => Expanded(
        child: Container(
          decoration: BoxDecoration(
            color: on ? _rhythmColor.withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _ink, width: 3),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              child,
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: _ink)),
            ],
          ),
        ),
      );
  return Row(
    children: [
      half(left, '왼쪽', leftOn),
      const SizedBox(width: 12),
      half(right, '오른쪽', rightOn),
    ],
  );
}

class _SideTapArt extends StatelessWidget {
  const _SideTapArt();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ArtLabel('앞사람이 왼쪽을 쳤다면', color: _rhythmColor, filled: false, fontSize: 13),
            Icon(Icons.arrow_downward_rounded, color: _ink),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _phoneHalves(
            left: const TapPulse(size: 100, color: _rhythmColor),
            right: const SizedBox(height: 100),
            leftOn: true,
          ),
        ),
      ],
    );
  }
}

class _DoubleTapArt extends StatelessWidget {
  const _DoubleTapArt();

  @override
  Widget build(BuildContext context) {
    Widget dot() => Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _rhythmColor,
            shape: BoxShape.circle,
            border: Border.all(color: _ink, width: 3),
          ),
        );
    return Column(
      children: [
        const ArtLabel('따다닥! 같은 쪽을 빠르게 두 번', color: _rhythmColor, filled: false, fontSize: 14),
        const SizedBox(height: 12),
        Expanded(
          child: _phoneHalves(
            left: const SizedBox(height: 100),
            right: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [dot(), const SizedBox(width: 12), dot()],
            ),
            rightOn: true,
          ),
        ),
      ],
    );
  }
}

class _HoldArt extends StatelessWidget {
  const _HoldArt();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Column(
              children: [
                SizedBox(height: 150, child: _sprite('c3_windup')),
                const SizedBox(height: 6),
                const TapPulse(size: 90, hold: true, color: _rhythmColor),
                const Text('꾹 누르면 힘이 모여요', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 90),
              child: Icon(Icons.arrow_forward_rounded, size: 40, color: _ink),
            ),
            Column(
              children: [
                SizedBox(height: 150, child: _sprite('c3_strike')),
                const SizedBox(height: 6),
                const Icon(Icons.back_hand_outlined, size: 56, color: _rhythmColor),
                const Text('손을 떼면 쾅!', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

class _SwipeArt extends StatelessWidget {
  const _SwipeArt();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomCenter, child: SizedBox(height: 150, child: _sprite('c3_side_ready')))),
            const Padding(
              padding: EdgeInsets.only(bottom: 50),
              child: Icon(Icons.swipe_right_alt_rounded, size: 64, color: _rhythmColor),
            ),
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.bottomCenter, child: SizedBox(height: 150, child: _sprite('c3_side_swing')))),
          ],
        ),
        const SizedBox(height: 14),
        const ArtLabel('가로로 쓱! 화살표 쪽으로', color: _rhythmColor, filled: false),
      ],
    );
  }
}

class _GuardArt extends StatelessWidget {
  const _GuardArt();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SizedBox(height: 120, child: _sprite('slime_red_ready', mult: 1.22)),
            const Padding(
              padding: EdgeInsets.only(bottom: 30),
              child: Icon(Icons.swipe_up_rounded, size: 64, color: _rhythmColor),
            ),
            SizedBox(height: 150, child: _sprite('c3_windup')),
          ],
        ),
        const SizedBox(height: 12),
        const ArtLabel('덮칠 때 위로 쓱!', color: _rhythmColor, filled: false),
        const SizedBox(height: 10),
        const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_rounded, size: 36, color: Color(0xFFE5484D)),
            Icon(Icons.favorite_rounded, size: 36, color: Color(0xFFE5484D)),
            Icon(Icons.favorite_border_rounded, size: 36, color: Color(0xFFB9A9A9)),
            SizedBox(width: 10),
            Text('못 막으면 하트가 깎여요', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ],
        ),
      ],
    );
  }
}

class _StarsArt extends StatelessWidget {
  const _StarsArt();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < 3; i++)
              Icon(
                Icons.star_rounded,
                size: 76,
                color: i < 2 ? const Color(0xFFFFB400) : const Color(0xFFCFC3A8),
              ),
          ],
        ),
        const SizedBox(height: 8),
        const ArtLabel('별 2개 이상이면 통과!', color: _rhythmColor),
        const SizedBox(height: 26),
        const Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.center,
          children: [
            ArtLabel('완벽!', color: Color(0xFF2E9E5B), fontSize: 16),
            ArtLabel('좋아요', color: Color(0xFF3E7BFA), fontSize: 16),
            ArtLabel('놓쳤어요', color: Color(0xFF8A8F99), fontSize: 16),
          ],
        ),
      ],
    );
  }
}
