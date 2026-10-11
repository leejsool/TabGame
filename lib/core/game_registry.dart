import 'package:flutter/material.dart';

import '../games/freecell/freecell_entry.dart';
import '../games/goblet/goblet_entry.dart';
import '../games/uttt/uttt_entry.dart';
import '../games/jigsaw/jigsaw_entry.dart';
import '../games/sudoku/sudoku_entry.dart';
import 'game_info.dart';

/// 앱에 들어갈 모든 게임 목록.
///
/// 새 게임을 만들면 해당 항목에 `builder:`만 연결하면 된다.
const List<GameInfo> allGames = [
  // ── 혼자 놀기 ──
  GameInfo(
    id: 'sudoku',
    title: '스도쿠',
    tagline: '숫자를 채워 넣는 논리 퍼즐',
    icon: Icons.grid_on_rounded,
    color: Color(0xFF3F7CAC),
    modes: [PlayMode.solo],
    builder: buildSudoku,
  ),
  GameInfo(
    id: 'minesweeper',
    title: '지뢰찾기',
    tagline: '숫자 단서로 지뢰를 피해요',
    icon: Icons.flag_rounded,
    color: Color(0xFFC8553D),
    modes: [PlayMode.solo],
  ),
  GameInfo(
    id: 'solitaire',
    title: '솔리테어',
    tagline: '카드를 순서대로 쌓아요',
    icon: Icons.style_rounded,
    color: Color(0xFF2E7D5B),
    modes: [PlayMode.solo],
  ),
  GameInfo(
    id: 'freecell',
    title: '프리셀',
    tagline: '빈 칸을 잘 쓰는 카드 퍼즐',
    icon: Icons.view_column_rounded,
    color: Color(0xFF6A4C93),
    modes: [PlayMode.solo],
    builder: buildFreecell,
  ),
  GameInfo(
    id: 'jigsaw',
    title: '직소퍼즐',
    tagline: '조각을 맞춰 그림을 완성해요',
    icon: Icons.extension_rounded,
    color: Color(0xFFE09F3E),
    modes: [PlayMode.solo],
    builder: buildJigsaw,
  ),
  GameInfo(
    id: 'pinball',
    title: '핀볼',
    tagline: '플리퍼로 공을 튕겨요',
    icon: Icons.blur_circular_rounded,
    color: Color(0xFF1B998B),
    modes: [PlayMode.solo],
  ),

  // ── 함께 놀기 ('아주 이상한 수학책' 게임들) ──
  GameInfo(
    id: 'ultimate_tictactoe',
    title: '얼티밋 틱택토',
    tagline: '틱택토 속의 틱택토',
    icon: Icons.tag_rounded,
    color: Color(0xFFD1495B),
    modes: [PlayMode.local2p, PlayMode.vsCpu],
    builder: buildUttt,
  ),
  GameInfo(
    id: 'goblet_gobblers',
    title: '고블렛 고블러스',
    tagline: '큰 컵으로 작은 컵을 덮어요',
    icon: Icons.layers_rounded,
    color: Color(0xFF00798C),
    modes: [PlayMode.local2p, PlayMode.vsCpu],
    builder: buildGoblet,
  ),
];
