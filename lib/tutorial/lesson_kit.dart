import 'package:flutter/material.dart';

/// 게임별 "교과학습"의 공통 틀: 단원 목록 → 단원 화면(이전/다음) + 글·그림·퀴즈 조각들.

/// 교과학습에서 쓰는 강조색 (하위 위젯이 [LessonAccent.of]로 읽는다).
class LessonAccent extends InheritedWidget {
  const LessonAccent({super.key, required this.color, required super.child});

  final Color color;

  static Color of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LessonAccent>()?.color ?? Theme.of(context).colorScheme.primary;

  @override
  bool updateShouldNotify(LessonAccent old) => old.color != color;
}

/// 메뉴·설정 화면의 큰 "교과학습" 단추 (게임마다 같은 크기·모양).
class LessonOpenButton extends StatelessWidget {
  const LessonOpenButton({super.key, required this.onPressed, this.label = '교과학습'});

  final VoidCallback onPressed;
  final String label;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.menu_book_rounded),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontFamily: 'NanumGothic', fontSize: 16, fontWeight: FontWeight.w800),
      ),
    );
  }
}

/// 교과학습의 한 단원.
class LessonUnit {
  const LessonUnit({required this.title, required this.subtitle, required this.icon, required this.build});

  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> Function(BuildContext context) build;
}

/// 단원 목록 화면. [heroArt]와 [heroText]는 맨 위 소개 상자에 들어간다.
class LessonListScreen extends StatelessWidget {
  const LessonListScreen({
    super.key,
    required this.accent,
    required this.heroArt,
    required this.heroText,
    required this.units,
    this.title = '교과학습',
  });

  final Color accent;
  final Widget heroArt;
  final String heroText;
  final List<LessonUnit> units;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return LessonAccent(
      color: accent,
      child: Scaffold(
        appBar: AppBar(title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800))),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: accent.withValues(alpha: 0.35)),
                    ),
                    child: Row(
                      children: [
                        SizedBox(width: 72, height: 72, child: heroArt),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(heroText, style: const TextStyle(fontSize: 15, height: 1.45, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                  for (var i = 0; i < units.length; i++)
                    Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 8),
                      color: scheme.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: accent.withValues(alpha: 0.14),
                          child: Icon(units[i].icon, color: accent),
                        ),
                        title: Text('${i + 1}. ${units[i].title}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text(units[i].subtitle),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => LessonUnitScreen(index: i, units: units, accent: accent),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 단원 하나: 내용 + 이전/다음 단추.
class LessonUnitScreen extends StatelessWidget {
  const LessonUnitScreen({super.key, required this.index, required this.units, required this.accent});

  final int index;
  final List<LessonUnit> units;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final unit = units[index];
    final hasNext = index + 1 < units.length;
    return LessonAccent(
      color: accent,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('${index + 1}. ${unit.title}', style: const TextStyle(fontWeight: FontWeight.w800))),
          body: SafeArea(
            top: false,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 680),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
                  children: [
                    ...unit.build(context),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        if (index > 0)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => Navigator.of(context).pushReplacement(
                                MaterialPageRoute<void>(builder: (_) => LessonUnitScreen(index: index - 1, units: units, accent: accent)),
                              ),
                              icon: const Icon(Icons.chevron_left_rounded),
                              label: const Text('이전'),
                            ),
                          ),
                        if (index > 0 && hasNext) const SizedBox(width: 10),
                        if (hasNext)
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: () => Navigator.of(context).pushReplacement(
                                MaterialPageRoute<void>(builder: (_) => LessonUnitScreen(index: index + 1, units: units, accent: accent)),
                              ),
                              icon: const Icon(Icons.chevron_right_rounded),
                              label: Text('다음: ${units[index + 1].title}', overflow: TextOverflow.ellipsis),
                            ),
                          )
                        else
                          Expanded(
                            flex: 2,
                            child: FilledButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('교과학습 마치기'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── 글 조각들 ─────────────────────────

Widget lessonH(BuildContext context, String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 6),
      child: Text(text, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: LessonAccent.of(context))),
    );

Widget lessonP(String text) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Text(text, style: const TextStyle(fontSize: 16, height: 1.6)),
    );

Widget lessonBullets(BuildContext context, List<String> items) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final t in items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ', style: TextStyle(fontSize: 16, color: LessonAccent.of(context), fontWeight: FontWeight.w900)),
                  Expanded(child: Text(t, style: const TextStyle(fontSize: 16, height: 1.55))),
                ],
              ),
            ),
        ],
      ),
    );

/// 눈에 띄는 한 줄 정리.
Widget lessonKey(BuildContext context, String text, {IconData icon = Icons.lightbulb_rounded}) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF3C4),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFFFD84D)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFFB88700), size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 15.5, height: 1.5, fontWeight: FontWeight.w700, color: Color(0xFF3A2F00)),
          ),
        ),
      ],
    ),
  );
}

