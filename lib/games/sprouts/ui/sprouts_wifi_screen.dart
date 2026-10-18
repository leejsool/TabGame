import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../net/lan_discovery.dart';
import '../../../net/lan_screens.dart';
import '../core/sprouts_board.dart';
import 'sprouts_painter.dart';
import 'sprouts_screen.dart';
import 'sprouts_setup_screen.dart';

export '../../../net/lan_screens.dart' show kRandomSide;

const String _game = 'sprouts';

/// 판을 소수점 둘째 자리까지 반올림해 (보낼 때와 같게) 만든 처음 판: 방을 연 쪽과 들어온 쪽이 정확히 같은 판으로 시작한다.
SproutsBoard roundedBoard(SproutsBoard b) =>
    SproutsBoard.fromData([for (final v in b.toData()) (v * 100).roundToDouble() / 100]);

/// 콩나물의 같은 Wi‑Fi로 함께 하기 첫 화면: 방을 만들거나, 만들어진 방을 찾아 들어간다.
///
/// 같은 공유기에 연결된 두 기기끼리 직접 이어진다 (인터넷·서버 필요 없음). 한 수를 둘 때마다 결과 판을 통째로 주고받아
/// 두 기기의 판이 늘 같고, 상대가 그은 선은 펜이 지나가듯 천천히 그려 보여 준다.
/// (연결 방식은 `lib/net/`, 판 진행은 [SproutsScreen]의 Wi‑Fi 모드)
class SproutsWifiScreen extends StatelessWidget {
  const SproutsWifiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LanChooseScreen(
      title: '콩나물 · 같은 Wi‑Fi로 함께',
      color: sproutsColor(0),
      recordsGame: _game,
      createRoom: (_) => const SproutsHostSetupScreen(),
      findRoom: (_) => const SproutsJoinScreen(),
    );
  }
}

/// 방을 열고 상대가 들어오기를 기다리는 화면. 상대가 들어오면 바로 게임이 시작된다.
class SproutsHostScreen extends StatelessWidget {
  const SproutsHostScreen({
    super.key,
    required this.dots,
    required this.hostSide,
    this.gamePort = kLanGamePort,
    this.discoveryPort = kLanDiscoveryPort,
  });

  /// 처음 점의 수.
  final int dots;

  /// 내가 맡을 쪽 (0 = 먼저, 1 = 나중, [kRandomSide] = 상대가 들어올 때 무작위).
  final int hostSide;

  /// (시험용) 연결을 기다리는 포트와 방 찾기 응답 포트.
  final int gamePort, discoveryPort;

  @override
  Widget build(BuildContext context) {
    return LanHostScreen(
      game: _game,
      gameName: '콩나물',
      info: {'dots': dots, 'hostSide': hostSide},
      summary: ['처음 점 $dots개', _sideText(hostSide, mine: true)],
      gamePort: gamePort,
      discoveryPort: discoveryPort,
      onGuest: () {
        final mySide = hostSide == kRandomSide ? Random().nextInt(2) : hostSide;
        final board = roundedBoard(SproutsBoard.initial(dots, Random()));
        return LanStart(
          message: {'dots': dots, 'side': 1 - mySide, 'board': board.toData()},
          hostScreen: (conn, desk) => SproutsScreen(mode: PlayMode.wifi, dotCount: dots, humanSide: mySide, link: conn, isHost: true, initialBoard: board, rejoinDesk: desk),
        );
      },
    );
  }
}

String _sideText(int side, {required bool mine}) => switch (side) {
      0 => mine ? '내가 먼저 시작 (초록 선)' : '방 만든 사람이 먼저 시작',
      1 => mine ? '내가 나중에 시작 (분홍 선)' : '방 만든 사람이 나중에 시작',
      _ => mine ? '먼저/나중은 상대가 들어오면 무작위로' : '먼저/나중은 들어가면 정해져요',
    };

/// 같은 Wi‑Fi에서 열린 방을 찾아 들어가는 화면. 주소를 직접 입력해서 들어갈 수도 있다.
class SproutsJoinScreen extends StatelessWidget {
  const SproutsJoinScreen({super.key, this.discoveryPort = kLanDiscoveryPort, this.extraTargets = const []});

  /// (시험용) 방 찾기 포트와 추가로 물어볼 주소.
  final int discoveryPort;
  final List<String> extraTargets;

  @override
  Widget build(BuildContext context) {
    return LanJoinScreen(
      game: _game,
      color: sproutsColor(0),
      discoveryPort: discoveryPort,
      extraTargets: extraTargets,
      roomTitle: (r) => '처음 점 ${r.info['dots']}개',
      roomSubtitle: (r) => _sideText(r.info['hostSide'] is int ? r.info['hostSide'] as int : kRandomSide, mine: false),
      buildGame: (m, conn) {
        final dots = m['dots'], side = m['side'], data = m['board'];
        if (dots is! int || dots < 2 || dots > 6 || side is! int || (side != 0 && side != 1) || data is! List) return null;
        final SproutsBoard board;
        try {
          board = SproutsBoard.fromData([for (final v in data) (v as num).toDouble()]);
        } catch (_) {
          return null;
        }
        if (board.dots.length != dots || board.curves.isNotEmpty) return null;
        return SproutsScreen(mode: PlayMode.wifi, dotCount: dots, humanSide: side, link: conn, initialBoard: board);
      },
    );
  }
}
