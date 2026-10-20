"""이미 도트 아트인 그림(확대된 스프라이트)을 원래 도트 크기(1칸 = 1점)의 PNG로 되돌린다.

도트 하나가 여러 점으로 커져 있고 (가장자리가 번지거나 칸이 어긋나 있을 수 있다), 이걸 `flutter test tool/make_dot_stages.dart`의
"exact" 방식이 칸 그대로 읽는다. 배경은 가장자리에서 이어진 같은 색을 투명하게 만든다.

사용: python tool/prepare_dot_sprites.py [원본 폴더] [만들 이름]   (아래 SPRITES를 고쳐서 새 그림을 넣는다. 이름을 주면 그 그림만)
"""
import math
import sys
from collections import Counter, deque
from pathlib import Path

from PIL import Image

SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else Path('tool/dot_stage_art/src')
OUT = Path('tool/dot_stage_art')
ONLY = sys.argv[2] if len(sys.argv) > 2 else None

# 파일, 만들 이름, 도트 한 칸의 대략적인 크기(점), 배경과 같다고 볼 색 차이, 지울 상자들 [왼쪽, 위, 오른쪽, 아래] (원본 점 좌표)
SPRITES = [
    ('mario.png', 'mario', 29.2, 90, []),
    ('mario_face.png', 'mario_face', 8.0, 90, []),
    # bowser: 검은 배경도 그림의 일부로 둔다 (-1: 배경을 지우지 않음)
    ('bowser.png', 'bowser', 3.0, -1, []),
    ('dragon.png', 'dragon', 3.0, 90, []),
    ('charmander.png', 'charmander', 25.5, 90, [[0, 0, 70, 50], [0, 440, 70, 511], [480, 470, 555, 511]]),
    ('pikachu.png', 'pikachu', 10.7, 70, [[0, 490, 40, 540]]),
    ('bear_hat.png', 'bear_hat', 9.4, 70, []),
    ('blue_crown.png', 'blue_crown', 6.3, 95, []),
    ('bunny.png', 'bunny', 6.6, 70, []),
    # 구슬(퍼러 비즈) 그림: 구슬 한 알 = 한 칸
    ('chiikawa_siren.webp', 'chiikawa_siren', 16.0, 70, []),
    # 비즈 도안(번호가 적힌 모눈): 칸 위치는 GRIDS에 적는다
    ('frame_dog.png', 'frame_dog', 40.0, 30, []),
    ('shinchan_friends.png', 'shinchan_friends', 40.0, 30, []),
    ('duffy.png', 'duffy', 9.0, 30, []),
    ('hello_kitty.png', 'hello_kitty', 40.0, 30, []),
    ('delivery_dog.png', 'delivery_dog', 40.0, 30, []),
    ('pancake_cat.png', 'pancake_cat', 40.0, 30, []),
    ('dino_kitty.png', 'dino_kitty', 40.0, 30, []),
    ('nick.png', 'nick', 40.0, 30, []),
    ('patrick.png', 'patrick', 40.0, 30, []),
    ('witch_kitty.png', 'witch_kitty', 40.0, 30, []),
    ('shiba_hero.png', 'shiba_hero', 40.0, 30, []),
    ('little_prince.png', 'little_prince', 40.0, 30, []),
    ('judy.png', 'judy', 40.0, 30, []),
    ('stacked_cats.png', 'stacked_cats', 40.0, 30, []),
]

# 그림마다 더 다듬는 방법 (없으면 아무것도 안 한다)
#   erase: 원본 점 좌표로 적은 상자 [왼쪽, 위, 오른쪽, 아래] 안의 칸을 지운다 (손·바닥 같은 배경 조각)
#   halo_white: 지운 배경에 이어진 흰 테두리(스티커 둘레)도 지운다
#   min_island: 이 칸 수보다 작은 외딴 조각은 지운다 (사진 속 먼지·무늬)
OPTS = {
    'bear_hat': {'erase': [[345, 0, 386, 140], [0, 85, 18, 165], [0, 250, 26, 372]], 'min_island': 25},
    'blue_crown': {'min_island': 40},
    'bunny': {'halo_white': True, 'min_island': 6},
}

