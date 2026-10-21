import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../net/lan_screens.dart' show kRandomSide;
import '../../../versus/vs_setup.dart';
import '../core/quoridor_ai.dart';
import '../game/quoridor_controller.dart';
import '../tutorial/quoridor_tutorial.dart';
import 'quoridor_board.dart';
import 'quoridor_screen.dart';
import 'quoridor_wifi_screen.dart';

/// 시작 전 설정: 몇 명이 할지(2 / 4) + CPU 대결이면 난이도, 같은 Wi‑Fi 대결이면 방을 만드는 내 순서.
class QuoridorSetupScreen extends StatefulWidget {
  const QuoridorSetupScreen({super.key, required this.mode});

  final PlayMode mode;

  @override
  State<QuoridorSetupScreen> createState() => _QuoridorSetupScreenState();
}

class _QuoridorSetupScreenState extends State<QuoridorSetupScreen> {
  int _players = 2;
  QLevel _level = QLevel.normal;
  late int _side = kRandomSide; // Wi‑Fi 방: 0 = 먼저, 1 = 두 번째, -1 = 무작위

  bool get _vsCpu => widget.mode == PlayMode.vsCpu;
  bool get _wifi => widget.mode == PlayMode.wifi;

  void _start() {
    final players = _players, level = _level, side = _side, mode = widget.mode;
    if (_wifi) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => QuoridorHostScreen(hostSide: side, flexible: true, level: level)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => QuoridorScreen(mode: mode, players: players, level: level)),
    );
  }

  void _resume(Map<String, dynamic> saved) {
    final controller = QuoridorController.fromJson(saved);
    if (controller == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => QuoridorScreen(mode: controller.mode, players: controller.players, controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VsSetupScaffold(
      gameId: 'quoridor',
      title: _vsCpu ? '쿼리도 · CPU와 대결' : (_wifi ? '쿼리도 · 방 만들기' : '쿼리도 · 한 기기로 함께'),
      switchFrom: _wifi ? null : widget.mode,
      startLabel: _wifi ? '방 열기' : '시작하기',
      onStart: _start,
      resume: _wifi
          ? null
          : VsResume(
              gameName: '쿼리도',
              describe: (j) {
                final cpu = j['mode'] == PlayMode.vsCpu.name;
                final who = cpu ? 'CPU 대결' : '한 기기로 함께';
                return '$who · ${j['players'] ?? 2}명 · ${(j['moves'] as List?)?.length ?? 0}수째';
              },
              onResume: _resume,
            ),
      tutorial: quoridorTutorial,
      children: [
        if (_wifi) ...[
          const VsHint('"모이는 대로 시작" 방이에요. 인원수를 미리 정하지 않아도 돼요. 한 명이라도 들어오면 "이대로 시작하기", "CPU 넣고 시작하기" 중에서 골라 시작해요. (2명 또는 4명이 할 수 있어서, 3명이 모이면 CPU 1명을 넣어요. 4명이 모이면 저절로 시작해요) 벽은 2명이면 10개씩, 4명이면 5개씩 가져요.'),
          const VsSectionTitle('CPU 난이도 (CPU를 넣을 때)', topGap: 24),
          VsLevelPicker<QLevel>(
            levels: QLevel.values,
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
              ChoiceChip(
                label: const Text('먼저 (1번째)'),
                avatar: Container(width: 14, height: 14, decoration: BoxDecoration(color: kPawnColors[0], shape: BoxShape.circle)),
                selected: _side == 0,
                onSelected: (_) => setState(() => _side = 0),
              ),
              ChoiceChip(
                label: const Text('두 번째'),
                avatar: Container(width: 14, height: 14, decoration: BoxDecoration(color: kPawnColors[1], shape: BoxShape.circle)),
                selected: _side == 1,
                onSelected: (_) => setState(() => _side = 1),
              ),
            ],
          ),
          const VsHint('다음 판부터는 순서가 한 칸씩 돌아가요.'),
        ] else ...[
          const VsSectionTitle('몇 명이 할까요?'),
          VsChoiceRow(cards: [
            _CountCard(players: 2, selected: _players == 2, onTap: () => setState(() => _players = 2), hint: _vsCpu ? '나 + CPU 1명' : '둘이서 · 벽 10개씩'),
            _CountCard(players: 4, selected: _players == 4, onTap: () => setState(() => _players = 4), hint: _vsCpu ? '나 + CPU 3명' : '네 명이서 · 벽 5개씩'),
          ]),
          VsHint(_vsCpu
              ? '벽은 2명이면 10개씩, 4명이면 5개씩 가져요. 다음 판부터는 시작하는 자리가 돌아가며 바뀌어요.'
              : '한 기기를 돌려 가며 해요. 벽은 2명이면 10개씩, 4명이면 5개씩 가져요.'),
          if (_vsCpu) ...[
            const VsSectionTitle('CPU 난이도', topGap: 24),
            VsLevelPicker<QLevel>(
              levels: QLevel.values,
              selected: _level,
              onChanged: (l) => setState(() => _level = l),
              label: (l) => l.label,
              description: (l) => l.description,
            ),
          ],
        ],
      ],
    );
  }
}

class _CountCard extends StatelessWidget {
  const _CountCard({required this.players, required this.selected, required this.onTap, required this.hint});

  final int players;
  final bool selected;
  final VoidCallback onTap;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return VsChoiceCard(
      color: kQuoridorColor,
      selected: selected,
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            height: 34,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < players; i++)
                  Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(color: kPawnColors[i], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('$players명', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kQuoridorColor)),
          Text(hint, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
