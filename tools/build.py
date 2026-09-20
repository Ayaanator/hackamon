"""Build IDE files and check the complete post-launch Share bundle.

python tools/build.py [--without-icon]
Always budget for the optional 5,304-byte icon and CRLF by default.
"""
import argparse
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LUA = ['hackamon.lua', 'battle.lua', 'fx.lua', 'gen.lua', 'screens.lua']

# Preserve tokens and quoted art/dialogue. No identifier
# renaming or bytecode: the deploy files remain portable across badge Lua versions.
TOKEN = re.compile(r'''"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|--[^\n]*|0[xX][\da-fA-F]+(?:\.[\da-fA-F]*)?(?:[pP][+-]?\d+)?|(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?|[a-zA-Z_]\w*|\.\.\.|\.\.|//|<<|>>|==|~=|<=|>=|::|[^\s]''')


def compact(line):
    if re.search(r'\[(=*)\[', line):
        raise ValueError('Long Lua strings/comments need explicit build support')
    tokens = TOKEN.findall(line)
    out, previous = [], ''
    for token in tokens:
        if token.startswith('--'):
            break
        if previous and ((re.match(r'\w', previous[-1]) and re.match(r'\w', token[0]))
                         or TOKEN.findall(previous + token) != [previous, token]):
            out.append(' ')
        out.append(token)
        previous = token
    return ''.join(out)


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
                out.append(compact(s))
        header_end = out.index(']==]') + 1 if ']==]' in out else 0
        header, body = out[:header_end], out[header_end:]
        # Group lines to reduce Windows CRLF overhead; source files stay readable.
        text = '\n'.join(header + [compact(' '.join(body[i:i+16])) for i in range(0, len(body), 16)]) + '\n'
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
