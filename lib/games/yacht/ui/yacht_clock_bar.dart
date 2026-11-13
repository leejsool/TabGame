import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 남은 시간만큼의 가로 막대 (시간 제한이 있는 판의 점수판 이름 줄 밑). 1초마다 줄어든 길이까지 1초에 걸쳐 고르게 미끄러진다.
///
/// 막대가 화면에서 한 점(픽셀)만큼 줄어들 때만 다시 그린다. 예전에는 차례 내내 매 프레임(초당 60번) 다시 그렸는데,
/// 막대는 1초에 몇 점밖에 안 움직여서 대부분 똑같은 그림이었다 (저성능 기기가 쉬지 못하고 뜨거워지던 원인).
/// 눈에 보이는 움직임은 그대로다.
class YachtClockBar extends StatefulWidget {
  const YachtClockBar({super.key, required this.clock, required this.total, required this.color});

  /// 남은 시간(초). 시계가 없는 때는 null.
  final ValueListenable<int?> clock;

  /// 한 차례의 제한 시간(초).
  final int total;

  /// 막대의 색 (10초 이하로 남으면 빨갛게 바뀐다).
  final Color color;

  @override
  State<YachtClockBar> createState() => _YachtClockBarState();
}

class _YachtClockBarState extends State<YachtClockBar> {
  static const int _slideMs = 1000;

  /// 지금 보이는 막대 길이 (0~1).
  final ValueNotifier<double> _shown = ValueNotifier(0);
  double _from = 0, _to = 0;
  Timer? _timer;
  int _stepMs = 16;
  int? _left;

  /// 지금 화면에 막대가 없는가 · 빨간색인가 (마지막으로 그린 모습).
  bool _hidden = true;
  bool _red = false;

  /// 막대의 폭 (화면 점 수). 한 점 움직이는 데 걸리는 시간을 정한다.
  double _pixels = 300;

  @override
  void initState() {
    super.initState();
    widget.clock.addListener(_onClock);
    _left = widget.clock.value;
    _hidden = _left == null;
    _from = _to = _shown.value = (_left ?? 0) / widget.total; // 처음에는 미끄러지지 않고 바로 그 길이
  }

  @override
  void didUpdateWidget(YachtClockBar old) {
    super.didUpdateWidget(old);
    if (old.clock != widget.clock) {
      old.clock.removeListener(_onClock);
      widget.clock.addListener(_onClock);
      _onClock();
    }
  }

  @override
  void dispose() {
    widget.clock.removeListener(_onClock);
    _timer?.cancel();
    _shown.dispose();
    super.dispose();
  }

  void _onClock() {
    final left = widget.clock.value;
    _left = left;
    if (left == null) {
      _timer?.cancel();
      _timer = null;
    } else if (_hidden) {
      _from = _to = _shown.value = left / widget.total; // 시계가 새로 나타났다: 바로 그 길이
    } else {
      // 1초가 지났거나, 다음 사람 차례가 되어 다시 가득 찬다: 지금 길이에서 새 길이까지 미끄러진다
      _from = _shown.value;
      _to = left / widget.total;
      _stepMs = _stepTime((_to - _from).abs() * _pixels);
      _timer?.cancel();
      _timer = Timer.periodic(Duration(milliseconds: _stepMs), _step);
    }
    final red = left != null && left <= 10;
    if ((left == null) != _hidden || red != _red) setState(() {}); // 나타남 · 사라짐 · 색 바뀜
  }

  /// 1초 동안 [moved]점을 움직일 때, 한 점 움직이는 데 걸리는 시간(밀리초). 너무 잦지도, 뚝뚝 끊기지도 않게.
  int _stepTime(double moved) => moved <= 0 ? 250 : (_slideMs / moved).round().clamp(16, 250);

  void _step(Timer timer) {
    final t = (timer.tick * _stepMs / _slideMs).clamp(0.0, 1.0);
    _shown.value = _from + (_to - _from) * t;
    if (t >= 1) {
      timer.cancel();
      if (identical(_timer, timer)) _timer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final left = _left;
    _hidden = left == null;
    if (left == null) return const SizedBox.shrink();
    _red = left <= 10;
    final color = _red ? const Color(0xFFD1373F) : widget.color;
    return LayoutBuilder(
      key: const ValueKey('yacht-clock'),
      builder: (context, box) {
        if (box.maxWidth.isFinite) _pixels = box.maxWidth * MediaQuery.devicePixelRatioOf(context);
        return ValueListenableBuilder<double>(
          valueListenable: _shown,
          builder: (context, v, _) => Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: v.clamp(0.0, 1.0),
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
              ),
            ),
          ),
        );
      },
    );
  }
}
