import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../versus/vs_setup.dart';
import '../core/yacht_cpu.dart';
import '../game/yacht_controller.dart';
import '../tutorial/yacht_tutorial.dart';
import 'yacht_party_picker.dart';
import 'yacht_screen.dart';

/// 한 기기로 하는 야추의 시작 전 설정: 봇(CPU)과 로컬 플레이어(사람)를 + / − 로 정한다 (합쳐서 2~4명).
/// 사람만 모이면 돌려 가며 하는 판, 사람 1명 + 봇이면 CPU와 대결, 섞어도 된다.
class YachtSetupScreen extends StatefulWidget {
  const YachtSetupScreen({super.key, this.mode = PlayMode.local2p});

  /// (옛 "CPU와 대결" 진입도 이 화면으로 온다. 어떤 방식이든 같은 설정 화면이다.)
  final PlayMode mode;

  @override
  State<YachtSetupScreen> createState() => _YachtSetupScreenState();
}

class _YachtSetupScreenState extends State<YachtSetupScreen> {
  int _humans = 1;
  int _bots = 1;
  YachtLevel _level = YachtLevel.normal;
  bool _threeKind = false;

  void _start() {
    final humans = _humans, players = _humans + _bots, level = _level, three = _threeKind;
    final bots = [for (var s = humans; s < players; s++) s];
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => YachtScreen(mode: PlayMode.local2p, players: players, level: level, threeKind: three, cpuSeats: bots)),
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
      title: '야추 · 로컬 플레이',
      switchFrom: PlayMode.local2p,
      onStart: _start,
      resume: VsResume(gameName: '야추', describe: yachtSavedLabel, onResume: _resume),
      tutorial: yachtTutorial,
      children: [
        YachtPartyPicker(humans: _humans, bots: _bots, onChanged: (h, b) => setState(() {
              _humans = h;
              _bots = b;
            })),
        VsHint(_bots > 0
            ? '봇은 CPU가 대신 굴려요. 사람이 여럿이면 기기를 돌려 가며 해요. 다음 판부터는 시작하는 순서가 돌아가요.'
            : '기기 하나를 돌려 가며 해요. 다음 판부터는 시작하는 순서가 돌아가요.'),
        const VsSectionTitle('옵션', topGap: 16),
        Material(
          color: Theme.of(context).colorScheme.surface,
          elevation: 1,
          borderRadius: BorderRadius.circular(16),
          child: SwitchListTile(
            key: const ValueKey('yacht-three-kind'),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
            title: const Text('쓰리카드 칸 넣기', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            subtitle: const Text('같은 눈 3개 이상이면 눈 5개의 합. 칸이 13개, 라운드도 13번이 돼요.', style: TextStyle(fontSize: 13)),
            value: _threeKind,
            onChanged: (v) => setState(() => _threeKind = v),
          ),
        ),
        if (_bots > 0) ...[
          const VsSectionTitle('봇 난이도', topGap: 16),
          VsLevelPicker<YachtLevel>(
            levels: YachtLevel.values,
            selected: _level,
            onChanged: (l) => setState(() => _level = l),
            label: (l) => l.label,
          ),
        ],
      ],
    );
  }
}

/// 이어하던 판을 한 줄로 설명한다 (설정 화면의 "이어하기" 카드).
String yachtSavedLabel(Map<String, dynamic> j) {
  final cards = (j['game'] as Map?)?['cards'] as List?;
  final players = cards?.length ?? 2;
  final cpus = j['mode'] == PlayMode.vsCpu.name ? players - 1 : ((j['cpu'] as List?)?.length ?? 0);
  final rounds = (j['game'] as Map?)?['three'] == true ? 13 : 12;
  final filled = cards == null || cards.isEmpty ? 0 : (cards.last as List).where((s) => s != null).length;
  final who = cpus == 0 ? '한 기기로 함께 · $players명' : (cpus == players - 1 ? 'CPU 대결 · $players명' : '사람 ${players - cpus} + 봇 $cpus');
  return '$who · ${filled < rounds ? filled + 1 : rounds}/$rounds 라운드';
}
