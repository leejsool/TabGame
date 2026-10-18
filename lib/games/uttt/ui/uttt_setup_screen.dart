import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../versus/vs_setup.dart';
import '../core/uttt_ai.dart';
import '../core/uttt_rules.dart';
import '../game/uttt_controller.dart';
import '../tutorial/uttt_tutorial.dart';
import 'uttt_lesson_screen.dart';
import 'uttt_board.dart';
import 'uttt_screen.dart';
import 'uttt_wifi_screen.dart';

/// CPU 대전 시작 전 설정: 난이도 + 내 표시(X/O).
class UtttSetupScreen extends StatefulWidget {
  const UtttSetupScreen({super.key});

  @override
  State<UtttSetupScreen> createState() => _UtttSetupScreenState();
}

class _UtttSetupScreenState extends State<UtttSetupScreen> {
  UttLevel _level = UttLevel.normal;
  int _side = kX;

  void _start() {
    final side = _side, level = _level;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UtttScreen(mode: PlayMode.vsCpu, humanSide: side, level: level),
      ),
    );
  }

  void _resume(Map<String, dynamic> saved) {
    final controller = UtttController.fromJson(saved);
    if (controller == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => UtttScreen(mode: controller.mode, controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VsSetupScaffold(
      gameId: 'ultimate_tictactoe',
      title: '궁극 틱택토 · CPU와 대결',
      onStart: _start,
      resume: VsResume(gameName: '궁극 틱택토', describe: utttSavedLabel, onResume: _resume),
      tutorial: utttTutorial,
      onLesson: () => openUtttLesson(context),
      children: [
        const VsSectionTitle('내 표시'),
        VsChoiceRow(cards: [
          _SideCard(side: kX, selected: _side == kX, onTap: () => setState(() => _side = kX)),
          _SideCard(side: kO, selected: _side == kO, onTap: () => setState(() => _side = kO)),
        ]),
        const VsHint('X가 먼저 시작해요. 다음 판부터는 번갈아 시작해요.'),
        const VsSectionTitle('CPU 난이도', topGap: 24),
        VsLevelPicker<UttLevel>(
          levels: UttLevel.values,
          selected: _level,
          onChanged: (l) => setState(() => _level = l),
          label: (l) => l.label,
          description: (l) => l.description,
        ),
      ],
    );
  }
}

/// 같은 Wi‑Fi로 방을 만들기 전 설정: 내 표시(X/O/무작위).
class UtttHostSetupScreen extends StatefulWidget {
  const UtttHostSetupScreen({super.key});

  @override
  State<UtttHostSetupScreen> createState() => _UtttHostSetupScreenState();
}

class _UtttHostSetupScreenState extends State<UtttHostSetupScreen> {
  int _side = kRandomSide;

  @override
  Widget build(BuildContext context) {
    return VsSetupScaffold(
      gameId: 'ultimate_tictactoe',
      title: '궁극 틱택토 · 방 만들기',
      startLabel: '방 열기',
      onStart: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => UtttHostScreen(hostSide: _side))),
      tutorial: utttTutorial,
      onLesson: () => openUtttLesson(context),
      children: [
        const VsSectionTitle('내 표시'),
        VsChoiceRow(cards: [
          _SideCard(side: kX, selected: _side == kX, onTap: () => setState(() => _side = kX)),
          _SideCard(side: kO, selected: _side == kO, onTap: () => setState(() => _side = kO)),
          VsChoiceCard(
            color: const Color(0xFF8E5BC4),
            selected: _side == kRandomSide,
            onTap: () => setState(() => _side = kRandomSide),
            child: const Column(
              children: [
                SizedBox(width: 64, height: 64, child: Icon(Icons.casino_rounded, size: 44, color: Color(0xFF8E5BC4))),
                SizedBox(height: 8),
                Text('무작위', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF8E5BC4))),
                Text('상대가 들어오면 정해요', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ]),
        const VsHint('X가 먼저 시작해요. 다음 판부터는 번갈아 시작해요.'),
      ],
    );
  }
}

class _SideCard extends StatelessWidget {
  const _SideCard({required this.side, required this.selected, required this.onTap});

  final int side;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = sideColor(side);
    return VsChoiceCard(
      color: color,
      selected: selected,
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(width: 64, height: 64, child: CustomPaint(painter: _SidePainter(side))),
          const SizedBox(height: 8),
          Text(side == kX ? 'X' : 'O', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          Text(side == kX ? '먼저 시작' : '나중에 시작', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _SidePainter extends CustomPainter {
  const _SidePainter(this.side);
  final int side;

  @override
  void paint(Canvas canvas, Size size) =>
      drawMark(canvas, side, Offset.zero & size, 1, strokeWidth: size.width * 0.14);

  @override
  bool shouldRepaint(_SidePainter old) => old.side != side;
}

/// 이어하던 판을 한 줄로 설명한다 (설정 화면·시작 화면의 "이어하기" 카드).
String utttSavedLabel(Map<String, dynamic> j) {
  final cpu = j['mode'] == PlayMode.vsCpu.name;
  return '${cpu ? 'CPU 대결' : '한 기기로 함께'} · ${(j['moves'] as List?)?.length ?? 0}수째';
}
