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
          title: '별을 모아 다음 코스로',
          body: '정확하게 칠수록 별이 많아져요. 별 2개 이상이면 다음 코스가 열려요.\n'
              '소리를 켜고 박자를 들으면서 하면 훨씬 쉬워요. 소리가 화면과 어긋나는 느낌이 들면 '
              '메뉴 아래의 "박자 보정"을 해 보세요.',
          art: (context, accent) => const ArtCanvas(width: 340, height: 280, child: _StarsArt()),
        ),
      ],
    );

/// 캐릭터 그림 (없으면 아이콘으로 대신한다).
Widget _sprite(String name, {required double height}) => Image.asset(
      'assets/rhythm/art/$name.png',
      height: height,
      fit: BoxFit.contain,
      alignment: Alignment.bottomCenter,
      errorBuilder: (_, _, _) => Icon(Icons.person_rounded, size: height * 0.5, color: _ink),
    );

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
              SizedBox(height: 150, child: Align(alignment: Alignment.bottomCenter, child: _sprite(sprite, height: me ? 148 : 130))),
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
            member('c0_strike', '1'),
            member('c1_strike', '2'),
            member('c2_strike', '3'),
            member('c3_windup', '나', me: true),
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
                SizedBox(height: 150, child: _sprite('c3_windup', height: 148)),
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
                SizedBox(height: 150, child: _sprite('c3_strike', height: 112)),
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
