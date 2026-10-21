import 'package:flutter/material.dart';

import 'pinball_hud.dart' show kPinballColor;

/// "점수 계산법": 판의 부품마다 받는 점수, 배수, 상점 값이 오르는 법을 한 화면에 풀어 쓴다.
class PinballScoringScreen extends StatelessWidget {
  const PinballScoringScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PinballScoringScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('점수 계산법')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                const _Formula(),
                const SizedBox(height: 18),
                const _Title('판에서 맞히는 것들 (1라운드 기본 점수)'),
                const _Part(art: 'bumper_red', name: '범퍼', what: '둥근 버섯 모양. 맞으면 공을 세게 튕겨 내요.', pts: '60'),
                const _Part(art: 'tri_red', name: '슬링샷', what: '플리퍼 위 양쪽 세모 고무. 공을 옆으로 차 내요.', pts: '25'),
                const _Part(art: 'target_blue', name: '표적', what: '맞으면 쓰러지는 알약·판때기.', pts: '250'),
                const _Part(icon: Icons.done_all_rounded, name: '표적 묶음 완성', what: '왼쪽(또는 오른쪽) 표적 세 개를 다 쓰러뜨리면.', pts: '800'),
                const _Part(icon: Icons.emoji_events_rounded, name: '잭팟', what: '아래 접시의 알약 4개를 모두 쓰러뜨리면.', pts: '1,500'),
                const _Part(art: 'star', name: '별 불빛 길 (롤오버)', what: '공이 지나가면 별에 불이 켜져요. 모두 켜면 600점 + 이번 라운드 배수 +0.25 (최대 +2).', pts: '100'),
                const _Part(icon: Icons.route_rounded, name: '궤도 길', what: '판 양옆을 크게 도는 길을 한 바퀴 돌면.', pts: '400'),
                const _Part(icon: Icons.rotate_right_rounded, name: '스피너', what: '공이 지나가면 빙글빙글 도는 판. 한 바퀴마다.', pts: '15'),
                const _Part(art: 'logo_r', name: '블랙홀', what: '가운데 R 마크 구멍. 공이 빨려 들어가면 점수를 주고 다시 뱉어요.', pts: '400'),
                const _Part(icon: Icons.bubble_chart_rounded, name: '멀티볼', what: '양쪽 표적 묶음을 다 완성하면 블랙홀에 불이 켜져요. 그때 블랙홀에 넣으면 공이 여러 개!', pts: '3,000'),
                const SizedBox(height: 18),
                const _Title('배수 — 점수가 불어나는 법'),
                const _Line(Icons.trending_up_rounded, '라운드 배율', '라운드가 하나 오를 때마다 같은 걸 맞혀도 ×1.3배씩 커져요. (5라운드면 약 ×2.9)'),
                const _Line(Icons.local_fire_department_rounded, '콤보 배수', '2.5초 안에 다음 것을 또 맞히면 콤보가 이어져요. 콤보 3번마다 배수가 +0.25 (최대 ×5). 공을 놓치거나 쉬면 콤보가 끊겨요.'),
                const _Line(Icons.star_rounded, '별 불빛 보너스', '별 불빛을 다 켤 때마다 이번 라운드 동안 배수 +0.25 (라운드가 바뀌면 사라져요).'),
                const _Line(Icons.auto_awesome_rounded, '업그레이드', '"황금 공", "반짝 범퍼" 같은 업그레이드가 점수를 더 키워요.'),
                const SizedBox(height: 18),
                const _Title('라운드와 점수 지갑'),
                const _Line(Icons.flag_rounded, '목표 점수', '라운드마다 제한 시간 안에 목표 점수까지 모아야 해요. 못 모으면 끝이에요.'),
                const _Line(Icons.favorite_rounded, '남은 공 3개', '공이 아래로 빠지면 공이 하나 줄어요. 3개를 다 놓치면 끝이에요.'),
                const _Line(Icons.health_and_safety_rounded, '볼 세이브', '공을 쏜 뒤 8초 동안은 양쪽 바깥 길에 노란 "세이브" 불이 켜져요. 그동안 공이 빠지면 공이 줄지 않고 다시 쏴 줘요 (한 번만). 상점의 "볼 세이브 켜기"를 사면 시간 제한 없이 켜 둘 수 있어요.'),
                const _Line(Icons.alt_route_rounded, '바깥 길과 안쪽 길', '플리퍼 옆 맨 바깥 길로 들어가면 그대로 빠지고, 그 바로 안쪽 길로 들어가면 플리퍼 위로 굴러 와서 다시 칠 수 있어요.'),
                const _Line(Icons.account_balance_wallet_rounded, '점수가 곧 돈', '상점에서 업그레이드를 사면 그만큼 점수가 줄어요. 다음 목표는 그대로라서 다시 채워야 해요.'),
                const _Line(Icons.sell_rounded, '상점 값', '라운드가 오를수록, 같은 걸 또 살수록(×1.6), 업그레이드를 많이 모을수록(1개마다 +10%) 비싸져요.'),
                const _Line(Icons.timer_rounded, '라운드 끝 보너스', '"시간 보너스"는 남은 시간만큼, "점수 이자"는 지금 점수에 비례해서 더 받아요 (업그레이드를 골랐을 때만). 각각 다음 라운드 목표 몫의 20%까지만 받아요.'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Formula extends StatelessWidget {
  const _Formula();

  @override
  Widget build(BuildContext context) {
    const s = TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, height: 1.4);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kPinballColor, borderRadius: BorderRadius.circular(18)),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('받는 점수 =', style: s),
          Text('기본 점수 × 라운드 배율\n× 콤보 배수 × 업그레이드', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, height: 1.4)),
          SizedBox(height: 6),
          Text('맞힐 때마다 공 옆에 +점수가 떠요. 노란 글씨면 배수가 붙은 거예요.', style: TextStyle(color: Colors.white70, fontSize: 13.5)),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
    );
  }
}

/// 판 부품 한 줄: 그림(또는 아이콘), 이름, 설명, 기본 점수.
class _Part extends StatelessWidget {
  const _Part({this.art, this.icon, required this.name, required this.what, required this.pts});

  final String? art;
  final IconData? icon;
  final String name, what, pts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: scheme.outlineVariant)),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: const Color(0xFF1B2747), borderRadius: BorderRadius.circular(12)),
              child: art != null ? Image.asset('assets/pinball/$art.png', fit: BoxFit.contain) : Icon(icon, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w900)),
                  Text(what, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant, height: 1.3)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text('$pts점', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: kPinballColor)),
          ],
        ),
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line(this.icon, this.title, this.body);

  final IconData icon;
  final String title, body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: kPinballColor, size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: '$title  ', style: const TextStyle(fontWeight: FontWeight.w900)),
                TextSpan(text: body, style: TextStyle(color: scheme.onSurfaceVariant)),
              ]),
              style: const TextStyle(fontSize: 14, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}
