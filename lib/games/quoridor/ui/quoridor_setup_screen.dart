import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../net/lan_screens.dart' show kRandomSide;
import '../../../versus/vs_setup.dart';
import '../core/quoridor_ai.dart';
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
  int _roomCpus = 0; // Wi‑Fi 방에서 CPU가 앉을 자리 수 (사람은 둘 이상)
  QLevel _level = QLevel.normal;
  late int _side = kRandomSide; // Wi‑Fi 방: 0 = 먼저, 1 = 나중, -1 = 무작위

  bool get _vsCpu => widget.mode == PlayMode.vsCpu;
  bool get _wifi => widget.mode == PlayMode.wifi;

  void _start() {
    final players = _players, level = _level, side = _side, mode = widget.mode, roomCpus = _roomCpus;
    if (_wifi) {
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => QuoridorHostScreen(hostSide: side, players: players, cpus: roomCpus, level: level)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => QuoridorScreen(mode: mode, players: players, level: level)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VsSetupScaffold(
      gameId: 'quoridor',
      title: _vsCpu ? '쿼리도 · CPU와 대결' : (_wifi ? '쿼리도 · 방 만들기' : '쿼리도 · 한 기기로 함께'),
      startLabel: _wifi ? '방 열기' : '시작하기',
      onStart: _start,
      tutorial: quoridorTutorial,
      children: [
        const VsSectionTitle('몇 명이 할까요?'),
        VsChoiceRow(cards: [
          _CountCard(players: 2, selected: _players == 2, onTap: () => setState(() {
            _players = 2;
            _roomCpus = 0;
            if (_side > 1) _side = kRandomSide;
          }), hint: _vsCpu ? '나 + CPU 1명' : (_wifi ? '모두 2명 · 벽 10개씩' : '둘이서 · 벽 10개씩')),
          _CountCard(players: 4, selected: _players == 4, onTap: () => setState(() => _players = 4), hint: _vsCpu ? '나 + CPU 3명' : (_wifi ? '모두 4명 · 벽 5개씩' : '네 명이서 · 벽 5개씩')),
        ]),
        if (_wifi && _players == 4) ...[
          const VsSectionTitle('그중 CPU는 몇 명?', topGap: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var m = 0; m <= 2; m++)
                ChoiceChip(
                  key: ValueKey('cpus$m'),
                  label: Text(m == 0 ? '없음 (모두 사람)' : 'CPU $m명 · 사람 ${4 - m}명'),
                  selected: _roomCpus == m,
                  onSelected: (_) => setState(() => _roomCpus = m),
                ),
            ],
          ),
        ],
        VsHint(_wifi
            ? '사람 수(${_players - _roomCpus}명)만큼 기기가 모두 같은 Wi‑Fi에 연결돼 있어야 해요. 사람이 모두 모이면 저절로 시작해요. 벽은 2명이면 10개씩, 4명이면 5개씩 가져요.'
            : _vsCpu
                ? '벽은 2명이면 10개씩, 4명이면 5개씩 가져요. 다음 판부터는 시작하는 자리가 돌아가며 바뀌어요.'
                : '한 기기를 돌려 가며 해요. 벽은 2명이면 10개씩, 4명이면 5개씩 가져요.'),
        if (_vsCpu || (_wifi && _roomCpus > 0)) ...[
          const VsSectionTitle('CPU 난이도', topGap: 24),
          VsLevelPicker<QLevel>(
            levels: QLevel.values,
            selected: _level,
            onChanged: (l) => setState(() => _level = l),
            label: (l) => l.label,
            description: (l) => l.description,
          ),
        ],
        if (_wifi) ...[
          const VsSectionTitle('내 순서', topGap: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(label: const Text('무작위'), avatar: const Icon(Icons.casino_rounded, size: 18), selected: _side == kRandomSide, onSelected: (_) => setState(() => _side = kRandomSide)),
              for (var i = 0; i < _players; i++)
                ChoiceChip(
                  label: Text(i == 0 ? '먼저 (1번째)' : '${i + 1}번째'),
                  avatar: Container(width: 14, height: 14, decoration: BoxDecoration(color: kPawnColors[i], shape: BoxShape.circle)),
                  selected: _side == i,
                  onSelected: (_) => setState(() => _side = i),
                ),
            ],
          ),
          const VsHint('다음 판부터는 순서가 한 칸씩 돌아가요.'),
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
