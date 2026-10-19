import 'package:flutter/material.dart';

import '../../../tutorial/art_common.dart';
import '../../../tutorial/tutorial.dart';
import '../ui/dot_painter.dart';

const Color _dotColor = Color(0xFF2F8FDB);
const Color _r = Color(0xFFE5484D);
const Color _y = Color(0xFFF7C948);
const Color _b = Color(0xFF3D7BE0);

/// 도트 캐논 게임 방법.
GameTutorial dotTutorial() => GameTutorial(
      title: '도트 캐논',
      color: _dotColor,
      steps: [
        TutorialStep(
          title: '액자 속 도트 그림을 지워요',
          body: '액자 안에 도트로 그린 그림이 있어요. 대포로 도트를 하나씩 맞혀서 그림을 전부 지우면 이겨요.\n'
              '대포는 색이 정해져 있어서, 같은 색 도트만 지울 수 있어요.',
          art: (context, accent) => ArtCanvas(
            width: 340,
            height: 170,
            child: Center(
              child: SizedBox(
                width: 160,
                height: 150,
                child: CustomPaint(
                  painter: DotArtPainter(
                    const [
                      -1, 0, 0, -1, 0, 0, -1, //
                      0, 1, 0, 0, 0, 0, 0,
                      0, 0, 0, 0, 0, 0, 0,
                      -1, 0, 0, 0, 0, 0, -1,
                      -1, -1, 0, 0, 0, -1, -1,
                      -1, -1, -1, 0, -1, -1, -1,
                    ],
                    7,
                    6,
                    const [_r, Color(0xFFFFFFFF)],
                  ),
                ),
              ),
            ),
          ),
        ),
        TutorialStep(
          title: '벨트가 액자를 빙글빙글 돌아요',
          body: '액자를 둘러싼 컨베이어 벨트는 시계 방향으로 돌아요. 벨트에 올라간 대포는 한 칸 갈 때마다 '
              '마주 보는 줄의 도트를 살펴보고, 가장 바깥에 보이는 도트가 자기 색이면 한 발 쏴요.',
          icon: Icons.autorenew_rounded,
        ),
        TutorialStep(
          title: '맨 앞 대포를 눌러 벨트에 올려요',
          body: '아래 대기열에서 줄마다 맨 앞 대포를 누르면 벨트 입구(왼쪽 아래)에서 벨트에 올라가요.\n'
              '입구에 다른 대포가 지나가는 중이면, 잠깐 기다렸다가 저절로 올라가요.\n'
              '대포의 숫자는 쏠 수 있는 탄의 수예요. 탄을 다 쓰면 대포가 사라져요.',
          art: (context, accent) => ArtCanvas(
            width: 340,
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: const [
                CannonTile(color: _r, ammo: 6, size: 76, glow: true),
                CannonTile(color: _y, ammo: 9, size: 76, glow: true),
                CannonTile(color: _b, ammo: 4, size: 76, glow: true),
              ],
            ),
          ),
        ),
        TutorialStep(
          title: '꾹 누르면 같은 색을 보여 줘요',
          body: '색이 비슷해서 헷갈리면, 대기 중인 대포 아무거나 꾹 누르고 있어 보세요.\n'
              '누르는 동안 같은 색 도트는 떠올라 커지고, 같은 색 대포(대기열·벨트 위)는 흰 고리가 생겨요. 다른 색은 흐려져요.\n'
              '손을 떼면 원래대로 돌아오고, 꾹 눌렀다 떼도 대포는 올라가지 않아요. 짧게 톡 누를 때만 올라가요.',
          art: (context, accent) => ArtCanvas(
            width: 340,
            height: 170,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Align(alignment: Alignment(-0.78, 0), child: Icon(Icons.touch_app_rounded, size: 34, color: _dotColor)),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: const [
                    CannonTile(color: _r, ammo: 6, size: 72, ring: true),
                    Opacity(opacity: 0.35, child: CannonTile(color: _y, ammo: 9, size: 72)),
                    CannonTile(color: _r, ammo: 4, size: 72, ring: true),
                    Opacity(opacity: 0.35, child: CannonTile(color: _b, ammo: 5, size: 72)),
                  ],
                ),
              ],
            ),
          ),
        ),
        TutorialStep(
          title: '바깥에 보이는 색만 맞힐 수 있어요',
          body: '대포는 줄에서 가장 바깥에 있는 도트만 맞힐 수 있어요. 안쪽에 덮여 있는 색은, 바깥 색을 먼저 지워야 쏠 수 있어요.\n'
              '맨 앞 대포가 반짝이면 지금 맞힐 수 있는 색이라는 뜻이에요.',
          icon: Icons.layers_rounded,
        ),
        TutorialStep(
          title: '벨트 자리는 한정되어 있어요',
          body: '벨트에는 대포를 정해진 수(위쪽 숫자)만큼만 올릴 수 있어요. 맞힐 수 없는 대포를 올리면 자리만 차지하고 벨트를 계속 돌아요.\n'
              '벨트 위 대포도 대기 중인 대포도 지금 보이는 도트를 맞힐 수 없게 되면 막힌 거예요. 그럴 땐 처음부터 다시 해요.',
          icon: Icons.block_rounded,
        ),
        TutorialStep(
          title: '내 사진으로 그림을 만들어요',
          body: '첫 화면의 "내 사진으로 만들기"에서 갤러리 사진을 고르면 도트 그림으로 바꿔 줘요. 크기와 색 수를 고를 수 있고, '
              '풀리는 대포 배치를 찾아서 난이도도 매겨 줘요.\n만든 그림은 "내가 만든 그림"에 남아요.',
          icon: Icons.add_photo_alternate_rounded,
        ),
      ],
    );
