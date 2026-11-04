import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/settings_scope.dart';
import '../../../net/lan_connection.dart';
import '../../../net/lan_discovery.dart';
import '../../../net/lan_screens.dart';
import '../../../versus/vs_setup.dart';
import '../core/kt_run.dart';
import '../core/kt_songs.dart';
import '../game/kt_race.dart';
import '../tutorial/kt_tutorial.dart';
import 'kt_board.dart';
import 'kt_race_screen.dart';

/// 건반 톡톡의 같은 Wi‑Fi 경주 첫 화면: 방을 만들거나 찾는다.
class KtWifiScreen extends StatelessWidget {
  const KtWifiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return LanChooseScreen(
      title: '건반 톡톡 · 같은 Wi‑Fi로 경주',
      color: kKeytapColor,
      recordsGame: 'keytap',
      createRoom: (_) => const KtRaceSetupScreen(),
      findRoom: (_) => const KtJoinScreen(),
    );
  }
}

/// 방을 열기 전에 곡과 CPU 솜씨를 고른다.
class KtRaceSetupScreen extends StatefulWidget {
  const KtRaceSetupScreen({super.key});

  @override
  State<KtRaceSetupScreen> createState() => _KtRaceSetupScreenState();
}

class _KtRaceSetupScreenState extends State<KtRaceSetupScreen> {
  KtSong _song = KtSong.all.first;
  KtCpuLevel _level = KtCpuLevel.normal;

  @override
  Widget build(BuildContext context) {
    return VsSetupScaffold(
      gameId: 'keytap',
      title: '경주 방 만들기',
      tutorial: keytapTutorial,
      startLabel: '방 열기',
      onStart: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => KtHostScreen(song: _song, level: _level))),
      children: [
        const VsSectionTitle('곡'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in KtSong.all)
              ChoiceChip(
                label: Text('${s.title} ${'●' * s.level}'),
                selected: s == _song,
                onSelected: (_) => setState(() => _song = s),
              ),
          ],
        ),
        const VsSectionTitle('빈자리를 채울 CPU', topGap: 24),
        VsLevelPicker<KtCpuLevel>(
          levels: KtCpuLevel.values,
          selected: _level,
          onChanged: (l) => setState(() => _level = l),
          label: (l) => l.label,
          description: (l) => '블록 100개 중 ${(l.accuracy * 100).round()}개쯤 맞혀요',
        ),
        const VsHint('모이는 대로 시작해요 (2~4명). 방장이 "CPU 넣고 시작"으로 빈자리를 채울 수 있어요.'),
      ],
    );
  }
}

/// 방을 열고 기다린다. 한 명이라도 들어오면 방장이 시작 단추를 누른다.
class KtHostScreen extends StatelessWidget {
  const KtHostScreen({super.key, required this.song, required this.level, this.gamePort = kLanGamePort, this.discoveryPort = kLanDiscoveryPort});

  final KtSong song;
  final KtCpuLevel level;
  final int gamePort, discoveryPort;

  LanLobbyPlan _plan(List<LanConnection> guests, int cpus, String hostNick) {
    final seed = Random().nextInt(1 << 30);
    final players = guests.length + 1 + cpus;
    final names = [hostNick, for (final g in guests) g.peerNick, for (var i = 0; i < cpus; i++) 'CPU ${i + 1}'];
    final cpuSeats = {for (var i = guests.length + 1; i < players; i++) i};
    return LanLobbyPlan(
      messages: [
        for (var i = 0; i < guests.length; i++) {'seat': i + 1, 'names': names, 'song': song.id, 'seed': seed, 'level': level.name},
      ],
      hostScreen: (conns, desk) => KtRaceScreen(
        race: KtRace(song: song, seed: seed, names: names, mySeat: 0, isHost: true, cpuSeats: cpuSeats, level: level),
        links: conns,
        linkSeats: [for (var i = 0; i < conns.length; i++) i + 1],
        rejoinDesk: desk,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hostNick = SettingsScope.of(context).nickname;
    return LanLobbyScreen.flexible(
      game: kKeytapLanGame,
      gameName: '건반 톡톡',
      info: {'song': song.id},
      summary: ['곡: ${song.title}', '모이는 대로 시작 · 2~4명', 'CPU ${level.label}'],
      room: LanFlexibleRoom(allowedPlayers: const {2, 3, 4}, onStart: (guests, cpus) => _plan(guests, cpus, hostNick)),
      gamePort: gamePort,
      discoveryPort: discoveryPort,
    );
  }
}

/// 같은 Wi‑Fi에서 열린 경주 방을 찾아 들어간다.
class KtJoinScreen extends StatelessWidget {
  const KtJoinScreen({super.key, this.discoveryPort = kLanDiscoveryPort, this.extraTargets = const []});

  final int discoveryPort;
  final List<String> extraTargets;

  @override
  Widget build(BuildContext context) {
    return LanJoinScreen(
      game: kKeytapLanGame,
      color: kKeytapColor,
      discoveryPort: discoveryPort,
      extraTargets: extraTargets,
      roomTitle: (r) {
        final joined = r.info['joined'] is int ? r.info['joined'] as int : 1;
        return '건반 톡톡 경주 (지금 $joined명)';
      },
      roomSubtitle: (r) => '곡: ${KtSong.byId('${r.info['song']}')?.title ?? '?'}',
      buildGame: (m, conn) {
        final seat = m['seat'], seed = m['seed'], rawNames = m['names'];
        final song = KtSong.byId('${m['song']}');
        if (seat is! int || seed is! int || rawNames is! List || song == null) return null;
        final names = [for (final n in rawNames) '$n'];
        if (seat < 1 || seat >= names.length) return null;
        return KtRaceScreen(
          race: KtRace(song: song, seed: seed, names: names, mySeat: seat, isHost: false, level: KtRace.levelOf(m['level'])),
          links: [conn],
        );
      },
    );
  }
}
