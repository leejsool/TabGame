part of 'prophecy_lesson_widgets.dart';

// 공부 화면의 나머지 시연 위젯 (파일을 역할별로 나눈 것)

/// "이 문장은 거짓이다"를 참이라고 가정해 보고, 거짓이라고 가정해 보는 장치.
class LiarDemo extends StatefulWidget {
  const LiarDemo({super.key});

  @override
  State<LiarDemo> createState() => _LiarDemoState();
}

class _LiarDemoState extends State<LiarDemo> {
  bool? _assume;

  @override
  Widget build(BuildContext context) {
    return _box(context, children: [
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: kProphColor.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(12)),
        child: const Text('"이 문장은 거짓이다."', textAlign: TextAlign.center, style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
      ),
      const SizedBox(height: 10),
      const Text('이 문장이 참인지 거짓인지 가정해 보세요.', textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          ChoiceChip(label: const Text('참이라고 하자'), selected: _assume == true, onSelected: (_) => setState(() => _assume = true)),
          ChoiceChip(label: const Text('거짓이라고 하자'), selected: _assume == false, onSelected: (_) => setState(() => _assume = false)),
        ],
      ),
      if (_assume == true)
        _verdict('참이라고 하면 문장이 말하는 대로 "거짓"이어야 해요. 그런데 참이라고 했으니 모순!', good: false)
      else if (_assume == false)
        _verdict('거짓이라고 하면 "이 문장은 거짓이다"라는 말이 틀린 셈이니, 문장은 거짓이 아니라 참이어야 해요. 또 모순!', good: false),
    ]);
  }
}

// ───────────────────────── 러셀의 역설 / 이발사의 역설 ─────────────────────────

/// "자기 수염을 깎지 않는 사람만 깎아 주는 이발사"는 자기 수염을 깎을까?
class BarberDemo extends StatefulWidget {
  const BarberDemo({super.key});

  @override
  State<BarberDemo> createState() => _BarberDemoState();
}

class _BarberDemoState extends State<BarberDemo> {
  bool? _shaves;

  @override
  Widget build(BuildContext context) {
    return _box(context, children: [
      const Text(
        '어느 마을의 이발사는 "마을에서 자기 수염을 스스로 깎지 않는 사람만, 그리고 그런 사람은 모두 깎아 준다"고 해요.',
        style: TextStyle(fontSize: 15, height: 1.5, fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 10),
      const Text('그럼 이발사 자신의 수염은 누가 깎을까요?', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          ChoiceChip(label: const Text('이발사가 스스로 깎는다'), selected: _shaves == true, onSelected: (_) => setState(() => _shaves = true)),
          ChoiceChip(label: const Text('다른 사람이 깎아 준다'), selected: _shaves == false, onSelected: (_) => setState(() => _shaves = false)),
        ],
      ),
      if (_shaves == true)
        _verdict('이발사는 "스스로 깎지 않는 사람"만 깎아 준다고 했어요. 그런데 스스로 깎았으니 자기 규칙을 어겨요. 모순!', good: false)
      else if (_shaves == false)
        _verdict('이발사의 수염을 깎지 않는 사람이 된 거라서, 이발사는 "스스로 깎지 않는 사람은 모두 깎아 준다"는 규칙대로 자기 수염을 깎아야 해요. 그러면 스스로 깎은 거니까… 또 모순!', good: false),
    ]);
  }
}

// ───────────────────────── 불시 시험 역설 ─────────────────────────

/// 불시 시험 역설: "다음 주 평일 중 하루 불시 시험을 본다"는 예고에서, 학생들이 금요일부터 하루씩 지워 나간다.
class ExamDemo extends StatefulWidget {
  const ExamDemo({super.key});

  @override
  State<ExamDemo> createState() => _ExamDemoState();
}

class _ExamDemoState extends State<ExamDemo> {
  int _step = 0; // 지워진 요일 수 (금요일부터)

  static const _days = ['월', '화', '수', '목', '금'];

