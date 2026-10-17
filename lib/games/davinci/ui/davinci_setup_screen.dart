import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../versus/vs_setup.dart';
import '../core/davinci_ai.dart';
import '../game/davinci_controller.dart';
import '../tutorial/davinci_tutorial.dart';
import 'davinci_screen.dart';
import 'davinci_tiles.dart';
import 'davinci_wifi_screen.dart';

/// 시작 전 설정: CPU 대결이면 CPU 수(1~3)와 난이도, 같은 Wi‑Fi 대결이면 몇 명이 할지(2~4)와 방을 만드는 내 순서.
class DavinciSetupScreen extends StatefulWidget {
  const DavinciSetupScreen({super.key, required this.mode});

  final PlayMode mode;

  @override
  State<DavinciSetupScreen> createState() => _DavinciSetupScreenState();
}

class _DavinciSetupScreenState extends State<DavinciSetupScreen> {
  int _cpus = 1;
  DvLevel _level = DvLevel.normal;
  int _side = kRandomSide; // Wi‑Fi 방: 0 = 먼저, 1 = 두 번째, -1 = 무작위

  bool get _wifi => widget.mode == PlayMode.wifi;

  void _start() {
    final cpus = _cpus, level = _level, side = _side;
    if (_wifi) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DavinciHostScreen(hostSide: side, flexible: true, level: level)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DavinciScreen(mode: PlayMode.vsCpu, players: cpus + 1, level: level)),
    );
  }

  void _resume(Map<String, dynamic> saved) {
    final controller = DavinciController.fromJson(saved);
    if (controller == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => DavinciScreen(controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VsSetupScaffold(
      gameId: 'davinci_code',
      title: _wifi ? '다빈치 코드 · 방 만들기' : '다빈치 코드 · CPU와 대결',
      startLabel: _wifi ? '방 열기' : '시작하기',
      onStart: _start,
      resume: _wifi
          ? null
          : VsResume(
              gameName: '다빈치 코드',
              describe: (j) {
                final level = j['level'] as int? ?? 0;
                final name = level >= 0 && level < DvLevel.values.length ? DvLevel.values[level].label : '';
                return 'CPU ${(j['players'] as int? ?? 2) - 1}명 · $name · ${(j['moves'] as List?)?.length ?? 0}수째';
              },
              onResume: _resume,
            ),
      tutorial: davinciTutorial,
      children: [
        if (!_wifi) ...[
          const VsSectionTitle('CPU 몇 명과 할까요?'),
          VsChoiceRow(cards: [
            for (final n in const [1, 2, 3]) _CountCard(count: n, label: '$n명', hint: '모두 ${n + 1}명이 해요', selected: _cpus == n, onTap: () => setState(() => _cpus = n)),
          ]),
          const VsHint('다음 판부터는 시작하는 자리가 돌아가며 바뀌어요.'),
          const VsSectionTitle('CPU 난이도', topGap: 24),
          VsLevelPicker<DvLevel>(
            levels: DvLevel.values,
            selected: _level,
            onChanged: (l) => setState(() => _level = l),
            label: (l) => l.label,
            description: (l) => l.description,
          ),
        ] else ...[
          const VsHint('"모이는 대로 시작" 방이에요. 인원수를 미리 정하지 않아도 돼요. 한 명이라도 들어오면 "이대로 시작하기", "CPU 1명 넣고 시작하기", "CPU 2명 넣고 시작하기" 중에서 골라 시작해요. (모두 4명까지, 4명이 모이면 저절로 시작해요) 사람과는 각자 자기 기기로 해서 서로의 것은 보이지 않아요.'),
          const VsSectionTitle('CPU 난이도 (CPU를 넣을 때)', topGap: 24),
          VsLevelPicker<DvLevel>(
            levels: DvLevel.values,
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
              ChoiceChip(label: const Text('무작위'), avatar: const Icon(Icons.casino_rounded, size: 18), selected: _side == kRandomSide, onSelected: (_) => setState(() => _side = kRandomSide)),
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
      color: kDavinciColor,
      selected: selected,
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < count; i++)
                  Container(
                    width: 15,
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: i.isEven ? const Color(0xFF2A2D32) : const Color(0xFFF6F1E4),
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: const Color(0xFF8A8F98)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: kDavinciColor)),
          Text(hint, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