# 칸 크기를 찾는 범위(추정값 ±비율). 기본은 10%.
SPREADS = {'pikachu': 0.04, 'chiikawa_siren': 0.05, 'bear_hat': 0.2, 'blue_crown': 0.2, 'bunny': 0.2}


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


# 반듯한 모눈 도안: (첫 칸 왼쪽, 위, 칸 너비, 칸 높이, 가로 칸 수, 세로 칸 수) 점 좌표.
# 칸 안쪽(테두리 줄 빼고)에서 가장 많은 색을 읽는다 (칸 가운데 번호 글씨는 적어서 묻힌다).
# 'bitbead'라고 적으면 bitbead.app 도안 모양(첫 칸 (85, 57), 칸 40점)으로 보고 칸 수는 그림에서 잰다.
# 칸 가운데에 번호(색 이름)가 적힌 칸만 구슬로 보고, 번호가 없는 칸은 빈 칸(배경)으로 둔다 (흰 구슬과 빈 칸을 가른다).
GRIDS = {
    'frame_dog': 'bitbead',
    'shinchan_friends': 'bitbead',
    'duffy': (2, 1, 352 / 38, 303 / 32, 38, 32),
    'hello_kitty': 'bitbead',
    'delivery_dog': 'bitbead',
    'pancake_cat': 'bitbead',
    'dino_kitty': 'bitbead',
    'nick': 'bitbead',
    'patrick': 'bitbead',
    'witch_kitty': 'bitbead',
    'shiba_hero': 'bitbead',
    'little_prince': 'bitbead',
    'judy': 'bitbead',
    'stacked_cats': 'bitbead',
}
# 이 이름들은 번호가 없는 칸을 빈 칸으로 보지 않는다 (번호가 흐릿한 작은 도안)
GRID_NO_LABEL_CHECK = {'duffy'}


def bitbead_grid(im):
    """bitbead 도안의 칸 자리: 가로 칸 수는 너비에서, 세로 칸 수는 모눈 아래 굵은 검은 줄까지에서 잰다."""
    w, h = im.size
    g = im.convert('L').load()
    bottom = next(y for y in range(57, h) if sum(1 for x in range(0, w, 4) if g[x, y] < 100) > (w / 4) * 0.9)
    return (85, 57, 40, 40, round((w - 85) / 40), round((bottom - 57) / 40))

# 사진으로 찍어 살짝 휘어진 구슬 그림: (가로 칸 크기, 세로 칸 크기) 점. 칸 위치를 한 줄로 정하지 않고 조각마다 따로 찾는다.
WARPED = {'chiikawa_siren': (16.6, 14.9)}


