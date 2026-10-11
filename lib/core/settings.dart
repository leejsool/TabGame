import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱 전체 설정. 바뀌면 화면이 자동으로 갱신되고, 기기에 저장된다.
class Settings extends ChangeNotifier {
  Settings._(this._prefs)
      : _sound = _prefs.getBool(_kSound) ?? true,
        _haptics = _prefs.getBool(_kHaptics) ?? true,
        _autoComplete = _prefs.getBool(_kAutoComplete) ?? true,
        _freecellAutoMove = _prefs.getBool(_kFreecellAutoMove) ?? true,
        _themeMode = ThemeMode.values.byName(
          _prefs.getString(_kTheme) ?? ThemeMode.system.name,
        );

  static const _kSound = 'sound';
  static const _kHaptics = 'haptics';
  static const _kTheme = 'themeMode';
  static const _kAutoComplete = 'autoComplete';
  static const _kFreecellAutoMove = 'freecellAutoMove';

  final SharedPreferences _prefs;
  bool _sound;
  bool _haptics;
  bool _autoComplete;
  bool _freecellAutoMove;
  ThemeMode _themeMode;

  static Future<Settings> load() async =>
      Settings._(await SharedPreferences.getInstance());

  bool get sound => _sound;
  bool get haptics => _haptics;

  /// 스도쿠: 남은 칸이 몇 개 안 남고 바로 보이는 칸뿐이면 자동으로 채워서 끝낸다.
  bool get autoComplete => _autoComplete;
  ThemeMode get themeMode => _themeMode;

  /// 프리셀: 손해 없는 카드를 완성 칸으로 자동으로 올린다.
  bool get freecellAutoMove => _freecellAutoMove;

  set freecellAutoMove(bool v) {
    _freecellAutoMove = v;
    _prefs.setBool(_kFreecellAutoMove, v);
    notifyListeners();
  }

  set autoComplete(bool v) {
    _autoComplete = v;
    _prefs.setBool(_kAutoComplete, v);
    notifyListeners();
  }

  set sound(bool v) {
    _sound = v;
    _prefs.setBool(_kSound, v);
    notifyListeners();
  }

  set haptics(bool v) {
    _haptics = v;
    _prefs.setBool(_kHaptics, v);
    notifyListeners();
  }

  set themeMode(ThemeMode v) {
    _themeMode = v;
    _prefs.setString(_kTheme, v.name);
    notifyListeners();
  }
}