  static const _lines = [
    '선생님: "다음 주 월~금 중 하루, 불시 시험을 보겠다. 그날 아침까지는 언제인지 아무도 모를 거야."',
    '금요일에 보는 시험이라면? 목요일까지 시험이 없었다면 금요일이 "확실"해져서 불시가 아니에요. 그러니 금요일은 아니에요!',
    '그럼 마지막 후보는 목요일이에요. 수요일까지 안 봤다면 목요일이 "확실"하니 불시가 아니에요. 목요일도 아니에요!',
    '같은 방식으로 수요일도 지워져요. 화요일까지 안 봤다면 수요일이 "확실"하니까요.',
    '화요일도 지워져요. 월요일까지 안 봤다면 화요일이 "확실"하니까요.',
    '월요일만 남는데, 다른 날이 모두 지워졌으니 월요일이 "확실"해요. 그래서 "불시 시험은 불가능하다!"',
  ];

  @override
  Widget build(BuildContext context) {
    final erased = _step.clamp(0, 5);
    return _box(context, children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 5; i++)
            Container(
              width: 48,
              height: 48,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (4 - i) < erased ? const Color(0xFFEEEEEE) : kProphColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: (4 - i) < erased ? const Color(0xFFBDBDBD) : kProphColor, width: 2),
              ),
              child: Text(
                _days[i],
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: (4 - i) < erased ? const Color(0xFFBDBDBD) : kProphColor,
                  decoration: (4 - i) < erased ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 10),
      Text(_lines[erased], style: const TextStyle(fontSize: 15, height: 1.5)),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (erased > 0) TextButton(onPressed: () => setState(() => _step = 0), child: const Text('처음부터')),
          if (erased < 5) FilledButton.tonal(onPressed: () => setState(() => _step++), child: Text(erased == 0 ? '학생들의 생각 따라가 보기' : '다음 생각')),
        ],
      ),
      if (erased == 5)
        _verdict('그런데 선생님이 수요일에 시험지를 나눠 주면? 학생들은 "불가능하다고 했는데!" 하며 정말 깜짝 놀라요. 예고는 참이 되었어요. 추론이 어디서 잘못된 걸까요?', good: false),
    ]);
  }
}

// ───────────────────────── 정지 문제 ─────────────────────────

/// 튜링의 정지 문제: "프로그램이 멈출지 맞히는 기계 H"가 있다고 하고, H의 예언을 뒤집는 프로그램 D를 만든다.
class HaltingDemo extends StatefulWidget {
  const HaltingDemo({super.key});

  @override
  State<HaltingDemo> createState() => _HaltingDemoState();
}

class _HaltingDemoState extends State<HaltingDemo> {
  bool? _predictHalts;

  @override
  Widget build(BuildContext context) {
    return _box(context, children: [
      const Text(
        '예언 기계 H는 어떤 프로그램이 "언젠가 멈출지, 영원히 돌지"를 항상 맞힌다고 해요.\n'
        '심술쟁이 프로그램 D는 이렇게 만들었어요: 자기 자신에 대한 H의 예언을 물어보고, 반대로 행동해요.\n'
        '• H가 "D는 멈춘다"라고 하면 → D는 영원히 돌아요.\n'
        '• H가 "D는 영원히 돈다"라고 하면 → D는 곧바로 멈춰요.',
        style: TextStyle(fontSize: 14.5, height: 1.55),
      ),
      const SizedBox(height: 10),
      const Text('H가 D(자기 자신)에 대해 어떻게 예언할까요?', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        children: [
          ChoiceChip(label: const Text('"멈춘다"'), selected: _predictHalts == true, onSelected: (_) => setState(() => _predictHalts = true)),
          ChoiceChip(label: const Text('"영원히 돈다"'), selected: _predictHalts == false, onSelected: (_) => setState(() => _predictHalts = false)),
        ],
      ),
      if (_predictHalts == true)
        _verdict('H가 "멈춘다"라고 예언하면 D는 반대로 영원히 돌아요. H의 예언이 틀렸어요!', good: false)
      else if (_predictHalts == false)
        _verdict('H가 "영원히 돈다"라고 예언하면 D는 곧바로 멈춰요. 이번에도 H의 예언이 틀렸어요!', good: false),
      if (_predictHalts != null)
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('어느 쪽으로 예언해도 틀려요. 그러니 "언제나 맞히는 예언 기계 H"는 만들 수 없어요. 게임 속 "자기 예언을 스스로 무너뜨리는 숫자"와 똑같은 모양이에요!',
              style: TextStyle(fontSize: 14.5, height: 1.5)),
        ),
    ]);
  }
}

