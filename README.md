# Hackamon

A Pokemon-style game for the Hack the North 2026 hacker badge. Scan NFC stickers to
meet wild Pokemon, battle them Game Boy style, and build your team.

Five small Lua files, installed through the
[badge IDE](https://badge.hackthenorth.com/ide/).

## Pokemon

You start with Pikachu. The other three live on NFC stickers.

| Code | Pokemon | HP | Type | Attack | Effect move |
| --- | --- | --- | --- | --- | --- |
| starter | Pikachu | 35 | Electric | Quick Attack | Thunder Wave: paralyzes, enemy may lose its turn for 3 turns |
| `PKM01` | Charmander | 39 | Fire | Scratch | Ember: damage plus a burn that hurts each turn |
| `PKM02` | Squirtle | 44 | Water | Tackle | Withdraw: halves incoming damage for two turns |
| `PKM03` | Bulbasaur | 45 | Grass | Tackle | Leech Seed: drains the enemy and heals you each turn |

Fire beats Grass, Grass beats Water, Water beats Fire, Electric beats Water, Grass resists
Electric. Super effective hits do 1.5x, resisted hits 0.5x.

## Playing

- The title parades the four Pokemon with moving sprites and coloured LEDs. A starts.
- Home: UP/DOWN selects SCAN, SWITCH LEAD, or EXIT; A confirms.
- Scan an NFC sticker to encounter its Pokemon. UP/DOWN selects a move, A attacks
  or advances dialogue, and B runs. SWITCH is available when you own another Pokemon.
- Attacks retain lunges, impact shakes/blinks, coloured particles and six-LED pulses.
  Special moves charge for 900 ms before impact. The home sprite bobs and LEDs breathe.
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
| Text files with LF, with icon | 36,018 | 12 |
| Text files with CRLF, with icon | **36,472** | **12** |
| Text files with CRLF, without icon | 31,168 | 11 |

This leaves **12,680 bytes** under the firmware's 49,152-byte sharing limit even
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
| Title | 33,586 | 30,066 |
| Home after loading gameplay | 56,610 | 46,682 |
| Battle | 56,863 | 46,935 |
| Attack | 58,228 | 47,968 |

These are post-GC live game allocations above the same mock-runtime baseline,
with flash contents held outside Lua. The attack measurement is about **18% lower**.
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
missing/invalid, not on every reopen. Startup logs `prepare: missing/invalid ...`
with the file that triggered regeneration. If this repeats, after loading run:

```
cat /littlefs/apps/hackamon/sprites10.ok
```

It should contain `10`. Capture that output and the first preparation/error log;
repeated cache loss needs diagnosis, not an assumption that a two-minute load is
normal. Existing valid version-10 sprites are byte-identical and are reused by
this update. The host suite verifies zero write calls on cached reopen.

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
  optional smaller variant. Comment and indentation removal reduce transfer bytes,
  not runtime RAM.
- `python tools/run_harness.py` (requires `pip install lupa`): **52 scenarios** across
  Lua 5.4 / 5.5 and source / deployment files. Checks cold and recipient launches,
  missing assets, migration preserving saves/icon, interrupted writes and recovery,
  invalid saves, unavailable NFC, injected setup/storage errors, missing marker
  read-back, battle/switch/capture/loss,
  repeated encounters, bounded widget creation, pixel format and actual installed size.
- `python tools/profile_memory.py --compare be431b3`: repeats the live Lua comparison
  above using the baseline commit's deployment files and the current `dist/` files.

Host tests do not replace physical-badge memory, display, callback-time, USB or
Bluetooth tests. Reference: [badge API/runtime/Share guide](https://badge.hackthenorth.com/ide/README.md).
