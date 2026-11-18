# fm1-chiptest

**Does your custom firmware actually run on the *newer* M‑VAVE FM‑1?**
Test it on **both** flash chips — before anyone flashes it to hardware.

---

## The problem

The M‑VAVE FM‑1 is a tiny, open FM synthesizer built on a JieLi AC791N chip.
Its community has exploded with custom firmware — but there's a catch hidden
under the hood.

Every FM‑1 stores its firmware in a 1 MiB SPI‑NOR flash. Until autumn 2026 that
was a **Puya P25Q80** (JEDEC `85 60 14`). Newer units — most of the ones now
shipped from AliExpress — come with a **UC25HQ80** (JEDEC `B3 60 14`) instead.

The two chips speak the *same* SPI‑NOR commands. They differ in exactly one way
that matters: **the JEDEC ID a firmware reads when it probes the chip.** A
firmware that only knows the Puya ID takes the newer unit for *unknown* — it
still boots, but **its saves stay in RAM and vanish on power‑off.** Its update
loader may even refuse to install.

For a community that flashes firmware from a browser with one click, that's the
difference between "works" and "silently loses everything you made."

## What this does

`fm1-chiptest` runs a firmware package **unchanged** in a realistic emulation of
the FM‑1 and checks, per chip, the three things that break:

| Test | Question it answers |
|---|---|
| **boot** | Does the firmware reach a running state (audio out, screen on, no crash)? |
| **save** | Does pressing `SAVE` write to flash (sector erase + page program), or only to RAM? |
| **reboot** | Does the save survive a power cycle (reload the flash image, data byte‑identical, no re‑write)? |

Pass all three on `uc25hq80` and the firmware is safe for the newer units.

## The result for Mutable Dreams 2.3

```
FM-1 chip compatibility — Mutable-Dreams-2.3.fwsc
p25q80    stock Puya P25Q80 (JEDEC 85 60 14)
  boot:   PASS   save:   PASS (16 writes)   reboot: PASS
uc25hq80  newer UC25HQ80 (JEDEC B3 60 14)
  boot:   PASS   save:   PASS (16 writes)   reboot: PASS
RESULT: ALL PASS — the firmware runs and saves on both flash chips.
```

On both chips the `SAVE` writes the same sectors (`0x0DA000`, `0x0FC000`) with the
same erase/program sequence, and the save survives a reboot **byte‑identically**.
[Mutable Dreams](https://github.com/kidbee85-beep/mutable-dreams) recognises the
`B3 60 14` ID and persists correctly on the newer hardware.

## Why this is a realistic test

This is built on [**fm1-emu**](https://github.com/joakimeriksson/fm1-emu)
(MIT) by Joakim Eriksson — an emulator that reproduces the whole FM‑1: both
`pi32v2` CPU cores (instruction set recovered by reverse engineering), timers and
interrupts, the SPI‑NOR flash, the 240×240 screen, the key matrix and encoders,
the audio output and the MIDI UART. It runs the *actual* `.fwsc` update package,
not a reimplementation.

Critically, its flash model distinguishes the two parts by exactly the thing the
hardware distinguishes — the JEDEC ID (`--flash-chip p25q80|uc25hq80`). Erase and
program are identical. So the test measures precisely what a real unit would:
**does the firmware recognise the newer chip's ID and persist to it?**

`fm1-chiptest` also shares its save test with the approach the community uses to
spot this bug: the emulator's `FM1_FLASH_TRACE` shows that a firmware which only
knows the Puya performs **no** erase/program on the newer part — its saves stay in
RAM.

## Install & use

Needs **Python 3** (present by default on macOS and Linux). On first run the tool
downloads the emulator binaries and the default firmware (Mutable Dreams 2.3) and
caches them under `~/.cache/fm1-chiptest/`.

```bash
# from a release archive (bundled emulator, works offline) or from this repo:
./fm1-chiptest
```

Test your own firmware:

```bash
./fm1-chiptest --firmware my-firmware.fwsc
```

Just the newer chip, with a machine-readable report:

```bash
./fm1-chiptest --firmware my-firmware.fwsc --chips uc25hq80 --json report.json
```

Point it at your own emulator binaries instead of downloading:

```bash
./fm1-chiptest --emu-dir path/to/fm1-emu-0.5.1-macos-arm64
```

Exit code is `0` on all‑pass and `1` otherwise, so it drops straight into CI.

## Building a release

```bash
./release.sh
```

writes to `dist/` one archive per platform (macOS arm64, Linux arm64/x86_64,
Windows x86_64) with the emulator bundled, a source‑only archive, and a
`SHA256SUMS.txt`.

## Supported platforms

| OS | Arch | Emulator |
|---|---|---|
| macOS | arm64 | bundled |
| Linux | arm64, x86_64 | bundled |
| Windows | x86_64 | bundled |
| macOS | x86_64 (Intel) | `--emu-dir` (build fm1-emu yourself) |

## License & credits

- This tool: MIT (`LICENSE`).
- Emulator: [fm1-emu](https://github.com/joakimeriksson/fm1-emu) — Joakim Eriksson, MIT.
- [m-bootloader](https://github.com/jvitkauskas/m-bootloader) — Julius Vitkauskas, MIT, is the
  recommended brick‑protection bootloader (install it separately; see its README for the
  UC25HQ80 status).
