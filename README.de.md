# fm1-chiptest

**Läuft deine Custom‑Firmware wirklich auf dem *neueren* M‑VAVE FM‑1?**
Teste sie auf **beiden** Flash‑Chips — bevor sie jemand auf Hardware flasht.

---

## Das Problem

Der M‑VAVE FM‑1 ist ein kleiner, offener FM‑Synthesizer auf einem JieLi AC791N.
Seine Community hat eine Flut an Custom‑Firmware hervorgebracht — mit einem Haken
unter der Haube.

Jeder FM‑1 speichert seine Firmware in einem 1 MiB SPI‑NOR‑Flash. Bis Herbst 2026
war das ein **Puya P25Q80** (JEDEC `85 60 14`). Neuere Geräte — die meisten, die
jetzt über AliExpress verschickt werden — tragen stattdessen einen **UC25HQ80**
(JEDEC `B3 60 14`).

Der Emulator modelliert die üblichen SPI‑NOR-Erase-/Program-Kommandos für beide
Bausteine und variiert **die JEDEC-ID, die eine Firmware beim Erkennen liest**.
Damit wird eine bekannte Kompatibilitätsprüfung isoliert. Elektrisches Verhalten,
Timing und Schutzfunktionen realer Chips sind damit nicht vollständig geprüft.
Eine Firmware, die nur die Puya‑ID kennt, hält das neuere Gerät für *unbekannt* —
sie bootet zwar, aber **ihre Saves bleiben im RAM und verschwinden beim
Ausschalten.** Der Installer verweigert unter Umständen sogar die Installation.

Für eine Community, die Firmware per Browser mit einem Klick flasht, ist das der
Unterschied zwischen „funktioniert" und „verliert stillschweigend alles, was du
gemacht hast."

## Was das Tool macht

`fm1-chiptest` führt ein Firmware‑Paket **unverändert** in einer realistischen
Emulation des FM‑1 aus und prüft pro Chip die drei Dinge, die kaputtgehen:

| Test | Beantwortete Frage |
|---|---|
| **boot** | Erreicht die Firmware einen laufenden Zustand (Audio, Display an, kein Absturz)? |
| **save** | Schreibt `SAVE` wirklich ins Flash (Sektor‑Erase + Page‑Program) — oder nur ins RAM? |
| **reboot** | Übersteht der Speicherstand einen Neustart (Flash‑Image neu geladen, Daten byte‑identisch, kein Re‑Write)? |

Alle drei Tests auf `uc25hq80` bestätigen den modellierten Boot-/Save-/Neustartpfad.
Sie sind **keine Sicherheits- oder Kompatibilitätsgarantie für echte Hardware**.
Die Prüfung auf einem realen UC25HQ80-FM-1 bleibt offen:
[Hardware-Testaufruf](https://github.com/kidbee85-beep/mutable-dreams/issues/21).
Vor einem Gerätetest Nutzerdaten sichern und den Bootloader-Status getrennt prüfen.

## Das Ergebnis für Mutable Dreams 2.3

```
p25q80    stock Puya P25Q80 (JEDEC 85 60 14)
  boot: PASS   save: PASS (16 writes)   reboot: PASS
uc25hq80  neuer UC25HQ80 (JEDEC B3 60 14)
  boot: PASS   save: PASS (16 writes)   reboot: PASS
RESULT: ALL PASS
```

Auf beiden Chips schreibt `SAVE` dieselben Sektoren (`0x0DA000`, `0x0FC000`) mit
derselben Erase/Program‑Folge, und der Speicherstand übersteht den Neustart
**byte‑identisch**. [Mutable Dreams](https://github.com/kidbee85-beep/mutable-dreams)
erkennt die neue ID und speichert im modellierten UC25HQ80-Flash korrekt.
Eine entsprechende Bestätigung von Speichern und stromlosem Neustart auf dem
realen UC25HQ80-Gerät liegt noch nicht vor.

## Warum der Test realistisch ist

Basis ist [**fm1-emu**](https://github.com/joakimeriksson/fm1-emu) (MIT) von
Joakim Eriksson — ein Emulator, der den kompletten FM‑1 nachbildet: beide
`pi32v2`‑CPU‑Kerne (Befehlssatz per Reverse Engineering rekonstruiert), Timer und
Interrupts, das SPI‑NOR‑Flash, das 240×240‑Display, Tastenmatrix und Encoder, den
Audio‑Ausgang und den MIDI‑UART. Er führt das *echte* `.fwsc`‑Update‑Paket aus,
keine Neuimplementierung.

Die beiden konfigurierten Flash-Modelle verwenden unterschiedliche JEDEC-IDs
(`--flash-chip p25q80|uc25hq80`) und dasselbe modellierte Erase-/Program-Verhalten.
Der Test isoliert damit **ob die Firmware die jeweilige konfigurierte ID erkennt
und Daten in diesem Modell dauerhaft speichert**. Reales Chip-Timing, elektrische
Eigenschaften, Schutzregister und tatsächlicher Stromverlust werden damit nicht
gemessen; dafür sind separate Hardwaretests erforderlich.

## Installation & Benutzung

Voraussetzung: **Python 3** (auf macOS und Linux standardmäßig vorhanden). Beim
ersten Lauf lädt das Tool die Emulator‑Binaries und die Standard‑Firmware
(Mutable Dreams 2.3) herunter und cacht sie unter `~/.cache/fm1-chiptest/`.

```bash
./fm1-chiptest                                  # Mutable Dreams 2.3 auf beiden Chips
./fm1-chiptest --firmware meine-firmware.fwsc   # eigene Firmware
./fm1-chiptest --firmware meine.fwsc --chips uc25hq80 --json report.json
```

Exit‑Code `0` = alles bestanden, sonst `1` (CI‑tauglich).

## Release bauen

```bash
./release.sh
```

schreibt nach `dist/` je Plattform ein Archiv (macOS arm64, Linux arm64/x86_64,
Windows x86_64) mit gebündeltem Emulator, ein reines Source‑Archiv und eine
`SHA256SUMS.txt`.

## Lizenz & Credits

- Dieses Tool: MIT (`LICENSE`).
- Emulator: [fm1-emu](https://github.com/joakimeriksson/fm1-emu) — Joakim Eriksson, MIT.
- [m-bootloader](https://github.com/jvitkauskas/m-bootloader) — Julius Vitkauskas, MIT —
  der empfohlene Brick‑Schutz (separat installieren; siehe dessen README zum UC25HQ80‑Status).
