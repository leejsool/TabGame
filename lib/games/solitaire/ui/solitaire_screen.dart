import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/game_fx.dart';
import '../../../core/game_widgets.dart';
import '../../../core/give_up.dart';
import '../../../core/leave_guard.dart';
import '../../../core/win_sound.dart';
import '../../../core/settings_scope.dart';
import '../tutorial/solitaire_tutorial.dart';
import '../data/solitaire_storage.dart';
import '../game/solitaire_controller.dart';
import '../solitaire_entry.dart';
import 'solitaire_table.dart';

part 'solitaire_screen_flow.dart';
part 'solitaire_screen_layout.dart';
part 'solitaire_screen_bars.dart';
part 'solitaire_screen_rules.dart';

/// 솔리테어 플레이 화면.
class SolitaireScreen extends StatefulWidget {
  const SolitaireScreen({super.key, this.deal = 1, this.draw = 1, this.saved, this.controller});

  /// 새로 시작할 판 번호와 뽑기 장수.
  final int deal;
  final int draw;

  /// 이어하기: 저장된 판 (있으면 [deal]/[draw]는 무시).
  final Map<String, dynamic>? saved;

  /// (테스트용) 미리 만든 컨트롤러.
  final SolitaireController? controller;

  @override
  State<SolitaireScreen> createState() => _SolitaireScreenState();
}

class _SolitaireScreenState extends State<SolitaireScreen> with WidgetsBindingObserver {
  // 화면이 직접 소유한다: 화면이 다시 빌드되어도 판이 사라지지 않는다.
  late final SolitaireController c = widget.controller ?? _create();
  Timer? _ticker;
  Timer? _saveDebounce;
  bool _noMovesShown = false;
  final Completer<void> _skipCelebration = Completer<void>();

  SolitaireController _create() {
    final autoMove =
        context.getInheritedWidgetOfExactType<SettingsScope>()?.notifier?.solitaireAutoMove ?? true;
    if (widget.saved != null) {
      return SolitaireController.fromJson(widget.saved!, autoMove: autoMove);
    }
    return SolitaireController(deal: widget.deal, draw: widget.draw, autoMoveEnabled: autoMove);
  }

  /// 알림 종류 → 진동·소리 (설정의 진동·효과음 스위치를 따른다).
  final GameFx _fx = GameFx({
    'drop': const Fx(haptic: Haptic.select),
    'win': const Fx(haptic: Haptic.heavy),
  });

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SolitaireStorage.setActive(c);
    c.addListener(_onChanged);
    c.onCompleted = _onCompleted;
    c.onNoMoves = _onNoMoves;
    c.onFeedback = _feedback;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => c.tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
  }

  @override
  void dispose() {
    _fx.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _saveDebounce?.cancel();
    c.removeListener(_onChanged);
    c.onCompleted = null;
    c.onNoMoves = null;
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