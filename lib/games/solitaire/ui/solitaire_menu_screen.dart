import '../../../tutorial/tutorial_button.dart';
import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../records/records_screen.dart';
import '../core/solitaire_rules.dart';
import '../data/solitaire_storage.dart';
import '../solitaire_entry.dart';
import '../tutorial/solitaire_tutorial.dart';

/// 솔리테어 첫 화면: 이어하기 + 뽑기 장수 고르기 + 새 게임 + 번호로 시작.
class SolitaireMenuScreen extends StatefulWidget {
  const SolitaireMenuScreen({super.key});

  @override
  State<SolitaireMenuScreen> createState() => _SolitaireMenuScreenState();
}

class _SolitaireMenuScreenState extends State<SolitaireMenuScreen> {
  Map<String, dynamic>? _saved;
  int _draw = 1;
  final Map<int, SolitaireStats> _stats = {};
  bool _loaded = false;
  final TextEditingController _number = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _number.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final saved = await SolitaireStorage.loadSaved();
    final draw = await SolitaireStorage.loadDraw();
    final s1 = await SolitaireStorage.stats(1);
    final s3 = await SolitaireStorage.stats(3);
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _draw = draw;
      _stats[1] = s1;
      _stats[3] = s3;
      _loaded = true;
    });
  }

  Future<void> _setDraw(int draw) async {
    setState(() => _draw = draw);
    await SolitaireStorage.saveDraw(draw);
  }

  Future<void> _newGame() async {
    await startSolitaireDeal(context, randomSolitaireDeal(), _draw, askIfSaved: true);
    if (mounted) _load();
  }

  Future<void> _startWithNumber() async {
    final n = int.tryParse(_number.text.trim());
    if (n == null || n < 1 || n > kMaxSolitaireDeal) {
      setState(() => _error = '1부터 $kMaxSolitaireDeal 사이의 번호를 넣어 주세요.');
      return;
    }
    setState(() => _error = null);
    FocusScope.of(context).unfocus();
    await startSolitaireDeal(context, n, _draw, askIfSaved: true);
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final heading = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);
    return Scaffold(
      appBar: AppBar(
        title: const Text('솔리테어', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '게임 방법',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => solitaireTutorial().open(context),
          ),
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () async {
              await openRecords(context, game: 'solitaire');
              if (mounted) _load();
            },
          ),
        ],
      ),
      body: SafeArea(top: false, child: !_loaded
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
                        onTap: () async {
                          await resumeSolitaire(context, _saved!);
                          if (mounted) _load();
                        },
                      ),
                      const SizedBox(height: 18),
                    ],
                    const TutorialButton(tutorial: solitaireTutorial),
                    const SizedBox(height: 18),
                    Text('뽑는 방식', style: heading),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _DrawCard(draw: 1, selected: _draw == 1, onTap: () => _setDraw(1))),
                        const SizedBox(width: 12),
                        Expanded(child: _DrawCard(draw: 3, selected: _draw == 3, onTap: () => _setDraw(3))),
                      ],
                    ),
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
                                      '새 게임 · $_draw장 뽑기',
                                      style: TextStyle(color: scheme.onPrimary, fontSize: 22, fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      '무작위 판으로 시작해요',
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
                    Text('번호로 시작', style: heading),
                    const SizedBox(height: 4),
                    Text(
                      '같은 번호는 늘 같은 판이에요. 친구와 같은 번호로 겨뤄 보세요! (1~$kMaxSolitaireDeal)',
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
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                              prefixText: '# ',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: _startWithNumber,
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18)),
                          child: const Text('시작'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _StatsRow(draw: _draw, stats: _stats[_draw] ?? const SolitaireStats()),
                  ],
                ),
              ),
            )),
    );
  }
}

class _DrawCard extends StatelessWidget {
  const _DrawCard({required this.draw, required this.selected, required this.onTap});

  final int draw;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = draw == 1 ? const Color(0xFF3FA796) : const Color(0xFF8E5BC4);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: color.withValues(alpha: selected ? 0.20 : 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? color : scheme.outlineVariant, width: selected ? 3 : 1.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            children: [
              Text('$draw장 뽑기', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: color)),
              const SizedBox(height: 2),
              Text(draw == 1 ? '쉬워요' : '더 어려워요', style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResumeCard extends StatelessWidget {
  const _ResumeCard({required this.saved, required this.onTap});

  final Map<String, dynamic> saved;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final moves = (saved['autos'] as List).where((a) => a == 0).length;
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
                    Text('#${saved['deal']} · ${saved['draw']}장 뽑기 · $moves수 · ${formatTime(saved['elapsed'] as int)}'),
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
  const _StatsRow({required this.draw, required this.stats});

  final int draw;
  final SolitaireStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget cell(String label, String value) => Expanded(
          child: Column(
            children: [
              FittedBox(child: Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800))),
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
      child: Column(
        children: [
          Text('$draw장 뽑기 기록', style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            children: [
              cell('완성', '${stats.wins}판'),
              cell('승률', stats.starts == 0 ? '-' : '${(stats.winRate * 100).round()}%'),
              cell('최단 시간', stats.bestSeconds == null ? '-' : formatTime(stats.bestSeconds!)),
              cell('최소 이동', stats.bestMoves == null ? '-' : '${stats.bestMoves}수'),
            ],
          ),
        ],
      ),
    );
  }
}
