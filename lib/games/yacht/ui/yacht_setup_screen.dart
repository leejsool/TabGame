import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../versus/vs_setup.dart';
import '../core/yacht_cpu.dart';
import '../game/yacht_controller.dart';
import '../tutorial/yacht_tutorial.dart';
import 'yacht_look.dart';
import 'yacht_screen.dart';

/// 시작 전 설정: 몇 명이 할지(2~4) + CPU 대결이면 난이도.
class YachtSetupScreen extends StatefulWidget {
  const YachtSetupScreen({super.key, required this.mode});

  final PlayMode mode;

  @override
  State<YachtSetupScreen> createState() => _YachtSetupScreenState();
}

class _YachtSetupScreenState extends State<YachtSetupScreen> {
  int _players = 2;
  YachtLevel _level = YachtLevel.normal;

  bool get _vsCpu => widget.mode == PlayMode.vsCpu;

  void _start() {
    final players = _players, level = _level, mode = widget.mode;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => YachtScreen(mode: mode, players: players, level: level)),
    );
  }

  void _resume(Map<String, dynamic> saved) {
    final controller = YachtController.fromJson(saved);
    if (controller == null) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => YachtScreen(mode: controller.mode, players: controller.players, controller: controller)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return VsSetupScaffold(
      gameId: 'yacht',
      title: _vsCpu ? '야추 · CPU와 대결' : '야추 · 한 기기로 함께',
      switchFrom: widget.mode,
      onStart: _start,
      resume: VsResume(gameName: '야추', describe: yachtSavedLabel, onResume: _resume),
      tutorial: yachtTutorial,
      children: [
        const VsSectionTitle('몇 명이 할까요?'),
        VsChoiceRow(cards: [
          for (final n in const [2, 3, 4])
            _CountCard(
              players: n,
              selected: _players == n,
              onTap: () => setState(() => _players = n),
              hint: _vsCpu ? '나 + CPU ${n - 1}명' : '$n명이서',
            ),
        ]),
        VsHint(_vsCpu
            ? '주사위를 12번(한 번에 최대 3번 굴리기) 굴려 점수를 가장 많이 모으면 이겨요. 다음 판부터는 시작하는 순서가 돌아가요.'
            : '기기 하나를 돌려 가며 해요. 다음 판부터는 시작하는 순서가 돌아가요.'),
        if (_vsCpu) ...[
          const VsSectionTitle('CPU 난이도', topGap: 24),
          VsLevelPicker<YachtLevel>(
            levels: YachtLevel.values,
            selected: _level,
            onChanged: (l) => setState(() => _level = l),
            label: (l) => l.label,
            description: (l) => l.description,
          ),
        ],
      ],
    );
  }
}

/// 이어하던 판을 한 줄로 설명한다 (설정 화면의 "이어하기" 카드).
String yachtSavedLabel(Map<String, dynamic> j) {
  final cpu = j['mode'] == PlayMode.vsCpu.name;
  final cards = (j['game'] as Map?)?['cards'] as List?;
  final players = cards?.length ?? 2;
  final filled = cards == null || cards.isEmpty ? 0 : (cards.last as List).where((s) => s != null).length;
  return '${cpu ? 'CPU 대결' : '한 기기로 함께'} · $players명 · ${filled < 12 ? filled + 1 : 12}/12 라운드';
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
      color: kYachtColor,
      selected: selected,
      onTap: onTap,
      child: Column(
        children: [
          SizedBox(
            height: 30,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < players; i++)
                  Container(
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(color: kYachtSeatColors[i], shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Text('$players명', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: kYachtColor)),
          Text(hint, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}
