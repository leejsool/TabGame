import 'package:flutter/material.dart';

/// 앱의 기본 글꼴 (작은 글씨 · 본문): 프리텐다드.
const String kAppFont = 'Pretendard';

/// 제목 · 게임 이름 같은 크고 굵은 글씨의 글꼴: 빗썸고딕 Original.
/// (한글 2,350자만 들어 있어서, 없는 글자는 [kTitleFontFallback]의 기본 글꼴로 나온다)
const String kTitleFont = 'BithumbGothic';
const List<String> kTitleFontFallback = [kAppFont];

/// 제목 글꼴을 입힌 글자 모양 ([base]가 있으면 거기에 입힌다).
TextStyle titleFont([TextStyle? base]) => (base ?? const TextStyle()).copyWith(fontFamily: kTitleFont, fontFamilyFallback: kTitleFontFallback);

/// 앱 테마에 글꼴을 입힌다: 본문은 [kAppFont], 큰 제목들(display · headline · title)과 화면 위 제목 줄 · 팝업 제목은 [kTitleFont].
/// 앱(lib/app.dart)과 시험의 미리보기 테마가 같이 쓴다.
ThemeData withAppFonts(ThemeData theme) {
  final t = theme.textTheme;
  return theme.copyWith(
    textTheme: t.copyWith(
      displayLarge: titleFont(t.displayLarge),
      displayMedium: titleFont(t.displayMedium),
      displaySmall: titleFont(t.displaySmall),
      headlineLarge: titleFont(t.headlineLarge),
      headlineMedium: titleFont(t.headlineMedium),
      headlineSmall: titleFont(t.headlineSmall),
      titleLarge: titleFont(t.titleLarge),
      titleMedium: titleFont(t.titleMedium),
    ),
    appBarTheme: theme.appBarTheme.copyWith(titleTextStyle: titleFont(t.titleLarge).copyWith(color: theme.colorScheme.onSurface)),
    dialogTheme: theme.dialogTheme.copyWith(titleTextStyle: titleFont(t.headlineSmall).copyWith(color: theme.colorScheme.onSurface)),
  );
}
