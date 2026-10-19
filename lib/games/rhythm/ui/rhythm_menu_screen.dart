import 'package:flutter/material.dart';

import '../core/rhythm_chart.dart';
import '../data/rhythm_storage.dart';
import '../tutorial/rhythm_tutorial.dart';
import '../../../records/records_screen.dart' show openRecords;
import 'calibration_screen.dart';
import 'camp_painter.dart';
import 'rhythm_screen.dart';
import 'rhythm_art.dart';

const _gold = Color(0xFFFFD21F);
const _ink = Color(0xFF1A1523);

/// 리듬 검사단 첫 화면.
class RhythmMenuScreen extends StatefulWidget {
  const RhythmMenuScreen({super.key});

  @override
  State<RhythmMenuScreen> createState() => _RhythmMenuScreenState();
}

class _RhythmMenuScreenState extends State<RhythmMenuScreen> {
  /// 이보다 낮은 화면에서는 스크롤한다 (제목 + 네 명 + 코스 카드들 + 버튼들이 다 들어가는 높이).
  /// 코스 카드가 늘면 그만큼 커진다 (코스 하나당 약 76px).
  static final double _minHeight = 520.0 + RhythmCourse.all.length * 76;

  final List<RhythmResult?> _best = List.filled(RhythmCourse.all.length, null);
  final List<int> _clears = List.filled(RhythmCourse.all.length, 0);
  RhythmArt? _art;

  @override
  void initState() {
    super.initState();
    _load();
    RhythmArt.load().then((a) {
      if (mounted) setState(() => _art = a);
    });
  }

  Future<void> _load() async {
    final best = <RhythmResult?>[];
    final clears = <int>[];
    for (var i = 0; i < RhythmCourse.all.length; i++) {
      best.add(await RhythmStorage.loadBest(i));
      clears.add(await RhythmStorage.clears(i));
    }
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < best.length; i++) {
        _best[i] = best[i];
        _clears[i] = clears[i];
      }
    });
  }

  /// 앞 코스를 합격(별 2개 이상)해야 열린다.
  bool _unlocked(int i) => i == 0 || (_best[i - 1]?.stars ?? 0) >= RhythmCourse.passStars;

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1B2A41),
      body: Stack(
        children: [
          Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: BackgroundPainter(_art ?? RhythmArt.empty())))),
          SafeArea(
            // 화면이 낮으면(가로 폰 등) 전체를 세로로 스크롤한다. 코스가 늘어도 아래 버튼이 잘리지 않는다.
            child: LayoutBuilder(builder: (context, box) {
              final content = Column(
                children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(side: BorderSide(color: _ink, width: 3.5)),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_rounded, color: _ink),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(side: BorderSide(color: _ink, width: 3.5)),
                        child: IconButton(
                          tooltip: '기록',
                          icon: const Icon(Icons.emoji_events_rounded, color: _ink),
                          onPressed: () async {
                            await openRecords(context, game: 'rhythm_swords');
                            if (mounted) _load();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(side: BorderSide(color: _ink, width: 3.5)),
                        child: IconButton(
                          tooltip: '게임 방법',
                          icon: const Icon(Icons.help_outline_rounded, color: _ink),
                          onPressed: () => rhythmTutorial().open(context),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                const _Title(),
                const SizedBox(height: 10),
                Expanded(child: _SquadRow(art: _art)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          child: TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: _ink, backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _ink, width: 3))),
                          onPressed: () => rhythmTutorial().open(context),
                          icon: const Icon(Icons.school_rounded),
                          label: const Text('튜토리얼 보기'),
                        )),
                        const SizedBox(height: 10),
                        for (var i = 0; i < RhythmCourse.all.length; i++) ...[
                          if (_unlocked(i))
                            _CourseCard(course: RhythmCourse.all[i], best: _best[i], clears: _clears[i], onTap: () => _open(RhythmScreen(course: i)))
                          else
                            _LockedCard(title: RhythmCourse.all[i].title, need: RhythmCourse.all[i - 1].title),
                          const SizedBox(height: 10),
                        ],
                        const _ComingSoonCard(),
                        TextButton.icon(
                          style: TextButton.styleFrom(foregroundColor: _ink, backgroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: _ink, width: 3))),
                          onPressed: () => _open(const CalibrationScreen()),
                          icon: const Icon(Icons.tune_rounded),
                          label: const Text('박자 보정 (소리가 어긋나면)'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              );
              if (box.maxHeight >= _minHeight) return content;
              return SingleChildScrollView(child: SizedBox(height: _minHeight, child: content));
            }),
          ),
        ],
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    Widget text(String s, double size, Paint? stroke, Color? color) => Text(
          s,
          style: TextStyle(fontSize: size, fontWeight: FontWeight.w900, foreground: stroke, color: color, height: 1.1),
        );
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 11
      ..strokeJoin = StrokeJoin.round
      ..color = _ink;
    return Column(
      children: [
        Stack(children: [text('리듬 검사단', 46, stroke, null), text('리듬 검사단', 46, null, _gold)]),
        const SizedBox(height: 4),
        Stack(children: [
          text('박자에 맞춰 검을 휘둘러요', 16, Paint()..style = PaintingStyle.stroke..strokeWidth = 5..strokeJoin = StrokeJoin.round..color = _ink, null),
          text('박자에 맞춰 검을 휘둘러요', 16, null, Colors.white),
        ]),
      ],
    );
  }
}

