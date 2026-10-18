import 'dart:async';

import '../core/game_speed.dart';

import 'package:flutter/foundation.dart';

/// CPU가 한 수를 "생각하는" 동안의 공통 관리: 계산은 다른 isolate에서 돌리고, 너무 빨리 끝나도
/// 최소 [minTime]은 기다렸다가 결과를 돌려준다. (수가 휙 나오면 사람이 따라가기 어려워서)
///
/// 컨트롤러는 이것을 하나 갖고, 대결 게임의 흐름을 이렇게 쓴다:
/// ```dart
/// Future<void> _cpuTurn() async {
///   final move = await _cpu.run(
///     task: () => compute(_cpuTask, args),
///     minTime: const Duration(milliseconds: 700),
///     onStart: notifyListeners,   // thinking == true 가 된 직후
///   );
///   if (move == null) return;     // 그 사이에 새 판·되돌리기·기권·화면 닫기가 있었다: 버린다
///   _apply(move);                 // thinking 은 이미 false
/// }
/// ```
/// 판을 새로 시작하거나 되돌리거나 기권할 때는 [cancel]을, 컨트롤러를 버릴 때는 [dispose]를 부른다.
class CpuTurnRunner {
  bool _thinking = false;
  bool _disposed = false;
  int _epoch = 0;

  /// CPU가 계산하는 중인가 (화면에 "생각 중…"을 보여 주고 사람의 입력을 막는 데 쓴다).
  bool get thinking => _thinking;

  bool get disposed => _disposed;

  /// 지금 진행 중인 계산이 있으면 그 결과를 버린다. (이미 계산이 끝나 있어도 [run]은 null을 돌려준다)
  void cancel() {
    _epoch++;
    _thinking = false;
  }

  void dispose() {
    _disposed = true;
    _epoch++;
    _thinking = false;
  }

  /// [task]를 돌리고 결과를 돌려준다. 도중에 [cancel]/[dispose]가 불렸으면 null.
  Future<T?> run<T>({
    required Future<T> Function() task,
    required Duration minTime,
    VoidCallback? onStart,
  }) async {
    final epoch = ++_epoch;
    _thinking = true;
    onStart?.call();
    final results = await Future.wait<Object?>([task(), Future<void>.delayed(GameSpeed.scale(minTime))]);
    if (_disposed || epoch != _epoch) return null;
    _thinking = false;
    return results[0] as T;
  }
}
