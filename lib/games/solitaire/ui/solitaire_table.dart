import 'dart:math';

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../core/card_look.dart';
import '../../../core/settings_scope.dart';
import '../../freecell/ui/playing_card.dart';
import '../../freecell/ui/win_celebration.dart';
import '../core/solitaire_rules.dart';
import '../game/solitaire_controller.dart';
import 'card_back.dart';

part 'solitaire_table_drag.dart';
part 'solitaire_table_layers.dart';

part 'solitaire_table_card_view.dart';

/// 화면 크기에서 카드 크기와 자리를 계산한다.
class SolMetrics {
  SolMetrics(this.view, double stackWeight) {
    var w = view.width / 8.1;
    // 세로가 모자라면 (가로 화면) 카드를 줄인다
    w = min(w, view.height / 6.0);
    cw = w;
    ch = w * 1.4;
    gap = w * 0.14;
    left = (view.width - (7 * cw + 6 * gap)) / 2;
    pad = w * 0.2;
    topY = pad;
    colY = topY + ch + w * 0.38;
    final avail = view.height - colY - pad;
    final n = max(10.0, stackWeight);
    offU = ((avail - ch) / n).clamp(ch * 0.12, ch * 0.36);
    offD = offU * 0.38;
    fanOff = cw * 0.3;
  }

  final Size view;
  late final double cw, ch, gap, left, pad, topY, colY, offU, offD, fanOff;

  double slotX(int slot) => left + slot * (cw + gap);

  Size get cardSize => Size(cw, ch);

  /// 위쪽 줄: 0 = 더미, 1 = 버린 카드, 3~6 = 완성 칸(무늬 순서).
  Offset topPos(int slot) => Offset(slotX(slot), topY);

  /// 열 [col]의 [k]번째 카드 위치 (열 길이 [len], 앞면 [up]장).
  Offset colPos(int col, int k, int len, int up) {
    final down = len - up;
    final y = k < down ? k * offD : down * offD + (k - down) * offU;
    return Offset(slotX(col), colY + y);
  }

  /// 앞으로 한 장 더 놓일 자리.
  Offset nextColPos(int col, int len, int up) {
    if (len == 0) return Offset(slotX(col), colY);
    return colPos(col, len, len + 1, up + 1);
  }
}

/// 열의 높이를 "앞면 카드 몇 장 분량"으로.
double stackWeightOf(SolState s) {
  var m = 0.0;
  for (var i = 0; i < 7; i++) {
    final len = s.tableau[i].length;
    if (len == 0) continue;
    final w = (len - s.up[i]) * 0.38 + (s.up[i] - 1);
    if (w > m) m = w;
  }
  return m;
}

enum _Src { waste, column, found }

class _Drag {
  _Drag({
    required this.src,
    required this.index,
    required this.cards,
    required this.grab,
    required this.topLeft,
    required this.targets,
  });

  final _Src src;
  final int index; // 열 번호 또는 무늬
  final List<int> cards;
  final Offset grab;
  Offset topLeft;
  final List<SolMove> targets;
  SolMove? hover;
}

class _Loc {
  const _Loc(this.pos, this.z, this.faceUp, {this.src, this.index = 0, this.count = 0});

  final Offset pos;
  final double z;
  final bool faceUp;

  /// 이 카드를 집을 수 있다면 어디서 (집을 수 없으면 null) / 열 번호·무늬 / 같이 집히는 장수.
  final _Src? src;
  final int index;
  final int count;
}

/// 솔리테어 판: 카드 그리기, 끌기, 탭 이동, 힌트 표시, 완성 연출.
class SolitaireTable extends StatefulWidget {
  const SolitaireTable({super.key, required this.controller, this.onCelebrationTap});

  final SolitaireController controller;

  /// 완성 연출 중에 화면을 눌렀을 때 (연출을 건너뛰고 결과를 보여주려고).
  final VoidCallback? onCelebrationTap;

  @override
  State<SolitaireTable> createState() => _SolitaireTableState();
}

class _SolitaireTableState extends State<SolitaireTable> with TickerProviderStateMixin {
  /// 다른 파일(part)에 나눠 둔 화면 조각에서 상태를 바꿀 때 쓴다.
  void _update(VoidCallback fn) => setState(fn);

  SolitaireController get c => widget.controller;

  final GlobalKey _stackKey = GlobalKey();
  SolMetrics? _m;
  _Drag? _drag;

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 800),
  );

  // 완성 연출
  Ticker? _ticker;
  WinCelebration? _show;
  Duration _lastTick = Duration.zero;
  bool _celebrating = false;
  final ValueNotifier<int> _winTick = ValueNotifier(0);
  bool _wasCompleted = false;

  @override
  void initState() {
    super.initState();
    c.addListener(_onController);
    _wasCompleted = c.completed;
  }

  @override
  void dispose() {
    c.removeListener(_onController);
    _ticker?.dispose();
    _show?.dispose();
    _pulse.dispose();
    _winTick.dispose();
    super.dispose();
  }

  void _onController() {
    final hasHint = c.hint != null;
    if (hasHint && !_pulse.isAnimating) {
      _pulse.repeat(reverse: true);
    } else if (!hasHint && _pulse.isAnimating) {
      _pulse.stop();
    }
    if (c.completed && !_wasCompleted) _startCelebration();
    if (!c.completed && _wasCompleted) _stopCelebration();
    _wasCompleted = c.completed;
  }

  // ── 완성 연출: 윈도우 솔리테어처럼 카드가 잔상을 남기며 튀고, 솟구쳐 터지고, 화면으로 날아온다 ──




  // ── 카드 자리 계산 ──




  // ── 입력 ──


  // ── 그리기 ──

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final m = SolMetrics(box.biggest, stackWeightOf(c.state));
        _m = m;
        return ListenableBuilder(
          listenable: c,
          builder: (context, _) => _stack(m),
        );
      },
    );
  }


}
