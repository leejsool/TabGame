# 도트 캐논 기본 그림 색 합치기 도구.
#
#   tool/도트색합치기.bat 더블클릭 (또는 python tool/dot_stage_editor.py --open) → 브라우저에 도구가 열린다
#
# 그림을 보며 애매한 색끼리 합치면 tool/dot_stage_art/stages.json 에 "merge": [["앞 색", "뒤 색"], ...]로 적고,
# "그림 다시 만들기"를 누르면 고친 그림 하나만 `flutter test tool/make_dot_stages.dart`(DOT_ONLY=번호)로 다시 만들어 lib/games/dotcannon/core/dot_stage_data.dart를 새로 만든다.
# (풀리는지 검사하고 대포 줄 수·탄 수도 다시 정하므로 게임 코드는 손대지 않아도 된다)
import json
import os
import re
import subprocess
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGES_JSON = os.path.join(ROOT, 'tool', 'dot_stage_art', 'stages.json')
STAGE_DART = os.path.join(ROOT, 'lib', 'games', 'dotcannon', 'core', 'dot_stage_data.dart')
LEVELS_DART = os.path.join(ROOT, 'lib', 'games', 'dotcannon', 'core', 'dot_levels.dart')
PAGE = os.path.join(ROOT, 'tool', 'dot_stage_editor.html')
PORT = int(os.environ.get('PORT', '8765'))

build = {'running': False, 'ok': None, 'log': ''}


def read_specs():
    with open(STAGES_JSON, encoding='utf-8') as f:
        return json.load(f)


def write_specs(specs):
    with open(STAGES_JSON, 'w', encoding='utf-8', newline='\n') as f:
        json.dump(specs, f, ensure_ascii=False, indent=2)
        f.write('\n')


def read_stages():
    """dot_stage_data.dart에서 지금 그림들을 읽는다."""
    with open(STAGE_DART, encoding='utf-8') as f:
        src = f.read()
    specs = {s['name']: s for s in read_specs()}
    out = []
    for m in re.finditer(r"DotStageData\((.*?)\n  \),", src, re.S):
        body = m.group(1)
        name = re.search(r"name: '((?:[^'\\]|\\.)*)'", body).group(1).replace("\\'", "'")
        colors = [int(c, 16) & 0xFFFFFF for c in re.findall(r'0x([0-9A-Fa-f]{8})', re.search(r'colors: \[(.*?)\]', body).group(1))]
        out.append({
            'name': name,
            'width': int(re.search(r'width: (\d+)', body).group(1)),
            'height': int(re.search(r'height: (\d+)', body).group(1)),
            'colors': ['%06X' % c for c in colors],
            'runs': re.search(r"runs: '([^']*)'", body).group(1),
            'merge': specs.get(name, {}).get('merge', []),
            'paint': len(specs.get(name, {}).get('paint', {})),
            'theme': specs.get(name, {}).get('theme', 'art'),
        })
    return out


def read_handmade():
    """게임에서 사진 그림보다 앞에 오는 손으로 그린 단계들의 이름 (dot_levels.dart의 _handmade)."""
    with open(LEVELS_DART, encoding='utf-8') as f:
        src = f.read()
    m = re.search(r'final List<DotLevel> _handmade = \[(.*?)\n\];', src, re.S)
    return re.findall(r"name: '([^']*)'", m.group(1)) if m else []


def apply_ops(spec, ops):
    """편집 도구에서 한 일을 차례대로 stages.json 항목에 적는다.
    합치기는 "merge"에 붙이고, 이미 칠해 둔 칸 중 그 색인 칸도 새 색으로 바꾼다 (만들 때 합치기가 칠하기보다 먼저라서)."""
    merge = spec.get('merge', [])
    paint = spec.get('paint', {})
    for op in ops:
        if op.get('type') == 'merge':
            a, b = str(op['from']).upper(), str(op['to']).upper()
            merge.append([a, b])
            for k, v in paint.items():
                if v == a:
                    paint[k] = b
        elif op.get('type') == 'paint':
            for k, v in op['cells'].items():
                paint[k] = '.' if v == '.' else str(v).upper()
    if merge:
        spec['merge'] = merge
    if paint:
        spec['paint'] = dict(sorted(paint.items(), key=lambda kv: tuple(int(n) for n in kv[0].split(',')[::-1])))


