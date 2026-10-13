import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'card_look.dart';

/// 앱 전체 설정. 바뀌면 화면이 자동으로 갱신되고, 기기에 저장된다.
class Settings extends ChangeNotifier {
  Settings._(this._prefs)
      : _sound = _prefs.getBool(_kSound) ?? true,
        _haptics = _prefs.getBool(_kHaptics) ?? true,
        _autoComplete = _prefs.getBool(_kAutoComplete) ?? true,
        _freecellAutoMove = _prefs.getBool(_kFreecellAutoMove) ?? true,
        _solitaireAutoMove = _prefs.getBool(_kSolitaireAutoMove) ?? true,
        _themeMode = ThemeMode.values.byName(
          _prefs.getString(_kTheme) ?? ThemeMode.system.name,
        ),
        _cardStyle = _readCardStyle(_prefs.getString(_kCardStyle)),
        _cardBackStyle = _readCardBackStyle(_prefs.getString(_kCardBackStyle)),
        _cardLayout = _readCardLayout(_prefs.getString(_kCardLayout)),
        _fourColor = _prefs.getBool(_kFourColor) ?? false,
        _autoUpdateCheck = _prefs.getBool(_kAutoUpdateCheck) ?? true,
        _showTutorials = _prefs.getBool(_kShowTutorials) ?? true {
    CardLook.style = _cardStyle;
    CardLook.backStyle = _cardBackStyle;
    CardLook.layout = _cardLayout;
    CardLook.fourColor = _fourColor;
  }

  static CardLayout _readCardLayout(String? name) {
    for (final l in CardLayout.values) {
      if (l.name == name) return l;
    }
    return CardLayout.auto;
  }

  static CardStyle _readCardStyle(String? name) {
    for (final s in CardStyle.values) {
      if (s.name == name) return s;
    }
    return CardStyle.bicycle; // 기본은 바이시클
  }

  static CardBackStyle _readCardBackStyle(String? name) {
    for (final style in CardBackStyle.values) {
      if (style.name == name) return style;
    }
    return CardBackStyle.classic;
  }

  static const _kSound = 'sound';
  static const _kHaptics = 'haptics';
  static const _kTheme = 'themeMode';
  static const _kAutoComplete = 'autoComplete';
  static const _kFreecellAutoMove = 'freecellAutoMove';
  static const _kSolitaireAutoMove = 'solitaireAutoMove';
  static const _kCardStyle = 'cardStyle';
  static const _kCardBackStyle = 'cardBackStyle';
  static const _kCardLayout = 'cardLayout';
  static const _kFourColor = 'cardFourColor';
  static const _kAutoUpdateCheck = 'autoUpdateCheck';
  static const _kLastUpdateCheck = 'lastUpdateCheckMs';
  static const _kShowTutorials = 'showTutorials';

  final SharedPreferences _prefs;
  bool _sound;
  bool _haptics;
  bool _autoComplete;
  bool _freecellAutoMove;
  bool _solitaireAutoMove;
  ThemeMode _themeMode;
  CardStyle _cardStyle;
  CardBackStyle _cardBackStyle;
  CardLayout _cardLayout;
  bool _fourColor;
  bool _autoUpdateCheck;
  bool _showTutorials;

  static Future<Settings> load() async =>
      Settings._(await SharedPreferences.getInstance());

  bool get sound => _sound;
  bool get haptics => _haptics;

  /// 스도쿠: 남은 칸이 몇 개 안 남고 바로 보이는 칸뿐이면 자동으로 채워서 끝낸다.
  bool get autoComplete => _autoComplete;
  ThemeMode get themeMode => _themeMode;

  /// 프리셀: 손해 없는 카드를 완성 칸으로 자동으로 올린다.
  bool get freecellAutoMove => _freecellAutoMove;

  /// 솔리테어: 손해 없는 카드를 완성 칸으로 자동으로 올린다.
  bool get solitaireAutoMove => _solitaireAutoMove;

  set solitaireAutoMove(bool v) {
    _solitaireAutoMove = v;
    _prefs.setBool(_kSolitaireAutoMove, v);
    notifyListeners();
  }

  /// 카드 앞면 모양 (프리셀·솔리테어). 기본은 바이시클.
  CardStyle get cardStyle => _cardStyle;

  set cardStyle(CardStyle v) {
    _cardStyle = v;
    CardLook.style = v;
    _prefs.setString(_kCardStyle, v.name);
    notifyListeners();
  }

  /// 카드 뒷면 모양.
  CardBackStyle get cardBackStyle => _cardBackStyle;

  set cardBackStyle(CardBackStyle v) {
    _cardBackStyle = v;
    CardLook.backStyle = v;
    _prefs.setString(_kCardBackStyle, v.name);
    notifyListeners();
  }

  /// 카드 앞면 배치: 자동 / 폰용(숫자·무늬 한 줄) / 전체.
  CardLayout get cardLayout => _cardLayout;

  set cardLayout(CardLayout v) {
    _cardLayout = v;
    CardLook.layout = v;
    _prefs.setString(_kCardLayout, v.name);
    notifyListeners();
  }

  /// 무늬마다 다른 색으로 카드를 구분하기 쉽게.
  bool get fourColor => _fourColor;

  set fourColor(bool v) {
    _fourColor = v;
    CardLook.fourColor = v;
    _prefs.setBool(_kFourColor, v);
    notifyListeners();
  }

  /// 앱을 켤 때 GitHub에서 새 버전이 있는지 알아서 확인한다.
  bool get autoUpdateCheck => _autoUpdateCheck;

  set autoUpdateCheck(bool v) {
    _autoUpdateCheck = v;
    _prefs.setBool(_kAutoUpdateCheck, v);
    notifyListeners();
  }

  /// 게임을 처음 열 때 게임 방법 안내를 자동으로 보여준다 (건너뛸 수 있다).
  bool get showTutorials => _showTutorials;

  set showTutorials(bool v) {
    _showTutorials = v;
    _prefs.setBool(_kShowTutorials, v);
    notifyListeners();
  }

  /// 마지막으로 업데이트를 확인한 때 (밀리초). 자동 확인을 너무 자주 하지 않으려고.
  int get lastUpdateCheckMs => _prefs.getInt(_kLastUpdateCheck) ?? 0;

  set lastUpdateCheckMs(int v) => _prefs.setInt(_kLastUpdateCheck, v);

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
