import 'package:flutter/material.dart';

import '../../../core/game_info.dart';
import '../../../core/solo_menu.dart';
import '../../../versus/vs_mode_switch.dart';
import '../core/kt_songs.dart';
import '../data/kt_history.dart';
import '../tutorial/kt_tutorial.dart';
import 'kt_board.dart';
import 'kt_hud.dart';
import 'kt_play_screen.dart';

/// 건반 톡톡 혼자 하기 첫 화면: 곡 고르기(곡마다 별·최고 점수)와 무한 모드.
class KtMenuScreen extends StatefulWidget {
  const KtMenuScreen({super.key});

  @override
  State<KtMenuScreen> createState() => _KtMenuScreenState();
}

class _KtMenuScreenState extends State<KtMenuScreen> {
  Map<String, KtBest>? _bests;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final b = await KtHistory.bests();
    if (mounted) setState(() => _bests = b);
  }

  Future<void> _play(KtSong? song) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => KtPlayScreen(song: song)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final bests = _bests ?? const {};
    return SoloMenuScaffold(
      title: '건반 톡톡',
      onHelp: () => keytapTutorial().open(context),
      recordsGame: 'keytap',
      onRecordsClosed: _load,
      loaded: _bests != null,
      sideChildren: [
        const _SectionLabel('무한 모드 · 틀릴 때까지 점점 빨라져요'),
        _EndlessCard(best: bests['endless']?.score ?? 0, onTap: () => _play(null)),
      ],
      children: [
        const Padding(padding: EdgeInsets.only(top: 4), child: VsModeSwitch(gameId: 'keytap', current: PlayMode.solo)),
        const _SectionLabel('곡 완주 · 한 바퀴 돌 때마다 별 하나 (점점 빨라져요)'),
        for (final s in KtSong.all) _SongCard(song: s, best: bests[s.id], onTap: () => _play(s)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
        child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

class _SongCard extends StatelessWidget {
  const _SongCard({required this.song, required this.best, required this.onTap});

  final KtSong song;
  final KtBest? best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: BorderSide(color: scheme.outlineVariant)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(color: kKeytapColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.music_note_rounded, color: kKeytapColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(song.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(
                      '${song.composer} · 빠르기 ${'●' * song.level}${'○' * (5 - song.level)}${(best?.score ?? 0) > 0 ? ' · 최고 ${best!.score}점' : ''}',
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              KtStars(stars: best?.stars ?? 0, size: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _EndlessCard extends StatelessWidget {
  const _EndlessCard({required this.best, required this.onTap});

  final int best;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: kKeytapColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.all_inclusive_rounded, color: Colors.white, size: 34),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('무한 모드', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: Colors.white)),
                    Text(best > 0 ? '최고 $best점' : '여러 곡이 이어서 나와요', style: const TextStyle(fontSize: 13, color: Colors.white70)),
                  ],
                ),
              ),
              const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
            ],
          ),
        ),
      ),
    );
  }
}
