import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../net/lan_discovery.dart';
import '../../../net/lan_screens.dart';
import '../core/prophecy_rules.dart';
import 'prophecy_board.dart';
import 'prophecy_screen.dart';
import 'prophecy_setup_screen.dart';

export '../../../net/lan_screens.dart' show kRandomSide;

const String _game = 'prophecy';

/// 예언의 같은 Wi‑Fi로 함께 하기 첫 화면: 방을 만들거나, 만들어진 방을 찾아 들어간다.
///
/// 같은 공유기에 연결된 두 기기끼리 직접 이어진다 (인터넷·서버 필요 없음). 이어진 뒤에는 두 기기가 같은 판을 보며
/// 차례로 수를 주고받는다. (연결 방식은 `lib/net/`, 판 진행은 [ProphecyScreen]의 Wi‑Fi 모드)
class ProphecyWifiScreen extends StatelessWidget {
  const ProphecyWifiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LanChooseScreen(
      title: '예언 · 같은 Wi‑Fi로 함께',
      color: kProphColor,
      recordsGame: _game,
      createRoom: (_) => const ProphecySetupScreen(mode: PlayMode.wifi),
      findRoom: (_) => const ProphecyJoinScreen(),
    );
  }
}

/// 방을 열고 상대가 들어오기를 기다리는 화면. 상대가 들어오면 바로 게임이 시작된다.
class ProphecyHostScreen extends StatelessWidget {
  const ProphecyHostScreen({
    super.key,
    required this.rows,
    required this.cols,
    required this.hostSide,
    this.gamePort = kLanGamePort,
    this.discoveryPort = kLanDiscoveryPort,
  });

  final int rows, cols;

  /// 내가 맡을 쪽 (0 = 먼저, 1 = 나중, [kRandomSide] = 상대가 들어올 때 무작위).
  final int hostSide;

  /// (시험용) 연결을 기다리는 포트와 방 찾기 응답 포트.
  final int gamePort, discoveryPort;

  String get _sideText => switch (hostSide) {
        0 => '내가 먼저 쓰기',
        1 => '내가 나중에 쓰기',
        _ => '먼저/나중은 상대가 들어오면 무작위로',
      };

  @override
  Widget build(BuildContext context) {
    return LanHostScreen(
      game: _game,
      gameName: '예언',
      info: {'rows': rows, 'cols': cols, 'hostSide': hostSide},
      summary: ['표 $rows×$cols', _sideText],
      gamePort: gamePort,
      discoveryPort: discoveryPort,
      onGuest: () {
        final mySide = hostSide == kRandomSide ? Random().nextInt(2) : hostSide;
        return LanStart(
          message: {'rows': rows, 'cols': cols, 'side': 1 - mySide},
          hostScreen: (conn, desk) => ProphecyScreen(mode: PlayMode.wifi, rows: rows, cols: cols, humanSide: mySide, link: conn, rejoinDesk: desk),
        );
      },
    );
  }
}

/// 같은 Wi‑Fi에서 열린 방을 찾아 들어가는 화면. 주소를 직접 입력해서 들어갈 수도 있다.
class ProphecyJoinScreen extends StatelessWidget {
  const ProphecyJoinScreen({super.key, this.discoveryPort = kLanDiscoveryPort, this.extraTargets = const []});

  /// (시험용) 방 찾기 포트와 추가로 물어볼 주소.
  final int discoveryPort;
  final List<String> extraTargets;

  @override
  Widget build(BuildContext context) {
    return LanJoinScreen(
      game: _game,
      color: kProphColor,
      discoveryPort: discoveryPort,
      extraTargets: extraTargets,
      roomTitle: (r) => '표 ${r.info['rows']}×${r.info['cols']}',
      roomSubtitle: (r) => switch (r.info['hostSide']) {
            0 => '방 만든 사람이 먼저 쓰기',
            1 => '방 만든 사람이 나중에 쓰기',
            _ => '먼저/나중은 들어가면 정해져요',
          },
      buildGame: (m, conn) {
        final rows = m['rows'], cols = m['cols'], side = m['side'];
        if (rows is! int || cols is! int || side is! int || rows < kMinSide || rows > kMaxSide || cols < kMinSide || cols > kMaxSide || (side != 0 && side != 1)) {
          return null;
        }
        return ProphecyScreen(mode: PlayMode.wifi, rows: rows, cols: cols, humanSide: side, link: conn);
      },
    );
  }
}
