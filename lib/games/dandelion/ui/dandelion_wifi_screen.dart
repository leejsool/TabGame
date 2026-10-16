import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../net/lan_discovery.dart';
import '../../../net/lan_screens.dart';
import '../core/dandelion_rules.dart';
import 'dandelion_art.dart';
import 'dandelion_screen.dart';
import 'dandelion_setup_screen.dart';

export '../../../net/lan_screens.dart' show kRandomSide;

const String _game = 'dandelion';

/// 민들레의 같은 Wi‑Fi로 함께 하기 첫 화면: 방을 만들거나, 만들어진 방을 찾아 들어간다.
///
/// 같은 공유기에 연결된 두 기기끼리 직접 이어진다 (인터넷·서버 필요 없음). 이어진 뒤에는 두 기기가 같은 초원을 보며
/// 꽃 심기와 바람을 차례로 주고받는다. (연결 방식은 `lib/net/`, 판 진행은 [DandelionScreen]의 Wi‑Fi 모드)
class DandelionWifiScreen extends StatelessWidget {
  const DandelionWifiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LanChooseScreen(
      title: '민들레 · 같은 Wi‑Fi로 함께',
      color: kDandelionColor,
      recordsGame: _game,
      createRoom: (_) => const DandelionHostSetupScreen(),
      findRoom: (_) => const DandelionJoinScreen(),
    );
  }
}

/// 방을 열고 상대가 들어오기를 기다리는 화면. 상대가 들어오면 바로 게임이 시작된다.
class DandelionHostScreen extends StatelessWidget {
  const DandelionHostScreen({
    super.key,
    required this.hostRole,
    this.gamePort = kLanGamePort,
    this.discoveryPort = kLanDiscoveryPort,
  });

  /// 내가 맡을 쪽 ([Role.index]. [kRandomSide]면 상대가 들어올 때 무작위).
  final int hostRole;

  /// (시험용) 연결을 기다리는 포트와 방 찾기 응답 포트.
  final int gamePort, discoveryPort;

  @override
  Widget build(BuildContext context) {
    return LanHostScreen(
      game: _game,
      gameName: '민들레',
      info: {'hostRole': hostRole},
      summary: [_roleText(hostRole, mine: true)],
      gamePort: gamePort,
      discoveryPort: discoveryPort,
      onGuest: () {
        final mine = hostRole == kRandomSide ? Random().nextInt(2) : hostRole;
        return LanStart(
          message: {'role': 1 - mine},
          hostScreen: (conn) => DandelionScreen(mode: PlayMode.wifi, humanRole: Role.values[mine], link: conn),
        );
      },
    );
  }
}

String _roleText(int role, {required bool mine}) => switch (role) {
      0 => mine ? '내가 민들레 (꽃을 심어요)' : '방 만든 사람이 민들레',
      1 => mine ? '내가 바람 (씨앗을 날려요)' : '방 만든 사람이 바람',
      _ => mine ? '민들레/바람은 상대가 들어오면 무작위로' : '민들레/바람은 들어가면 정해져요',
    };

/// 같은 Wi‑Fi에서 열린 방을 찾아 들어가는 화면. 주소를 직접 입력해서 들어갈 수도 있다.
class DandelionJoinScreen extends StatelessWidget {
  const DandelionJoinScreen({super.key, this.discoveryPort = kLanDiscoveryPort, this.extraTargets = const []});

  /// (시험용) 방 찾기 포트와 추가로 물어볼 주소.
  final int discoveryPort;
  final List<String> extraTargets;

  @override
  Widget build(BuildContext context) {
    return LanJoinScreen(
      game: _game,
      color: kDandelionColor,
      discoveryPort: discoveryPort,
      extraTargets: extraTargets,
      roomTitle: (r) => '민들레',
      roomSubtitle: (r) => _roleText(r.info['hostRole'] is int ? r.info['hostRole'] as int : kRandomSide, mine: false),
      buildGame: (m, conn) {
        final role = m['role'];
        if (role is! int || role < 0 || role >= Role.values.length) return null;
        return DandelionScreen(mode: PlayMode.wifi, humanRole: Role.values[role], link: conn);
      },
    );
  }
}
