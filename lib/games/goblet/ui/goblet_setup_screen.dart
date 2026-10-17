import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../versus/vs_setup.dart';
import '../core/goblet_ai.dart';
import '../core/goblet_rules.dart';
import '../game/goblet_controller.dart';
import 'goblet_piece.dart';
import '../tutorial/goblet_tutorial.dart';
import 'goblet_screen.dart';
import 'goblet_wifi_screen.dart';

/// CPU 대전 시작 전 설정: 난이도 + 내 팀.
class GobbletSetupScreen extends StatefulWidget {
  const GobbletSetupScreen({super.key});

  @override
  State<GobbletSetupScreen> createState() => _GobbletSetupScreenState();
}

class _GobbletSetupScreenState extends State<GobbletSetupScreen> {
  CpuLevel _level = CpuLevel.normal;
  Team _team = Team.red;

  void _start() {
    final team = _team, level = _level;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GobbletScreen(mode: PlayMode.vsCpu, humanTeam: team, level: level),
      ),
    );
  }

  void _resume(Map<String, dynamic> saved) {
    final controller = GobbletController.fromJson(saved);
    if (controller == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => GobbletScreen(mode: controller.mode, controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VsSetupScaffold(
      gameId: 'goblet_gobblers',
      title: 'CPU와 대결',
      onStart: _start,
      resume: VsResume(gameName: '고블렛 고블러스', describe: gobletSavedLabel, onResume: _resume),
      tutorial: gobletTutorial,
      children: [
        const VsSectionTitle('내 팀'),
        VsChoiceRow(cards: [
          for (final t in Team.values) _TeamCard(team: t, selected: _team == t, onTap: () => setState(() => _team = t)),
        ]),
        const VsHint('빨강팀이 먼저 시작해요. 다음 판부터는 번갈아 시작해요.'),
        const VsSectionTitle('CPU 난이도', topGap: 24),
        VsLevelPicker<CpuLevel>(
          levels: CpuLevel.values,
          selected: _level,
          onChanged: (l) => setState(() => _level = l),
          label: (l) => l.label,
          description: (l) => l.description,
        ),
      ],
    );
  }
}

/// 같은 Wi‑Fi로 방을 만들기 전 설정: 내 팀(빨강/파랑/무작위).
class GobbletHostSetupScreen extends StatefulWidget {
  const GobbletHostSetupScreen({super.key});

  @override
  State<GobbletHostSetupScreen> createState() => _GobbletHostSetupScreenState();
}

class _GobbletHostSetupScreenState extends State<GobbletHostSetupScreen> {
  int _team = kRandomSide; // 0 = 빨강, 1 = 파랑, -1 = 무작위

  @override
  Widget build(BuildContext context) {
    return VsSetupScaffold(
      gameId: 'goblet_gobblers',
      title: '고블렛 고블러스 · 방 만들기',
      startLabel: '방 열기',
      onStart: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => GobbletHostScreen(hostTeam: _team))),
      tutorial: gobletTutorial,
      children: [
        const VsSectionTitle('내 팀'),
        VsChoiceRow(cards: [
          for (final t in Team.values) _TeamCard(team: t, selected: _team == t.index, onTap: () => setState(() => _team = t.index)),
          VsChoiceCard(
            color: const Color(0xFF8E5BC4),
            selected: _team == kRandomSide,
            onTap: () => setState(() => _team = kRandomSide),
            child: const Column(
              children: [
                SizedBox(width: 72, height: 72, child: Icon(Icons.casino_rounded, size: 48, color: Color(0xFF8E5BC4))),
                SizedBox(height: 8),
                Text('무작위', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF6E3FA3))),
                Text('상대가 들어오면 정해요', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ]),
        const VsHint('빨강팀이 먼저 시작해요. 다음 판부터는 번갈아 시작해요.'),
      ],
    );
  }
}

class _TeamCard extends StatelessWidget {
  const _TeamCard({required this.team, required this.selected, required this.onTap});

  final Team team;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pal = TeamPalette.of(team);
    return VsChoiceCard(
      color: pal.main,
      selected: selected,
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            width: 72,
            height: 72,
            child: CustomPaint(
              painter: GobblerPainter(team: team, size: 3, mood: selected ? PieceMood.happy : PieceMood.normal),
            ),
          ),
          const SizedBox(height: 8),
          Text(team.label, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: pal.dark)),
          Text(team == Team.red ? '먼저 시작' : '나중에 시작', style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

/// 이어하던 판을 한 줄로 설명한다 (설정 화면·시작 화면의 "이어하기" 카드).
String gobletSavedLabel(Map<String, dynamic> j) {
  final cpu = j['mode'] == PlayMode.vsCpu.name;
  return '${cpu ? 'CPU 대결' : '한 기기로 함께'} · ${(j['history'] as List?)?.length ?? 0}수째';
}
