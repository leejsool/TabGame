import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../core/settings_scope.dart';
import '../../../net/lan_discovery.dart';
import '../../../net/lan_screens.dart';
import '../core/davinci_ai.dart';
import 'davinci_screen.dart';
import 'davinci_setup_screen.dart';
import 'davinci_tiles.dart';

export '../../../net/lan_screens.dart' show kRandomSide, roomSizeText;

const String _game = 'davinci_code';

/// 다빈치 코드의 같은 Wi‑Fi로 함께 하기 첫 화면: 방을 만들거나, 만들어진 방을 찾아 들어간다. (2~4명)
///
/// 남의 타일이 보이면 안 되니, 사람과는 각자 자기 기기로 한다. 모든 기기가 같은 씨앗으로 타일을 나눈 뒤
/// 서로의 수(뽑기·맞히기·멈추기)만 주고받는다. 3~4명이면 방장 기기가 모든 수를 받아 확인하고 다른 사람들에게 전해 준다.
class DavinciWifiScreen extends StatelessWidget {
  const DavinciWifiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LanChooseScreen(
      title: '다빈치 코드 · 같은 Wi‑Fi로 함께',
      color: kDavinciColor,
      recordsGame: _game,
      createRoom: (_) => const DavinciSetupScreen(mode: PlayMode.wifi),
      findRoom: (_) => const DavinciJoinScreen(),
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
class DavinciHostScreen extends StatelessWidget {
  const DavinciHostScreen({
    super.key,
    required this.hostSide,
    this.players = 2,
    this.cpus = 0,
    this.level = DvLevel.normal,
    this.gamePort = kLanGamePort,
    this.discoveryPort = kLanDiscoveryPort,
    this.seed,
  });

  /// 내가 맡을 자리 (0 = 먼저 … 3, [kRandomSide] = 모두 모이면 무작위).
  final int hostSide;

  /// 모두 몇 명이 하는지 (CPU 포함, 2~4).
  final int players;

  /// 그중 CPU가 몇 명인지 (사람은 둘 이상이어야 한다). CPU의 수는 방을 연 기기가 정한다.
  final int cpus;
  final DvLevel level;

  /// (시험용) 연결을 기다리는 포트와 방 찾기 응답 포트, 패를 나눌 씨앗.
  final int gamePort, discoveryPort;
  final int? seed;

  @override
  Widget build(BuildContext context) {
    final hostNick = SettingsScope.of(context).nickname;
    final humans = players - cpus;
    return LanLobbyScreen(
      game: _game,
      gameName: '다빈치 코드',
      info: {'hostSide': hostSide, 'players': players, 'cpus': cpus},
      summary: [roomSizeText(players, cpus), if (cpus > 0) 'CPU ${level.label}', _sideText(hostSide, mine: true)],
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
        final s = seed ?? rng.nextInt(1 << 30);
        return LanLobbyPlan(
          messages: [for (var i = 0; i < guests.length; i++) {'side': seats[i], 'players': players, 'names': names, 'cpus': cpuSeats, 'seed': s}],
          hostScreen: (conns) => DavinciScreen(
            mode: PlayMode.wifi,
            players: players,
            humanSeat: hostSeat,
            level: level,
            names: names,
            cpuSeats: cpuSeats,
            seed: s,
            links: conns,
            linkSeats: seats.sublist(0, conns.length),
          ),
        );
      },
    );
  }
}

/// 같은 Wi‑Fi에서 열린 방을 찾아 들어가는 화면. 주소를 직접 입력해서 들어갈 수도 있다.
class DavinciJoinScreen extends StatelessWidget {
  const DavinciJoinScreen({super.key, this.discoveryPort = kLanDiscoveryPort, this.extraTargets = const []});

  /// (시험용) 방 찾기 포트와 추가로 물어볼 주소.
  final int discoveryPort;
  final List<String> extraTargets;

  @override
  Widget build(BuildContext context) {
    return LanJoinScreen(
      game: _game,
      color: kDavinciColor,
      discoveryPort: discoveryPort,
      extraTargets: extraTargets,
      roomTitle: (r) {
        final n = r.info['players'] is int ? r.info['players'] as int : 2;
        final cpus = r.info['cpus'] is int ? r.info['cpus'] as int : 0;
        final joined = r.info['joined'] is int ? r.info['joined'] as int : 1;
        return '다빈치 코드 · ${roomSizeText(n, cpus)} ($joined/${n - cpus})';
      },
      roomSubtitle: (r) => _sideText(r.info['hostSide'] is int ? r.info['hostSide'] as int : kRandomSide, mine: false),
      buildGame: (m, conn) {
        final side = m['side'], seed = m['seed'];
        final players = m['players'];
        if (players is! int || players < 2 || players > 4) return null;
        if (side is! int || side < 0 || side >= players || seed is! int) return null;
        final raw = m['names'];
        final names = raw is List && raw.length == players ? [for (final n in raw) '$n'] : null;
        final rawCpus = m['cpus'];
        final cpuSeats = rawCpus is List ? [for (final x in rawCpus) if (x is int) x] : <int>[];
        if (cpuSeats.any((x) => x < 0 || x >= players || x == side) || players - cpuSeats.length < 2) return null;
        return DavinciScreen(mode: PlayMode.wifi, players: players, humanSeat: side, names: names, cpuSeats: cpuSeats, seed: seed, links: [conn]);
      },
    );
  }
}
