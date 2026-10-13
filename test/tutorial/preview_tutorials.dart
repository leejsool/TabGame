import 'package:tabgame/games/freecell/tutorial/freecell_tutorial.dart';
import 'package:tabgame/games/goblet/tutorial/goblet_tutorial.dart';
import 'package:tabgame/games/jigsaw/tutorial/jigsaw_tutorial.dart';
import 'package:tabgame/games/minesweeper/tutorial/mines_tutorial.dart';
import 'package:tabgame/games/rhythm/tutorial/rhythm_tutorial.dart';
import 'package:tabgame/games/solitaire/tutorial/solitaire_tutorial.dart';
import 'package:tabgame/games/uttt/tutorial/uttt_tutorial.dart';
import 'package:tabgame/tutorial/tutorial.dart';

/// 미리보기 도구가 그림으로 뽑을 슬라이드형 튜토리얼들.
Map<String, GameTutorial> previewTutorials() => {
      'mines': minesTutorial(),
      'solitaire': solitaireTutorial(),
      'freecell': freecellTutorial(),
      'jigsaw': jigsawTutorial(),
      'rhythm': rhythmTutorial(),
      'uttt': utttTutorial(),
      'goblet': gobletTutorial(),
    };
