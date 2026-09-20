# Hackamon

A Pokemon-style game for the Hack the North 2026 hacker badge. Scan NFC stickers to
meet wild Pokemon, battle them Game Boy style, and build your team.

Six small Lua files, installed through the
[badge IDE](https://badge.hackthenorth.com/ide/).

## Pokemon

Each received copy starts with Pikachu. The other four live on NFC stickers.

| Code | Pokemon | HP | Type | Attack | Effect move |
| --- | --- | --- | --- | --- | --- |
| starter | Pikachu | 35 | Electric | Quick Attack | Thunder Wave: 90% accurate; paralysis, no damage |
| `PKM01` | Charmander | 36 | Fire | Scratch | Ember: 40 power, special Fire damage, 10% burn chance |
| `PKM02` | Squirtle | 38 | Water | Tackle | Withdraw: raises physical Defense one stage, up to +6 |
| `PKM03` | Bulbasaur | 38 | Grass/Poison | Tackle | Leech Seed: 90% accurate; drains 1/8 max HP per turn |
| `PKM04` | Mewtwo | **100** | Psychic | Swift: 60 power, special Normal damage | Psystrike: 100 power, special Psychic damage against physical Defense |

Stats are fixed at level 15, neutral nature, zero IVs/EVs, except Mewtwo has the requested custom 100 HP. Quick Attack, Scratch,
and Tackle are **Normal-type physical attacks, power 40**, regardless of the
Pokemon using them. Quick Attack has +1 priority; otherwise Speed decides who
acts first, with random ties. A fainted Pokemon cannot act.

Damage uses the level/power/Attack/Defense formula, separate special stats for
Ember and Swift, an 85-100% random roll, 1.5x same-type bonus, 2x super effectiveness and
0.5x resistance. Ember is strong against Bulbasaur, resisted by Squirtle/Charmander,
and neutral against Pikachu/Mewtwo. Psystrike uses Special Attack against physical
Defense (including Withdraw), is strong against Bulbasaur's Poison typing, and is
resisted by Mewtwo. Swift uses Special Defense, has no Psychic same-type bonus,
and does not check accuracy. Both Mewtwo moves ignore the burn damage penalty.
Normal attacks have white impact particles; attack LEDs use the attacker's colour. Withdraw acts on its
user without making the opponent lunge or flash as if damaged.

Burn halves physical damage and drains 1/16 max HP each turn; Fire types cannot
burn. Paralysis halves Speed and prevents 25% of moves on either side; Electric
types cannot be paralyzed. Both persist until the encounter ends, including
through switches, and cannot coexist. Withdraw lasts until switching, affects
physical Defense (also used by Psystrike), and raises it to 1.5x at +1, 2x at +2, up to 4x at +6.
Leech Seed fails against Grass, persists until the seeded Pokemon switches,
and heals only the HP actually drained. Seed drains resolve before burn damage.

These rules follow the modern mechanics implemented by Pokemon Showdown's
[move data](https://github.com/smogon/pokemon-showdown/blob/master/data/moves.ts),
[status conditions](https://github.com/smogon/pokemon-showdown/blob/master/data/conditions.ts),
[species stats](https://github.com/smogon/pokemon-showdown/blob/master/data/pokedex.ts),
and [damage calculation](https://github.com/smogon/pokemon-showdown/blob/master/sim/battle-actions.ts).
This remains a small badge adaptation: no PP, critical hits, abilities, held items,
weather, or leveling. Winning captures the opponent; losing now preserves your collection.

## Playing

- The title parades all five Pokemon with moving sprites and coloured LEDs. A starts.
- Home: UP/DOWN selects SCAN, SWITCH LEAD, or EXIT; A confirms.
- Scan an NFC sticker to encounter its Pokemon. UP/DOWN selects a move, A attacks
  or advances dialogue, and B runs. SWITCH is available when you own another Pokemon.
- Attacks retain lunges, impact shakes/blinks and coloured particles. Special moves
  restore the original clockwise six-LED chase and automatic **1,500 ms charge**,
  followed by impact; the full effect lasts 3,200 ms. Press A once, then watch the
  charge; holding A is not required. HP bars change at impact and A cannot skip
  the animation. The home sprite bobs and LEDs breathe.
- Every encounter starts with your team healed. Winning captures a new Pokemon;
  duplicates do not change ownership. Losing returns home with your collection intact.
- Mewtwo uses purple LEDs for its normal flash, special chase, and idle animation.
  A full team's switch menu scrolls within the existing three visible rows.
- HOME returns to the home menu during play and exits from the title or interrupted
  startup. EXIT saves and leaves. Complete a normal exit before powering off.
- The enemy remains top-right and your lead bottom-left, with HP bars and dialogue.
  Both sides now reuse the same 40x40 artwork facing. The separate title wipe is gone.

## Stickers

Write the code as an NDEF **Text** record onto an NTAG215 sticker with the NFC Tools
phone app. Uppercase, no spaces.

## Install / upgrade

Use all **six files in [dist/](dist/)**. No build tools are needed to install them.
`game.lua` is new: separating gameplay from the entry file reduces launch memory.

1. Save your current IDE work. In the [badge IDE](https://badge.hackthenorth.com/ide/),
   **Import app** using `dist/hackamon.lua`, then **Replace editor files**. The importer
   creates `manifest.cfg` and `main.lua`. Keep the slug `hackamon`. See the one-time save reset below.
2. Add `game.lua`, `battle.lua`, `fx.lua`, `screens.lua`, and `gen.lua` with **+**, using
   the matching `dist/` contents and these exact filenames. Replace all six together.
3. You may keep or add the launcher image icon. This build budgets for its full 5,304 bytes.
4. **Connect > Push > Reboot**, then open Hackamon once and let preparation finish.
   The upgrade removes the eight old `s*.bin` / `m*.bin` generated sprites and old
   marker, one per tick, and writes five `p*.bin` sprites. It preserves the icon.
   The new save format starts with Pikachu once; subsequent captures persist. Let this finish **before sharing**; merely pushing code leaves old
   generated files on the badge until the game runs.
5. A starts the game. The short preparation/loading stages ignore gameplay buttons.

If Import app is absent, copy the header's `key=value` lines to `manifest.cfg` and
all code after `]==]` to `main.lua`, then add the five modules.

Do not upload repository source, tests or tooling. Unknown extra files left by other
versions are not included in the budget; inspect those individually if the device's
Share size remains larger after a completed first launch.

## Size budget

The complete installed app, **after generation**, includes code, manifest, five
40x40 RGB565 sprites, completion marker, transfer marker, and the optional full-size launcher icon:

| Configuration | Installed bytes | Files |
| --- | ---: | ---: |
| Text files with LF, with icon | 41,227 | 15 |
| Text files with CRLF, with icon | **41,270** | **15** |
| CRLF with icon, import header also retained in main.lua | 41,380 | 15 |
| Text files with CRLF, without icon | 35,966 | 14 |

This leaves **7,882 bytes** under the firmware's 49,152-byte sharing limit even
with the image icon and Windows line endings. Our build rejects anything above
**42 KiB**, including the retained-header variant, leaving at least 6 KiB below 48 KiB.
The target increased from 36 KiB to accommodate Mewtwo and transfer-safe saves. The harness also
counts the actual generated files, independently of the build's expected sizes.

The previous build was 51,931 bytes with the icon and LF. Its dependence on removing
the icon was insufficient margin. This version, including the fifth Pokemon, reduces that full bundle by about 20%.

## Runtime memory

File size and runtime RAM are separate budgets. This version also reduces RAM:

- A 3,029-byte entry file loads only startup code. Gameplay moves to `game.lua`,
  compiled after sprite generation, widget construction and title cleanup. Fixed
  registered callbacks forward events to its returned handler table. The startup
  implementation is cleared separately, so retained callback references cannot
  keep it active. Gameplay does not compile inside buttons.
- Five shared sprite files, one per Pokemon, instead of separate facing files, while retaining
  original 40x40 pixel art. Opaque RGB565 avoids indexed-alpha conversion.
- A smaller effects implementation, four preallocated particles instead of six,
  and a maximum of 17 live app widgets in the host tests. Effect widgets are created
  one per tick before play; an attack does not allocate more widgets.
- Flatter Pokemon/move data, one reusable particle style table, and no per-frame
  style-table creation. Repeated battles and HOME interruptions reuse the UI.
- Initialization functions, sprite renderer/art, screen builder and title functions
  are released when their stage is complete. Screen creation remains one widget
  per tick, separate from sprite writes and module compilation.
- Run-length encoding reduces the stored pixel descriptions. Only the current
  sprite's 400-character description is expanded when rendering begins. The original four
  resulting binary sprites are byte-identical to the previous build. The first
  launch adds Mewtwo; once all five files and the version-10 marker are present,
  later launches reuse them.
- Each append batches eight output rows (640 bytes; the first write is 652 bytes
  including the header). No complete bitmap is assembled in Lua. The
  completion marker is cleared before regeneration, so interrupted writes are retried
  on a fresh launch. Write errors and a missing marker read-back stop preparation
  with an explicit error; HOME exits safely. Recipients reuse transferred sprites
  without rebuilding them.

A repeatable **64-bit host Lua 5.5** comparison against the reported failing build,
commit `01cbf93`, gives:

| Phase | Previous live Lua bytes | New live Lua bytes |
| --- | ---: | ---: |
| Main loaded | 26,313 | 11,778 |
| Title | 34,082 | 14,425 |
| Home after loading gameplay | 53,534 | 52,329 |
| Battle | 53,851 | 53,116 |
| Attack | 54,207 | 53,472 |

These are post-GC live game allocations above the same mock-runtime baseline,
with flash contents held outside Lua. This corrected model keeps the original
registered callback references alive; older measurements did not account for
that retention. Main and title remain over **55% lower** than that failing build. Relative to
the preceding four-Pokemon build (`83f3848`), this update adds about **1.7 KiB**
of live host Lua memory at home/attack. It adds no widgets; native image widgets
still display at most two sprites at once.
Deployment whitespace compression saves transfer bytes,
not Lua runtime memory; the source remains readable in the repository root.
They are **not** total badge RAM, transient peaks, native image/widget memory,
ESP32 timing, or a claim that every low-memory badge will run the game.

A separate allocator-limited test gives entry-chunk compilation/execution only
24 KiB above its fixed host harness baseline. The new source and deploy entry
files pass in Lua 5.4 and 5.5; `01cbf93` fails under the same allowance. This is a
regression check for the smaller loader, not a measurement of total badge RAM.

The manifest's 96 KiB is a ceiling, not a reservation. It does not consume or supply
96 KiB automatically. Actual physical-badge capacity still needs verification with
the sparse `lua=... peak=... free=... widgets=...` console logs and `heap` before launch.
Do not increase the quota or delete unrelated apps as a RAM remedy.

## Why preparation was slow

The previous row-at-a-time renderer made **85 separate flash-write calls** for four
sprites. Small writes limited temporary memory, but repeatedly incurred filesystem
overhead. This renderer batches a few rows into **26 writes** for all five sprites, at most one per tick,
while keeping its write buffer under 1 KB. It caches palette conversions and uses
incremental GC during generation. A supplied device log on firmware
`v0.1.2-392-gd3089c4` reports the older four-sprite generation completing in **5,047 ms** and the next
reopen skipping generation. That verifies caching on that badge, not a timing
guarantee for every badge.

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
this update after Mewtwo is generated. The host suite verifies zero sprite writes on cached reopen.

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

The supplied log reached `title dropped` twice but never `battle loaded` in
`981cf00`. That loader replaced global lifecycle functions after launch. Keeping
the originally registered callback references in the host harness reproduces
the same stalled loading state. The entry callbacks now remain fixed and forward
to `GAME.tick`, `GAME.button`, and `GAME.exit` only after `require("game")` succeeds.
The tests use retained references for all events, assert their identities stay
unchanged, and check that exiting during NFC scanning reaches gameplay cleanup.
The previous tests resolved callback globals on every event and missed this bug.

UP/DOWN now moves the existing cursor widget with one alignment call. It does not
rebuild menu text, resize the dialogue box, or toggle other widgets per press. The
same cursor is repositioned explicitly between menu selection and dialogue cues.
With all five Pokemon captured, the switch menu has four choices: only crossing
a visible-row boundary also updates the text (at most two UI calls). The host
suite exercises 300 presses per menu and checks both bounds.

The title releases its resources before game loading and no longer calls the
full home-screen update from its animation tick. Failures during title cleanup,
module loading, particle setup or home rendering leave an exit state; HOME exits
instead of retrying partially completed cleanup. HOME can also cancel startup.

These changes reduce avoidable UI work and repair fragile error paths; they do
not establish the cause of a freeze on an untested receiver. Startup now logs
`badge.sys.version()` with memory counters. If a receiving badge freezes, record
whether LEDs/sprites still animate and capture its firmware line and first
`script_app` error. Firmware callback deadlines and available native heap can differ.

## Saves and fresh transfers

The team is stored in `appdata/team`, which Share never sends. A small random
`trainer.id` marker travels with the app. On launch, the marker must match the
private save; otherwise the game starts with only Pikachu and writes a new marker.
That makes normal badge-to-badge transfers, repeated transfers over an existing
recipient, and onward sharing start fresh. Reopening the same badge restores its
captured Pokemon and selected lead. Losses keep the collection too.

**The first launch of this update resets old saves once.** Older saves have no
marker to distinguish a local collection from stale recipient data. Subsequent
IDE code updates preserve progress provided `trainer.id` and `appdata/team` remain.
The game verifies save writes and reports a storage failure instead of silently
claiming that progress was saved. Do not manually upload someone else's private data.

The marker identifies a played copy, not a firmware installation event. A byte-for-byte
copy returned to its original badge without being opened on another badge still
has that badge's marker and cannot be distinguished from reopening. The app API
exposes no installation event. Ordinary recipient launches replace the marker,
which is what enables fresh starts on subsequent transfers.

## Share and verify

After the first launch completes, use **Share > Send an app > Hackamon > A: offer app**.
The receiver opens **Share > Receive an app** and accepts. On current firmware,
Share reboots around radio use. Personal team saves are not transferred.

Check the size shown by Share after migration, then test launch, SCAN, a battle,
HOME during dialogue, another battle, exit/reopen, and onward sharing on the friend?s
badge. Firmware versions, available native heap and fragmentation still differ.

## Developer checks

- `python tools/build.py`: regenerates `dist/`; budgets for the icon and CRLF by
  default; enforces the 42 KiB target and 16-file limit. `--without-icon` reports the
  optional smaller variant. Token-preserving whitespace removal and line grouping
  reduce transfer bytes, not runtime RAM. Strings and sprite artwork are preserved.
- `python tools/run_harness.py` (requires `pip install lupa`): **152 scenarios** across
  Lua 5.4 / 5.5 and source / deployment files. Checks cold and recipient launches,
  missing assets, migration preserving saves/icon, interrupted writes and recovery,
  invalid saves, unavailable NFC, injected setup/storage errors, missing marker
  read-back, title/game-loading/home failures, stable registered callbacks,
  NFC cleanup via the registered exit, HOME escape, cursor stress tests,
  battle/switch/capture/loss, fifth-Pokemon scrolling and purple LEDs,
  separate-runtime reopens, captures persisting, sender/receiver save isolation,
  retransfer over an existing save, onward/return sharing, and save-write failures,
  repeated encounters, bounded widget creation, pixel format and actual installed size.
  Also checks all six chase positions, one LED latch per frame, the charge delay,
  HP/impact synchronization and protection against skipping a special animation.
- `python tools/check_battle.py`: deterministic damage, accuracy, status, priority,
  switching, type immunity and stat tests on both Lua versions and source/dist;
  checks whitespace compaction against numeric, quoted and operator edge cases.
- `python tools/check_startup.py`: limits entry-chunk compilation/execution to
  24 KiB above a fixed host baseline and compares the original four generated sprite files to
  commit `01cbf93`, with one new Mewtwo sprite. The old entry chunk fails that allowance; the new one passes.
- `python tools/profile_memory.py --compare 01cbf93`: repeats the live Lua comparison
  above using the baseline commit's deployment files and the current `dist/` files.

Host tests do not replace physical-badge memory, display, callback-time, USB or
Bluetooth tests. Reference: [badge API/runtime/Share guide](https://badge.hackthenorth.com/ide/README.md).
