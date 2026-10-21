import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/solo_menu.dart';
import '../../../tutorial/tutorial_button.dart';
import '../data/pinball_history.dart';
import '../tutorial/pinball_tutorial.dart';
import 'pinball_hud.dart' show fmtNum, kPinballColor;
import 'pinball_scoring_screen.dart';
import 'pinball_screen.dart';

/// 핀볼 첫 화면: 도전 시작 + 지금까지의 최고 기록.
class PinballMenuScreen extends StatefulWidget {
  const PinballMenuScreen({super.key});

  @override
  State<PinballMenuScreen> createState() => _PinballMenuScreenState();
}

class _PinballMenuScreenState extends State<PinballMenuScreen> {
  List<PinballRecord>? _list;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l = await PinballHistory.load();
    if (mounted) setState(() => _list = l);
  }

  Future<void> _start() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const PinballScreen()));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    final scheme = Theme.of(context).colorScheme;
    final best = list == null || list.isEmpty ? null : list.map((r) => r.round).reduce(max);
    final bestScore = list == null || list.isEmpty ? null : list.map((r) => r.score).reduce(max);
    return SoloMenuScaffold(
      title: '핀볼',
      onHelp: () => pinballTutorial().open(context),
      recordsGame: 'pinball',
      onRecordsClosed: _load,
      loaded: list != null,
      children: [
        const TutorialButton(tutorial: pinballTutorial),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(50), textStyle: const TextStyle(fontFamily: 'NanumGothic', fontSize: 16, fontWeight: FontWeight.w800)),
          onPressed: () => PinballScoringScreen.open(context),
          icon: const Icon(Icons.calculate_rounded),
          label: const Text('점수 계산법'),
        ),
        const SizedBox(height: 18),
        Material(
          color: kPinballColor,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: _start,
            child: const Padding(
              padding: EdgeInsets.all(22),
              child: Row(
                children: [
                  Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 48),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('도전 시작', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900)),
                        SizedBox(height: 4),
                        Text('공 3개로 시간 안에 목표 점수를 채우고,\n업그레이드를 골라 더 멀리 가요', style: TextStyle(color: Colors.white, fontSize: 14, height: 1.3)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: scheme.surface, borderRadius: BorderRadius.circular(20), border: Border.all(color: scheme.outlineVariant)),
          child: best == null
              ? Text('아직 도전 기록이 없어요.', style: TextStyle(color: scheme.onSurfaceVariant))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _stat(context, '가장 먼 라운드', '$best'),
                    _stat(context, '최고 점수', fmtNum(bestScore!)),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 12.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
      ],
    );
  }
}