// ───────────────────────── 집합으로 수를 쌓기 ─────────────────────────

/// 폰 노이만이 보여 준 방법: 0 = {}, 그다음 수는 앞선 모든 수를 모은 집합. 슬라이더로 수를 바꿔 본다.
class VonNeumannExplorer extends StatefulWidget {
  const VonNeumannExplorer({super.key});

  @override
  State<VonNeumannExplorer> createState() => _VonNeumannExplorerState();
}

class _VonNeumannExplorerState extends State<VonNeumannExplorer> {
  double _n = 3;

  @override
  Widget build(BuildContext context) {
    final n = _n.round();
    final accent = LessonAccent.of(context);
    return _box(context, children: [
      Row(
        children: [
          Text('수 $n', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: accent)),
          Expanded(
            child: Slider(value: _n, min: 0, max: 4, divisions: 4, label: '$n', onChanged: (v) => setState(() => _n = v)),
          ),
        ],
      ),
      Text(
        n == 0
            ? '0 = { }  (아무것도 안 든 빈 주머니, "공집합")'
            : '$n = {${[for (var i = 0; i < n; i++) i].join(', ')}}  (0부터 ${n - 1}까지 모두 든 집합)',
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      const Text('수 대신 처음의 { }만 써서 풀어 쓰면:', style: TextStyle(fontSize: 13.5)),
      Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: const Color(0xFFF4F1EA), borderRadius: BorderRadius.circular(10)),
        child: SelectableText(vonNeumann(n), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, height: 1.5, fontFamily: 'NanumGothic')),
      ),
      const SizedBox(height: 8),
      Text('원소는 $n개, 중괄호 한 쌍은 모두 ${braceCount(n)}개 (= 2를 $n번 곱한 수)예요.', style: const TextStyle(fontSize: 14, height: 1.5)),
    ]);
  }
}

// ───────────────────────── 수학의 탑 ─────────────────────────

/// 수학의 "탑": 아래 층이 위 층을 받친다. [cracked]이면 맨 아래에 금이 간다.
class MathTowerArt extends StatelessWidget {
  const MathTowerArt({super.key, this.cracked = false});

  final bool cracked;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _TowerPainter(cracked: cracked, accent: LessonAccent.of(context)), size: Size.infinite);
  }
}

class _TowerPainter extends CustomPainter {
  _TowerPainter({required this.cracked, required this.accent});

  final bool cracked;
  final Color accent;

  static const _layers = ['미적분·해석학', '대수·기하', '실수·분수·정수', '자연수와 산수', '집합과 공리 (기초)'];

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final layerH = (h - 20) / _layers.length;
    for (var i = 0; i < _layers.length; i++) {
      // 위(0)에서 아래(4)로 갈수록 넓어지는 층
      final width = w * (0.45 + 0.1 * i);
      final r = Rect.fromCenter(center: Offset(w / 2, 10 + layerH * (0.5 + i)), width: width, height: layerH - 4);
      final cracks = cracked && i == _layers.length - 1;
      final shape = RRect.fromRectAndRadius(r, const Radius.circular(8));
      canvas.drawRRect(shape, Paint()..color = cracks ? const Color(0xFFE8B4B4) : accent.withValues(alpha: 0.12 + 0.08 * i));
      canvas.drawRRect(
        shape,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = cracks ? _bad : accent,
      );
      final tp = TextPainter(
        text: TextSpan(text: _layers[i], style: const TextStyle(fontFamily: 'NanumGothic', fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF333333))),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: width - 8);
      tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
      if (cracks) {
        final c = r.center;
        canvas.drawPath(
          Path()
            ..moveTo(c.dx - 18, r.top)
            ..lineTo(c.dx - 6, c.dy - 4)
            ..lineTo(c.dx - 20, c.dy + 6)
            ..lineTo(c.dx - 8, r.bottom),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3
            ..strokeCap = StrokeCap.round
            ..color = _bad,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_TowerPainter old) => old.cracked != cracked || old.accent != accent;
}
