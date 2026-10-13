import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../records/records_screen.dart';
import '../core/getcolor_rules.dart';
import '../data/getcolor_storage.dart';
import '../game/getcolor_controller.dart';
import '../getcolor_entry.dart';
import '../tutorial/getcolor_tutorial.dart';
import 'getcolor_painter.dart';

const levelColors = {
  GcLevel.easy: Color(0xFF3FA796),
  GcLevel.normal: Color(0xFF3F7CAC),
  GcLevel.hard: Color(0xFFE09F3E),
  GcLevel.master: Color(0xFFD1495B),
};

/// 겟 컬러 첫 화면: 이어하기 + 난이도 고르기(고르면 바로 시작).
class GetColorMenuScreen extends StatefulWidget {
  const GetColorMenuScreen({super.key});

  @override
  State<GetColorMenuScreen> createState() => _GetColorMenuScreenState();
}

class _GetColorMenuScreenState extends State<GetColorMenuScreen> {
  Map<String, dynamic>? _saved;
  final Map<GcLevel, GetColorStats> _stats = {};
  bool _loaded = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final saved = await GetColorStorage.loadSaved();
    for (final l in GcLevel.values) {
      _stats[l] = await GetColorStorage.stats(l);
    }
    if (!mounted) return;
    setState(() {
      _saved = saved;
      _loaded = true;
    });
  }

  Future<void> _start(GcLevel level) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await startGetColor(context, level, askIfSaved: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final heading = Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800);
    return Scaffold(
      appBar: AppBar(
        title: const Text('겟 컬러', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '게임 방법',
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => getColorTutorial().open(context),
          ),
          IconButton(
            tooltip: '내 기록',
            icon: const Icon(Icons.emoji_events_rounded),
            onPressed: () async {
              await openRecords(context, game: 'get_color');
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
                        onTap: () async {
                          await resumeGetColor(context, _saved!);
                          if (mounted) _load();
                        },
                      ),
                      const SizedBox(height: 18),
                    ],
                    Text('난이도를 골라 시작해요', style: heading),
                    const SizedBox(height: 12),
                    for (final l in GcLevel.values) ...[
                      _LevelCard(level: l, stats: _stats[l] ?? const GetColorStats(), onTap: () => _start(l)),
                      const SizedBox(height: 12),
                    ],
                  ],
                ),
              ),
            ),
    );
  }
}

/// 난이도 카드에 놓는 작은 병 그림 (색 가짓수만큼 색이 보인다).
class _MiniBottles extends StatelessWidget {
  const _MiniBottles({required this.level});

  final GcLevel level;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 78,
      height: 52,
      child: CustomPaint(painter: _MiniPainter(level)),
    );
  }
}

class _MiniPainter extends CustomPainter {
  _MiniPainter(this.level);

  final GcLevel level;

  @override
  void paint(Canvas canvas, Size size) {
    const w = 16.0;
    final scale = size.height / (w * kBottleAspect);
    final shown = level.colors.clamp(1, 3);
    for (var i = 0; i < 3; i++) {
      canvas.save();
      canvas.translate(i * (w * scale + 4) , 0);
      canvas.scale(scale);
      if (i < shown) {
        final base = i * 3;
        paintBottle(canvas, w, [
          (base % 12, 1),
          ((base + 1) % 12, 1),
          ((base + 2) % 12, 1),
          ((base + 3) % 12, 1),
        ]);
      } else {
        paintBottle(canvas, w, const []);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_MiniPainter old) => old.level != level;
}

class _LevelCard extends StatelessWidget {
  const _LevelCard({required this.level, required this.stats, required this.onTap});

  final GcLevel level;
  final GetColorStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = levelColors[level]!;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
          ),
          child: Row(
            children: [
              _MiniBottles(level: level),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(level.label, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: color)),
                    Text('${level.description} · 병 ${level.bottles}개', style: const TextStyle(fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(
                      stats.wins == 0
                          ? '아직 클리어한 적이 없어요'
                          : '클리어 ${stats.wins}번 · 최단 ${formatTime(stats.bestSeconds!)} · 최소 ${stats.bestMoves}번',
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurface.withValues(alpha: 0.65)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: color),
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
    final c = GetColorController.fromJson(saved);
    final level = c.level;
    final done = c.doneCount;
    final elapsed = c.elapsed.value;
    c.dispose();
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
                    Text('${level.label} · 완성한 병 $done/${level.colors} · ${formatTime(elapsed)}'),
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
