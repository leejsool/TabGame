part of 'davinci_controller.dart';

/// effects 조각 (화면 코드를 역할별로 나눈 파일)
extension DavinciControllerEffects on DavinciController {
  /// 상대의 수를 보여 주는 중이라 내가 아직 못 두는가.
  bool get effectBusy => animate && ((effect?.blocking ?? false) || _effects.any((e) => e.blocking));

  /// 화면에 "차례"로 보여 줄 자리. 판([turn])은 수를 두자마자 다음 사람으로 넘어가지만,
  /// 상대(CPU·다른 기기)의 수를 한 단계씩 보여 주는 동안은 그 수를 둔 사람이 계속 차례로 보여야 한다.
  /// (안 그러면 CPU1이 타일을 고르는 중에 파란 실루엣이 벌써 CPU2로 넘어간다)
  /// 내가 둔 수는 바로 넘어간다 (내 수는 막지 않고 표시만 하니까).
  int get displayTurn {
    if (!animate) return state.turn;
    final e = effect ?? (_effects.isEmpty ? null : _effects.first);
    return e != null && e.actor != humanSeat ? e.actor : state.turn;
  }

  /// 연출 동안 (실제로는 이미 공개됐더라도) 아직 숨은 타일로 보여야 하는 타일들.
  /// 맞힌 타일은 "추측 중"일 때까지, 틀렸을 때 내가 뽑았던 타일은 결과가 다 보일 때까지 세워 둔다.
  Set<int> get hiddenOverride {
    final e = effect;
    if (e == null || e.kind != 2) return const {};
    return {
      if (e.correct == true && e.stage != DvEffectStage.result) e.tile!,
      if (e.correct == false && e.guesserTile != null) e.guesserTile!,
    };
  }

  /// 연출 중 맞히려고 떠올라 있는 타일.
  int? get liftedTile {
    final e = effect;
    return e != null && e.kind == 2 && e.stage != DvEffectStage.result ? e.tile : null;
  }

  /// 아직 다 보여 주지 못한 연출(지금 보이는 것과 줄 서 있는 것)이 있는가.
  bool get effectsPending => animate && (effect != null || _effects.isNotEmpty || _incoming.isNotEmpty);

  /// 연출이 끝나기 전에는 아직 "탈락"으로 보이면 안 되는 자리들: 맞혔다고 보여 주는 중인(또는 줄 서 있는) 추측의 대상.
  /// (판 자체는 이미 반영돼 있어서, 이렇게 하지 않으면 ○ / ✕가 뜨기도 전에 탈락이 떠 버린다)
  Set<int> get outPendingSeats => {
        if (animate)
          for (final e in [?effect, ..._effects])
            if (e.kind == 2 && e.correct == true && e.target != null) e.target!,
      };

  /// 끝난 판의 결과를 보여 줘도 되는가 (마지막 추측의 ○ / ✕까지 다 보인 뒤).
  bool get showOver => isOver && !effectsPending;

  Duration _ms(double factor) => GameSpeed.scale(cpuStepDelay) * factor;

  void _enqueue(DvEffect e) {
    if (!animate || _disposed) return;
    _effects.add(e);
    _pump();
  }

  Future<void> _pump() async {
    if (_pumping) return;
    _pumping = true;
    final epoch = _fxEpoch;
    while (_effects.isNotEmpty && !_disposed && epoch == _fxEpoch) {
      final e = _effects.removeAt(0);
      effect = e;
      if (!e.ask) e.stage = DvEffectStage.result;
      if (e.ask) {
        // 맞히기는 두 단계로 보여 준다: 먼저 타일을 고르고(떠오른다), 잠깐 뒤에 말풍선으로 숫자를 말한다. (동시에 보이면 따라가기 어렵다)
        if (e.kind == 2) {
          e.stage = DvEffectStage.pick;
          _notify();
          await Future<void>.delayed(_ms(1.2));
          if (_disposed || epoch != _fxEpoch) break;
        }
        e.stage = DvEffectStage.ask;
        _notify();
        await Future<void>.delayed(_ms(e.kind == 2 ? 1.5 : (e.kind == 0 ? 1.2 : 0.9)));
        if (_disposed || epoch != _fxEpoch) break;
      }
      if (e.kind == 2) {
        e.stage = DvEffectStage.result;
        _notify();
        await Future<void>.delayed(_ms(1.4));
        if (_disposed || epoch != _fxEpoch) break;
      }
      effect = null;
      _notify();
    }
    if (epoch == _fxEpoch) {
      effect = null;
      _pumping = false;
      _drainIncoming(); // 줄 서 있던 다음 소식을 반영한다 (수면 새 연출이 시작된다)
      if (!_pumping && _effects.isEmpty && _incoming.isEmpty) {
        _idle?.complete();
        _idle = null;
      }
      if (!_disposed) _notify();
    }
  }

  /// 줄 서 있는 소식을 연출이 쉬는 동안 하나씩 판에 반영한다. 수를 반영하면 새 연출이 시작되니 거기서 멈추고, 그 연출이 끝나면 이어서 한다.
  void _drainIncoming() {
    while (_incoming.isNotEmpty && !_pumping && _effects.isEmpty && !_disposed) {
      final item = _incoming.removeAt(0);
      if (item.move != null) {
        if (!state.isLegal(item.move!)) continue; // (줄 세울 때 이미 확인한 수라 여기까지 오지 않는다)
        _apply(item.move!);
        _next(); // (다음이 CPU 차례이면 방장 기기가 CPU의 수를 둔다)
      } else {
        _showSelection(item.actor!, item.seat!, item.index!);
      }
    }
    if (_incoming.isEmpty) _shadow = null;
  }

  void _clearEffects() {
    _fxEpoch++;
    _effects.clear();
    _incoming.clear();
    _shadow = null;
    remoteSel = null;
    effect = null;
    _pumping = false;
    _idle?.complete();
    _idle = null;
  }

  Future<void> _effectsIdle() {
    if (!_pumping && _effects.isEmpty && _incoming.isEmpty) return Future.value();
    return (_idle ??= Completer<void>()).future;
  }

  DvState get _latest => _shadow ?? state;
}
