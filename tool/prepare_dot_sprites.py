"""이미 도트 아트인 그림(확대된 스프라이트)을 원래 도트 크기(1칸 = 1점)의 PNG로 되돌린다.

도트 하나가 여러 점으로 커져 있고 (가장자리가 번지거나 칸이 어긋나 있을 수 있다), 이걸 `flutter test tool/make_dot_stages.dart`의
"exact" 방식이 칸 그대로 읽는다. 배경은 가장자리에서 이어진 같은 색을 투명하게 만든다.

사용: python tool/prepare_dot_sprites.py   (아래 SPRITES를 고쳐서 새 그림을 넣는다)
"""
import sys
from collections import Counter, deque
from pathlib import Path

from PIL import Image

SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('tool/dot_stage_art/src')
OUT = Path('tool/dot_stage_art')

# 파일, 만들 이름, 도트 한 칸의 대략적인 크기(점), 배경과 같다고 볼 색 차이, 지울 상자들 [왼쪽, 위, 오른쪽, 아래] (원본 점 좌표)
SPRITES = [
    ('mario.png', 'mario', 29.2, 90, []),
    ('mario_face.png', 'mario_face', 8.0, 90, []),
    # bowser: 검은 배경도 그림의 일부로 둔다 (-1: 배경을 지우지 않음)
    ('bowser.png', 'bowser', 3.0, -1, []),
    ('dragon.png', 'dragon', 3.0, 90, []),
    ('charmander.png', 'charmander', 25.5, 90, [[0, 0, 70, 50], [0, 440, 70, 511], [480, 470, 555, 511]]),
    ('pikachu.png', 'pikachu', 10.7, 70, [[0, 490, 40, 540]]),
]


def diff(p, q):
    return abs(p[0] - q[0]) + abs(p[1] - q[1]) + abs(p[2] - q[2])


def fit_grid(im, guess, axis, spread=0.1):
    """칸 크기와 시작 위치를 찾는다: 색이 확 바뀌는 자리가 칸 경계에 가장 잘 맞는 값."""
    w, h = im.size
    px = im.load()
    cuts = Counter()
    if axis == 0:
        for y in range(0, h, max(1, h // 120)):
            for x in range(1, w):
                if diff(px[x, y], px[x - 1, y]) > 60:
                    cuts[x] += 1
        size = w
    else:
        for x in range(0, w, max(1, w // 120)):
            for y in range(1, h):
                if diff(px[x, y], px[x, y - 1]) > 60:
                    cuts[y] += 1
        size = h
    best = None
    c = guess * (1 - spread)
    while c <= guess * (1 + spread):
        o = 0.0
        while o < c:
            score = 0.0
            for pos, n in cuts.items():
                r = (pos - o) % c
                score += n * min(r, c - r)
            if best is None or score < best[0]:
                best = (score, c, o)
            o += 0.25
        c += 0.02
    return best[1], best[2], size


def main():
    for fname, name, guess, tol, masks in SPRITES:
        im = Image.open(SRC / fname).convert('RGB')
        # 지울 상자는 가장자리 색으로 덮는다 (사진 검색 화면의 아이콘·글자)
        edge = Counter(im.getpixel((x, 0)) for x in range(im.width)).most_common(1)[0][0]
        for l, t, r, b in masks:
            for y in range(t, min(b, im.height)):
                for x in range(l, min(r, im.width)):
                    im.putpixel((x, y), edge)
        spread = 0.04 if name == 'pikachu' else 0.1
        cw, ox, w = fit_grid(im, guess, 0, spread)
        ch, oy, h = fit_grid(im, guess, 1, spread)
        cols = round((w - ox) / cw)
        rows = round((h - oy) / ch)
        px = im.load()
        cells = [[None] * cols for _ in range(rows)]
        for j in range(rows):
            for i in range(cols):
                x0, x1 = ox + (i + 0.3) * cw, ox + (i + 0.7) * cw
                y0, y1 = oy + (j + 0.3) * ch, oy + (j + 0.7) * ch
                seen = Counter()
                for y in range(max(0, int(y0)), min(h, int(y1) + 1)):
                    for x in range(max(0, int(x0)), min(w, int(x1) + 1)):
                        p = px[x, y]
                        seen[(p[0] // 8 * 8, p[1] // 8 * 8, p[2] // 8 * 8)] += 1
                cells[j][i] = seen.most_common(1)[0][0] if seen else edge
        # 배경: 가장자리 칸에서 가장 많은 색과 비슷한 칸을, 가장자리에서 이어진 만큼 지운다
        border = Counter(cells[j][i] for j in range(rows) for i in range(cols) if j in (0, rows - 1) or i in (0, cols - 1))
        bg = border.most_common(1)[0][0]
        clear = [[False] * cols for _ in range(rows)]
        q = deque()
        for j in range(rows):
            for i in range(cols):
                if (j in (0, rows - 1) or i in (0, cols - 1)) and diff(cells[j][i], bg) <= tol:
                    clear[j][i] = True
                    q.append((j, i))
        if tol < 0:
            q.clear()
            clear = [[False] * cols for _ in range(rows)]
        while q:
            j, i = q.popleft()
            for dj, di in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nj, ni = j + dj, i + di
                if 0 <= nj < rows and 0 <= ni < cols and not clear[nj][ni] and diff(cells[nj][ni], bg) <= tol:
                    clear[nj][ni] = True
                    q.append((nj, ni))
        if name == 'pikachu':
            # 꼬리 사이처럼 막힌 곳에 남은 풀색도 지운다
            for j in range(rows):
                for i in range(cols):
                    if diff(cells[j][i], bg) <= 45:
                        clear[j][i] = True
        out = Image.new('RGBA', (cols, rows), (0, 0, 0, 0))
        for j in range(rows):
            for i in range(cols):
                if not clear[j][i]:
                    r, g, b = cells[j][i]
                    out.putpixel((i, j), (min(255, r + 4), min(255, g + 4), min(255, b + 4), 255))
        out.save(OUT / f'{name}.png')
        big = out.resize((cols * 8, rows * 8), Image.NEAREST)
        bgimg = Image.new('RGBA', big.size, (247, 241, 227, 255))
        bgimg.alpha_composite(big)
        bgimg.convert('RGB').save(Path(r'C:\ftmp') / f'sprite_{name}.png')
        print(name, f'{cols}x{rows}', f'cell {cw:.2f}x{ch:.2f}', 'bg', bg, 'dots', sum(not c for r_ in clear for c in r_))


main()
