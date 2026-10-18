import '../../../core/win_celebration.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/game_fx.dart';
import '../../../core/game_widgets.dart';
import '../../../core/give_up.dart';
import '../../../core/leave_guard.dart';
import '../../../core/win_sound.dart';
import '../data/getcolor_storage.dart';
import '../game/getcolor_controller.dart';
import '../getcolor_entry.dart';
import '../tutorial/getcolor_tutorial.dart';
import 'getcolor_board.dart';

part 'getcolor_screen_flow.dart';
part 'getcolor_screen_layout.dart';

/// 겟 컬러 플레이 화면.
class GetColorScreen extends StatefulWidget {
  const GetColorScreen({super.key, required this.controller});

  /// 이 화면이 맡아서 정리한다.
  final GetColorController controller;

  @override
  State<GetColorScreen> createState() => _GetColorScreenState();
}

class _GetColorScreenState extends State<GetColorScreen> with WidgetsBindingObserver {
  GetColorController get c => widget.controller;
  Timer? _ticker;
  Timer? _saveDebounce;

  /// 알림 종류 → 진동·소리 (설정의 진동·효과음 스위치를 따른다).
  final GameFx _fx = GameFx({
    'select': const Fx(haptic: Haptic.select),
    'pour': const Fx(haptic: Haptic.light),
    'bottle': const Fx(haptic: Haptic.medium),
    'win': const Fx(haptic: Haptic.heavy),
  });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    GetColorStorage.setActive(c);
    c.addListener(_onChanged);
    c.onFeedback = _feedback;
    c.onWon = _onWon;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => c.tick());
  }

  @override
  void dispose() {
    _fx.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _saveDebounce?.cancel();
    c.removeListener(_onChanged);
    c.onFeedback = null;
    c.onWon = null;
    _save();
    // 저장은 비동기로 컨트롤러 상태를 읽으므로, 저장 쪽에서 먼저 JSON 으로 굳힌 뒤 정리한다.
    Future<void>.microtask(c.dispose);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) {
      c.setPaused(true);
      _save();
    }
  }


  bool _stuckShown = false;



  // ── 끝났을 때 ──


  // ── 포기 ──




  // ── 화면 ──

  /// "저장 안 하고 나가기"를 골랐다: 이 판은 더 보관하지 않는다.
  bool _discarded = false;




  @override
  Widget build(BuildContext context) {
    return SaveLeaveGuard(active: _inProgress, onSave: _save, onDiscard: _discard, child: _scaffold(context));
  }

}
