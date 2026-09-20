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

- Launch: a title screen where the four Pokemon parade across a night sky, each posing
  on a cream stage with its element's LED colour. A wipes to the home screen.
  Original pixel art is rendered at a crisp 2x scale (40x40 instead of 44x44).
- HOME returns to the home screen from anywhere. **EXIT** on the home menu leaves the
  game after saving your team. HOME during the title exits; input is briefly locked
  during sprite preparation and the transition to gameplay.
- Home: **SCAN** turns on the NFC reader. **SWITCH LEAD** picks which Pokemon goes first.
- Hold a sticker to the back of the badge. A wild Pokemon appears.
- Battle: UP/DOWN pick a move, A uses it, B runs. A advances the dialogue, and HP bars
  drop in step with the text. The attacker lunges, the target shakes and blinks, and
  the LEDs play in the move's colour. Attack moves are quick: a triple flash and an instant
  hit. Special moves are long: three laps around the LED ring, then all six hold for the
  impact. The struck Pokemon blinks and flames, bubbles, leaves or sparks burst over it.
- **SWITCH** appears in the battle menu once you own more than one Pokemon. Switching
  uses your turn.
- Every battle starts with your whole team at full HP.
- Beat a wild Pokemon you don't own and it joins your team. Beat one you already own and
  nothing changes, no duplicates.
- If any of your Pokemon faints, you lose the whole team and start over with Pikachu.

## Screen layout

Enemy sprite top-right with its name and HP bar top-left. Your Pokemon bottom-left,
mirrored to face the enemy, with its name, HP bar and numbers bottom-right. Dialogue box
along the bottom: messages on the left, move menu on the right.

## Stickers

Write the code as an NDEF **Text** record onto an NTAG215 sticker with the NFC Tools
phone app. Uppercase, no spaces.

## Installing the memory update

Use the ready-built files in **[dist/](dist/)**. No Python installation is needed
unless you edit the game. The default uses the `PKM` text icon, not `icon.bin`.