def ascii_temp():
    for d in (r'C:\ftmp', r'F:\MyApp\tools\tmp'):
        if os.path.isdir(d):
            return d
    d = os.path.join(os.path.splitdrive(ROOT)[0] + os.sep, 'ftmp')
    os.makedirs(d, exist_ok=True)
    return d


def run_build(only=None):
    """[only]: stages.json 안 번호. 주면 그 그림 하나만 다시 만든다 (나머지 그림은 그대로)."""
    build.update(running=True, ok=None, log='그림을 다시 만드는 중...\n')
    env = dict(os.environ)
    env.pop('DOT_ONLY', None)
    if only is not None:
        env['DOT_ONLY'] = str(only)
    env['TEMP'] = env['TMP'] = ascii_temp()  # (사용자 폴더 이름이 한글이면 flutter test가 멈춘다)
    if os.path.isdir(r'C:\pubcache') and 'PUB_CACHE' not in env:
        env['PUB_CACHE'] = r'C:\pubcache'
    try:
        p = subprocess.Popen('flutter test tool/make_dot_stages.dart', cwd=ROOT, env=env, shell=True,
                             stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        for line in p.stdout:
            build['log'] += line.decode('utf-8', 'replace')
        build['ok'] = p.wait() == 0
    except Exception as e:  # noqa: BLE001
        build['log'] += f'\n실행하지 못했어요: {e}\n'
        build['ok'] = False
    build['running'] = False


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def send(self, code, body, kind='application/json; charset=utf-8'):
        data = body if isinstance(body, bytes) else json.dumps(body, ensure_ascii=False).encode('utf-8')
        self.send_response(code)
        self.send_header('Content-Type', kind)
        self.send_header('Cache-Control', 'no-store')
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path in ('/', '/index.html'):
            with open(PAGE, 'rb') as f:
                self.send(200, f.read(), 'text/html; charset=utf-8')
        elif self.path == '/api/stages':
            self.send(200, {'handmade': read_handmade(), 'stages': read_stages()})
        elif self.path == '/api/build':
            self.send(200, build)
        else:
            self.send(404, {'error': 'not found'})

    def do_POST(self):
        n = int(self.headers.get('Content-Length', 0))
        req = json.loads(self.rfile.read(n) or b'{}')
        if self.path == '/api/build':
            if not build['running']:
                names = [s['name'] for s in read_specs()]
                only = names.index(req['name']) if req.get('name') in names else None
                threading.Thread(target=run_build, args=(only,), daemon=True).start()
            self.send(200, {'started': True})
            return
        if self.path not in ('/api/save', '/api/reset', '/api/theme'):
            self.send(404, {'error': 'not found'})
            return
        specs = read_specs()
        spec = next((s for s in specs if s['name'] == req.get('name')), None)
        if spec is None:
            self.send(400, {'error': '그 이름의 그림이 stages.json에 없어요'})
            return
        if self.path == '/api/theme':
            if req.get('theme') not in ('anime', 'movie', 'art'):
                self.send(400, {'error': '모르는 묶음이에요'})
                return
            spec['theme'] = req['theme']
        elif self.path == '/api/save':
            apply_ops(spec, req.get('ops', []))
        else:
            spec.pop('merge', None)
            spec.pop('paint', None)
        write_specs(specs)
        self.send(200, {'ok': True})


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    url = f'http://localhost:{PORT}'
    ThreadingHTTPServer.allow_reuse_address = False  # (윈도우에서는 이게 켜져 있으면 같은 자리에 두 번 켜진다)
    try:
        server = ThreadingHTTPServer(('127.0.0.1', PORT), Handler)
    except OSError:
        # 이미 켜져 있으면 창만 다시 연다
        if '--open' in sys.argv:
            webbrowser.open(url)
        sys.exit(0)
    print(f'도트 캐논 색 합치기 도구: {url}')
    print('다 쓰면 이 검은 창을 닫으세요.')
    if '--open' in sys.argv:
        threading.Timer(0.5, webbrowser.open, [url]).start()
    server.serve_forever()
