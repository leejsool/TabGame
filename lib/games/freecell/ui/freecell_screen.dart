import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/format.dart';
import '../../../core/game_fx.dart';
import '../../../core/game_widgets.dart';
import '../../../core/give_up.dart';
import '../../../core/leave_guard.dart';
import '../../../core/win_sound.dart';
import '../../../core/settings.dart';
import '../../../core/settings_scope.dart';
import '../tutorial/freecell_tutorial.dart';
import '../core/freecell_difficulty.dart';
import '../data/freecell_storage.dart';
import '../freecell_entry.dart';
import '../game/freecell_controller.dart';
import 'freecell_menu_screen.dart' show levelColors;
import 'freecell_table.dart';

part 'freecell_screen_flow.dart';
part 'freecell_screen_layout.dart';
part 'freecell_screen_bars.dart';
part 'freecell_screen_rules.dart';

/// 프리셀 플레이 화면.
class FreecellScreen extends StatefulWidget {
  const FreecellScreen({super.key, this.deal = 1, this.saved, this.controller});

  /// 새로 시작할 판 번호.
  final int deal;

  /// 이어하기: 저장된 판 (있으면 [deal]은 무시).
  final Map<String, dynamic>? saved;

  /// (테스트용) 미리 만든 컨트롤러.
  final FreecellController? controller;

  @override
  State<FreecellScreen> createState() => _FreecellScreenState();
}

class _FreecellScreenState extends State<FreecellScreen> with WidgetsBindingObserver {
  // 화면이 직접 소유한다: 화면이 다시 빌드되어도 판이 사라지지 않는다.
  late final FreecellController c = widget.controller ?? _create();
  Timer? _ticker;
  Timer? _saveDebounce;
  bool _noMovesShown = false;
  final Completer<void> _skipCelebration = Completer<void>();
  FcDifficultyTable? _table;

  /// 이 판의 난이도 (표를 읽은 뒤에만 안다).
  FcLevel? get _level => _table?.levelOf(c.deal);

  FreecellController _create() {
    final autoMove =
        context.getInheritedWidgetOfExactType<SettingsScope>()?.notifier?.freecellAutoMove ?? true;
    if (widget.saved != null) {
      return FreecellController.fromJson(widget.saved!, autoMove: autoMove);
    }
    return FreecellController(deal: widget.deal, autoMoveEnabled: autoMove);
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
    FreecellStorage.setActive(c);
    c.addListener(_onChanged);
    c.onCompleted = _onCompleted;
    c.onNoMoves = _onNoMoves;
    c.onFeedback = _feedback;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => c.tick());
    WidgetsBinding.instance.addPostFrameCallback((_) => c.start());
    FcDifficultyTable.load().then((t) {
      if (mounted) setState(() => _table = t);
    }).catchError((_) {}); // 난이도 표를 못 읽어도 게임은 계속된다
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