def warp_cells(im, p, q, alpha, step=40, half=64):
    """휘어진 구슬 그림에서 구슬마다 색을 읽는다.

    그림을 step 점 간격의 작은 조각(가로세로 2*half)으로 나눠, 조각마다 밝기의 p(가로)·q(세로) 주기 성분으로
    구슬 가운데가 어디서 시작하는지(어긋남)를 잰다. 이웃 조각끼리 어긋남이 이어지도록 맞춘 뒤(구슬 한 칸씩 건너뛰지 않게)
    점마다 '몇 번째 구슬의 어디쯤'인지 계산하고, 구슬 가운데 근처 점들의 가장 흔한 색을 그 구슬 색으로 한다."""
    w, h = im.size
    data = im.load()
    alpha = alpha.load()  # 가운데가 대부분 투명한 구슬은 None(배경)
    lum = [[sum(data[x, y]) for x in range(w)] for y in range(h)]
    # 색이 바뀌는 곳(가로·세로 이웃 점의 밝기 차)은 어느 색 구슬이든 늘 구슬 사이 틈이다.
    # 그래서 가로 차이는 세로로 더하고(열마다 → 가로 칸 위치), 세로 차이는 가로로 더해(행마다 → 세로 칸 위치) 주기를 잰다.
    ex = [[abs(lum[y][x + 1] - lum[y][x]) if x + 1 < w else 0 for x in range(w)] for y in range(h)]
    ey = [[abs(lum[y + 1][x] - lum[y][x]) if y + 1 < h else 0 for x in range(w)] for y in range(h)]
    # 누적합: 가로 차이를 세로로 더한 것(열마다), 세로 차이를 가로로 더한 것(행마다)
    colsum = [[0] * (w) for _ in range(h + 1)]
    for y in range(h):
        a, b = colsum[y], colsum[y + 1]
        row = ex[y]
        for x in range(w):
            b[x] = a[x] + row[x]
    rowsum = [[0] * (w + 1) for _ in range(h)]
    for y in range(h):
        acc, row, out = 0, ey[y], rowsum[y]
        for x in range(w):
            acc += row[x]
            out[x + 1] = acc
    hann = [0.5 - 0.5 * math.cos(2 * math.pi * k / (2 * half)) for k in range(2 * half)]

    def shift(v, period):
        m = sum(v) / len(v)
        re = im_ = 0.0
        for k, val in enumerate(v):
            d = (val - m) * hann[k]
            re += d * math.cos(2 * math.pi * k / period)
            im_ += d * math.sin(2 * math.pi * k / period)
        return (math.atan2(im_, re) / (2 * math.pi) * period) % period, math.hypot(re, im_)

    gx = list(range(half, w - half, step))
    gy = list(range(half, h - half, step))
    fields = []
    for period, axis in ((p, 0), (q, 1)):
        val = [[0.0] * len(gx) for _ in gy]
        mag = [[0.0] * len(gx) for _ in gy]
        for b, Y in enumerate(gy):
            for a, X in enumerate(gx):
                if axis == 0:
                    v = [colsum[Y + half][x] - colsum[Y - half][x] for x in range(X - half, X + half)]
                    o = X - half
                else:
                    v = [rowsum[y][X + half] - rowsum[y][X - half] for y in range(Y - half, Y + half)]
                    o = Y - half
                sh, mg = shift(v, period)
                val[b][a] = o + sh + 0.5 + period / 2  # 틈(차이가 큰 곳)에서 반 칸 옮긴 곳 = 구슬 가운데 (점 좌표)
                mag[b][a] = mg
        # 믿을 만한 조각부터 이웃으로 퍼지며 한 칸씩 건너뛰지 않게 맞춘다
        flat = sorted((mag[b][a] for b in range(len(gy)) for a in range(len(gx))), reverse=True)
        strong = flat[len(flat) // 3]
        done = [[False] * len(gx) for _ in gy]
        start = max(((b, a) for b in range(len(gy)) for a in range(len(gx))), key=lambda t: mag[t[0]][t[1]])
        done[start[0]][start[1]] = True
        dq = deque([start])
        while dq:
            b, a = dq.popleft()
            for db, da in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nb, na = b + db, a + da
                if 0 <= nb < len(gy) and 0 <= na < len(gx) and not done[nb][na] and mag[nb][na] >= strong:
                    k = round((val[b][a] - val[nb][na]) / period)
                    val[nb][na] += k * period
                    done[nb][na] = True
                    dq.append((nb, na))
        # 약한 조각(배경 등)은 맞춘 이웃들의 평균으로 채운다
        changed = True
        while changed:
            changed = False
            for b in range(len(gy)):
                for a in range(len(gx)):
                    if done[b][a]:
                        continue
                    nbrs = [val[b + db][a + da] for db, da in ((1, 0), (-1, 0), (0, 1), (0, -1))
                            if 0 <= b + db < len(gy) and 0 <= a + da < len(gx) and done[b + db][a + da]]
                    if nbrs:
                        m = sum(nbrs) / len(nbrs)
                        val[b][a] += round((m - val[b][a]) / period) * period
                        done[b][a] = True
                        changed = True
        fields.append(val)

    def interp(val, x, y):
        fx = min(max((x - gx[0]) / step, 0), len(gx) - 1.001)
        fy = min(max((y - gy[0]) / step, 0), len(gy) - 1.001)
        a, b = int(fx), int(fy)
        tx, ty = fx - a, fy - b
        return (val[b][a] * (1 - tx) * (1 - ty) + val[b][a + 1] * tx * (1 - ty)
                + val[b + 1][a] * (1 - tx) * ty + val[b + 1][a + 1] * tx * ty)

    seen = {}
    marks = []
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            u = (x - interp(fields[0], x, y)) / p
            v = (y - interp(fields[1], x, y)) / q
            i, j = round(u), round(v)
            if abs(u - i) > 0.22 or abs(v - j) > 0.22:
                continue
            marks.append((x, y))
            c = data[x, y]
            key = None if alpha[x, y] < 128 else (c[0] // 8 * 8, c[1] // 8 * 8, c[2] // 8 * 8)
            seen.setdefault((j, i), Counter())[key] += 1
    # 확인용: 구슬 가운데라고 본 곳을 원본 위에 빨갛게 찍은 그림
    dbg = im.copy()
    for x, y in marks:
        dbg.putpixel((x, y), (255, 0, 0))
    dbg.save('C:/ftmp/warp_check.png')
    # 그림 가장자리에 잘려 반쯤만 보이는 구슬은 뺀다 (보통 구슬보다 읽은 점이 훨씬 적다)
    sizes = sorted(sum(c.values()) for c in seen.values())
    full = sizes[len(sizes) // 2]
    seen = {k: c for k, c in seen.items() if sum(c.values()) >= full * 0.6}
    i0 = min(i for _, i in seen)
    i1 = max(i for _, i in seen)
    j0 = min(j for j, _ in seen)
    j1 = max(j for j, _ in seen)
    return [[seen[(j, i)].most_common(1)[0][0] if (j, i) in seen else None for i in range(i0, i1 + 1)] for j in range(j0, j1 + 1)]


def main():
    for fname, name, guess, tol, masks in SPRITES:
        if ONLY and name != ONLY:
            continue
        im = Image.open(SRC / fname).convert('RGBA')
        alpha = im.getchannel('A')
        # 투명한 배경은 흰색으로 (그냥 RGB로 바꾸면 검게 된다)
        white = Image.new('RGBA', im.size, (255, 255, 255, 255))
        white.alpha_composite(im)
        im = white.convert('RGB')
        # 지울 상자는 가장자리 색으로 덮는다 (사진 검색 화면의 아이콘·글자)
        edge = Counter(im.getpixel((x, 0)) for x in range(im.width)).most_common(1)[0][0]
        for l, t, r, b in masks:
            for y in range(t, min(b, im.height)):
                for x in range(l, min(r, im.width)):
                    im.putpixel((x, y), edge)
        warp = WARPED.get(name)
        grid = GRIDS.get(name)
        if grid:
            ox, oy, cw, ch, cols, rows = bitbead_grid(im) if grid == 'bitbead' else grid
            px = im.load()
            check_label = name not in GRID_NO_LABEL_CHECK
            cells = []
            for j in range(rows):
                row_ = []
                for i in range(cols):
                    seen = Counter()
                    for y in range(int(oy + (j + 0.2) * ch), int(oy + (j + 0.8) * ch) + 1):
                        for x in range(int(ox + (i + 0.2) * cw), int(ox + (i + 0.8) * cw) + 1):
                            p_ = px[x, y]
                            seen[(p_[0] // 8 * 8, p_[1] // 8 * 8, p_[2] // 8 * 8)] += 1
                    fill = seen.most_common(1)[0][0]
                    if check_label:
                        # 가운데에 바탕과 확 다른 점(번호 글씨)이 있어야 구슬이다
                        ink = 0
                        for y in range(int(oy + (j + 0.3) * ch), int(oy + (j + 0.7) * ch)):
                            for x in range(int(ox + (i + 0.25) * cw), int(ox + (i + 0.75) * cw)):
                                if diff(px[x, y], fill) > 200:
                                    ink += 1
                        if ink < 4:
                            fill = None
                    row_.append(fill)
                cells.append(row_)
        elif warp:
            cw, ch = warp
            ox = oy = 0.0
            cells = warp_cells(im, cw, ch, alpha)
            rows, cols = len(cells), len(cells[0])
        else:
            spread = SPREADS.get(name, 0.1)
            cw, ox, w = fit_grid(im, guess, 0, spread)
            ch, oy, h = fit_grid(im, guess, 1, spread)
            cols = round((w - ox) / cw)
            rows = round((h - oy) / ch)
            px = im.load()
            cells = [[None] * cols for _ in range(rows)]
        for j in range(rows if not (warp or grid) else 0):
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
        by_none = warp or (grid and name not in GRID_NO_LABEL_CHECK)  # 빈 칸을 이미 None으로 가려 둠
        if by_none:
            clear = [[cells[j][i] is None for i in range(cols)] for j in range(rows)]
            cells = [[c or (0, 0, 0) for c in r_] for r_ in cells]
        else:
            clear = [[False] * cols for _ in range(rows)]
        q = deque()
        for j in range(rows):
            for i in range(cols):
                if not by_none and (j in (0, rows - 1) or i in (0, cols - 1)) and diff(cells[j][i], bg) <= tol:
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
        opts = OPTS.get(name, {})
        for l, t, r, b in opts.get('erase', []):
            for j in range(rows):
                for i in range(cols):
                    cx, cy = ox + (i + 0.5) * cw, oy + (j + 0.5) * ch
                    if l <= cx < r and t <= cy < b:
                        clear[j][i] = True
        if opts.get('halo_white'):
            q = deque((j, i) for j in range(rows) for i in range(cols) if clear[j][i])
            while q:
                j, i = q.popleft()
                for dj, di in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nj, ni = j + dj, i + di
                    if 0 <= nj < rows and 0 <= ni < cols and not clear[nj][ni] and diff(cells[nj][ni], (248, 248, 248)) <= 60:
                        clear[nj][ni] = True
                        q.append((nj, ni))
        if opts.get('min_island'):
            seen = [[False] * cols for _ in range(rows)]
            for j0 in range(rows):
                for i0 in range(cols):
                    if clear[j0][i0] or seen[j0][i0]:
                        continue
                    comp, stack = [], [(j0, i0)]
                    seen[j0][i0] = True
                    while stack:
                        j, i = stack.pop()
                        comp.append((j, i))
                        for dj, di in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                            nj, ni = j + dj, i + di
                            if 0 <= nj < rows and 0 <= ni < cols and not clear[nj][ni] and not seen[nj][ni]:
                                seen[nj][ni] = True
                                stack.append((nj, ni))
                    if len(comp) < opts['min_island']:
                        for j, i in comp:
                            clear[j][i] = True
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
        if warp or grid:
            out = out.crop(out.getbbox())  # 빈 둘레 줄은 잘라 낸다
            cols, rows = out.size
        out.save(OUT / f'{name}.png')
        big = out.resize((cols * 8, rows * 8), Image.NEAREST)
        bgimg = Image.new('RGBA', big.size, (247, 241, 227, 255))
        bgimg.alpha_composite(big)
        bgimg.convert('RGB').save(Path(r'C:\ftmp') / f'sprite_{name}.png')
        print(name, f'{cols}x{rows}', f'cell {cw:.2f}x{ch:.2f}', 'bg', bg, 'dots', sum(not c for r_ in clear for c in r_))


main()
