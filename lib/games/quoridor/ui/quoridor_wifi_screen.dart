import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../core/settings_scope.dart';
import '../../../net/lan_discovery.dart';
import '../../../net/lan_screens.dart';
import '../core/quoridor_ai.dart' show QLevel;
import '../core/quoridor_rules.dart' show wallsPerPlayer;
import 'quoridor_board.dart';
import 'quoridor_screen.dart';
import 'quoridor_setup_screen.dart';

const String _game = 'quoridor';

/// 쿼리도의 같은 Wi‑Fi로 함께 하기 첫 화면: 방을 만들거나, 만들어진 방을 찾아 들어간다. (2명 또는 4명)
///
/// 같은 공유기에 연결된 두 기기끼리 직접 이어진다 (인터넷·서버 필요 없음). 이어진 뒤에는 두 기기가 같은 판을 보며
/// 차례로 수를 주고받는다. (연결 방식은 `lib/net/`, 판 진행은 [QuoridorScreen]의 Wi‑Fi 모드)
class QuoridorWifiScreen extends StatelessWidget {
  const QuoridorWifiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LanChooseScreen(
      title: '쿼리도 · 같은 Wi‑Fi로 함께',
      color: kQuoridorColor,
      recordsGame: _game,
      createRoom: (_) => const QuoridorSetupScreen(mode: PlayMode.wifi),
      findRoom: (_) => const QuoridorJoinScreen(),
    );
  }
}

String _sideText(int side, {required bool mine}) => switch (side) {
      0 => mine ? '내가 먼저 시작' : '방 만든 사람이 먼저 시작',
      1 => mine ? '내가 두 번째로 시작' : '방 만든 사람이 두 번째',
      2 => mine ? '내가 세 번째로 시작' : '방 만든 사람이 세 번째',
      3 => mine ? '내가 네 번째로 시작' : '방 만든 사람이 네 번째',
      _ => mine ? '순서는 모두 모이면 무작위로' : '순서는 시작할 때 정해져요',
    };

/// 방을 열고 사람들이 모이기를 기다리는 화면. [players]명이 모두 모이면 바로 게임이 시작된다.
///
/// 방장 기기가 모든 수를 받아 확인하고 다른 사람들에게 전해 준다 (4명일 때).
class QuoridorHostScreen extends StatelessWidget {
  const QuoridorHostScreen({
    super.key,
    required this.hostSide,
    this.players = 2,
    this.cpus = 0,
    this.level = QLevel.normal,
    this.gamePort = kLanGamePort,
    this.discoveryPort = kLanDiscoveryPort,
  });

  /// 내가 맡을 자리 (0 = 먼저 … 3, [kRandomSide] = 모두 모이면 무작위).
  final int hostSide;

  /// 모두 몇 명이 하는지 (CPU 포함, 2 또는 4).
  final int players;

  /// 그중 CPU가 몇 명인지 (사람은 둘 이상이어야 한다). CPU의 수는 방을 연 기기가 정한다.
  final int cpus;
  final QLevel level;

  /// (시험용) 연결을 기다리는 포트와 방 찾기 응답 포트.
  final int gamePort, discoveryPort;

  @override
  Widget build(BuildContext context) {
    final hostNick = SettingsScope.of(context).nickname;
    final humans = players - cpus;
    return LanLobbyScreen(
      game: _game,
      gameName: '쿼리도',
      info: {'hostSide': hostSide, 'players': players, 'cpus': cpus},
      summary: ['${roomSizeText(players, cpus)} · 벽 ${wallsPerPlayer(players)}개씩', if (cpus > 0) 'CPU ${level.label}', _sideText(hostSide, mine: true)],
      needGuests: humans - 1,
      gamePort: gamePort,
      discoveryPort: discoveryPort,
      onFull: (guests) {
        final rng = Random();
        final seats = [for (var i = 0; i < players; i++) i];
        final int hostSeat;
        if (hostSide == kRandomSide) {
          seats.shuffle(rng);
          hostSeat = seats.removeAt(0);
        } else {
          hostSeat = hostSide;
          seats
            ..remove(hostSeat)
            ..shuffle(rng);
        }
        // 남은 자리 중 앞에서부터 손님이, 나머지는 CPU가 앉는다
        final cpuSeats = seats.sublist(guests.length)..sort();
        final names = List<String>.filled(players, '');
        names[hostSeat] = hostNick;
        for (var i = 0; i < guests.length; i++) {
          names[seats[i]] = guests[i].peerNick;
        }
        for (var i = 0; i < cpuSeats.length; i++) {
          names[cpuSeats[i]] = 'CPU ${i + 1}';
        }
        return LanLobbyPlan(
          messages: [for (var i = 0; i < guests.length; i++) {'side': seats[i], 'players': players, 'names': names, 'cpus': cpuSeats}],
          hostScreen: (conns) => QuoridorScreen(
            mode: PlayMode.wifi,
            players: players,
            humanSeat: hostSeat,
            level: level,
            names: names,
            cpuSeats: cpuSeats,
            links: conns,
            linkSeats: seats.sublist(0, conns.length),
          ),
        );
      },
    );
  }
}

/// 같은 Wi‑Fi에서 열린 방을 찾아 들어가는 화면. 주소를 직접 입력해서 들어갈 수도 있다.
class QuoridorJoinScreen extends StatelessWidget {
  const QuoridorJoinScreen({super.key, this.discoveryPort = kLanDiscoveryPort, this.extraTargets = const []});

  /// (시험용) 방 찾기 포트와 추가로 물어볼 주소.
  final int discoveryPort;
  final List<String> extraTargets;

  @override
  Widget build(BuildContext context) {
    return LanJoinScreen(
      game: _game,
      color: kQuoridorColor,
      discoveryPort: discoveryPort,
      extraTargets: extraTargets,
      roomTitle: (r) {
        final n = r.info['players'] is int ? r.info['players'] as int : 2;
        final cpus = r.info['cpus'] is int ? r.info['cpus'] as int : 0;
        final joined = r.info['joined'] is int ? r.info['joined'] as int : 1;
        return n == 2 ? '쿼리도 · 2명' : '쿼리도 · ${roomSizeText(n, cpus)} ($joined/${n - cpus})';
      },
      roomSubtitle: (r) => _sideText(r.info['hostSide'] is int ? r.info['hostSide'] as int : kRandomSide, mine: false),
      buildGame: (m, conn) {
        final side = m['side'];
        final players = m['players'] is int ? m['players'] as int : 2; // (옛 방은 2명)
        if (players != 2 && players != 4) return null;
        if (side is! int || side < 0 || side >= players) return null;
        final raw = m['names'];
        final names = raw is List && raw.length == players ? [for (final n in raw) '$n'] : null;
        final rawCpus = m['cpus'];
        final cpuSeats = rawCpus is List ? [for (final x in rawCpus) if (x is int) x] : <int>[];
        if (cpuSeats.any((x) => x < 0 || x >= players || x == side) || players - cpuSeats.length < 2) return null;
        return QuoridorScreen(mode: PlayMode.wifi, players: players, humanSeat: side, names: names, cpuSeats: cpuSeats, links: [conn]);
      },
    );
  }
}
