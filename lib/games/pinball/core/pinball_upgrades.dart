import 'dart:math';

import 'package:flutter/material.dart';

/// 업그레이드 한 가지. [tier] 1=흔한 것, 2=귀한 것. [max]번까지 겹쳐 고를 수 있다.
class Upgrade {
  const Upgrade(this.id, this.name, this.desc, this.icon, this.tier, this.max, {this.consumable = false, this.color = const Color(0xFF1B998B)});

  final String id;
  final String name;

  /// 한 번 고를 때 생기는 효과를 말하는 설명.
  final String desc;
  final IconData icon;
  final int tier;
  final int max;

  /// 한 번 쓰면 사라지는 것 (예: 다음 라운드의 시간).
  final bool consumable;
  final Color color;
}

const List<Upgrade> kUpgrades = [
  Upgrade('flip_len', '긴 플리퍼', '플리퍼가 6% 길어져요 (두 번까지, 가운데 구멍은 남아요)', Icons.straighten_rounded, 1, 2, color: Color(0xFFFFB400)),
  Upgrade('flip_pow', '힘센 플리퍼', '플리퍼가 더 빠르고 세게 올라가요', Icons.bolt_rounded, 1, 4, color: Color(0xFFFFB400)),
  Upgrade('bumper_pts', '반짝 범퍼', '범퍼(맞으면 공을 튕겨 내는 둥근 버섯) 점수 +50%', Icons.blur_on_rounded, 1, 5, color: Color(0xFFFF6B6B)),
  Upgrade('target_pts', '표적 사냥꾼', '표적(쓰러지는 알약·판때기)과 잭팟 점수 ×1.5', Icons.gps_fixed_rounded, 1, 3, color: Color(0xFFFF6B6B)),
  Upgrade('combo_time', '느긋한 콤보', '콤보(쉬지 않고 연속으로 맞힌 수)가 끊기기까지 0.8초 더 여유가 생겨요', Icons.hourglass_bottom_rounded, 1, 3, color: Color(0xFFB36BFF)),
  Upgrade('combo_step', '콤보 증폭', '콤보 3번마다 오르는 점수 배수가 더 크게 올라가요', Icons.stacked_line_chart_rounded, 2, 3, color: Color(0xFFB36BFF)),
  Upgrade('time_plus', '시간 연장', '라운드마다 시간 +4초', Icons.more_time_rounded, 1, 5, color: Color(0xFF2F8FDB)),
  Upgrade('guard', '공 보호막', '라운드마다 보호막 1개 충전 (떨어지는 공을 한 번 튕겨 올려요)', Icons.shield_rounded, 2, 3, color: Color(0xFF2F8FDB)),
  Upgrade('extra_ball', '여분 공', '남은 공(목숨)이 1개 늘어나요', Icons.favorite_rounded, 2, 2, color: Color(0xFF2F8FDB)),
  Upgrade('twin', '쌍둥이 공', '발사할 때 공이 1개 더 나와요', Icons.bubble_chart_rounded, 2, 2, color: Color(0xFF1B998B)),
  Upgrade('moon', '달 중력', '중력이 10% 약해져 공이 느리게 떨어져요', Icons.nightlight_round, 1, 3, color: Color(0xFF1B998B)),
  Upgrade('big_ball', '큰 공', '공이 12% 커져서 맞히기 쉬워요', Icons.circle, 1, 2, color: Color(0xFF1B998B)),
  Upgrade('interest', '점수 이자', '라운드를 깰 때마다 지금 점수의 3%를 더 받아요 (다음 라운드 목표 몫의 20%까지)', Icons.savings_rounded, 2, 3, color: Color(0xFF3FB950)),
  Upgrade('coupon', '할인 쿠폰', '상점 카드 값이 15% 싸져요', Icons.sell_rounded, 1, 3, color: Color(0xFF3FB950)),
  Upgrade('gold', '황금 공', '무엇을 맞히든 모든 점수 +15%', Icons.workspace_premium_rounded, 2, 5, color: Color(0xFFFFD84D)),
  Upgrade('time_bonus', '시간 보너스', '라운드를 깰 때 남은 시간 1초마다 이번 라운드 몫의 0.4%를 더 받아요 (다음 라운드 목표 몫의 20%까지)', Icons.timer_rounded, 1, 3, color: Color(0xFF3FB950)),
  Upgrade('calm', '흔들기 달인', '흔들기 게이지가 천천히 차서 틸트가 잘 안 나요', Icons.vibration_rounded, 1, 2, color: Color(0xFF8E9AAF)),
  Upgrade('lane_pts', '궤도 달인', '별 불빛 길(롤오버)과 양옆 큰 궤도 길 점수 +50%', Icons.route_rounded, 1, 4, color: Color(0xFFB36BFF)),
  Upgrade('spin_pts', '팽이 스피너', '스피너(공이 지나가면 빙글빙글 도는 판) 한 바퀴 점수 +50%', Icons.rotate_right_rounded, 1, 4, color: Color(0xFFFF6B6B)),
  Upgrade('hole_pts', '블랙홀 사냥', '블랙홀(가운데 R 마크 구멍)에 공을 넣을 때 점수 +50%, 멀티볼 점수도 커져요', Icons.circle_outlined, 2, 3, color: Color(0xFF8E4EC6)),
  Upgrade('time_pack', '시간 팩', '다음 라운드 시작할 때 시간 +12초 (한 번)', Icons.alarm_add_rounded, 1, 99, consumable: true, color: Color(0xFF2F8FDB)),
];

