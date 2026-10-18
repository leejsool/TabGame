import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../net/lan_discovery.dart';
import '../../../net/lan_screens.dart';
import '../core/goblet_rules.dart';
import 'goblet_piece.dart';
import 'goblet_screen.dart';
import 'goblet_setup_screen.dart';

export '../../../net/lan_screens.dart' show kRandomSide;

const String _game = 'goblet_gobblers';

/// 고블렛 고블러스의 같은 Wi‑Fi로 함께 하기 첫 화면: 방을 만들거나, 만들어진 방을 찾아 들어간다.
///
/// 같은 공유기에 연결된 두 기기끼리 직접 이어진다 (인터넷·서버 필요 없음). 이어진 뒤에는 두 기기가 같은 판을 보며
/// 차례로 수를 주고받는다. (연결 방식은 `lib/net/`, 판 진행은 [GobbletScreen]의 Wi‑Fi 모드)
class GobbletWifiScreen extends StatelessWidget {
  const GobbletWifiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LanChooseScreen(
      title: '고블렛 고블러스 · 같은 Wi‑Fi로 함께',
      color: TeamPalette.red.dark,
      recordsGame: _game,
      createRoom: (_) => const GobbletHostSetupScreen(),
      findRoom: (_) => const GobbletJoinScreen(),
    );
  }
}

String _teamText(int team, {required bool mine}) => switch (team) {
      0 => mine ? '나는 빨강팀 (먼저 시작)' : '방 만든 사람이 빨강팀 (먼저 시작)',
      1 => mine ? '나는 파랑팀 (나중에 시작)' : '방 만든 사람이 파랑팀 (나중에 시작)',
      _ => mine ? '팀은 상대가 들어오면 무작위로' : '팀은 들어가면 정해져요',
    };

/// 방을 열고 상대가 들어오기를 기다리는 화면. 상대가 들어오면 바로 게임이 시작된다.
class GobbletHostScreen extends StatelessWidget {
  const GobbletHostScreen({
    super.key,
    required this.hostTeam,
    this.gamePort = kLanGamePort,
    this.discoveryPort = kLanDiscoveryPort,
  });

  /// 내가 맡을 팀 (0 = 빨강팀, 1 = 파랑팀, [kRandomSide] = 상대가 들어올 때 무작위).
  final int hostTeam;

  /// (시험용) 연결을 기다리는 포트와 방 찾기 응답 포트.
  final int gamePort, discoveryPort;

  @override
  Widget build(BuildContext context) {
    return LanHostScreen(
      game: _game,
      gameName: '고블렛 고블러스',
      info: {'hostTeam': hostTeam},
      summary: [_teamText(hostTeam, mine: true)],
      gamePort: gamePort,
      discoveryPort: discoveryPort,
      onGuest: () {
        final mine = hostTeam == kRandomSide ? Random().nextInt(2) : hostTeam;
        return LanStart(
          message: {'team': 1 - mine},
          hostScreen: (conn, desk) => GobbletScreen(mode: PlayMode.wifi, humanTeam: Team.values[mine], link: conn, rejoinDesk: desk),
        );
      },
    );
  }
}

/// 같은 Wi‑Fi에서 열린 방을 찾아 들어가는 화면. 주소를 직접 입력해서 들어갈 수도 있다.
class GobbletJoinScreen extends StatelessWidget {
  const GobbletJoinScreen({super.key, this.discoveryPort = kLanDiscoveryPort, this.extraTargets = const []});

  /// (시험용) 방 찾기 포트와 추가로 물어볼 주소.
  final int discoveryPort;
  final List<String> extraTargets;

  @override
  Widget build(BuildContext context) {
    return LanJoinScreen(
      game: _game,
      color: TeamPalette.red.dark,
      discoveryPort: discoveryPort,
      extraTargets: extraTargets,
      roomTitle: (r) => '고블렛 고블러스',
      roomSubtitle: (r) => _teamText(r.info['hostTeam'] is int ? r.info['hostTeam'] as int : kRandomSide, mine: false),
      buildGame: (m, conn) {
        final team = m['team'];
        if (team is! int || (team != 0 && team != 1)) return null;
        return GobbletScreen(mode: PlayMode.wifi, humanTeam: Team.values[team], link: conn);
      },
    );
  }
}