class _SquadRow extends StatelessWidget {
  const _SquadRow({required this.art});

  final RhythmArt? art;

  @override
  Widget build(BuildContext context) {
    final a = art;
    if (a == null) return const SizedBox.shrink();
    return CustomPaint(painter: SquadPainter(a), size: Size.infinite);
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course, required this.best, required this.clears, required this.onTap});

  final RhythmCourse course;
  final RhythmResult? best;
  final int clears;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _ink, width: 4),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), offset: const Offset(0, 5))],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(color: const Color(0xFFFF7A2F), shape: BoxShape.circle, border: Border.all(color: _ink, width: 3)),
                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 36),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.title, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900, color: _ink)),
                    Text(course.subtitle, style: TextStyle(fontSize: 13.5, color: _ink)),
                    const SizedBox(height: 2),
                    if (best == null)
                      const Text('아직 수료하지 않았어요', style: TextStyle(fontSize: 12.5, color: Color(0xFF7A6B5A)))
                    else
                      Row(
                        children: [
                          for (var i = 0; i < 3; i++)
                            Icon(Icons.star_rounded, size: 20, color: i < best!.stars ? _gold : const Color(0xFFD9CDB5)),
                          const SizedBox(width: 6),
                          Text('최고 ${best!.score}점 · $clears회 수료', style: const TextStyle(fontSize: 12.5, color: Color(0xFF7A6B5A))),
                        ],
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: _ink),
            ],
          ),
        ),
      ),
    );
  }
}

class _LockedCard extends StatelessWidget {
  const _LockedCard({required this.title, required this.need});

  final String title;
  final String need;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(18), border: Border.all(color: _ink, width: 3)),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: _ink),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _ink, fontWeight: FontWeight.w900, fontSize: 16)),
                Text("'$need'에서 별 ${RhythmCourse.passStars}개 이상을 받으면 열려요", style: const TextStyle(color: _ink, fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonCard extends StatelessWidget {
  const _ComingSoonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.4), borderRadius: BorderRadius.circular(18), border: Border.all(color: _ink, width: 3)),
      child: const Row(
        children: [
          Icon(Icons.more_horiz_rounded, color: _ink),
          SizedBox(width: 12),
          Expanded(child: Text('다음 모험도 준비 중이에요', style: TextStyle(color: _ink, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }
}