/// 긴 플리퍼 한 번에 늘어나는 비율. 두 번 모으고 큰 공을 두 번 모아도 두 플리퍼 사이로 공이 빠질 틈이 남는 만큼만.
const double kFlipLenStep = 0.06;

Upgrade upgradeById(String id) => kUpgrades.firstWhere((u) => u.id == id);

/// 고른 업그레이드들이 규칙·물리에 주는 영향을 한 곳에 모은 것.
class PinballMods {
  PinballMods(Map<String, int> s)
      : flipLen = 1 + kFlipLenStep * (s['flip_len'] ?? 0),
        flipPow = 1 + 0.12 * (s['flip_pow'] ?? 0),
        bumperMul = 1 + 0.5 * (s['bumper_pts'] ?? 0),
        targetMul = pow(1.5, s['target_pts'] ?? 0).toDouble(),
        comboExtra = 0.8 * (s['combo_time'] ?? 0),
        comboStep = 0.25 + 0.12 * (s['combo_step'] ?? 0),
        roundTime = 4.0 * (s['time_plus'] ?? 0),
        shieldsPerRound = s['guard'] ?? 0,
        twin = s['twin'] ?? 0,
        gravity = pow(0.9, s['moon'] ?? 0).toDouble(),
        ballScale = 1 + 0.12 * (s['big_ball'] ?? 0),
        interest = 0.03 * (s['interest'] ?? 0),
        price = max(0.4, 1 - 0.15 * (s['coupon'] ?? 0)),
        scoreMul = 1 + 0.15 * (s['gold'] ?? 0),
        timeBonus = 0.004 * (s['time_bonus'] ?? 0),
        tiltEase = pow(0.65, s['calm'] ?? 0).toDouble(),
        laneMul = 1 + 0.5 * (s['lane_pts'] ?? 0),
        spinMul = 1 + 0.5 * (s['spin_pts'] ?? 0),
        holeMul = 1 + 0.5 * (s['hole_pts'] ?? 0);

  final double flipLen, flipPow, bumperMul, targetMul, comboExtra, comboStep, roundTime;
  final int shieldsPerRound;
  final int twin;
  final double gravity, ballScale, interest, price, scoreMul, timeBonus, tiltEase, laneMul, spinMul, holeMul;
}
