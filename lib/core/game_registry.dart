import 'package:flutter/material.dart';

import '../games/dandelion/dandelion_entry.dart';
import '../games/dandelion/tutorial/dandelion_tutorial.dart';
import '../games/freecell/freecell_entry.dart';
import '../games/getcolor/getcolor_entry.dart';
import '../games/getcolor/tutorial/getcolor_tutorial.dart';
import '../games/freecell/tutorial/freecell_tutorial.dart';
import '../games/goblet/goblet_entry.dart';
import '../games/goblet/tutorial/goblet_tutorial.dart';
import '../games/uttt/tutorial/uttt_tutorial.dart';
import '../games/uttt/uttt_entry.dart';
import '../games/jigsaw/jigsaw_entry.dart';
import '../games/jigsaw/tutorial/jigsaw_tutorial.dart';
import '../games/minesweeper/minesweeper_entry.dart';
import '../games/minesweeper/tutorial/mines_tutorial.dart';
import '../games/rhythm/rhythm_entry.dart';
import '../games/rhythm/tutorial/rhythm_tutorial.dart';
import '../games/solitaire/solitaire_entry.dart';
import '../games/sprouts/sprouts_entry.dart';
import '../games/sprouts/tutorial/sprouts_tutorial.dart';
import '../games/solitaire/tutorial/solitaire_tutorial.dart';
import '../games/sudoku/sudoku_entry.dart';
import '../games/sudoku/tutorial/sudoku_tutorial.dart';
import '../games/dandelion/ui/dandelion_records_tab.dart';
import '../games/freecell/ui/freecell_records_tab.dart';
import '../games/getcolor/ui/getcolor_records_tab.dart';
import '../games/goblet/ui/goblet_records_tab.dart';
import '../games/jigsaw/ui/jigsaw_records_tab.dart';
import '../games/minesweeper/ui/mines_records_tab.dart';
import '../games/rhythm/ui/rhythm_records_tab.dart';
import '../games/solitaire/ui/solitaire_records_tab.dart';
import '../games/sprouts/ui/sprouts_records_tab.dart';
import '../games/sudoku/ui/sudoku_records_tab.dart';
import '../games/uttt/ui/uttt_records_tab.dart';
import '../hub/game_icons.dart';
import 'game_info.dart';

