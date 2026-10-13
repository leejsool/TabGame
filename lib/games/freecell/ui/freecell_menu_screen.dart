import '../../../tutorial/tutorial_button.dart';
import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../records/records_screen.dart';
import '../core/freecell_difficulty.dart';
import '../core/freecell_rules.dart';
import '../data/freecell_storage.dart';
import '../freecell_entry.dart';
import '../tutorial/freecell_tutorial.dart';

const levelColors = {
  FcLevel.easy: Color(0xFF3FA796),
  FcLevel.medium: Color(0xFF3F7CAC),
  FcLevel.hard: Color(0xFF8E5BC4),
  FcLevel.expert: Color(0xFFD1495B),
};

/// 프리셀 첫 화면: 이어하기 + 난이도 고르기 + 새 게임 + 번호로 시작.
class FreecellMenuScreen extends StatefulWidget {
  const FreecellMenuScreen({super.key});

  @override
  State<FreecellMenuScreen> createState() => _FreecellMenuScreenState();
}

class _FreecellMenuScreenState extends State<FreecellMenuScreen> {
  Map<String, dynamic>? _saved;
  FreecellStats _stats = const FreecellStats();
  FcDifficultyTable? _table;
  FcLevel? _level; // null = 무작위
  bool _loaded = false;
  final TextEditingController _number = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _number.addListener(() => setState(() {})); // 입력할 때마다 난이도 미리보기를 갱신
    _load();
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final saved = await FreecellStorage.loadSaved();
    final stats = await FreecellStorage.stats();
    final level = await FreecellStorage.loadLevel();
    FcDifficultyTable? table;
    try {
      table = await FcDifficultyTable.load();
    } catch (_) {
      table = null; // 난이도 표를 못 읽어도 게임은 할 수 있게
    }
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _stats = stats;
      _level = table == null ? null : level;
      _table = table;
      _loaded = true;
    });
  }

  Future<void> _setLevel(FcLevel? level) async {
    setState(() => _level = level);
    await FreecellStorage.saveLevel(level);
  }

  Future<void> _newGame() async {
    final deal = await pickDeal(_level);
    if (!mounted) return;
    await startFreecellDeal(context, deal);
    if (mounted) _load();
  }

  Future<void> _startWithNumber() async {
    final n = int.tryParse(_number.text.trim());
    if (n == null || n < 1 || n > kMaxDeal) {
      setState(() => _error = '1부터 $kMaxDeal 사이의 번호를 넣어 주세요.');
      return;
    }
    if (n == kUnsolvableDeal) {
      setState(() => _error = '$n번은 풀 수 없는 판이라 쓸 수 없어요.');
      return;
    }
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    await startFreecellDeal(context, n);
    if (mounted) _load();
  }

  /// 입력 중인 번호의 난이도 안내 (표를 읽었고 번호가 올바를 때만).
  String? get _numberHint {
    final n = int.tryParse(_number.text.trim());
    final table = _table;
    if (n == null || table == null || n < 1 || n > kMaxDeal || n == kUnsolvableDeal) return null;
    return '#$n · ${table.levelOf(n).label} 난이도';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('프리셀', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '게임 방법',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => freecellTutorial().open(context),
          ),
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () async {
              await openRecords(context, game: 'freecell');
              if (mounted) _load();
            },
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    if (_saved != null) ...[
                      _ResumeCard(
                        saved: _saved!,
                        table: _table,
                        onTap: () async {
                          await resumeFreecell(context, _saved!);
                          if (mounted) _load();
                        },
                      ),
                      const SizedBox(height: 18),
                    ],
                    const TutorialButton(tutorial: freecellTutorial),
                    const SizedBox(height: 18),
                    Text('난이도',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 10),
                    if (_table != null) _levelPicker(context),
                    const SizedBox(height: 16),
                    Material(
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(24),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: _newGame,
                        child: Padding(
                          padding: const EdgeInsets.all(22),
                          child: Row(
                            children: [
                              const Icon(Icons.shuffle_rounded, color: Colors.white, size: 38),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _level == null ? '새 게임' : '새 게임 · ${_level!.label}',
                                      style: TextStyle(
                                          color: scheme.onPrimary, fontSize: 22, fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      _level == null
                                          ? '무작위 판으로 시작해요 (모두 풀 수 있는 판)'
                                          : _level!.description,
                                      style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.85)),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.chevron_right_rounded, color: scheme.onPrimary),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text('번호로 시작',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      '같은 번호는 늘 같은 판이에요. 친구와 같은 번호로 겨뤄 보세요! (1~$kMaxDeal)',
                      style: TextStyle(fontSize: 13, color: scheme.onSurface.withValues(alpha: 0.65)),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _number,
                            keyboardType: TextInputType.number,
                            onSubmitted: (_) => _startWithNumber(),
                            decoration: InputDecoration(
                              hintText: '예: 617',
                              errorText: _error,
                              helperText: _numberHint,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              prefixText: '# ',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _startWithNumber,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                          ),
                          child: const Text('시작'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _StatsRow(stats: _stats),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _levelPicker(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget chip(FcLevel? level, String label, Color color) {
      final selected = _level == level;
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        selectedColor: color.withValues(alpha: 0.22),
        side: BorderSide(color: selected ? color : scheme.outlineVariant, width: selected ? 2 : 1),
        labelStyle: TextStyle(
          fontWeight: FontWeight.w800,
          color: selected ? color : scheme.onSurface.withValues(alpha: 0.8),
        ),
        onSelected: (_) => _setLevel(level),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        chip(null, '무작위', scheme.primary),
        for (final l in FcLevel.values) chip(l, l.label, levelColors[l]!),
      ],
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.saved, required this.table, required this.onTap});

  final Map<String, dynamic> saved;
  final FcDifficultyTable? table;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final moves = (saved['autos'] as List).where((a) => a == 0).length;
    final deal = saved['deal'] as int;
    final level = table?.levelOf(deal);
    return Card(
      color: scheme.primaryContainer,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.play_circle_fill_rounded, size: 44, color: scheme.primary),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('이어하기', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                      '#$deal${level == null ? '' : ' · ${level.label}'} · $moves수 · ${formatTime(saved['elapsed'] as int)}',
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});

  final FreecellStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget cell(String label, String value) => Expanded(
          child: Column(
            children: [
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 12, color: scheme.onSurface.withValues(alpha: 0.65))),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          cell('완성', '${stats.wins}판'),
          cell('승률', stats.starts == 0 ? '-' : '${(stats.winRate * 100).round()}%'),
          cell('최단 시간', stats.bestSeconds == null ? '-' : formatTime(stats.bestSeconds!)),
          cell('최소 이동', stats.bestMoves == null ? '-' : '${stats.bestMoves}수'),
        ],
      ),
    );
  }
}
