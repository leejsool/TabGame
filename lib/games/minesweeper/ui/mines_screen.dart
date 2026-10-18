import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/game_fx.dart';
import '../../../core/game_widgets.dart';
import '../../../core/give_up.dart';
import '../../../core/leave_guard.dart';
import '../../../core/win_sound.dart';
import '../tutorial/mines_tutorial.dart';
import '../core/mines_rules.dart';
import '../data/mines_storage.dart';
import '../game/mines_controller.dart';
import 'mines_board.dart';

part 'mines_screen_flow.dart';
part 'mines_screen_layout.dart';
part 'mines_screen_rules.dart';

/// 지뢰찾기 플레이 화면.
class MinesScreen extends StatefulWidget {
  const MinesScreen({super.key, this.level = MinesLevel.beginner, this.saved, this.controller});

  final MinesLevel level;

  /// 이어하기: 저장된 판 (있으면 [level]은 무시).
  final Map<String, dynamic>? saved;

  /// (테스트용) 미리 만든 컨트롤러.
  final MinesController? controller;

  @override
  State<MinesScreen> createState() => _MinesScreenState();
}

class _MinesScreenState extends State<MinesScreen> with WidgetsBindingObserver {
  // 화면이 직접 소유한다: 화면이 다시 빌드되어도 판이 사라지지 않는다.
  late final MinesController c = widget.controller ??
      (widget.saved != null ? MinesController.fromJson(widget.saved!) : MinesController(level: widget.level));
  Timer? _ticker;
  Timer? _saveDebounce;
  final Completer<void> _skip = Completer<void>();

  /// 알림 종류 → 진동·소리 (설정의 진동·효과음 스위치를 따른다).
  /// 소리: 지뢰를 밟으면 "쾅" (사용자가 고른 소리: dragon-studio-boom).
  final GameFx _fx = GameFx({
    'reveal': const Fx(haptic: Haptic.select),
    'flag': const Fx(haptic: Haptic.light),
    'boom': const Fx(haptic: Haptic.heavy, sound: 'sfx/boom.wav'),
    'win': const Fx(haptic: Haptic.heavy),
  });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MinesStorage.setActive(c);
    c.addListener(_onChanged);
    c.onStarted = () => MinesStorage.recordStart(c.level);
    c.onWon = _onWon;
    c.onLost = _onLost;
    c.onFeedback = _feedback;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => c.tick());
  }

  @override
  void dispose() {
    _fx.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _saveDebounce?.cancel();
    c.removeListener(_onChanged);
    c.onStarted = null;
    c.onWon = null;
    c.onLost = null;
    c.onFeedback = null;
    _save();
    c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      c.setPaused(true);
      _save();
    }
  }



  // ── 끝났을 때 ──

  // ── 화면 ──

  /// "저장 안 하고 나가기"를 골랐다: 이 판은 더 보관하지 않는다.
  bool _discarded = false;




  @override
  Widget build(BuildContext context) {
    return SaveLeaveGuard(active: _inProgress, onSave: _save, onDiscard: _discard, child: _scaffold(context));
  }

}

/// 규칙 설명.