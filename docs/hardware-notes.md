# Hardware notes

Measured on a Hack the North 2026 badge running firmware `v0.1.2-392-gd3089c4`
(ESP-IDF 5.5.3, built 2026-09-17). Numbers come from the IDE console.

## The badge

- ESP32-C3, single core, about 160 KB of RAM total, 4 MB flash.
- 320x240 colour LCD, D-pad, A, B, Home, Start, six RGB LEDs, accelerometer.
- FM17522-class NFC reader. Reads ISO 14443A tags. Read only from Lua.
- Bluetooth Low Energy, exposed to Lua as a 44-byte broadcast channel.

## Memory budget

| Moment | Free heap | Largest block |
| --- | --- | --- |
| Launcher closes, app about to start | 77,744 | 63,488 |
| Bare Lua VM started (tiny main.lua) | 54,336 | 38,912 |
| After Bluetooth init | 3,964 | |
| Share app after Bluetooth init, no Lua | 27,308 | |

So:

- The Lua VM itself costs about 18 KB before any app code.
- Bluetooth costs about 50 KB and needs a large contiguous block to start.
- Compiling Lua costs roughly 2.5 times the source size at peak. A 12.8 KB file
  compiled. A 16 KB file died at 41 KB used.
- NFC has no visible RAM cost. A 9 KB game with NFC scanning runs fine.

## What this means for apps

- **Radio apps must be tiny.** The radio must start before anything big is compiled,
  and after it starts there is about 4 KB left. In practice that means one file under
  about 2 KB, which is what the organizers' own Nearby Hello demo is.
- **A loader that starts the radio then requires the game does not work.** The
  radio starts fine, but the game module then has nothing to compile into.
- **After any radio app, power cycle the badge.** Bluetooth stays resident until reboot.
  A later app, even a 1 KB one, will fail with `Lua memory limit exceeded` at around
  17 KB used. The firmware reboots after the built-in Share app for the same reason.
- **`heap_kb=96` does nothing useful.** It is a quota, not a reservation.
- **Keep `main.lua` under about 10 KB** for non-radio apps to leave compile headroom.

## Failure signatures

| Console line | Meaning |
| --- | --- |
| `BLE_INIT: Malloc failed` then a panic | Radio started with under about 20 KB contiguous. Reboot, shrink the app. |
| `BLE_INIT: hci inits failed` | Same, radio failed cleanly. |
| `Lua memory limit exceeded (used 17xxx ...)` on a tiny app | Bluetooth still resident. Power cycle. |
| `Lua memory limit exceeded` in `main.lua` on a big app | Compile peak too large. Shrink the source. |
| `main.lua is not a regular file` | Workspace code file has the wrong name. |
| `manifest.cfg is missing a slug= line` | Header was pasted into main.lua, not imported. |
