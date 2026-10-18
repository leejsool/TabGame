import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'card_look.dart';
import 'game_speed.dart';
import 'nickname.dart';

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
        _suitPalette = _readSuitPalette(_prefs),
        _autoUpdateCheck = _prefs.getBool(_kAutoUpdateCheck) ?? true,
        _hiddenGames = {...?_prefs.getStringList(_kHiddenGames)},
        _showTutorials = _prefs.getBool(_kShowTutorials) ?? true,
        _fastPace = _prefs.getBool(_kFastPace) ?? false {
    GameSpeed.factor = _fastPace ? GameSpeed.fastFactor : 1;
    CardLook.style = _cardStyle;
    CardLook.backStyle = _cardBackStyle;
    CardLook.layout = _cardLayout;
    CardLook.palette = _suitPalette;
    // 별명은 처음 한 번 저절로 지어서 저장해 둔다 (바꾸고 싶으면 설정이나 같은 Wi‑Fi 첫 화면에서)
    final saved = cleanNickname(_prefs.getString(_kNickname));
    _nickname = saved ?? randomNickname();
    if (saved == null) _prefs.setString(_kNickname, _nickname);
  }

  /// 예전 "무늬 4색으로 보기"(켜짐/꺼짐) 설정도 이어받는다.
  static SuitPalette _readSuitPalette(SharedPreferences prefs) {
    final name = prefs.getString(_kSuitPalette);
    for (final p in SuitPalette.values) {
      if (p.name == name) return p;
    }
    return (prefs.getBool(_kFourColor) ?? false) ? SuitPalette.fourColor : SuitPalette.twoColor;
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
  static const _kFastPace = 'fastPace';
  static const _kTheme = 'themeMode';
  static const _kAutoComplete = 'autoComplete';
  static const _kFreecellAutoMove = 'freecellAutoMove';
  static const _kSolitaireAutoMove = 'solitaireAutoMove';
  static const _kCardStyle = 'cardStyle';
  static const _kCardBackStyle = 'cardBackStyle';
  static const _kCardLayout = 'cardLayout';
  static const _kFourColor = 'cardFourColor'; // 예전 설정 (켜짐/꺼짐)
  static const _kSuitPalette = 'suitPalette';
  static const _kAutoUpdateCheck = 'autoUpdateCheck';
  static const _kLastUpdateCheck = 'lastUpdateCheckMs';
  static const _kShowTutorials = 'showTutorials';
  static const _kNickname = 'nickname';
  static const _kHiddenGames = 'hiddenGames';

  final SharedPreferences _prefs;
  bool _sound;
  bool _haptics;
  bool _fastPace;
  bool _autoComplete;
  bool _freecellAutoMove;
  bool _solitaireAutoMove;
  ThemeMode _themeMode;
  CardStyle _cardStyle;
  CardBackStyle _cardBackStyle;
  CardLayout _cardLayout;
  SuitPalette _suitPalette;
  bool _autoUpdateCheck;
  final Set<String> _hiddenGames;
  bool _showTutorials;
  late String _nickname;

  static Future<Settings> load() async =>
      Settings._(await SharedPreferences.getInstance());

  bool get sound => _sound;
  bool get haptics => _haptics;

  /// 빠른 진행: CPU 대기와 상대 수 보여 주기가 짧아진다.
  bool get fastPace => _fastPace;

  /// 내 별명: 같은 Wi‑Fi로 함께 할 때 방 이름과 상대에게 보이는 이름. 처음에는 저절로 지어진다 (예: "빨간 토끼").
  String get nickname => _nickname;

  /// 별명을 바꾼다. 비어 있으면 무시하고, 너무 길면 [kMaxNicknameLength]글자까지만 남긴다.
  set nickname(String v) {
    final clean = cleanNickname(v);
    if (clean == null || clean == _nickname) return;
    _nickname = clean;
    _prefs.setString(_kNickname, clean);
    notifyListeners();
  }

  /// 새 별명을 무작위로 뽑는다 (지금과 다른 것).
  void rerollNickname() {
    var next = randomNickname();
    while (next == _nickname) {
      next = randomNickname();
    }
    nickname = next;
  }

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

  /// 무늬 색깔 (기본 두 색 / 4색 / 4색 계열 유지).
  SuitPalette get suitPalette => _suitPalette;

  set suitPalette(SuitPalette v) {
    _suitPalette = v;
    CardLook.palette = v;
    _prefs.setString(_kSuitPalette, v.name);
    notifyListeners();
  }

  /// 앱을 켤 때 GitHub에서 새 버전이 있는지 알아서 확인한다.
  bool get autoUpdateCheck => _autoUpdateCheck;

  set autoUpdateCheck(bool v) {
    _autoUpdateCheck = v;
    _prefs.setBool(_kAutoUpdateCheck, v);
    notifyListeners();
  }

  /// 메인 화면에서 숨겨 둔 게임들의 이름표 (`GameInfo.id`). 처음에는 비어 있어서 모든 게임이 보인다.
  Set<String> get hiddenGames => Set.unmodifiable(_hiddenGames);

  /// 이 게임이 메인 화면에 보이는가.
  bool isGameVisible(String id) => !_hiddenGames.contains(id);

  /// 게임을 메인 화면에 보이게 하거나 숨긴다. (숨겨도 게임과 기록은 그대로 남는다)
  void setGameVisible(String id, bool visible) {
    final changed = visible ? _hiddenGames.remove(id) : _hiddenGames.add(id);
    if (!changed) return;
    _prefs.setStringList(_kHiddenGames, _hiddenGames.toList()..sort());
    notifyListeners();
  }

  /// 숨겨 둔 게임을 모두 다시 보이게 한다.
  void showAllGames() {
    if (_hiddenGames.isEmpty) return;
    _hiddenGames.clear();
    _prefs.remove(_kHiddenGames);
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

  set fastPace(bool v) {
    _fastPace = v;
    GameSpeed.factor = v ? GameSpeed.fastFactor : 1;
    _prefs.setBool(_kFastPace, v);
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
