import 'package:flutter/material.dart';

import '../../../core/win_celebration.dart';
import '../../../core/win_sound.dart';
import '../../../versus/vs_screen_parts.dart' show showVsRules;
import '../core/park_rules.dart';
import '../tutorial/park_tutorial.dart';
import 'park_board.dart';
import 'park_found_panel.dart';

/// 공원 길찾기: 단계(2×2·3×3·4×4)를 골라 A에서 B까지 길을 긋고, 조건에 맞는 길을 모두 모은다.
class ParkScreen extends StatefulWidget {
  const ParkScreen({super.key});

  @override
  State<ParkScreen> createState() => _ParkScreenState();
}

/// 길을 다 그은 뒤의 알림.
class _Note {
  const _Note(this.text, this.color, this.icon);
  final String text;
  final Color color;
  final IconData icon;
}

class _ParkScreenState extends State<ParkScreen> {
  int _stageIndex = 0;
  List<Walk> _steps = const [];

  /// 단계마다 찾은 길 (찾은 순서대로).
  final Map<int, List<List<Walk>>> _found = {};
  _Note? _note;
  int? _highlight;

  ParkStage get _stage => kParkStages[_stageIndex];
  List<List<Walk>> get _list => _found.putIfAbsent(_stageIndex, () => []);
  late final List<int> _answers = [for (final s in kParkStages) s.answer];

  void _pickStage(int i) => setState(() {
        _stageIndex = i;
        _steps = const [];
        _note = null;
        _highlight = null;
      });

  void _changed(List<Walk> steps) => setState(() {
        _steps = steps;
        _note = null;
        _highlight = null;
      });

  void _done() {
    final s = _stage;
    if (!s.isComplete(_steps)) {
      if (_steps.isNotEmpty) setState(() => _note = const _Note('B까지 이어 주세요. 길 끝에서 다시 그으면 이어져요.', Color(0xFF6B7280), Icons.more_horiz_rounded));
      return;
    }
    final sides = s.sides(_steps);
    final left = sides.contains(ForestSide.left), right = sides.contains(ForestSide.right);
    if (!left || !right) {
      final why = !left && !right
          ? '숲이 바로 옆에 있는 구간이 하나도 없어요.'
          : !left
              ? '숲이 오른편에 있는 구간만 있어요. 왼편 구간도 있어야 해요.'
              : '숲이 왼편에 있는 구간만 있어요. 오른편 구간도 있어야 해요.';
      setState(() => _note = _Note('조건에 맞지 않아요. $why', Theme.of(context).colorScheme.error, Icons.cancel_rounded));
      return;
    }
    final key = pathKey(_steps);
    final at = _list.indexWhere((p) => pathKey(p) == key);
    if (at >= 0) {
      setState(() {
        _note = _Note('이미 찾았던 길이에요 (${at + 1}번)', const Color(0xFF7C5CC4), Icons.replay_rounded);
        _highlight = at;
      });
      return;
    }
    setState(() {
      _list.add(List.of(_steps));
      _highlight = _list.length - 1;
      _note = _Note('새 길을 찾았어요! 왼편 숲과 오른편 숲을 모두 지나요. (${_list.length}번)', const Color(0xFF2E8B3E), Icons.check_circle_rounded);
    });
    if (_list.length == _answers[_stageIndex]) {
      WinSound.play(context);
      showWinCelebration(context, title: '모두 찾았어요!', subtitle: '${_stage.title} 공원: 전부 ${_list.length}가지');
    }
  }

  void _pick(int i) => setState(() {
        _steps = _list[i];
        _highlight = i;
        _note = _Note('${i + 1}번으로 찾은 길이에요.', kParkColor, Icons.visibility_rounded);
      });

  bool get _sorted {
    for (var i = 1; i < _list.length; i++) {
      if (pathKey(_list[i - 1]).compareTo(pathKey(_list[i])) > 0) return false;
    }
    return true;
  }