/// 앱에 들어갈 모든 게임 목록.
///
/// 새 게임은 이 목록에 항목 하나만 추가하면 허브 카드·모드 고르기·기록 화면까지 모두 붙는다.
///  - `builder`: 게임 화면 (없으면 "준비 중"으로 표시)
///  - `tutorial`: 게임 방법 안내
///  - `iconPainter` / `iconImage`: 허브 카드의 큰 그림 (없으면 `icon`)
///  - `recordsTab`: "내 기록" 화면의 기록 보드 (게임 안에서는 `openRecords(context, game: id)`로 연다)
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
    tutorial: sudokuTutorial,
    iconPainter: paintSudokuIcon,
    recordsTab: SudokuRecordsTab.new,
  ),
  GameInfo(
    id: 'minesweeper',
    title: '지뢰찾기',
    tagline: '숫자 단서로 지뢰를 피해요',
    icon: Icons.flag_rounded,
    color: Color(0xFFC8553D),
    modes: [PlayMode.solo],
    builder: buildMinesweeper,
    tutorial: minesTutorial,
    iconPainter: paintMinesIcon,
    recordsTab: MinesRecordsTab.new,
  ),
  GameInfo(
    id: 'solitaire',
    title: '솔리테어',
    tagline: '카드를 순서대로 쌓아요',
    icon: Icons.style_rounded,
    color: Color(0xFF2E7D5B),
    modes: [PlayMode.solo],
    builder: buildSolitaire,
    tutorial: solitaireTutorial,
    iconPainter: paintSolitaireIcon,
    recordsTab: SolitaireRecordsTab.new,
  ),
  GameInfo(
    id: 'freecell',
    title: '프리셀',
    tagline: '빈 칸을 잘 쓰는 카드 퍼즐',
    icon: Icons.view_column_rounded,
    color: Color(0xFF6A4C93),
    modes: [PlayMode.solo],
    builder: buildFreecell,
    tutorial: freecellTutorial,
    iconPainter: paintFreecellIcon,
    recordsTab: FreecellRecordsTab.new,
  ),
  GameInfo(
    id: 'jigsaw',
    title: '직소퍼즐',
    tagline: '조각을 맞춰 그림을 완성해요',
    icon: Icons.extension_rounded,
    color: Color(0xFFE09F3E),
    modes: [PlayMode.solo],
    builder: buildJigsaw,
    tutorial: jigsawTutorial,
    iconPainter: paintJigsawIcon,
    recordsTab: JigsawRecordsTab.new,
  ),
  GameInfo(
    id: 'get_color',
    title: '겟 컬러',
    tagline: '같은 색끼리 병에 모아요',
    icon: Icons.local_drink_rounded,
    color: Color(0xFF8E4EC6),
    modes: [PlayMode.solo],
    builder: buildGetColor,
    tutorial: getColorTutorial,
    iconPainter: paintGetColorIcon,
    recordsTab: GetColorRecordsTab.new,
  ),
  GameInfo(
    id: 'rhythm_swords',
    title: '리듬 검사단',
    tagline: '박자에 맞춰 검을 휘둘러요',
    icon: Icons.music_note_rounded,
    color: Color(0xFFE2793A),
    modes: [PlayMode.solo],
    builder: buildRhythm,
    tutorial: rhythmTutorial,
    iconImage: 'assets/rhythm/art/c3_side_swing.png',
    recordsTab: RhythmRecordsTab.new,
  ),
  GameInfo(
    id: 'pinball',
    title: '핀볼',
    tagline: '플리퍼로 공을 튕겨요',
    icon: Icons.blur_circular_rounded,
    color: Color(0xFF1B998B),
    modes: [PlayMode.solo],
    iconPainter: paintPinballIcon,
  ),

  // ── 함께 놀기 ('아주 이상한 수학책' 게임들) ──
  GameInfo(
    id: 'ultimate_tictactoe',
    title: '궁극 틱택토',
    tagline: '틱택토 속의 틱택토',
    icon: Icons.tag_rounded,
    color: Color(0xFFD1495B),
    modes: [PlayMode.local2p, PlayMode.vsCpu],
    builder: buildUttt,
    tutorial: utttTutorial,
    iconPainter: paintUtttIcon,
    recordsTab: UtttRecordsTab.new,
  ),
  GameInfo(
    id: 'goblet_gobblers',
    title: '고블렛 고블러스',
    tagline: '큰 컵으로 작은 컵을 덮어요',
    icon: Icons.layers_rounded,
    color: Color(0xFF00798C),
    modes: [PlayMode.local2p, PlayMode.vsCpu],
    builder: buildGoblet,
    tutorial: gobletTutorial,
    iconPainter: paintGobletIcon,
    recordsTab: GobbletRecordsTab.new,
    recordsTitle: '고블렛',
  ),
  GameInfo(
    id: 'sprouts',
    title: '콩나물',
    tagline: '점을 잇고 새 점을 찍어요',
    icon: Icons.scatter_plot_rounded,
    color: Color(0xFF5E9E2F),
    modes: [PlayMode.local2p, PlayMode.vsCpu],
    builder: buildSprouts,
    tutorial: sproutsTutorial,
    iconPainter: paintSproutsIcon,
    recordsTab: SproutsRecordsTab.new,
  ),
  GameInfo(
    id: 'dandelion',
    title: '민들레',
    tagline: '꽃을 심고 바람에 씨앗을 날려요',
    icon: Icons.local_florist_rounded,
    color: Color(0xFFD99A00),
    modes: [PlayMode.local2p, PlayMode.vsCpu],
    builder: buildDandelion,
    tutorial: dandelionTutorial,
    iconPainter: paintDandelionIcon,
    recordsTab: DandelionRecordsTab.new,
  ),
];
