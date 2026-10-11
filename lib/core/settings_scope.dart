import 'package:flutter/widgets.dart';

import 'settings.dart';

/// 앱 어디서든 설정을 꺼내 쓸 수 있게 해준다. (`SettingsScope.of(context)`)
class SettingsScope extends InheritedNotifier<Settings> {
  const SettingsScope({super.key, required Settings settings, required super.child})
      : super(notifier: settings);

  static Settings of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SettingsScope>();
    assert(scope != null, 'SettingsScope가 위젯 트리에 없어요.');
    return scope!.notifier!;
  }
}
