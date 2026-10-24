import 'package:flutter/material.dart';

import '../../../tutorial/lesson_kit.dart';
import '../core/park_rules.dart';
import 'park_board.dart';

/// 공원 길찾기 교과학습의 만져 보는 그림들: 글자 늘어놓기, 모든 최단경로, 덧셈으로 세기.

int _fact(int n) => n <= 1 ? 1 : n * _fact(n - 1);

/// [letters]를 늘어놓는 서로 다른 방법들 (사전 순).
List<String> distinctArrangements(List<String> letters) {
  final out = <String>{};
  void go(List<String> rest, String acc) {
    if (rest.isEmpty) {
      out.add(acc);
      return;
    }
    for (var i = 0; i < rest.length; i++) {
      go([...rest]..removeAt(i), acc + rest[i]);
    }
  }

  go(letters, '');
  return out.toList()..sort();
}

/// 글자 묶음을 골라 서로 다른 줄을 모두 보여 주고, 같은 것이 있는 순열 식으로 확인한다.
class PermExplorer extends StatefulWidget {
  const PermExplorer({super.key});

  @override
  State<PermExplorer> createState() => _PermExplorerState();
}

class _PermExplorerState extends State<PermExplorer> {
  static const _words = ['RRDD', 'RRRD', 'RRRDD', '토마토', '사과사과'];
  String _word = _words.first;

  @override
  Widget build(BuildContext context) {
    final accent = LessonAccent.of(context);
    final letters = _word.split('');
    final list = distinctArrangements(letters);
    final counts = <String, int>{};
    for (final l in letters) {
      counts[l] = (counts[l] ?? 0) + 1;
    }
    final same = counts.entries.where((e) => e.value > 1).toList();
    final formula =
        '${letters.length}! ÷ (${same.map((e) => '${e.value}!').join(' × ')}) = '
        '${_fact(letters.length)} ÷ ${same.fold(1, (a, e) => a * _fact(e.value))} = ${list.length}가지';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              for (final w in _words) ChoiceChip(label: Text(w), selected: w == _word, onSelected: (_) => setState(() => _word = w)),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final s in list)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: accent.withValues(alpha: 0.5)),
                  ),
                  child: Text(s, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 2)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formula,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: accent),
          ),
        ],
      ),
    );
  }
}

/// n×n 공원의 모든 최단경로 (사전 순). 조건에 맞는 길은 초록 테두리.
List<List<Walk>> allPaths(int n) => [
  for (final s in distinctArrangements([...List.filled(n, 'R'), ...List.filled(n, 'D')]))
    [for (final ch in s.split('')) ch == 'R' ? Walk.right : Walk.down],
];

class AllPathsExplorer extends StatefulWidget {
  const AllPathsExplorer({super.key});

  @override
  State<AllPathsExplorer> createState() => _AllPathsExplorerState();
}

class _AllPathsExplorerState extends State<AllPathsExplorer> {
  int _stage = 0;
  bool _markValid = false;

  @override
  Widget build(BuildContext context) {
    final stage = kParkStages[_stage];
    final paths = allPaths(stage.size);
    final tile = stage.size == 2 ? 92.0 : 70.0;
    final valid = paths.where(stage.isValid).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('2×2 공원')),
            ButtonSegment(value: 1, label: Text('3×3 공원')),
          ],
          selected: {_stage},
          showSelectedIcon: false,
          onSelectionChanged: (s) => setState(() => _stage = s.first),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          alignment: WrapAlignment.center,
          children: [
            for (final p in paths)
              Container(
                width: tile,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _markValid && stage.isValid(p) ? const Color(0xFF2E8B3E) : const Color(0x22000000),
                    width: _markValid && stage.isValid(p) ? 3 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      width: tile - 10,
                      height: tile - 10,
                      child: ParkBoard(stage: stage, steps: p, compact: true),
                    ),
                    Text(pathKey(p), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '모두 ${paths.length}가지',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        SwitchListTile(
          value: _markValid,
          onChanged: (v) => setState(() => _markValid = v),
          title: Text(_markValid ? '조건에 맞는 길: $valid가지 (초록 테두리)' : '조건에 맞는 길 표시하기'),
        ),
      ],
    );
  }
}

/// 교차점마다 그 점까지 가는 최단경로 수 (위 + 왼쪽)를 적은 n×n 격자.
///
/// [oneSide]면 숲(대각선 칸)을 그리고, 숲 줄 아래로 내려간 점(열 < 행)은 갈 수 없는 회색 점으로 둔다
/// → B의 수가 "숲이 오른편에만 있는 길"의 수.
class PathCountPainter extends CustomPainter {
  PathCountPainter(this.n, {this.oneSide = false});

  final int n;
  final bool oneSide;

  bool _open(int r, int c) => !oneSide || c >= r;

  @override
  void paint(Canvas canvas, Size size) {
    final side = (size.shortestSide - 84) / n;
    final origin = Offset((size.width - side * n) / 2, (size.height - side * n) / 2);
    Offset at(int r, int c) => origin + Offset(c * side, r * side);
    const ink = Color(0xFF263B2B);
    final line = Paint()
      ..color = const Color(0xFF6B8F71)
      ..strokeWidth = 2;
    final faint = Paint()
      ..color = const Color(0x22000000)
      ..strokeWidth = 1.5;
    if (oneSide) {
      for (var i = 0; i < n; i++) {
        final center = at(i, i) + Offset(side / 2, side / 2);
        canvas.drawCircle(center, side * 0.2, Paint()..color = const Color(0xFF8BC79A));
        canvas.drawCircle(
          center,
          side * 0.2,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0xFF2F7A45),
        );
      }
    }
    for (var r = 0; r <= n; r++) {
      for (var c = 0; c <= n; c++) {
        if (c < n) canvas.drawLine(at(r, c), at(r, c + 1), _open(r, c) && _open(r, c + 1) ? line : faint);
        if (r < n) canvas.drawLine(at(r, c), at(r + 1, c), _open(r, c) && _open(r + 1, c) ? line : faint);
      }
    }
    final ways = List.generate(n + 1, (_) => List.filled(n + 1, 0));
    for (var r = 0; r <= n; r++) {
      for (var c = 0; c <= n; c++) {
        if (!_open(r, c)) continue;
        ways[r][c] = r == 0 || c == 0 ? 1 : ways[r - 1][c] + (_open(r, c - 1) ? ways[r][c - 1] : 0);
      }
    }
    for (var r = 0; r <= n; r++) {
      for (var c = 0; c <= n; c++) {
        final p = at(r, c);
        if (!_open(r, c)) {
          canvas.drawCircle(p, side * 0.08, Paint()..color = const Color(0x44000000));
          continue;
        }
        final goal = r == n && c == n;
        final radius = side * 0.24;
        canvas.drawCircle(p, radius, Paint()..color = goal ? kParkColor : Colors.white);
        canvas.drawCircle(
          p,
          radius,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = kParkColor,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: '${ways[r][c]}',
            style: TextStyle(
              fontFamily: 'NanumGothic',
              fontSize: radius * 0.9,
              fontWeight: FontWeight.w800,
              color: goal ? Colors.white : ink,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
      }
    }
    for (final (label, r, off) in [('A', 0, const Offset(-1, -1)), ('B', n, const Offset(1, 1))]) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: const TextStyle(fontFamily: 'NanumGothic', fontSize: 18, fontWeight: FontWeight.w900, color: ink),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at(r, r) + off * 26 - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(PathCountPainter old) => old.n != n || old.oneSide != oneSide;
}
