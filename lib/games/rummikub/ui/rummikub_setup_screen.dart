import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../versus/vs_setup.dart';
import '../core/rummikub_ai.dart';
import '../game/rummikub_controller.dart';
import '../tutorial/rummikub_tutorial.dart';
import 'rummikub_screen.dart';
import 'rummikub_tiles.dart';
import 'rummikub_wifi_screen.dart';

/// 시작 전 설정: CPU 대결이면 CPU 수와 난이도, 같은 Wi‑Fi 대결이면 방을 만드는 내 순서.
class RummikubSetupScreen extends StatefulWidget {
  const RummikubSetupScreen({super.key, required this.mode});

  final PlayMode mode;

  @override
  State<RummikubSetupScreen> createState() => _RummikubSetupScreenState();
}

class _RummikubSetupScreenState extends State<RummikubSetupScreen> {
  int _cpus = 1;
  int _players = 2; // Wi‑Fi 방: 모두 몇 명 (CPU 포함)
  int _roomCpus = 0; // Wi‑Fi 방에서 CPU가 앉을 자리 수 (사람은 둘 이상)
  RkLevel _level = RkLevel.normal;
  late int _side = _wifi ? kRkRandomSide : 0; // 0 = 먼저 … 3 (Wi‑Fi 방은 -1 = 무작위)

  bool get _wifi => widget.mode == PlayMode.wifi;

  void _start() {
    final cpus = _cpus, level = _level, side = _side, players = _players, roomCpus = _roomCpus;
    if (_wifi) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RummikubHostScreen(hostSide: side, players: players, cpus: roomCpus, level: level)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RummikubScreen(mode: PlayMode.vsCpu, players: cpus + 1, level: level)),
    );
  }

  void _resume(Map<String, dynamic> saved) {
    final controller = RummikubController.fromJson(saved);
    if (controller == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RummikubScreen(controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VsSetupScaffold(
      gameId: 'rummikub',
      title: _wifi ? '루미큐브 · 방 만들기' : '루미큐브 · CPU와 대결',
      startLabel: _wifi ? '방 열기' : '시작하기',
      onStart: _start,
      resume: _wifi
          ? null
          : VsResume(
              gameName: '루미큐브',
              describe: (j) {
                final cpus = (j['players'] as int? ?? 2) - 1;
                final level = j['level'] as int? ?? 0;
                final name = level >= 0 && level < RkLevel.values.length ? RkLevel.values[level].label : '';
                return 'CPU $cpus명 · $name · ${j['moveCount'] ?? 0}차례째';
              },
              onResume: _resume,
            ),
      tutorial: rummikubTutorial,
      children: [
        if (!_wifi) ...[
          const VsSectionTitle('CPU 몇 명과 할까요?'),
          VsChoiceRow(cards: [
            for (final n in const [1, 2, 3]) _CountCard(count: n, label: '$n명', hint: '모두 ${n + 1}명이 해요', selected: _cpus == n, onTap: () => setState(() => _cpus = n)),
          ]),
          const VsHint('다음 판부터는 먼저 시작하는 사람이 돌아가며 바뀌어요.'),
          const VsSectionTitle('CPU 난이도', topGap: 24),
          VsLevelPicker<RkLevel>(
            levels: RkLevel.values,
            selected: _level,
            onChanged: (l) => setState(() => _level = l),
            label: (l) => l.label,
            description: (l) => l.description,
          ),
        ] else ...[
          const VsSectionTitle('몇 명이 할까요?'),
          VsChoiceRow(cards: [
            for (final n in const [2, 3, 4])
              _CountCard(
                count: n,
                label: '$n명',
                hint: '모두 $n명이 해요',
                icon: Icons.person_rounded,
                selected: _players == n,
                onTap: () => setState(() {
                  _players = n;
                  if (_roomCpus > n - 2) _roomCpus = n - 2;
                  if (_side >= n) _side = kRkRandomSide;
                }),
              ),
          ]),
          if (_players > 2) ...[
            const VsSectionTitle('그중 CPU는 몇 명?', topGap: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (var m = 0; m <= _players - 2; m++)
                  ChoiceChip(
                    key: ValueKey('cpus$m'),
                    label: Text(m == 0 ? '없음 (모두 사람)' : 'CPU $m명 · 사람 ${_players - m}명'),
                    selected: _roomCpus == m,
                    onSelected: (_) => setState(() => _roomCpus = m),
                  ),
              ],
            ),
          ],
          VsHint('사람 수(${_players - _roomCpus}명)만큼 기기가 모두 같은 Wi‑Fi에 연결돼 있어야 해요. 서로의 타일은 보이지 않아요. 사람이 모두 모이면 저절로 시작해요.'),
          if (_roomCpus > 0) ...[
            const VsSectionTitle('CPU 난이도', topGap: 24),
            VsLevelPicker<RkLevel>(
              levels: RkLevel.values,
              selected: _level,
              onChanged: (l) => setState(() => _level = l),
              label: (l) => l.label,
              description: (l) => l.description,
            ),
          ],
          const VsSectionTitle('내 순서', topGap: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(label: const Text('무작위'), avatar: const Icon(Icons.casino_rounded, size: 18), selected: _side == kRkRandomSide, onSelected: (_) => setState(() => _side = kRkRandomSide)),
              for (var i = 0; i < _players; i++)
                ChoiceChip(label: Text(i == 0 ? '먼저 (1번째)' : '${i + 1}번째'), selected: _side == i, onSelected: (_) => setState(() => _side = i)),
            ],
          ),
          const VsHint('다음 판부터는 순서가 한 칸씩 돌아가요.'),
        ],
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.count, required this.label, required this.hint, required this.selected, required this.onTap, this.icon = Icons.smart_toy_rounded});

  final int count;
  final String label;
  final String hint;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return VsChoiceCard(
      color: kRkWood,
      selected: selected,
      onTap: onTap,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (var i = 0; i < count; i++) Icon(icon, size: count >= 3 ? 20 : 26, color: kRkWood)],
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kRkWood)),
          Text(hint, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
