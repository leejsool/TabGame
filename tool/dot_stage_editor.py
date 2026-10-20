# 도트 캐논 기본 그림 색 합치기 도구.
#
#   python tool/dot_stage_editor.py      → 브라우저에서 http://localhost:8765 을 연다
#
# 그림을 보며 애매한 색끼리 합치면 tool/dot_stage_art/stages.json 에 "merge": [["앞 색", "뒤 색"], ...]로 적고,
# "그림 다시 만들기"를 누르면 `flutter test tool/make_dot_stages.dart`를 돌려 lib/games/dotcannon/core/dot_stage_data.dart를 새로 만든다.
# (풀리는지 검사하고 대포 줄 수·탄 수도 다시 정하므로 게임 코드는 손대지 않아도 된다)
import json
import os
import re
import subprocess
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
STAGES_JSON = os.path.join(ROOT, 'tool', 'dot_stage_art', 'stages.json')
STAGE_DART = os.path.join(ROOT, 'lib', 'games', 'dotcannon', 'core', 'dot_stage_data.dart')
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
    merges = {s['name']: s.get('merge', []) for s in read_specs()}
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
            'merge': merges.get(name, []),
        })
    return out


def ascii_temp():
    for d in (r'C:\ftmp', r'F:\MyApp\tools\tmp'):
        if os.path.isdir(d):
            return d
    d = os.path.join(os.path.splitdrive(ROOT)[0] + os.sep, 'ftmp')
    os.makedirs(d, exist_ok=True)
    return d


def run_build():
    build.update(running=True, ok=None, log='그림을 다시 만드는 중...\n')
    env = dict(os.environ)
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
            self.send(200, read_stages())
        elif self.path == '/api/build':
            self.send(200, build)
        else:
            self.send(404, {'error': 'not found'})

    def do_POST(self):
        n = int(self.headers.get('Content-Length', 0))
        req = json.loads(self.rfile.read(n) or b'{}')
        if self.path == '/api/build':
            if not build['running']:
                threading.Thread(target=run_build, daemon=True).start()
            self.send(200, {'started': True})
            return
        if self.path not in ('/api/save', '/api/reset'):
            self.send(404, {'error': 'not found'})
            return
        specs = read_specs()
        spec = next((s for s in specs if s['name'] == req.get('name')), None)
        if spec is None:
            self.send(400, {'error': '그 이름의 그림이 stages.json에 없어요'})
            return
        if self.path == '/api/save':
            pairs = [[str(a).upper(), str(b).upper()] for a, b in req.get('merges', [])]
            spec['merge'] = spec.get('merge', []) + pairs
        else:
            spec.pop('merge', None)
        write_specs(specs)
        self.send(200, {'merge': spec.get('merge', [])})


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    print(f'도트 캐논 색 합치기 도구: http://localhost:{PORT}  (끝내려면 Ctrl+C)')
    ThreadingHTTPServer(('127.0.0.1', PORT), Handler).serve_forever()
