import 'package:flutter/material.dart';

/// 스도쿠 화면의 색. 밝은/어두운 테마 두 벌.
class SudokuColors {
  const SudokuColors({
    required this.cell,
    required this.peer,
    required this.sameDigit,
    required this.selected,
    required this.given,
    required this.user,
    required this.wrong,
    required this.wrongBg,
    required this.lineThin,
    required this.lineThick,
    required this.note,
    required this.noteHighlight,
    required this.hintCause,
    required this.hintTarget,
    required this.hintRegion,
    required this.accent,
    required this.place,
    required this.remove,
  });

  final Color cell;
  final Color peer;
  final Color sameDigit;
  final Color selected;
  final Color given;
  final Color user;
  final Color wrong;
  final Color wrongBg;
  final Color lineThin;
  final Color lineThick;
  final Color note;
  final Color noteHighlight;
  final Color hintCause;
  final Color hintTarget;
  final Color hintRegion;
  final Color accent;
  final Color place;
  final Color remove;

  static const light = SudokuColors(
    cell: Color(0xFFFFFFFF),
    peer: Color(0xFFE8ECF5),
    sameDigit: Color(0xFFC3D2FA),
    selected: Color(0xFF93AAF3),
    given: Color(0xFF1F2430),
    user: Color(0xFF2F5BD0),
    wrong: Color(0xFFE03150),
    wrongBg: Color(0xFFFDE2E6),
    lineThin: Color(0xFFC5CBD9),
    lineThick: Color(0xFF4F586E),
    note: Color(0xFF5C667F),
    noteHighlight: Color(0xFFA9BEF8),
    hintCause: Color(0xFFFFE9A6),
    hintTarget: Color(0xFFBFE8C4),
    hintRegion: Color(0xFFFFF7DC),
    accent: Color(0xFF2F5BD0),
    place: Color(0xFF1E8E3E),
    remove: Color(0xFFD32F2F),
  );

  static const dark = SudokuColors(
    cell: Color(0xFF1F2533),
    peer: Color(0xFF2A3245),
    sameDigit: Color(0xFF34508F),
    selected: Color(0xFF4A6BC4),
    given: Color(0xFFE8ECF6),
    user: Color(0xFF7EA0FF),
    wrong: Color(0xFFFF6B7F),
    wrongBg: Color(0xFF4A2530),
    lineThin: Color(0xFF3A4358),
    lineThick: Color(0xFF9AA5BF),
    note: Color(0xFF9AA5BF),
    noteHighlight: Color(0xFF4E6FD0),
    hintCause: Color(0xFF5C5430),
    hintTarget: Color(0xFF2D5A3A),
    hintRegion: Color(0xFF3A3828),
    accent: Color(0xFF7EA0FF),
    place: Color(0xFF6FD08A),
    remove: Color(0xFFFF8A80),
  );

  static SudokuColors of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
