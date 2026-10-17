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
  RkLevel _level = RkLevel.normal;
  late int _side = _wifi ? kRkRandomSide : 0; // 0 = 먼저, 1 = 두 번째 (Wi‑Fi 방은 -1 = 무작위)

  bool get _wifi => widget.mode == PlayMode.wifi;

  void _start() {
    final cpus = _cpus, level = _level, side = _side;
    if (_wifi) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RummikubHostScreen(hostSide: side, flexible: true, level: level)));
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
          const VsHint('"모이는 대로 시작" 방이에요. 인원수를 미리 정하지 않아도 돼요. 한 명이라도 들어오면 "이대로 시작하기", "CPU 1명 넣고 시작하기", "CPU 2명 넣고 시작하기" 중에서 골라 시작해요. (모두 4명까지, 4명이 모이면 저절로 시작해요) 사람과는 각자 자기 기기로 해서 서로의 것은 보이지 않아요.'),
          const VsSectionTitle('CPU 난이도 (CPU를 넣을 때)', topGap: 24),
          VsLevelPicker<RkLevel>(
            levels: RkLevel.values,
            selected: _level,
            onChanged: (l) => setState(() => _level = l),
            label: (l) => l.label,
            description: (l) => l.description,
          ),
          const VsSectionTitle('내 순서', topGap: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(label: const Text('무작위'), avatar: const Icon(Icons.casino_rounded, size: 18), selected: _side == kRkRandomSide, onSelected: (_) => setState(() => _side = kRkRandomSide)),
              ChoiceChip(label: const Text('먼저 (1번째)'), selected: _side == 0, onSelected: (_) => setState(() => _side = 0)),
              ChoiceChip(label: const Text('두 번째'), selected: _side == 1, onSelected: (_) => setState(() => _side = 1)),
            ],
          ),
          const VsHint('다음 판부터는 순서가 한 칸씩 돌아가요.'),
        ],
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.count, required this.label, required this.hint, required this.selected, required this.onTap});

  final int count;
  final String label;
  final String hint;
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
            children: [for (var i = 0; i < count; i++) Icon(Icons.smart_toy_rounded, size: count >= 3 ? 20 : 26, color: kRkWood)],
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kRkWood)),
          Text(hint, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
