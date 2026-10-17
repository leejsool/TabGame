import 'package:flutter/material.dart';

import 'game_save.dart';

/// 나가려 할 때 고른 것.
enum LeaveChoice { stay, save, discard }

/// "저장하고 나갈까요?" 물음창. 계속 하려면 [LeaveChoice.stay].
Future<LeaveChoice> askLeaveChoice(BuildContext context, {String? detail}) async {
  final choice = await showDialog<LeaveChoice>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.exit_to_app_rounded, size: 30),
      title: const Text('게임에서 나갈까요?'),
      content: Text(
        '${detail == null ? '' : '$detail\n\n'}저장하고 나가면 나중에 이어서 할 수 있어요.\n저장하지 않고 나가면 이 판은 사라져요.',
        textAlign: TextAlign.center,
      ),
      actionsAlignment: MainAxisAlignment.center,
      actionsOverflowAlignment: OverflowBarAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, LeaveChoice.stay), child: const Text('계속하기')),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Theme.of(ctx).colorScheme.error),
          onPressed: () => Navigator.pop(ctx, LeaveChoice.discard),
          child: const Text('저장 안 하고 나가기'),
        ),
        FilledButton(onPressed: () => Navigator.pop(ctx, LeaveChoice.save), child: const Text('저장하고 나가기')),
      ],
    ),
  );
  return choice ?? LeaveChoice.stay;
}

/// 하던 판이 있는데 같은 화면에서 새 판을 시작하려 할 때 확인한다. 계속하면 true.
Future<bool> confirmNewGame(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('새 판을 시작할까요?'),
      content: const Text('지금 하던 판은 사라지고 새 판이 시작돼요.', textAlign: TextAlign.center),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('새 판')),
      ],
    ),
  );
  return ok ?? false;
}

/// 진행 중인 판에서 뒤로가기(안드로이드 뒤로가기 단추·앱바 뒤로 화살표)를 누르면 저장할지 물어보는 감싸개.
///
/// [active]가 false(아직 아무것도 안 했거나 이미 끝난 판)면 묻지 않고 바로 나간다.
class SaveLeaveGuard extends StatelessWidget {
  const SaveLeaveGuard({
    super.key,
    required this.active,
    required this.onSave,
    required this.onDiscard,
    required this.child,
    this.detail,
  });

  /// 지금 나가려 할 때 물어야 하는 판인가 (누를 때마다 새로 본다).
  final bool Function() active;

  /// "저장하고 나가기"를 골랐을 때: 지금 모습을 보관한다.
  final Future<void> Function() onSave;

  /// "저장 안 하고 나가기"를 골랐을 때: 보관된 것을 지운다.
  final Future<void> Function() onDiscard;

  final String? detail;
  final Widget child;

  Future<void> _onBack(BuildContext context) async {
    final navigator = Navigator.of(context);
    if (active()) {
      final choice = await askLeaveChoice(context, detail: detail);
      switch (choice) {
        case LeaveChoice.stay:
          return;
        case LeaveChoice.save:
          await onSave();
        case LeaveChoice.discard:
          await onDiscard();
      }
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack(context);
      },
      child: child,
    );
  }
}

/// 대결 게임 화면이 진행 중인 판을 [GameSave]에 보관하는 도우미.
///
/// [snapshot]이 판의 지금 모습(JSON)을 돌려준다. 아직 아무것도 안 했거나 끝난 판은 null (= 보관할 것이 없다).
/// 앱을 잠시 내려 두면(`paused`) 알아서 보관해 둔다. 저장 안 하고 나가기를 골랐으면 [discard] 뒤로는 더 보관하지 않는다.
class GameSaver with WidgetsBindingObserver {
  GameSaver({required this.gameId, required this.snapshot});

  final String gameId;
  final Map<String, dynamic>? Function() snapshot;

  bool _discarded = false;
  bool _attached = false;

  /// 지금 나갈 때 물어야 하는 판인가.
  bool get active => !_discarded && snapshot() != null;

  void attach() {
    if (_attached) return;
    _attached = true;
    WidgetsBinding.instance.addObserver(this);
  }

  void detach() {
    if (!_attached) return;
    _attached = false;
    WidgetsBinding.instance.removeObserver(this);
  }

  /// 지금 모습을 보관한다. 보관할 것이 없는 판(끝났거나 시작 전)이면 보관된 것을 지운다.
  Future<void> save() async {
    if (_discarded) return;
    final s = snapshot();
    if (s == null) {
      await GameSave.clear(gameId);
    } else {
      await GameSave.write(gameId, s);
    }
  }

  /// 판이 끝났을 때: 이어하기 보관을 지우고 더는 보관하지 않는다.
  Future<void> finish() async {
    if (_discarded) return; // (이미 지웠다)
    _discarded = true;
    await GameSave.clear(gameId);
  }

  /// 저장 안 하고 나가기.
  Future<void> discard() => finish();

  /// 같은 화면에서 새 판을 시작할 때: 다시 보관할 수 있게 한다.
  void rearm() => _discarded = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive || state == AppLifecycleState.hidden) {
      save();
    }
  }
}
