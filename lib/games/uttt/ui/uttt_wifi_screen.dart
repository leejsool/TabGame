import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../net/lan_discovery.dart';
import '../../../net/lan_screens.dart';
import '../core/uttt_rules.dart';
import 'uttt_board.dart';
import 'uttt_screen.dart';
import 'uttt_setup_screen.dart';

export '../../../net/lan_screens.dart' show kRandomSide;

const String _game = 'ultimate_tictactoe';

/// 궁극 틱택토의 같은 Wi‑Fi로 함께 하기 첫 화면: 방을 만들거나, 만들어진 방을 찾아 들어간다.
///
/// 같은 공유기에 연결된 두 기기끼리 직접 이어진다 (인터넷·서버 필요 없음). 이어진 뒤에는 두 기기가 같은 판을 보며
/// 차례로 수를 주고받는다. (연결 방식은 `lib/net/`, 판 진행은 [UtttScreen]의 Wi‑Fi 모드)
class UtttWifiScreen extends StatelessWidget {
  const UtttWifiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LanChooseScreen(
      title: '궁극 틱택토 · 같은 Wi‑Fi로 함께',
      color: kXColor,
      recordsGame: _game,
      createRoom: (_) => const UtttHostSetupScreen(),
      findRoom: (_) => const UtttJoinScreen(),
    );
  }
}

/// 방을 열고 상대가 들어오기를 기다리는 화면. 상대가 들어오면 바로 게임이 시작된다.
class UtttHostScreen extends StatelessWidget {
  const UtttHostScreen({
    super.key,
    required this.hostSide,
    this.gamePort = kLanGamePort,
    this.discoveryPort = kLanDiscoveryPort,
  });

  /// 내가 맡을 표시 ([kX] = 먼저 시작, [kO] = 나중, [kRandomSide] = 상대가 들어올 때 무작위).
  final int hostSide;

  /// (시험용) 연결을 기다리는 포트와 방 찾기 응답 포트.
  final int gamePort, discoveryPort;

  @override
  Widget build(BuildContext context) {
    return LanHostScreen(
      game: _game,
      gameName: '궁극 틱택토',
      info: {'hostSide': hostSide},
      summary: [_sideText(hostSide, mine: true)],
      gamePort: gamePort,
      discoveryPort: discoveryPort,
      onGuest: () {
        final mySide = hostSide == kRandomSide ? Random().nextInt(2) : hostSide;
        return LanStart(
          message: {'side': 1 - mySide},
          hostScreen: (conn, desk) => UtttScreen(mode: PlayMode.wifi, humanSide: mySide, link: conn, rejoinDesk: desk),
        );
      },
    );
  }
}

String _sideText(int side, {required bool mine}) => switch (side) {
      kX => mine ? '내가 X (먼저 시작)' : '방 만든 사람이 X (먼저 시작)',
      kO => mine ? '내가 O (나중에 시작)' : '방 만든 사람이 O (나중에 시작)',
      _ => mine ? 'X/O는 상대가 들어오면 무작위로' : 'X/O는 들어가면 정해져요',
    };

/// 같은 Wi‑Fi에서 열린 방을 찾아 들어가는 화면. 주소를 직접 입력해서 들어갈 수도 있다.
class UtttJoinScreen extends StatelessWidget {
  const UtttJoinScreen({super.key, this.discoveryPort = kLanDiscoveryPort, this.extraTargets = const []});

  /// (시험용) 방 찾기 포트와 추가로 물어볼 주소.
  final int discoveryPort;
  final List<String> extraTargets;

  @override
  Widget build(BuildContext context) {
    return LanJoinScreen(
      game: _game,
      color: kXColor,
      discoveryPort: discoveryPort,
      extraTargets: extraTargets,
      roomTitle: (r) => '궁극 틱택토',
      roomSubtitle: (r) => _sideText(r.info['hostSide'] is int ? r.info['hostSide'] as int : kRandomSide, mine: false),
      buildGame: (m, conn) {
        final side = m['side'];
        if (side is! int || (side != kX && side != kO)) return null;
        return UtttScreen(mode: PlayMode.wifi, humanSide: side, link: conn);
      },
    );
  }
}