1. Save your current IDE files first. Open the [badge IDE](https://badge.hackthenorth.com/ide/).
2. **Import app**, choose `dist/hackamon.lua`, then **Replace editor files**.
   Keep the slug `hackamon` to retain your team save.
3. Add `battle.lua`, `fx.lua`, `screens.lua`, and `gen.lua` with **+**, pasting
   the contents of the matching `dist/` files. Keep these exact filenames.
4. Do not add an image icon: it would put this version over the Share size cap.
5. Badge off, USB data cable in, badge on. **Connect**, choose **USB JTAG/serial
   debug unit**, then **Push**. Reboot once for this update, especially if the
   badge has just shown a memory error or its runtime manifest changed.
6. Open Hackamon. The first launch creates the new sprites in small batches;
   subsequent launches and recipients reuse them. Wait for the title, press A,
   and let the brief transition finish before choosing SCAN.

If Import app is absent, put only the header's `key=value` lines in
`manifest.cfg` and everything after `]==]` in `main.lua`, then add the four modules.

**Updating a badge with the old image icon:** Push does not remove remote files.
To use this version's text icon and stay under the sharing cap, enter these exact
commands separately in the IDE console:

```
rm /littlefs/apps/hackamon/icon.bin
reload
```

This removes only the optional Hackamon launcher picture; the `PKM` text icon
replaces it. Do not delete saves or other apps. If earlier versions left other
files in this app directory, inspect them before removing anything; the build's
size calculation assumes only the listed deployment files and generated assets.

## What changed for memory

The reported `on_button` error showed 52,423 bytes used, a 98,304-byte limit,
and a 55,563-byte peak. This does **not** prove the quota was reached: the firmware
uses the same message for a failed system allocation, and the failed request is
not included in those counters. The exact failed allocation needs the device log.
Increasing the already-maximal manifest quota is not a fix.

- **Opaque sprites:** both facings now use RGB565, with the cream background
  baked in. The title's cream stage matches it. This avoids the old indexed-alpha
  conversion path. An old 44x44 ARGB8888 decode needs 7,744 pixel bytes; a new
  40x40 RGB565 image contains 3,200 pixel bytes. LVGL can stream RGB files when
  configured for partial decoding; actual buffers/cache use depend on firmware.
- **Bounded generation:** two output rows (160 bytes) per append instead of
  retaining a complete 3,884-byte file plus its concatenation. The renderer and
  art table are released before gameplay. This is a buffer bound, not total Lua RAM.
- **Safe transition:** the title no longer enables the home menu halfway through
  its wipe. Battle/effects modules load on separate ticks after title resources
  are released, before NFC is enabled. No button callback compiles a module.
- **Bounded effects:** six reusable particle widgets, one reusable particle-style
  table, and animation updates no more than roughly 30 per second. Game speed
  remains clock-based. The host harness peaks at 19 live app widgets.
- **Clean cancellation:** HOME clears unfinished dialogue, callbacks, and battle
  state; repeated encounters cannot inherit old messages.
- **Share-aware assets:** `sprites9.ok` and the eight sprite files travel with the
  app. A fresh recipient no longer rebuilds correct sprites just because private
  store values were not transferred. A missing asset triggers regeneration.

The 96 KiB quota is retained as a ceiling, not a RAM reservation or a guarantee.
There is no supported heap setting above 96. Sparse console logs at load phases
report Lua used/peak bytes, free system heap, and widget count.

References: [badge runtime and Share guide](https://badge.hackthenorth.com/ide/README.md),
[LVGL v9 binary decoder](https://github.com/lvgl/lvgl/blob/release/v9.2/src/libs/bin_decoder/lv_bin_decoder.c).
The decoder reference explains the format tradeoff; it does not establish which
LVGL configuration a particular badge runs.

## Sharing to friends

The default bundle after sprite generation is **46,012 bytes in 15 files**,
including manifest, five Lua files, eight sprites, and the completion marker.
It leaves **3,140 bytes** under Share's **49,152-byte / 16-file** cap.
The optional image icon would increase it to 51,316 bytes, which is too large.
Before generation the uploaded code/config is 20,315 bytes.

On current firmware, use **Share > Send an app > Hackamon > A: offer app**.
Your friend opens **Share > Receive an app** and accepts the incoming app.
Wait for completion, return to the launcher, and open Hackamon. The friend can
then share the same app onward; personal team saves are not transferred.
There is no recipient-count limit stated in the guide. Each receiver still needs
compatible firmware, enough storage, and sufficient free system RAM.

Test the first sender-to-friend transfer and an onward friend-to-friend transfer.
On both badges, try launch, immediate A presses through the title transition,
SCAN, a battle, HOME mid-dialogue, another battle, and exit/reopen. If it fails,
record the first error and preceding `lua=... peak=... free=... widgets=...` lines.
The console's `heap` command before launch also helps distinguish available system
RAM from the app quota. A reboot is a diagnostic recovery step, not a guarantee.

## Building and testing

`python tools/build.py` refreshes the five deployment files and checks the full
post-generation Share bundle using the actual manifest size. Comments are stripped
for transfer size; stripping them is not a runtime-memory optimization.
`python tools/build.py --with-icon` intentionally fails for this build.

`python tools/run_harness.py` (requires `pip install lupa`) runs 20 scenarios across
Lua 5.4 and 5.5, against both source and deployment files:

- Cold launch, a fresh recipient using received assets, missing-asset recovery,
  invalid-save recovery, and unavailable NFC.
- Button presses during the wipe/loading phase, repeated HOME interruptions,
  attacks and elemental animations, switching, capture, duplicate capture,
  loss/reset, saving, and exit.
- Sprite headers, dimensions, exact mirroring, maximum write size, no module
  compilation in button callbacks, title release before gameplay loading,
  and particle/widget reuse through repeated encounters.

These are host tests with mocked badge APIs. They do not measure native image
allocation, ESP32 heap fragmentation, callback timing, appearance on the physical
screen, USB upload, or Bluetooth transfer. Hardware validation is still required.
