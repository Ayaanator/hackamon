"""Seeded balance samples through the actual Lua battle implementation."""
from pathlib import Path
from lupa import lua54, lua55

ROOT = Path(__file__).resolve().parent.parent
SAMPLES = 2000
source = (ROOT / 'tools/mewtwo_balance.lua').read_bytes()

for engine in (lua54, lua55):
    for directory in (ROOT, ROOT / 'dist'):
        rt = engine.LuaRuntime(encoding=None, unpack_returned_tuples=True)
        battle = rt.eval(b'function(s,d) return assert(load(s))(d) end')(source, directory.as_posix().encode())
        for smart, solo in [(False, None), (True, None), *[(True, i) for i in range(1, 5)]]:
            results = [battle(seed, smart, solo) for seed in range(1, SAMPLES+1)]
            wins = [r for r in results if r[0]]
            rate = len(wins) / SAMPLES
            if solo:
                assert rate < 0.01, 'a single starter reliably defeats Mewtwo'
            elif smart:
                assert 0.75 <= rate <= 0.99, 'full-team tactics are impossible or trivial'
                assert 1 <= sum(r[2] for r in wins) / len(wins) <= 1.8, 'too many teammates survive'
            else:
                assert rate < 0.10, 'basic-attack spam reliably wins'
            label = f'solo {solo}' if solo else ('team tactics' if smart else 'basic attacks')
            print(f'{engine.__name__} {directory.name} {label}: {len(wins)}/{SAMPLES} wins; '
                  f'{sum(r[1] for r in results)/SAMPLES:.1f} turns; '
                  f'{sum(r[2] for r in wins)/max(1,len(wins)):.1f} survivors on wins', flush=True)
