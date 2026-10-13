import 'package:flutter/material.dart';

import '../../../tutorial/tutorial.dart';
import 'basic_lesson_screen.dart';

/// 스도쿠 게임 방법: 기본 규칙을 진짜 판에서 한 단계씩 직접 해 보며 배운다.
/// (심화 기술은 이 안내가 끝난 뒤 메뉴의 "심화 기술 연습"에서 원할 때 연습한다.)
GameTutorial sudokuTutorial() => GameTutorial(
      title: '스도쿠',
      color: const Color(0xFF3F7CAC),
      builder: (context, {required firstTime}) => SudokuBasicLessonScreen(firstTime: firstTime),
    );
