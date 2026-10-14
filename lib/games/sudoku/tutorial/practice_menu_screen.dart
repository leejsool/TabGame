import 'package:flutter/material.dart';

import '../../../tutorial/tutorial_progress.dart';
import 'technique_info.dart';
import 'technique_lesson_screen.dart';

/// 심화 기술 연습 목록. 기술마다 예제 판 위에서 직접 연습할 수 있다.
class SudokuPracticeMenuScreen extends StatefulWidget {
  const SudokuPracticeMenuScreen({super.key});

  @override
  State<SudokuPracticeMenuScreen> createState() => _SudokuPracticeMenuScreenState();
}

class _SudokuPracticeMenuScreenState extends State<SudokuPracticeMenuScreen> {
  Set<String> _done = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final done = await TutorialProgress.doneLessons();
    if (mounted) setState(() => _done = done);
  }

  Future<void> _open(int index) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => SudokuTechniqueLessonScreen(index: index)),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final doneCount = kTechniqueInfos.where((i) => _done.contains(i.id)).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('심화 기술 연습', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(top: false, child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
            children: [
              Text(
                '어려운 판은 "싱글"만으로는 풀리지 않아요. 기술을 하나씩, 예제 판에서 직접 해 보며 '
                '익혀요. 마음 내키는 것부터 골라도 좋아요. ($doneCount / ${kTechniqueInfos.length} 완료)',
                style: TextStyle(
                  height: 1.5,
                  color: scheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              for (var level = 1; level <= 4; level++) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 22, bottom: 8),
                  child: Text(
                    levelTitle(level),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w800, color: scheme.primary),
                  ),
                ),
                for (var i = 0; i < kTechniqueInfos.length; i++)
                  if (kTechniqueInfos[i].level == level)
                    _TechniqueTile(
                      info: kTechniqueInfos[i],
                      done: _done.contains(kTechniqueInfos[i].id),
                      onTap: () => _open(i),
                    ),
              ],
            ],
          ),
        ),
      )),
    );
  }
}

class _TechniqueTile extends StatelessWidget {
  const _TechniqueTile({required this.info, required this.done, required this.onTap});

  final TechniqueInfo info;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: scheme.surface,
        elevation: 1,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                  color: done ? const Color(0xFF2E9E5B) : scheme.outline,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        info.label,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        info.summary,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: scheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
