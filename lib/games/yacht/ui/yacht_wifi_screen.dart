import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../core/settings_scope.dart';
import '../../../net/lan_connection.dart';
import '../../../net/lan_discovery.dart';
import '../../../net/lan_screens.dart';
import '../core/yacht_cpu.dart';
import '../../../versus/vs_setup.dart';
import 'yacht_look.dart';
import 'yacht_screen.dart';
import 'yacht_setup_screen.dart';

const String _game = 'yacht';

/// 야추의 같은 Wi‑Fi로 함께 하기 첫 화면: 방을 만들거나, 만들어진 방을 찾아 들어간다. (2~4명)
class YachtWifiScreen extends StatelessWidget {
  const YachtWifiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LanChooseScreen(
      title: '야추 · 같은 Wi‑Fi로 함께',
      color: kYachtColor,
      recordsGame: _game,
      createRoom: (_) => const YachtRoomOptionsScreen(),
      findRoom: (_) => const YachtJoinScreen(),
    );
  }
}

/// 방을 열기 전에 규칙을 고르는 화면 (대성One Rule). 고르고 "방 만들기"를 누르면 방을 연다.
class YachtRoomOptionsScreen extends StatefulWidget {
  const YachtRoomOptionsScreen({super.key});

  @override
  State<YachtRoomOptionsScreen> createState() => _YachtRoomOptionsScreenState();
}

class _YachtRoomOptionsScreenState extends State<YachtRoomOptionsScreen> {
  bool _daesung = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('야추 · 방 만들기', style: TextStyle(fontWeight: FontWeight.w800))),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const VsSectionTitle('규칙'),
                YachtDaesungSwitch(value: _daesung, onChanged: (v) => setState(() => _daesung = v)),
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const ValueKey('yacht-room-create'),
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(builder: (_) => YachtHostScreen(daesung: _daesung)),
                  ),
                  icon: const Icon(Icons.wifi_rounded),
                  label: const Text('방 만들기'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    textStyle: const TextStyle(fontFamily: 'NanumGothic', fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 방을 열고 사람들이 모이기를 기다리는 화면. 모이는 대로 방장이 시작 단추로 인원을 정한다 (CPU를 넣어 채울 수도 있다).
///
/// 방장 기기가 모든 소식(굴리기 · 잡기 · 적기)을 받아 확인하고 다른 사람들에게 전해 준다.
class YachtHostScreen extends StatelessWidget {
  const YachtHostScreen({super.key, this.level = YachtLevel.normal, this.threeKind = false, this.daesung = false, this.gamePort = kLanGamePort, this.discoveryPort = kLanDiscoveryPort, this.rng});

  /// CPU를 넣었을 때 · 나간 사람 자리를 CPU가 맡을 때의 난이도.
  final YachtLevel level;

  /// 쓰리카드 칸을 넣고 하는 방인가 (손님들에게도 시작 메시지로 알린다).
  final bool threeKind;

  /// 대성One Rule 방인가 (방 찾기 목록 · 시작 메시지로 손님들에게도 알린다).
  final bool daesung;

  /// (시험용) 연결을 기다리는 포트와 방 찾기 응답 포트, 자리 섞기.
  final int gamePort, discoveryPort;
  final Random? rng;

  /// 모인 사람들([guests])과 CPU 수로 자리(= 시작하는 순서)를 무작위로 나누고 시작 메시지와 방장의 게임 화면을 정한다.
  LanLobbyPlan _plan(List<LanConnection> guests, int cpus, String hostNick) {
    final players = guests.length + 1 + cpus;
    final seats = [for (var i = 0; i < players; i++) i]..shuffle(rng ?? Random());
    final hostSeat = seats.removeAt(0);
    // 남은 자리 중 앞에서부터 손님이, 나머지는 CPU가 앉는다
    final cpuSeats = seats.sublist(guests.length)..sort();
    final names = List<String>.filled(players, '');
    names[hostSeat] = hostNick;
    for (var i = 0; i < guests.length; i++) {
      names[seats[i]] = guests[i].peerNick;
    }
    for (var i = 0; i < cpuSeats.length; i++) {
      names[cpuSeats[i]] = cpuSeats.length == 1 ? 'CPU' : 'CPU ${i + 1}';
    }
    return LanLobbyPlan(
      messages: [
        for (var i = 0; i < guests.length; i++) {'side': seats[i], 'players': players, 'names': names, 'cpus': cpuSeats, 'level': level.index, if (threeKind) 'three': true, if (daesung) 'ds': true},
      ],
      hostScreen: (conns, desk) => YachtScreen(
        mode: PlayMode.wifi,
        players: players,
        level: level,
        humanSeat: hostSeat,
        names: names,
        cpuSeats: cpuSeats,
        threeKind: threeKind,
        daesung: daesung,
        links: conns,
        linkSeats: seats.sublist(0, conns.length),
        rejoinDesk: desk,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hostNick = SettingsScope.of(context).nickname;
    return LanLobbyScreen.flexible(
      game: _game,
      gameName: '야추',
      info: {if (daesung) 'ds': true},
      summary: [if (daesung) '대성One Rule (초록 대성One 주사위의 로고는 만능)', '모이는 대로 시작 · 방장이 시작 단추로 인원을 정해요 (2~4명)', '시작하는 순서는 무작위로 정해져요', 'CPU를 넣으면 ${level.label} 난이도'],
      room: LanFlexibleRoom(
        allowedPlayers: const {2, 3, 4},
        onStart: (guests, cpus) => _plan(guests, cpus, hostNick),
      ),
      gamePort: gamePort,
      discoveryPort: discoveryPort,
    );
  }
}

/// 같은 Wi‑Fi에서 열린 방을 찾아 들어가는 화면. 주소를 직접 입력해서 들어갈 수도 있다.
class YachtJoinScreen extends StatelessWidget {
  const YachtJoinScreen({super.key, this.discoveryPort = kLanDiscoveryPort, this.extraTargets = const []});

  /// (시험용) 방 찾기 포트와 추가로 물어볼 주소.
  final int discoveryPort;
  final List<String> extraTargets;

  @override
  Widget build(BuildContext context) {
    return LanJoinScreen(
      game: _game,
      color: kYachtColor,
      discoveryPort: discoveryPort,
      extraTargets: extraTargets,
      roomTitle: (r) {
        final joined = r.info['joined'] is int ? r.info['joined'] as int : 1;
        return '야추 · 모이는 대로 시작 (지금 $joined명)';
      },
      roomSubtitle: (r) => '${r.info['ds'] == true ? '대성One Rule · ' : ''}2~4명 · 시작하는 순서는 무작위',
      buildGame: (m, conn) {
        final side = m['side'], players = m['players'];
        if (players is! int || players < 2 || players > 4) return null;
        if (side is! int || side < 0 || side >= players) return null;
        final raw = m['names'];
        final names = raw is List && raw.length == players ? [for (final n in raw) '$n'] : null;
        final rawCpus = m['cpus'];
        final cpuSeats = rawCpus is List ? [for (final x in rawCpus) if (x is int) x] : <int>[];
        if (cpuSeats.any((x) => x < 0 || x >= players || x == side) || players - cpuSeats.length < 2) return null;
        final lv = m['level'];
        final level = lv is int && lv >= 0 && lv < YachtLevel.values.length ? YachtLevel.values[lv] : YachtLevel.normal;
        return YachtScreen(mode: PlayMode.wifi, players: players, level: level, humanSeat: side, names: names, cpuSeats: cpuSeats, links: [conn], threeKind: m['three'] == true, daesung: m['ds'] == true);
      },
    );
  }
}
