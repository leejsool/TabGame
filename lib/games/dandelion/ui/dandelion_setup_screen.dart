import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../versus/vs_setup.dart';
import '../core/dandelion_ai.dart';
import '../core/dandelion_rules.dart';
import '../tutorial/dandelion_tutorial.dart';
import 'dandelion_art.dart';
import 'dandelion_lesson_screen.dart';
import 'dandelion_screen.dart';
import 'dandelion_wifi_screen.dart';

/// CPU 대전 시작 전 설정: 내가 맡을 쪽(민들레/바람) + 난이도.
class DandelionSetupScreen extends StatefulWidget {
  const DandelionSetupScreen({super.key});

  @override
  State<DandelionSetupScreen> createState() => _DandelionSetupScreenState();
}

class _DandelionSetupScreenState extends State<DandelionSetupScreen> {
  DandLevel _level = DandLevel.normal;
  Role _role = Role.dandelion;

  void _start() {
    final role = _role, level = _level;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => DandelionScreen(mode: PlayMode.vsCpu, humanRole: role, level: level),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VsSetupScaffold(
      gameId: 'dandelion',
      title: 'CPU와 대결',
      onStart: _start,
      tutorial: dandelionTutorial,
      onLesson: () => openDandelionLesson(context),
      children: [
        const VsSectionTitle('내가 맡을 쪽'),
        VsChoiceRow(cards: [
          for (final r in Role.values) _RoleCard(role: r, selected: _role == r, onTap: () => setState(() => _role = r)),
        ]),
        const VsHint('민들레가 먼저 꽃을 심고, 바람이 이어서 불어요.'),
        const VsSectionTitle('CPU 난이도', topGap: 24),
        VsLevelPicker<DandLevel>(
          levels: DandLevel.values,
          selected: _level,
          onChanged: (l) => setState(() => _level = l),
          label: (l) => l.label,
          description: (l) => l.description,
        ),
      ],
    );
  }
}

/// 같은 Wi‑Fi로 방을 만들기 전 설정: 내가 맡을 쪽(민들레/바람/무작위).
class DandelionHostSetupScreen extends StatefulWidget {
  const DandelionHostSetupScreen({super.key});

  @override
  State<DandelionHostSetupScreen> createState() => _DandelionHostSetupScreenState();
}

class _DandelionHostSetupScreenState extends State<DandelionHostSetupScreen> {
  int _role = kRandomSide;

  @override
  Widget build(BuildContext context) {
    const random = Color(0xFF8E5BC4);
    return VsSetupScaffold(
      gameId: 'dandelion',
      title: '민들레 · 방 만들기',
      startLabel: '방 열기',
      onStart: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DandelionHostScreen(hostRole: _role))),
      tutorial: dandelionTutorial,
      onLesson: () => openDandelionLesson(context),
      children: [
        const VsSectionTitle('내가 맡을 쪽'),
        VsChoiceRow(cards: [
          for (final r in Role.values) _RoleCard(role: r, selected: _role == r.index, onTap: () => setState(() => _role = r.index)),
          VsChoiceCard(
            color: random,
            selected: _role == kRandomSide,
            onTap: () => setState(() => _role = kRandomSide),
            child: const Column(
              children: [
                SizedBox(width: 64, height: 64, child: Icon(Icons.casino_rounded, size: 44, color: random)),
                SizedBox(height: 8),
                Text('무작위', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: random)),
                Text('상대가 들어오면 정해요', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ]),
        const VsHint('민들레가 먼저 꽃을 심고, 바람이 이어서 불어요. 한 판 더 할 때마다 서로 바뀌어요.'),
      ],
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.selected, required this.onTap});

  final Role role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = roleColor(role);
    return VsChoiceCard(
      color: color,
      selected: selected,
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(width: 64, height: 64, child: CustomPaint(painter: _RolePainter(role))),
          const SizedBox(height: 8),
          Text(role.label, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
          Text(role == Role.dandelion ? '꽃을 심어 초원을 덮어요' : '바람으로 빈칸을 남겨요',
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}

class _RolePainter extends CustomPainter {
  const _RolePainter(this.role);
  final Role role;

  @override
  void paint(Canvas canvas, Size size) => paintRoleIcon(canvas, size, role);

  @override
  bool shouldRepaint(_RolePainter old) => old.role != role;
}