/// [height]를 null로 주면 그림 높이에 맞춰 늘어난다 (그림이 스스로 높이를 정할 때).
Widget lessonArt(Widget child, {double? height = 240, String? caption}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      children: [
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x22000000)),
          ),
          clipBehavior: Clip.antiAlias,
          child: child,
        ),
        if (caption != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(caption, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5, color: Color(0xFF666666))),
          ),
      ],
    ),
  );
}

/// 단계(depth)를 슬라이더로 올리며 같은 규칙이 되풀이되는 모습을 보는 그림.
class LessonDepthExplorer extends StatefulWidget {
  const LessonDepthExplorer({
    super.key,
    required this.painter,
    required this.minDepth,
    required this.maxDepth,
    required this.caption,
    this.initial,
    this.height = 260,
  });

  final CustomPainter Function(int depth) painter;
  final int minDepth;
  final int maxDepth;
  final String Function(int depth) caption;
  final int? initial;
  final double height;

  @override
  State<LessonDepthExplorer> createState() => LessonDepthExplorerState();
}

class LessonDepthExplorerState extends State<LessonDepthExplorer> {
  late int _depth = widget.initial ?? widget.minDepth;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        lessonArt(CustomPaint(painter: widget.painter(_depth)), height: widget.height),
        Row(
          children: [
            const Text('단계', style: TextStyle(fontWeight: FontWeight.w800)),
            Expanded(
              child: Slider(
                min: widget.minDepth.toDouble(),
                max: widget.maxDepth.toDouble(),
                divisions: widget.maxDepth - widget.minDepth,
                value: _depth.toDouble(),
                label: '$_depth',
                onChanged: (v) => setState(() => _depth = v.round()),
              ),
            ),
            SizedBox(width: 24, child: Text('$_depth', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17))),
          ],
        ),
        Text(widget.caption(_depth), textAlign: TextAlign.center, style: const TextStyle(fontSize: 14.5, height: 1.45, color: Color(0xFF555555))),
      ],
    );
  }
}

/// 객관식 퀴즈 한 문제.
class LessonQuiz extends StatefulWidget {
  const LessonQuiz({
    super.key,
    required this.question,
    required this.options,
    required this.answer,
    required this.explain,
    this.figure,
  });

  /// 문제를 이해하는 데 도움이 되는 그림 (문제 글 아래에 가운데로 놓인다).
  final Widget? figure;
  final String question;
  final List<String> options;
  final int answer;
  final String explain;

  @override
  State<LessonQuiz> createState() => LessonQuizState();
}

class LessonQuizState extends State<LessonQuiz> {
  int? _picked;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final done = _picked != null;
    final correct = _picked == widget.answer;
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      color: scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.question, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, height: 1.4)),
            if (widget.figure != null) Padding(padding: const EdgeInsets.only(top: 10), child: Center(child: widget.figure)),
            const SizedBox(height: 8),
            for (var i = 0; i < widget.options.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: OutlinedButton(
                  onPressed: done ? null : () => setState(() => _picked = i),
                  style: OutlinedButton.styleFrom(
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    backgroundColor: !done
                        ? null
                        : i == widget.answer
                            ? const Color(0xFF2E9E5B).withValues(alpha: 0.16)
                            : i == _picked
                                ? const Color(0xFFE5484D).withValues(alpha: 0.12)
                                : null,
                    side: BorderSide(
                      color: !done
                          ? scheme.outline
                          : i == widget.answer
                              ? const Color(0xFF2E9E5B)
                              : i == _picked
                                  ? const Color(0xFFE5484D)
                                  : scheme.outlineVariant,
                      width: done && (i == widget.answer || i == _picked) ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.options[i],
                          style: TextStyle(fontSize: 15, height: 1.35, color: scheme.onSurface),
                        ),
                      ),
                      if (done && i == widget.answer) const Icon(Icons.check_circle_rounded, color: Color(0xFF2E9E5B)),
                      if (done && i == _picked && i != widget.answer) const Icon(Icons.cancel_rounded, color: Color(0xFFE5484D)),
                    ],
                  ),
                ),
              ),
            if (done) ...[
              const SizedBox(height: 8),
              Text(
                correct ? '정답! 🎉' : '아쉬워요. 정답은 "${widget.options[widget.answer]}"예요.',
                style: TextStyle(fontWeight: FontWeight.w800, color: correct ? const Color(0xFF2E9E5B) : const Color(0xFFE5484D)),
              ),
              const SizedBox(height: 4),
              Text(widget.explain, style: const TextStyle(fontSize: 14.5, height: 1.5)),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(onPressed: () => setState(() => _picked = null), child: const Text('다시 풀기')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
