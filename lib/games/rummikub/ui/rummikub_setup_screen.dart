import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../versus/vs_setup.dart';
import '../core/rummikub_ai.dart';
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
  late int _side = _wifi ? kRkRandomSide : 0; // 0 = 먼저, 1 = 나중 (Wi‑Fi 방은 -1 = 무작위)

  bool get _wifi => widget.mode == PlayMode.wifi;

  void _start() {
    final cpus = _cpus, level = _level, side = _side;
    if (_wifi) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => RummikubHostScreen(hostSide: side)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RummikubScreen(mode: PlayMode.vsCpu, players: cpus + 1, level: level)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VsSetupScaffold(
      gameId: 'rummikub',
      title: _wifi ? '루미큐브 · 방 만들기' : '루미큐브 · CPU와 대결',
      startLabel: _wifi ? '방 열기' : '시작하기',
      onStart: _start,
      tutorial: rummikubTutorial,
      children: [
        if (!_wifi) ...[
          const VsSectionTitle('CPU 몇 명과 할까요?'),
          VsChoiceRow(cards: [
            for (final n in const [1, 2, 3]) _CountCard(count: n, selected: _cpus == n, onTap: () => setState(() => _cpus = n)),
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
          const VsSectionTitle('나는'),
          VsChoiceRow(cards: [
            _SideCard(label: '먼저', hint: '첫 차례', selected: _side == 0, onTap: () => setState(() => _side = 0)),
            _SideCard(label: '나중', hint: '두 번째 차례', selected: _side == 1, onTap: () => setState(() => _side = 1)),
            _SideCard(label: '무작위', hint: '상대가 들어오면 정해요', icon: Icons.casino_rounded, selected: _side == kRkRandomSide, onTap: () => setState(() => _side = kRkRandomSide)),
          ]),
          const VsHint('사람과는 같은 Wi‑Fi에서 각자 자기 기기로 해요. 서로의 타일은 보이지 않아요. 다음 판부터는 번갈아 시작해요.'),
        ],
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.count, required this.selected, required this.onTap});

  final int count;
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
            children: [for (var i = 0; i < count; i++) Icon(Icons.smart_toy_rounded, size: count == 3 ? 20 : 26, color: kRkWood)],
          ),
          const SizedBox(height: 8),
          Text('$count명', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kRkWood)),
          Text('모두 ${count + 1}명이 해요', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({required this.label, required this.hint, required this.selected, required this.onTap, this.icon});

  final String label;
  final String hint;
  final IconData? icon;
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
          Icon(icon ?? Icons.grid_view_rounded, size: 40, color: kRkWood),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: kRkWood)),
          Text(hint, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
