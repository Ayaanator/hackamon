# Hackamon

A Pokemon-style game for the Hack the North 2026 hacker badge. Scan NFC stickers to
meet wild Pokemon, battle them Game Boy style, and build your team.

Five small Lua files, installed through the
[badge IDE](https://badge.hackthenorth.com/ide/).

## Pokemon

You start with Pikachu. The other three live on NFC stickers.

| Code | Pokemon | HP | Type | Attack | Effect move |
| --- | --- | --- | --- | --- | --- |
| starter | Pikachu | 35 | Electric | Quick Attack | Thunder Wave: 90% accurate; paralysis, no damage |
| `PKM01` | Charmander | 36 | Fire | Scratch | Ember: 40 power, special Fire damage, 10% burn chance |
| `PKM02` | Squirtle | 38 | Water | Tackle | Withdraw: raises physical Defense one stage, up to +6 |
| `PKM03` | Bulbasaur | 38 | Grass/Poison | Tackle | Leech Seed: 90% accurate; drains 1/8 max HP per turn |

Stats are fixed at level 15, neutral nature, zero IVs/EVs. Quick Attack, Scratch,
and Tackle are **Normal-type physical attacks, power 40**, regardless of the
Pokemon using them. Quick Attack has +1 priority; otherwise Speed decides who
acts first, with random ties. A fainted Pokemon cannot act.

Damage uses the level/power/Attack/Defense formula, separate special stats for
Ember, an 85-100% random roll, 1.5x same-type bonus, 2x super effectiveness and
0.5x resistance. In this move set, Ember is the only damaging elemental move:
it is strong against Bulbasaur, resisted by Squirtle/Charmander, and neutral
against Pikachu. Normal attacks have white impact effects. Withdraw acts on its
user without making the opponent lunge or flash as if damaged.

Burn halves physical damage and drains 1/16 max HP each turn; Fire types cannot
burn. Paralysis halves Speed and prevents 25% of moves on either side; Electric
types cannot be paralyzed. Both persist until the encounter ends, including
through switches, and cannot coexist. Withdraw lasts until switching, affects
physical damage only, and raises Defense to 1.5x at +1, 2x at +2, up to 4x at +6.
Leech Seed fails against Grass, persists until the seeded Pokemon switches,
and heals only the HP actually drained. Seed drains resolve before burn damage.

These rules follow the modern mechanics implemented by Pokemon Showdown's
[move data](https://github.com/smogon/pokemon-showdown/blob/master/data/moves.ts),
[status conditions](https://github.com/smogon/pokemon-showdown/blob/master/data/conditions.ts),
[species stats](https://github.com/smogon/pokemon-showdown/blob/master/data/pokedex.ts),
and [damage calculation](https://github.com/smogon/pokemon-showdown/blob/master/sim/battle-actions.ts).
This remains a small badge adaptation: no PP, critical hits, abilities, held items,
weather, or leveling. The existing capture-on-win and team-reset-on-loss rules remain.

## Playing

- The title parades the four Pokemon with moving sprites and coloured LEDs. A starts.
- Home: UP/DOWN selects SCAN, SWITCH LEAD, or EXIT; A confirms.
- Scan an NFC sticker to encounter its Pokemon. UP/DOWN selects a move, A attacks
  or advances dialogue, and B runs. SWITCH is available when you own another Pokemon.
- Attacks retain lunges, impact shakes/blinks and coloured particles. Special moves
  restore the original clockwise six-LED chase and automatic **1,500 ms charge**,
  followed by impact; the full effect lasts 3,200 ms. Press A once, then watch the
  charge; holding A is not required. HP bars change at impact and A cannot skip
  the animation. The home sprite bobs and LEDs breathe.
- Every encounter starts with your team healed. Winning captures a new Pokemon;
  duplicates do not change ownership. Losing resets your team to Pikachu.
- HOME returns to the home menu during play and exits from the title or interrupted
  startup. EXIT saves and leaves. Complete a normal exit before powering off.
- The enemy remains top-right and your lead bottom-left, with HP bars and dialogue.
  Both sides now reuse the same 40x40 artwork facing. The separate title wipe is gone.

## Stickers

Write the code as an NDEF **Text** record onto an NTAG215 sticker with the NFC Tools
phone app. Uppercase, no spaces.

## Install / upgrade

Use all **five files in [dist/](dist/)**. No build tools are needed to install them.

1. Save your current IDE work. In the [badge IDE](https://badge.hackthenorth.com/ide/),
   **Import app** using `dist/hackamon.lua`, then **Replace editor files**. The importer
   creates `manifest.cfg` and `main.lua`. Keep the slug `hackamon` to retain your save.
2. Add `battle.lua`, `fx.lua`, `screens.lua`, and `gen.lua` with **+**, using the
   matching `dist/` contents and these exact filenames. Replace all five together.
3. You may keep or add the launcher image icon. This build budgets for its full 5,304 bytes.
4. **Connect > Push > Reboot**, then open Hackamon once and let preparation finish.
   The upgrade removes the eight old `s*.bin` / `m*.bin` generated sprites and old
   marker, one per tick, and writes four `p*.bin` sprites. It preserves the icon and
   personal saves. Let this finish **before sharing**; merely pushing code leaves old
   generated files on the badge until the game runs.
5. A starts the game. The short preparation/loading stages ignore gameplay buttons.

If Import app is absent, copy the header's `key=value` lines to `manifest.cfg` and
all code after `]==]` to `main.lua`, then add the four modules.

Do not upload repository source, tests or tooling. Unknown extra files left by other
versions are not included in the budget; inspect those individually if the device's
Share size remains larger after a completed first launch.

## Size budget

The complete installed app, **after generation**, includes code, manifest, four
40x40 RGB565 sprites, completion marker, and the optional full-size launcher icon:

| Configuration | Installed bytes | Files |
| --- | ---: | ---: |
| Text files with LF, with icon | 36,821 | 12 |
| Text files with CRLF, with icon | **36,860** | **12** |
| Text files with CRLF, without icon | 31,556 | 11 |

This leaves **12,292 bytes** under the firmware's 49,152-byte sharing limit even
with the image icon and Windows line endings. Our build rejects anything above
**36 KiB**, rather than just checking that it barely fits 48 KiB. The harness also
counts the actual generated files, independently of the build's expected sizes.

The previous build was 51,931 bytes with the icon and LF. Its dependence on removing
the icon was insufficient margin. This version reduces that full bundle by about 30%.

## Runtime memory

File size and runtime RAM are separate budgets. This version also reduces RAM:

- Four shared sprite files instead of eight separate facing files, while retaining
  original 40x40 pixel art. Opaque RGB565 avoids indexed-alpha conversion.
- A smaller effects implementation, four preallocated particles instead of six,
  and a maximum of 17 live app widgets in the host tests. Effect widgets are created
  one per tick before play; an attack does not allocate more widgets.
- Flatter Pokemon/move data, one reusable particle style table, and no per-frame
  style-table creation. Repeated battles and HOME interruptions reuse the UI.
- Initialization functions, sprite renderer/art, screen builder and title functions
  are released when their stage is complete. Screen creation remains one widget
  per tick, separate from sprite writes and module compilation.
- Each append batches eight output rows (640 bytes; the first write is 652 bytes
  including the header). No complete bitmap is assembled in Lua. The
  completion marker is cleared before regeneration, so interrupted writes are retried
  on a fresh launch. Write errors and a missing marker read-back stop preparation
  with an explicit error; HOME exits safely. Recipients reuse transferred sprites
  without rebuilding them.

A repeatable **64-bit host Lua 5.5** comparison against commit `be431b3` gives:

| Phase | Previous live Lua bytes | New live Lua bytes |
| --- | ---: | ---: |
| Title | 33,586 | 31,261 |
| Home after loading gameplay | 56,610 | 50,713 |
| Battle | 56,863 | 51,030 |
| Attack | 58,228 | 51,866 |

These are post-GC live game allocations above the same mock-runtime baseline,
with flash contents held outside Lua. The attack measurement is about **11% lower**.
The corrected mechanics, restored chase and startup fix add 3,540 live Lua bytes during this
attack compared with the immediately preceding `9e22cdc` build (48,326 bytes).
They add no widgets. Deployment whitespace compression saves transfer bytes,
not Lua runtime memory; the source remains readable in the repository root.
They are **not** total badge RAM, transient peaks, native image/widget memory,
ESP32 timing, or a claim that every low-memory badge will run the game.

The manifest's 96 KiB is a ceiling, not a reservation. It does not consume or supply
96 KiB automatically. Actual physical-badge capacity still needs verification with
the sparse `lua=... peak=... free=... widgets=...` console logs and `heap` before launch.
Do not increase the quota or delete unrelated apps as a RAM remedy.

## Why preparation was slow

The previous row-at-a-time renderer made **85 separate flash-write calls** for four
sprites. Small writes limited temporary memory, but repeatedly incurred filesystem
overhead. This renderer batches a few rows into **21 writes**, at most one per tick,
while keeping its write buffer under 1 KB. It caches palette conversions and uses
incremental GC during generation. Fewer writes are verified; real seconds saved
still depend on the physical badge and are not measured by the host tests.

The screen shows the current sprite number and the console reports elapsed time.
Normally preparation happens only when sprites or their completion marker are
missing/invalid, not on every reopen. Startup logs `prepare: ...`
with the file that triggered regeneration. If this repeats, after loading run:

```
cat /littlefs/apps/hackamon/sprites10.ok
```

It should contain `10`. Capture that output and the first preparation/error log;
repeated cache loss needs diagnosis, not an assumption that a two-minute load is
normal. Existing valid version-10 sprites are byte-identical and are reused by
this update. The host suite verifies zero write calls on cached reopen.

One badge running `v0.1.2-392-gd3089c4` stopped at `Sprite missing: 1` even though
console `ls /littlefs/apps/hackamon` showed all four `p*.bin` files at the correct
3,212-byte size. The failed check used `badge.fs.exists()`. Startup and generation
now read the file and check its length instead; neither relies on `exists()`.
Generation reads back one sprite per tick before saving the completion marker.
This temporarily reads up to 3,212 bytes per image, separate from the 652-byte
write buffer; the verification helper is released before the title loads.

Because that failed launch never saved the marker, the first launch after this
fix prepares sprites once more. A subsequent reopen should reuse them. If the
read-based verification still reports `Sprite invalid`, capture that error and
the directory listing: readable files have not yet been verified on the device.
The regression suite covers false existence reports on both cold and cached
launches, truncated images, and silent append failures.

## Menu responsiveness and interrupted transitions

UP/DOWN now moves the existing cursor widget with one alignment call. It does not
rebuild menu text, resize the dialogue box, or toggle other widgets per press. The
same cursor is repositioned explicitly between menu selection and dialogue cues.
The host suite exercises 300 presses in each menu and checks this bound.

The title releases its resources before game loading and no longer calls the
full home-screen update from its animation tick. Failures during title cleanup,
module loading, particle setup or home rendering leave an exit state; HOME exits
instead of retrying partially completed cleanup. HOME can also cancel startup.

These changes reduce avoidable UI work and repair fragile error paths; they do
not establish the cause of a freeze on an untested receiver. Startup now logs
`badge.sys.version()` with memory counters. If a receiving badge freezes, record
whether LEDs/sprites still animate and capture its firmware line and first
`script_app` error. Firmware callback deadlines and available native heap can differ.

## Share and verify

After the first launch completes, use **Share > Send an app > Hackamon > A: offer app**.
The receiver opens **Share > Receive an app** and accepts. On current firmware,
Share reboots around radio use. Personal team saves are not transferred.

Check the size shown by Share after migration, then test launch, SCAN, a battle,
HOME during dialogue, another battle, exit/reopen, and onward sharing on the friend?s
badge. Firmware versions, available native heap and fragmentation still differ.

## Developer checks

- `python tools/build.py`: regenerates `dist/`; budgets for the icon and CRLF by
  default; enforces the 36 KiB target and 16-file limit. `--without-icon` reports the
  optional smaller variant. Token-preserving whitespace removal and line grouping
  reduce transfer bytes, not runtime RAM. Strings and sprite artwork are preserved.
- `python tools/run_harness.py` (requires `pip install lupa`): **88 scenarios** across
  Lua 5.4 / 5.5 and source / deployment files. Checks cold and recipient launches,
  missing assets, migration preserving saves/icon, interrupted writes and recovery,
  invalid saves, unavailable NFC, injected setup/storage errors, missing marker
  read-back, title/loading/home failures, HOME escape, cursor stress tests,
  battle/switch/capture/loss,
  repeated encounters, bounded widget creation, pixel format and actual installed size.
  Also checks all six chase positions, one LED latch per frame, the charge delay,
  HP/impact synchronization and protection against skipping a special animation.
- `python tools/check_battle.py`: deterministic damage, accuracy, status, priority,
  switching, type immunity and stat tests on both Lua versions and source/dist;
  checks whitespace compaction against numeric, quoted and operator edge cases.
- `python tools/profile_memory.py --compare be431b3`: repeats the live Lua comparison
  above using the baseline commit's deployment files and the current `dist/` files.

Host tests do not replace physical-badge memory, display, callback-time, USB or
Bluetooth tests. Reference: [badge API/runtime/Share guide](https://badge.hackthenorth.com/ide/README.md).