  /// 찾은 길을 사전식으로 (R = 오른쪽, D = 아래: DD…가 앞, RR…가 뒤) 줄 세운다. 번호도 새로 매겨진다.
  void _sort() => setState(() {
        final shown = _highlight == null ? null : pathKey(_list[_highlight!]);
        _list.sort((a, b) => pathKey(a).compareTo(pathKey(b)));
        _highlight = shown == null ? null : _list.indexWhere((p) => pathKey(p) == shown);
        _note = _Note('찾은 길을 사전식으로 정렬했어요. (R = 오른쪽, D = 아래)', kParkColor, Icons.sort_by_alpha_rounded);
      });

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('찾은 길을 지울까요?'),
        content: Text('${_stage.title} 공원에서 찾은 길 ${_list.length}가지를 모두 지우고 처음부터 찾아요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('아니요')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('지우기')),
        ],
      ),
    );
    if (ok == true) {
      setState(() {
        _list.clear();
        _steps = const [];
        _note = null;
        _highlight = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('공원 길찾기', style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.transparent,
        actions: [IconButton(tooltip: '규칙', icon: const Icon(Icons.help_outline_rounded), onPressed: () => showParkRules(context))],
      ),
      body: SafeArea(
        top: false,
        child: LayoutBuilder(builder: (context, box) {
          final landscape = box.maxWidth > box.maxHeight * 1.15;
          final board = ParkBoard(stage: _stage, steps: _steps, onChanged: _changed, onDone: _done);
          final panel = ParkFoundPanel(
            stage: _stage,
            found: _list,
            allFound: _list.length == _answers[_stageIndex],
            highlight: _highlight,
            onPick: _pick,
            onClear: _list.isEmpty ? null : _clear,
            onSort: _sorted ? null : _sort,
            horizontal: !landscape,
          );
          if (landscape) {
            return Row(children: [
              Expanded(child: Padding(padding: const EdgeInsets.all(8), child: board)),
              SizedBox(
                width: box.maxWidth * 0.42,
                child: ListView(padding: const EdgeInsets.fromLTRB(8, 4, 16, 16), children: [
                  _stagePicker(),
                  const SizedBox(height: 10),
                  _status(),
                  const SizedBox(height: 8),
                  const _Legend(),
                  const SizedBox(height: 16),
                  panel,
                ]),
              ),
            ]);
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(children: [
              _stagePicker(),
              Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: board)),
              const _Legend(),
              const SizedBox(height: 8),
              _status(),
              const SizedBox(height: 12),
              panel,
            ]),
          );
        }),
      ),
    );
  }

  Widget _stagePicker() => SegmentedButton<int>(
        segments: [
          for (var i = 0; i < kParkStages.length; i++)
            ButtonSegment(value: i, label: Text('${kParkStages[i].title} 공원', style: const TextStyle(fontWeight: FontWeight.w800))),
        ],
        selected: {_stageIndex},
        showSelectedIcon: false,
        onSelectionChanged: (s) => _pickStage(s.first),
      );

  Widget _status() {
    final note = _note;
    final sides = _stage.sides(_steps);
    final l = sides.where((s) => s == ForestSide.left).length, r = sides.where((s) => s == ForestSide.right).length;
    final (text, color, icon) = note != null
        ? (note.text, note.color, note.icon)
        : _steps.isEmpty
            ? ('A에서 손가락을 대고 산책로를 따라 B까지 그어 보세요. (오른쪽·아래로만)', kParkColor, Icons.touch_app_rounded)
            : ('숲이 왼편인 구간 $l개 · 오른편인 구간 $r개', kParkColor, Icons.route_rounded);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(children: [
        Icon(icon, color: color),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontWeight: FontWeight.w700, color: color, height: 1.35))),
      ]),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    Widget item(Color c, String badge, String text) => Row(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 11, backgroundColor: c, child: Text(badge, style: const TextStyle(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w800))),
          const SizedBox(width: 5),
          Text(text, style: const TextStyle(fontSize: 13.5)),
        ]);
    return Wrap(spacing: 16, runSpacing: 6, alignment: WrapAlignment.center, children: [
      item(kLeftColor, '왼', '숲이 진행 방향 바로 왼편'),
      item(kRightColor, '오', '숲이 진행 방향 바로 오른편'),
    ]);
  }
}

Future<void> showParkRules(BuildContext context) => showVsRules(
      context,
      title: '공원 길찾기 규칙',
      lines: const [
        '선분이 산책로, 초록 ○가 숲이에요.',
        'A로 들어가서 최단경로(오른쪽·아래로만)로 걸어 B로 나와요.',
        '진행 방향의 바로 왼편에 숲이 있는 구간이 한 번 이상, 바로 오른편에 숲이 있는 구간도 한 번 이상 있어야 해요.',
        'A에서 손가락을 대고 그으면 길이 그려져요. 되돌아가면 지워지고, 길 끝에서 다시 그으면 이어져요.',
        '조건에 맞는 길을 모두 찾아 보세요. 몇 가지일까요?',
      ],
      openTutorial: () => parkTutorial().open(context),
    );
