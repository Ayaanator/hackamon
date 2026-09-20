"""Build IDE files and check the complete post-launch Share bundle.

python tools/build.py [--without-icon]
Always budget for the optional 5,304-byte icon and CRLF by default.
"""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LUA = ['hackamon.lua', 'battle.lua', 'fx.lua', 'gen.lua', 'screens.lua']


def build(with_icon=True):
    dist = ROOT / 'dist'
    dist.mkdir(exist_ok=True)
    sizes = {}
    for name in LUA:
        out, in_header = [], False
        for line in (ROOT / name).read_text(encoding='utf-8').splitlines():
            s = line.strip()
            if s == '--[==[badge-app':
                in_header = True
            if in_header:
                out.append(line)
                if s == ']==]':
                    in_header = False
            elif s and not s.startswith('--'):
                out.append(s)
        text = '\n'.join(out) + '\n'
        (dist / name).write_text(text, encoding='utf-8', newline='\n')
        sizes[name] = len(text.encode('utf-8'))
    bundle = (dist / 'hackamon.lua').read_text(encoding='utf-8')
    header, body = bundle.split(']==]\n', 1)
    manifest = header.split('\n', 1)[1]
    del sizes['hackamon.lua']
    sizes['manifest.cfg'] = len(manifest.encode('utf-8'))
    sizes['main.lua'] = len(body.encode('utf-8'))
    assert sizes['main.lua'] <= 65536
    sizes['sprites10.ok'] = 2
    for i in range(1, 5):
        sizes[f'p{i}.bin'] = 12 + 40 * 40 * 2
    if with_icon:
        sizes['icon.bin'] = 5304
    for name, size in sorted(sizes.items()):
        print(f'{size:6d}  {name}')
    total = sum(sizes.values())
    crlf_extra = manifest.count('\n') + body.count('\n') + sum((dist / n).read_text(encoding='utf-8').count('\n') for n in LUA if n != 'hackamon.lua')
    worst = total + crlf_extra
    print(f'{total:6d}  total in {len(sizes)} files (Share cap 49152 bytes, 16 files)')
    print(f'With CRLF line endings: {worst} bytes; margin {49152 - worst} bytes')
    if worst > 36 * 1024 or len(sizes) > 16:
        raise SystemExit('OVER OUR 36 KiB BUDGET (including icon and CRLF)')
    print(f'cold install {total - 4 * 3212 - 2} bytes')
    return sizes


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--without-icon', action='store_true')
    parser.add_argument('--with-icon', action='store_true', help='Default; retained for compatibility')
    build(not parser.parse_args().without_icon)
