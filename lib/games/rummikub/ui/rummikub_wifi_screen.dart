import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../net/lan_discovery.dart';
import '../../../net/lan_screens.dart';
import 'rummikub_screen.dart';
import 'rummikub_setup_screen.dart';
import 'rummikub_tiles.dart';

/// 방을 만드는 쪽이 "내 순서"를 상대가 들어올 때 무작위로 정하겠다고 할 때의 값.
const int kRkRandomSide = kRandomSide;

const String _game = 'rummikub';

/// 루미큐브의 같은 Wi‑Fi로 함께 하기 첫 화면: 방을 만들거나, 만들어진 방을 찾아 들어간다.
///
/// 남의 패가 보이면 안 되니, 사람과는 각자 자기 기기로 한다. 두 기기가 같은 씨앗으로 패를 나눈 뒤
/// 서로의 차례 결과(판의 모습, 또는 타일 뽑기)만 주고받는다.
class RummikubWifiScreen extends StatelessWidget {
  const RummikubWifiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LanChooseScreen(
      title: '루미큐브 · 같은 Wi‑Fi로 함께',
      color: kRkWood,
      recordsGame: _game,
      createRoom: (_) => const RummikubSetupScreen(mode: PlayMode.wifi),
      findRoom: (_) => const RummikubJoinScreen(),
    );
  }
}

String _sideText(int side, {required bool mine}) => switch (side) {
      0 => mine ? '내가 먼저 시작' : '방 만든 사람이 먼저 시작',
      1 => mine ? '내가 나중에 시작' : '방 만든 사람이 나중에 시작',
      _ => mine ? '먼저/나중은 상대가 들어오면 무작위로' : '먼저/나중은 들어가면 정해져요',
    };

/// 방을 열고 상대가 들어오기를 기다리는 화면. 상대가 들어오면 바로 게임이 시작된다.
class RummikubHostScreen extends StatelessWidget {
  const RummikubHostScreen({
    super.key,
    required this.hostSide,
    this.gamePort = kLanGamePort,
    this.discoveryPort = kLanDiscoveryPort,
    this.seed,
  });

  /// 내가 맡을 순서 (0 = 먼저, 1 = 나중, [kRkRandomSide] = 상대가 들어올 때 무작위).
  final int hostSide;

  /// (시험용) 연결을 기다리는 포트와 방 찾기 응답 포트, 패를 나눌 씨앗.
  final int gamePort, discoveryPort;
  final int? seed;

  @override
  Widget build(BuildContext context) {
    return LanHostScreen(
      game: _game,
      gameName: '루미큐브',
      info: {'hostSide': hostSide},
      summary: [_sideText(hostSide, mine: true)],
      gamePort: gamePort,
      discoveryPort: discoveryPort,
      onGuest: () {
        final rng = Random();
        final mySide = hostSide == kRkRandomSide ? rng.nextInt(2) : hostSide;
        final s = seed ?? rng.nextInt(1 << 30);
        return LanStart(
          message: {'side': 1 - mySide, 'seed': s},
          hostScreen: (conn) => RummikubScreen(mode: PlayMode.wifi, humanSeat: mySide, seed: s, link: conn),
        );
      },
    );
  }
}

/// 같은 Wi‑Fi에서 열린 방을 찾아 들어가는 화면. 주소를 직접 입력해서 들어갈 수도 있다.
class RummikubJoinScreen extends StatelessWidget {
  const RummikubJoinScreen({super.key, this.discoveryPort = kLanDiscoveryPort, this.extraTargets = const []});

  /// (시험용) 방 찾기 포트와 추가로 물어볼 주소.
  final int discoveryPort;
  final List<String> extraTargets;

  @override
  Widget build(BuildContext context) {
    return LanJoinScreen(
      game: _game,
      color: kRkWood,
      discoveryPort: discoveryPort,
      extraTargets: extraTargets,
      roomTitle: (r) => '루미큐브',
      roomSubtitle: (r) => _sideText(r.info['hostSide'] is int ? r.info['hostSide'] as int : kRkRandomSide, mine: false),
      buildGame: (m, conn) {
        final side = m['side'], seed = m['seed'];
        if (side is! int || (side != 0 && side != 1) || seed is! int) return null;
        return RummikubScreen(mode: PlayMode.wifi, humanSeat: side, seed: seed, link: conn);
      },
    );
  }
}
